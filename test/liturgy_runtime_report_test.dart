// Runtime audit of the Ordo/Hours port on the bundled content, 2025–2032 ×
// 4 dioceses: legacy fixed-days dependencies, missing Propers, Common-only
// and day-fallback Offices, reference-only / missing readings, integrity
// errors, plus decode and resolution timings (host, JIT).
//
// ORDO_RUNTIME_REPORT=1 flutter test test/liturgy_runtime_report_test.dart
//   writes reports/flutter-liturgy-runtime.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/reading_references.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final timings = <String, num>{};

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('runtime-report-');
    // Decode of each collection from the bundle bytes (as `compute` does).
    for (final name in kContentCollections) {
      final bytes = File('$kContentAssetDir/$name.json.gz').readAsBytesSync();
      final watch = Stopwatch()..start();
      decodeContentCollection(bytes);
      timings['decode.$name.ms'] = watch.elapsedMicroseconds / 1000;
    }
    final watch = Stopwatch()..start();
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kLiturgicalCollections);
    timings['liturgicalCore.ready.ms'] = watch.elapsedMilliseconds;
    await ContentStore.instance.ensureLoaded(kContentCollections);
    timings['allContent.ready.ms'] = watch.elapsedMilliseconds;
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('runtime audit', () {
    var watch = Stopwatch()..start();
    final engine = OrdoRuntime.engine;
    timings['engine.build.ms'] = watch.elapsedMilliseconds;
    watch = Stopwatch()..start();
    engine.resolve('2026-10-06');
    timings['engine.firstDay.ms'] = watch.elapsedMilliseconds;
    watch = Stopwatch()..start();
    engine.year(2027);
    timings['engine.year2027.ms'] = watch.elapsedMilliseconds;
    final service = LiturgicalContentService();
    watch = Stopwatch()..start();
    service.contentForDate(DateTime(2026, 10, 6));
    timings['hours.firstContent.ms'] = watch.elapsedMilliseconds;
    watch = Stopwatch()..start();
    service.contentForDate(DateTime(2026, 10, 6));
    timings['hours.sameDayAgain.ms'] = watch.elapsedMilliseconds;
    watch = Stopwatch()..start();
    engine.notesOf(engine.resolve('2026-11-02'));
    timings['ordo.notesOfDay.ms'] = watch.elapsedMilliseconds;

    final counts = <String, int>{
      'days': 0,
      'options': 0,
      'legacyFixedDays': 0,
      'properTexts': 0,
      'missingProper': 0,
      'commonOnly': 0,
      'dayFallback': 0,
      'unavailableOffices': 0,
      'integrityErrors': 0,
      'readingsReferenceOnly': 0,
      'readingsMissing': 0,
    };
    final missingProper = <String>{};
    final unavailable = <String>{};
    final referenceOnly = <String>{};
    final missingReadings = <String>{};
    final index = ReadingReferenceIndex.current();
    for (final diocese in kDioceses) {
      for (var year = 2025; year <= 2032; year++) {
        for (final iso in daysOfYear(year)) {
          final content = service.contentForDate(
            dateOfIso(iso),
            diocese: diocese,
          );
          counts['days'] = counts['days']! + 1;
          for (final option in content.options) {
            counts['options'] = counts['options']! + 1;
            switch (option.properSource) {
              case ProperSource.legacyDays:
                counts['legacyFixedDays'] = counts['legacyFixedDays']! + 1;
              case ProperSource.properTexts:
                counts['properTexts'] = counts['properTexts']! + 1;
            }
            if (option.missingProper) {
              counts['missingProper'] = counts['missingProper']! + 1;
              missingProper.add(option.optionId);
            }
            final status =
                (option.day?.data['_contentStatus'] as Map?)?['hours'];
            if (status == 'common-only') {
              counts['commonOnly'] = counts['commonOnly']! + 1;
            }
            if (status == 'day-fallback') {
              counts['dayFallback'] = counts['dayFallback']! + 1;
            }
            for (final template in option.templates) {
              if (template.day.data['_integrityErrors'] != null) {
                counts['integrityErrors'] = counts['integrityErrors']! + 1;
              }
            }
          }
          for (final item in content.unavailable) {
            if (item.assembled) continue;
            counts['unavailableOffices'] = counts['unavailableOffices']! + 1;
            unavailable.add(item.id);
          }
          for (final item in readingReferencesForDay(content.ordo, index)) {
            if (item.status == ReadingReferenceStatus.referenceOnly) {
              counts['readingsReferenceOnly'] =
                  counts['readingsReferenceOnly']! + 1;
              referenceOnly.add(item.optionId);
            }
            if (item.status == ReadingReferenceStatus.missing) {
              counts['readingsMissing'] = counts['readingsMissing']! + 1;
              missingReadings.add(item.optionId);
            }
          }
        }
      }
    }
    final manifest =
        jsonDecode(File('$kContentAssetDir/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final collections = (manifest['collections'] as Map)
        .cast<String, dynamic>();
    int bundleBytes(Iterable<String> names) => names.fold(
      0,
      (sum, name) =>
          sum + ((collections[name] as Map?)?['bundleBytes'] as int? ?? 0),
    );
    if (Platform.environment['ORDO_RUNTIME_REPORT'] == '1') {
      File('reports/flutter-liturgy-runtime.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({
          'scope': {
            'years': [2025, 2032],
            'dioceses': kDioceses,
          },
          'counts': counts,
          'legacyFixedDaysDependencies': counts['legacyFixedDays'],
          'missingProperCelebrations': missingProper.toList()..sort(),
          'unavailableOffices': unavailable.toList()..sort(),
          'referenceOnlyReadings': referenceOnly.toList()..sort(),
          'missingReadings': missingReadings.toList()..sort(),
          'engineParityMismatches': 'see reports/flutter-ordo-parity.json (0)',
          'bundle': {
            'totalBytes': bundleBytes(collections.keys),
            'ordoBytes': bundleBytes([...kOrdoCalendarCollections, 'liturgicalProperTexts', ...kOrdoNotesCollections]),
            'collections': {
              for (final entry in collections.entries) entry.key: {'count': (entry.value as Map)['count'], 'storedBytes': (entry.value as Map)['storedBytes'], 'bundleBytes': (entry.value as Map)['bundleBytes']},
            },
          },
          'timingsHostJit': timings,
        })}\n',
      );
    }
    expect(counts['legacyFixedDays'], 0);
    expect(counts['integrityErrors'], 0);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
