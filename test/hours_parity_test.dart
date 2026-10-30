// Web ↔ Flutter parity of the Hours: the same legal Office cards, the same
// assemblies («З дня» / Commons), the same Proper source and the same
// Office text (hash) as the web pipeline on the same snapshot, 2025–2035 ×
// 4 dioceses (fixture: mybrev `npm run ordo:flutter-fixture`).
//
// HOURS_PARITY_REPORT=1 also writes reports/flutter-hours-parity.json.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/office_assembly.dart';

import 'support/ordo_fixture.dart';

/// Office text of an assembled document (mybrev `officeHash`).
String officeHash(LiturgicalDay day) {
  final fields = <String, dynamic>{};
  for (final field in [
    ...kOfficeFieldSlots.keys,
    ...kFirstVesperFields,
    'officeOfReadingsTeDeum',
  ]) {
    final value = day.data[field];
    if (value == null || value == '') continue;
    fields[field] = value;
  }
  return sha256
      .convert(utf8.encode(canonicalJson(fields)))
      .toString()
      .substring(0, 16);
}

String sourceName(LiturgicalOptionSource source) => switch (source) {
  LiturgicalOptionSource.period => 'period',
  LiturgicalOptionSource.dynamic => 'dynamic',
  LiturgicalOptionSource.fixed => 'fixed',
  LiturgicalOptionSource.officeForDead => 'office-for-dead',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('hours-parity-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'Hours cards and assemblies equal the web, 2025–2035 × 4 dioceses',
    () {
      final fixture = ordoParityFixture();
      final days = (fixture['days'] as Map).cast<String, dynamic>();
      final service = LiturgicalContentService();
      final structure = <String>[];
      final text = <String>[];
      var compared = 0;
      var templatesCompared = 0;
      final properSources = <String, int>{};
      for (final MapEntry(key: diocese, value: list) in days.entries) {
        for (final record in (list as List).cast<Map<String, dynamic>>()) {
          final expected = (record['hours'] as List?)
              ?.cast<Map<String, dynamic>>();
          if (expected == null) continue;
          final date = dateOfIso(record['date'] as String);
          final content = service.contentForDate(date, diocese: diocese);
          compared++;
          final actual = content.options;
          String shape(Map<String, dynamic> item) => jsonEncode({
            'key': item['key'],
            'optionId': item['optionId'],
            'source': item['source'],
            'properSource': item['properSource'],
            'missingProper': item['missingProper'] ?? false,
            'templates': [
              for (final t in (item['templates'] as List).cast<Map>())
                [t['id'], t['label'], t['choice'], t['integrity']],
            ],
          });
          final want = expected.map(shape).toList();
          final got = [
            for (final option in actual)
              shape({
                'key': option.key,
                'optionId': option.ordo?.optionId ?? 'office-for-dead',
                'source': sourceName(option.source),
                'properSource': option.properSource,
                'missingProper': option.missingProper,
                'templates': [
                  for (final t in option.templates)
                    {
                      'id': t.id,
                      'label': t.label,
                      'choice': t.choice,
                      'integrity': (t.day.data['_integrityErrors'] as List?)
                          ?.map((e) => (e as Map)['field'])
                          .toList(),
                    },
                ],
              }),
          ];
          for (final option in actual) {
            final source = option.properSource ?? '-';
            properSources[source] = (properSources[source] ?? 0) + 1;
          }
          if (jsonEncode(want) != jsonEncode(got)) {
            structure.add(
              '${record['date']} $diocese\n  web:     $want\n  flutter: $got',
            );
            continue;
          }
          for (var i = 0; i < actual.length; i++) {
            final wantTemplates = (expected[i]['templates'] as List)
                .cast<Map>();
            for (var j = 0; j < actual[i].templates.length; j++) {
              templatesCompared++;
              final hash = officeHash(actual[i].templates[j].day);
              if (hash != wantTemplates[j]['hash']) {
                text.add(
                  '${record['date']} $diocese ${actual[i].templates[j].id}',
                );
              }
            }
          }
        }
      }
      if (Platform.environment['HOURS_PARITY_REPORT'] == '1') {
        File('reports/flutter-hours-parity.json').writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert({
            'heads': {'web': Platform.environment['WEB_HEAD'], 'flutter': Platform.environment['FLUTTER_HEAD'], 'flutterSdk': '3.41.4'},
            'fixtureSnapshot': fixture['snapshot'],
            'bundleContentVersion': (jsonDecode(File('assets/content/manifest.json').readAsStringSync()) as Map)['contentVersion'],
            'daysCompared': compared,
            'assembliesCompared': templatesCompared,
            'structureMismatches': structure.length,
            'officeTextMismatches': text.length,
            'structureExamples': structure.take(10).toList(),
            'officeTextExamples': text.take(20).toList(),
            'optionsByProperSource': properSources,
          })}\n',
        );
      }
      expect(compared, greaterThan(11000));
      expect(structure, isEmpty, reason: structure.take(6).join('\n'));
      expect(text, isEmpty, reason: text.take(20).join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
