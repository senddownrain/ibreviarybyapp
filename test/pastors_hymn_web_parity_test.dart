// Web ↔ Flutter parity of the Pastors hymn selection: every hymn field of every
// Common (base and seasonal variants) × every pastors feast name, compared by
// hash with the mybrev `preparePastorsHymn` output
// (fixture: scripts/build_pastors_hymn_parity.mjs, no text copies).
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_alternatives.dart';
import 'package:mybrev_flutter/utils/pastors_hymn.dart';

const _seasons = ['advent', 'christmas', 'lent', 'easter'];
const _hymns = [
  'officeOfReadingsHymn',
  'laudesHymn',
  'vesperHymn',
  'vesper1Hymn',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('pastors-hymn-parity-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  String hash(String value) =>
      sha256.convert(utf8.encode(value)).toString().substring(0, 16);

  test(
    'hymn selection equals the Web for every Common hymn and feast name',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/pastors_hymn_parity.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final templates = HiveService.templates();
      String? source(String key) {
        final parts = key.split(':');
        final template = templates[parts.first];
        if (template == null) return null;
        if (parts.length == 2) return template[parts[1]] as String?;
        final variants = template['_seasonalVariants'] as Map?;
        return (variants?[parts[1]] as Map?)?[parts[2]] as String?;
      }

      final mismatches = <String>[];
      var transformed = 0;
      var seasonal = 0;
      final cases = (fixture['cases'] as List).cast<List>();
      for (final item in cases) {
        final html = source(item[0] as String);
        expect(
          html,
          isNotNull,
          reason: '${item[0]} is missing from the bundle',
        );
        final out = preparePastorsHymn(html!, item[1] as String);
        // Seasonal variants are one flattened paragraph without <hr>. Web main
        // (src/utils/pastorsHymn.js) does not assemble that layout and leaves
        // it unchanged, which the reader then splits into a bare opening and
        // one glued block. Flutter assembles four complete hymns instead (see
        // the next test); only the <hr> layout is compared with Web by hash.
        if ((item[0] as String).split(':').length == 3) {
          seasonal++;
          continue;
        }
        if (out != html) transformed++;
        if (hash(out) != item[2]) mismatches.add('${item[0]} | ${item[1]}');
      }
      expect(cases.length, greaterThan(1000));
      expect(seasonal, greaterThan(1000));
      expect(transformed, fixture['transformed']);
      expect(mismatches, isEmpty, reason: mismatches.take(8).join('\n'));
    },
  );

  test('every seasonal Pastors hymn offers four complete hymns', () {
    final templates = HiveService.templates();
    final variants = templates['pastors']!['_seasonalVariants'] as Map;
    for (final season in _seasons) {
      for (final field in _hymns) {
        final html = (variants[season] as Map)[field] as String;
        final options = getLiturgicalAlternatives(
          preparePastorsHymn(html, 'Св. Яна Паўла ІІ, папы'),
          kind: 'hymn',
        );
        expect(options.map((o) => o.title), [
          'Пра Папу',
          'Пра біскупа',
          'Пра прэзбітэра',
          'Пра некалькіх пастыраў',
        ], reason: '$season $field');
        for (final option in options) {
          expect(option.html, isNot(contains('Пра Папу:')));
          expect(option.html, contains('Амэн'));
        }
        // nothing of the stored hymn is lost: every source line is in some hymn
        final joined = options.map((o) => o.html).join('\n');
        final lines = html
            .replaceAll(RegExp(r'</?p\b[^>]*>'), '<br />')
            .split(RegExp(r'<br\s*/?>'))
            .map((line) => line.trim())
            .where(
              (line) =>
                  line.isNotEmpty && !RegExp(r'^Пра [^:]+:$').hasMatch(line),
            );
        for (final line in lines) {
          expect(joined, contains(line), reason: '$season $field: $line');
        }
      }
    }
  });
}
