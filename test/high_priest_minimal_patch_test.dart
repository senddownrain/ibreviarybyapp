// Run unchanged on PR #63 AND its original base 2420c45. Only stable APIs are
// used: the legacy run exercises the real old ContentService/Store/Updater.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/content/content_updater.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';

const _id = 'feast-christthehighpriest';
final _referenceFields = {
  for (final h in [1, 2, 3])
    for (final s in ['Hymn', 'Ps1', 'Ps2', 'Ps3']) 'sext$h$s',
};
String _text(Object? html) => parseFragment(
  // Keep paragraph/line boundaries when comparing historical Web HTML
  // with the exact approved PR255 strings (their SHA checks are separate).
  (html?.toString() ?? '').replaceAll(
    RegExp(r'<(?:br\s*/?|/?p)(?:\s[^>]*)?>', caseSensitive: false),
    ' ',
  ),
).text!.replaceAll(RegExp(r'\s+'), ' ').trim();

class _PatchRemote implements ContentRemote {
  _PatchRemote(this.docs, this.version);
  final Map<String, Map<String, dynamic>> docs;
  final int version;
  late final hashes = docs.map((id, doc) => MapEntry(id, documentHash(doc)));
  final fetched = <String>[];

  @override
  Future<Map<String, dynamic>?> fetchCurrent() async => {
    'schemaVersion': kContentSchemaVersion,
    'contentVersion': version,
    'collections': {
      'days': {'digest': contentDigest(hashes)},
    },
  };
  @override
  Future<Map<String, dynamic>?> fetchCollectionManifest(
    String collection,
  ) async => {
    'digest': contentDigest(hashes),
    'hashes': hashes,
    'sizes': {
      for (final e in docs.entries)
        e.key: utf8.encode(jsonEncode(e.value)).length,
    },
  };
  @override
  Future<Map<String, Map<String, dynamic>>> fetchDocuments(
    String collection,
    List<String> ids,
  ) async {
    fetched.addAll(ids);
    return {for (final id in ids) id: docs[id]!};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'minimal 12-field patch: real service/updater, complete Proper, '
    '44-date parity and offline restart (also runs on pre-PR Flutter)',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'minimal-daytime-',
      );
      Future<void> open() async {
        await HiveService.init(path: directory.path, loadBundle: true);
        await ContentStore.instance.ensureLoaded(kLiturgicalCollections);
        await ContentStore.instance.idle();
      }

      try {
        await open();
        final before = Map<String, dynamic>.from(
          HiveService.daysBox.get(_id) as Map,
        );
        final plan =
            jsonDecode(
                  File(
                    'reports/liturgy/christ-high-priest-daytime-patch.json',
                  ).readAsStringSync(),
                )
                as Map;
        final update = (plan['updates'] as List).single as Map;
        final set = Map<String, dynamic>.from(update['set'] as Map);
        expect(set.keys.toSet(), _referenceFields);
        expect(set.values.toSet(), {'from-day'});
        expect((update['changedFields'] as List).toSet(), _referenceFields);
        expect(documentHash(before), update['preconditionHash']);
        final after = {...before, ...set};
        expect(documentHash(after), update['resultHash']);
        for (final entry in before.entries) {
          if (!_referenceFields.contains(entry.key)) {
            expect(
              after[entry.key],
              entry.value,
              reason: 'untouched source: ${entry.key}',
            );
          }
        }
        final remote = _PatchRemote({
          for (final id in HiveService.daysBox.keys)
            id: id == _id
                ? after
                : Map<String, dynamic>.from(HiveService.daysBox.get(id) as Map),
        }, HiveService.daysBox.baselineVersion + 1000);
        final updater = ContentUpdater(remote: remote);
        final check = await updater.check();
        expect(check.kind, ContentCheckKind.patch);
        expect(check.plan!.documents, 1);
        expect(check.plan!.isRebuildSized, isFalse);
        await updater.apply(check.plan!);
        expect(remote.fetched, [_id]);
        expect(HiveService.daysBox.get(_id), after);
        expect((await updater.check()).kind, ContentCheckKind.current);

        final fixture =
            jsonDecode(
                  utf8.decode(
                    gzip.decode(
                      File(
                        'test/fixtures/high_priest_daytime_parity.json.gz',
                      ).readAsBytesSync(),
                    ),
                  ),
                )
                as Map;
        final rows = (fixture['cases'] as List).cast<Map>();
        expect(rows, hasLength(44));
        void verify(Map row) {
          final content = LiturgicalContentService().contentForDate(
            DateTime.parse(row['date'] as String),
            diocese: row['diocese'] as String,
          );
          expect(content.ordo.primary.id, row['primary']);
          final day = content.options
              .firstWhere((o) => o.optionId == row['primary'])
              .day!;
          expect(row['legacyPatched'], row['patched']);
          for (final entry in (row['patched'] as Map).entries) {
            final field = entry.key as String;
            final actual = daytimeHourField(
              day,
              int.parse(field[4]),
              field.substring(5),
            );
            expect(
              actual,
              entry.value,
              reason: '${row['date']} ${row['diocese']} $field',
            );
            final web = (row['webPatched'] as Map)[field] as String;
            final difference = (row['expectedWebDifferences'] as Map)[field];
            if (difference == 'preserved-full-Lauds-conclusion') {
              expect(actual, before[field]);
              expect(day.field(field), before['laudesPr']);
              expect(_text(actual), endsWith('Амэн.'));
              const shortEnding = 'Праз Пана нашага.';
              expect(_text(web), endsWith(shortEnding));
              final prefix = _text(
                web,
              ).substring(0, _text(web).length - shortEnding.length);
              expect(
                _text(actual),
                startsWith('$prefixПраз Пана нашага Езуса Хрыста,'),
              );
            } else if (difference == 'HTML-only') {
              expect(_text(actual), _text(web));
            } else {
              expect(difference, isNull);
              expect(actual, web);
            }
          }
          for (final h in [1, 2, 3]) {
            for (final suffix in ['Ant1', 'R', 'Pr']) {
              expect(day.field('sext$h$suffix'), before['sext$h$suffix']);
            }
            for (final suffix in ['Hymn', 'Ps1', 'Ps2', 'Ps3']) {
              expect(daytimeHourField(day, h, suffix), isNotEmpty);
            }
            expect(daytimeHourField(day, h, 'Ant2'), '');
            expect(daytimeHourField(day, h, 'Ant3'), '');
          }
        }

        for (final row in rows) {
          verify(row);
        }
        await Hive.close();
        await open(); // No remote call: only the original bundle and saved overlay.
        expect(HiveService.daysBox.get(_id), after);
        verify(
          rows.singleWhere(
            (r) => r['date'] == '2026-05-28' && r['diocese'] == 'pinsk',
          ),
        );
        expect(remote.fetched, [_id]);
      } finally {
        await ContentStore.instance.idle();
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
