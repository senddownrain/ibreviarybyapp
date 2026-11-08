import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/content/content_updater.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/movable_feasts.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';

import 'support/legacy_high_priest_baseline.dart';

const _id = 'feast-christthehighpriest';
const _suffixes = [
  'Hymn',
  'Ant1',
  'Ant2',
  'Ant3',
  'Ps1',
  'Ps2',
  'Ps3',
  'R',
  'Pr',
];
final _canonical = Map<String, dynamic>.from(
  (jsonDecode(
            File(
              'content-patches/christ-high-priest-daytime-by.json',
            ).readAsStringSync(),
          )
          as Map)['fields']
      as Map,
);

LiturgicalDay _day(Map<String, dynamic> data) => LiturgicalDay.fromMap(data);
LiturgicalDay _period() => _day({
  'id': 'ordinary-w8-d5',
  'laudesHymn': 'weekday Lauds',
  for (final h in [1, 2, 3])
    for (final s in _suffixes) 'sext$h$s': 'weekday:$h:$s',
});
String _text(Object? html) => parseFragment(
  html?.toString() ?? '',
).text!.replaceAll(RegExp(r'\s+'), ' ').trim();

class _Remote implements ContentRemote {
  _Remote(this.docs, this.version);
  final Map<String, Map<String, dynamic>> docs;
  final int version;
  Map<String, dynamic>? corrupt;
  final fetched = <String>[];
  Map<String, String> get hashes =>
      docs.map((id, doc) => MapEntry(id, documentHash(doc)));

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
    return {for (final id in ids) id: corrupt ?? docs[id]!};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'canonical source has three independent readings, antiphons and K/N',
    () {
      expect(_canonical, hasLength(15));
      for (final (h, reference) in [
        (1, 'Гбр 7, 26-27'),
        (2, '1 П 2, 4-5'),
        (3, '1 П 2, 9-10'),
      ]) {
        expect(_canonical['sext${h}R'], contains(reference));
        expect(_canonical['sext${h}R'], contains('К.</span>'));
        expect(_canonical['sext${h}R'], contains('Н.</span>'));
        expect(_canonical['sext${h}Ant2'], '');
        expect(_canonical['sext${h}Ant3'], '');
        expect(_canonical['sext${h}Pr'], _canonical['sext1Pr']);
      }
      expect({
        for (final h in [1, 2, 3]) _canonical['sext${h}R'],
      }, hasLength(3));
      expect({
        for (final h in [1, 2, 3]) _canonical['sext${h}Ant1'],
      }, hasLength(3));
    },
  );

  test(
    'empty fields and stale references cannot destroy a supplied Proper',
    () {
      final proper = _day({
        'id': _id,
        '_rank': 'festum',
        ..._canonical,
        'laudesHymn': '',
        'officeOfReadingsHymn': null,
        'vesperPr': '',
        'sext1Hymn': '',
        'sext2Hymn': null,
        'sext3Hymn': '<p>[from-day]</p>',
        'sext1Ps1': null,
        'sext2Ps2': '',
        'sext3Ps3': 'from-day',
        '_fromDayFields': [..._canonical.keys, 'sext1Ps1'],
      });
      final period = _period();
      final resolved = resolveMovableFeastAgainstPeriod(proper, period, _id);
      final again = resolveDayAgainstPeriod(resolved, period)!;
      for (final h in [1, 2, 3]) {
        for (final s in ['Hymn', 'Ps1', 'Ps2', 'Ps3']) {
          expect(daytimeHourField(again, h, s), 'weekday:$h:$s');
        }
        for (final s in ['Ant1', 'Ant2', 'Ant3', 'R', 'Pr']) {
          expect(daytimeHourField(again, h, s), _canonical['sext$h$s']);
        }
      }
      expect(again.field('laudesHymn'), '');
      expect(again.field('officeOfReadingsHymn'), isNull);
      expect(again.field('vesperPr'), '');
    },
  );

  test(
    'another movable feast shares Terce Proper and uses its Lauds collect',
    () {
      final resolved = resolveMovableFeastAgainstPeriod(
        _day({
          'id': 'other',
          '_rank': 'festum',
          'laudesPr': 'own Lauds collect',
          'sext1Ant1': 'own antiphon',
          'sext1Ant2': '',
          'sext1Ant3': '',
          'sext1R': 'own reading',
          'sext2R': '',
          'sext1Pr': '',
          'sext2Pr': '',
          'sext3Pr': '',
        }),
        _period(),
        'other',
      );
      for (final h in [1, 2, 3]) {
        expect(daytimeHourField(resolved, h, 'R'), 'own reading');
        expect(daytimeHourField(resolved, h, 'Ant1'), 'own antiphon');
        expect(daytimeHourField(resolved, h, 'Ant2'), '');
        expect(daytimeHourField(resolved, h, 'Ant3'), '');
        expect(daytimeHourField(resolved, h, 'Pr'), 'own Lauds collect');
      }
      final missingReading = resolveMovableFeastAgainstPeriod(
        _day({'id': 'other', '_rank': 'feast', 'sext1R': ''}),
        _period(),
        'other',
      );
      expect(daytimeHourField(missingReading, 1, 'R'), '');
    },
  );

  test('single antiphon in Sext/None never borrows Terce Ant2/Ant3', () {
    final day = _day({
      'id': 'mixed',
      'sext1Ant1': 'first',
      'sext1Ant2': 'second',
      'sext1Ant3': 'third',
      for (final h in [2, 3]) ...{
        'sext${h}Ant1': 'own:$h',
        'sext${h}Ant2': '',
        'sext${h}Ant3': '',
      },
    });
    for (final h in [2, 3]) {
      expect(daytimeHourField(day, h, 'Ant1'), 'own:$h');
      expect(daytimeHourField(day, h, 'Ant2'), '');
      expect(daytimeHourField(day, h, 'Ant3'), '');
    }
  });

  test('solemnities and movable memorials retain their previous semantics', () {
    for (final rank in ['solemnitas', 'solemnity', 'memoria']) {
      final own = _day({
        'id': 'other',
        '_rank': rank,
        'sext1Ps1': '',
        'sext2Pr': '',
        'laudesHymn': '',
      });
      expect(
        resolveMovableFeastAgainstPeriod(own, _period(), 'other').toMap(),
        resolveDayAgainstPeriod(own, _period())!.toMap(),
      );
    }
    // A contradictory explicit rank must not enable feast inheritance.
    expect(
      resolveMovableFeastAgainstPeriod(
        _day({'id': _id, '_rank': 'solemnitas', 'sext1Ps1': ''}),
        _period(),
        _id,
      ).field('sext1Ps1'),
      '',
    );
  });

  test('legacy feast-type rank is used when the rank field is empty', () {
    final result = resolveMovableFeastAgainstPeriod(
      _day({
        'id': 'other',
        '_rank': '',
        '_feastType': 'festum',
        'sext1Ps1': null,
      }),
      _period(),
      'other',
    );
    expect(result.field('sext1Ps1'), 'weekday:1:Ps1');
  });

  test('daytime single-antiphon exclusions cannot change the other Hours', () {
    final period = _day({
      ..._period().toMap(),
      for (final prefix in ['laudes', 'vesper', 'officeOfReadings']) ...{
        '${prefix}Ant2': 'weekday second antiphon',
        '${prefix}Ant3': 'weekday third antiphon',
      },
    });
    final proper = _day({
      'id': 'other',
      '_rank': 'festum',
      for (final prefix in ['laudes', 'vesper', 'officeOfReadings']) ...{
        '${prefix}Ant1': 'own first antiphon',
        '${prefix}Ant2': '[from-day]',
        '${prefix}Ant3': null,
      },
    });
    final previous = resolveDayAgainstPeriod(proper, period)!;
    final resolved = resolveMovableFeastAgainstPeriod(proper, period, 'other');
    for (final field in previous.data.keys.where(
      (field) => !field.startsWith('sext'),
    )) {
      expect(resolved.data[field], previous.data[field], reason: field);
    }
  });

  group('real offline bundle and ContentUpdater', () {
    late Directory directory;
    Future<void> open() async {
      await HiveService.init(path: directory.path, loadBundle: true);
      await ContentStore.instance.ensureLoaded(kLiturgicalCollections);
      await ContentStore.instance.idle();
    }

    LiturgicalDay feast([DateTime? date, String diocese = 'pinsk']) {
      final content = LiturgicalContentService().contentForDate(
        date ?? DateTime(2026, 5, 28),
        diocese: diocese,
      );
      expect(content.ordo.primary.id, 'christ-the-high-priest');
      return content.options
          .firstWhere((o) => o.optionId == 'christ-the-high-priest')
          .day!;
    }

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('high-priest-');
      await open();
    });
    tearDown(() async {
      await ContentStore.instance.idle();
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test('28 May 2026 Pinsk: all three hours from the current bundle', () {
      final actual = feast();
      final raw = Map<String, dynamic>.from(
        HiveService.daysBox.get(_id) as Map,
      );
      expect(documentHash(raw), '82cc1163da5f1e12');
      expect(HiveService.daysBox.overlayLength, 0);
      final period = resolvePeriodDayAgainstPsalter(
        _day(
          Map<String, dynamic>.from(
            HiveService.daysBox.get('ordinary-w8-d5') as Map,
          ),
        ),
        _day(
          Map<String, dynamic>.from(
            HiveService.daysBox.get('ordinary-w4-d5') as Map,
          ),
        ),
      )!;
      for (final h in [1, 2, 3]) {
        for (final s in ['Hymn', 'Ps1', 'Ps2', 'Ps3']) {
          expect(
            daytimeHourField(actual, h, s),
            daytimeHourField(period, h, s),
          );
          expect(daytimeHourField(actual, h, s), isNotEmpty);
        }
        for (final s in ['R', 'Ant1']) {
          expect(
            _text(daytimeHourField(actual, h, s)),
            _text(_canonical['sext$h$s']),
          );
        }
        expect(daytimeHourField(actual, h, 'Ant2'), '');
        expect(daytimeHourField(actual, h, 'Ant3'), '');
        expect(actual.field('sext${h}Pr'), raw['laudesPr']);
      }
      final previous = resolveDayAgainstPeriod(_day(raw), period)!;
      for (final field in previous.data.keys.where(
        (f) => !f.startsWith('sext'),
      )) {
        expect(actual.data[field], previous.data[field], reason: field);
      }
    });

    test('movable date in every diocese, 2025–2035 (including 2027)', () {
      for (var year = 2025; year <= 2035; year++) {
        final anchors = YearAnchors.compute(year);
        final date = dateOfIso(addDays(anchors.pentecost, 4));
        for (final diocese in ['pinsk', 'grodno', 'vitebsk', 'minsk-mohilev']) {
          final actual = feast(date, diocese);
          for (final h in [1, 2, 3]) {
            expect(
              _text(actual.field('sext${h}R')),
              _text(_canonical['sext${h}R']),
            );
            expect(
              daytimeHourField(actual, h, 'Ps1'),
              isNotEmpty,
              reason: '$date $diocese $h',
            );
          }
        }
      }
    });

    test(
      'safe patch is verified, survives restart, and later text wins',
      () async {
        // Exercise the old-app migration, not the already updated bundle.
        await installLegacyHighPriestBaseline();
        final plan =
            jsonDecode(
                  File(
                    'reports/liturgy/christ-high-priest-daytime-patch.json',
                  ).readAsStringSync(),
                )
                as Map;
        final update = (plan['updates'] as List).single as Map;
        final before = Map<String, dynamic>.from(
          HiveService.daysBox.get(_id) as Map,
        );
        expect(documentHash(before), update['preconditionHash']);
        final after = {
          ...before,
          ...Map<String, dynamic>.from(update['set'] as Map),
        };
        expect(documentHash(after), update['resultHash']);
        final docs = {
          for (final id in HiveService.daysBox.keys)
            id: Map<String, dynamic>.from(HiveService.daysBox.get(id) as Map),
        };
        docs[_id] = after;
        final remote = _Remote(
          docs,
          HiveService.daysBox.baselineVersion + 1000,
        );
        final updater = ContentUpdater(remote: remote);
        final check = await updater.check();
        expect(check.kind, ContentCheckKind.patch);
        expect(check.plan!.documents, 1);
        expect(check.plan!.isRebuildSized, isFalse);
        remote.corrupt = {...after, 'sext1R': 'corrupt transport'};
        await expectLater(
          updater.apply(check.plan!),
          throwsA(isA<ContentUpdateRejected>()),
        );
        expect(HiveService.daysBox.overlayLength, 0);
        remote.corrupt = null;
        await updater.apply(check.plan!);
        expect(remote.fetched.toSet(), {_id});
        expect((await updater.check()).kind, ContentCheckKind.current);
        for (final entry in _canonical.entries) {
          expect(feast().data[entry.key], before[entry.key] ?? '');
        }
        // Explicit markers also fix older resolvers (before this Dart change).
        final oldResolver = resolveDayAgainstPeriod(_day(after), _period())!;
        for (final h in [1, 2, 3]) {
          expect(daytimeHourField(oldResolver, h, 'Ps1'), 'weekday:$h:Ps1');
          expect(daytimeHourField(oldResolver, h, 'R'), before['sext${h}R']);
        }
        await Hive.close();
        await open();
        for (final entry in _canonical.entries) {
          expect(feast().data[entry.key], before[entry.key] ?? '');
        }
        // A subsequent reviewed patch is the only content authority. No runtime
        // JSON overlay can mask it. Reuse a real supplied reading as the marker.
        docs[_id] = {...after, 'sext2R': _canonical['sext3R']};
        final next = ContentUpdater(
          remote: _Remote(docs, remote.version + 1000),
        );
        await next.apply((await next.check()).plan!);
        expect(feast().field('sext2R'), _canonical['sext3R']);
        expect(feast().field('sext1R'), before['sext1R']);
      },
    );
  });
}
