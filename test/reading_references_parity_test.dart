// Ordo reading references: the same readings (status and documents) as the
// web `readingReferencesForDay` on the same corpus, 2025–2035 × 4 dioceses.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/ordo/reading_references.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

import 'support/ordo_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('reading-refs-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kLiturgicalCollections);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'reading references equal the web',
    () {
      final fixture = ordoParityFixture();
      final engine = bundledOrdoEngine();
      final index = ReadingReferenceIndex.current();
      final mismatches = <String>[];
      final statuses = <String, int>{};
      var compared = 0;
      for (final MapEntry(key: diocese, value: list)
          in (fixture['days'] as Map).cast<String, dynamic>().entries) {
        for (final record in (list as List).cast<Map<String, dynamic>>()) {
          final day = engine.resolve(
            record['date'] as String,
            diocese: diocese,
          );
          final actual = [
            for (final item in readingReferencesForDay(day, index))
              {
                'optionId': item.optionId,
                'status': item.status,
                'documents': [for (final doc in item.documents) doc.id],
                if (item.reference != null) 'reference': true,
              },
          ];
          for (final item in actual) {
            final status = item['status'] as String;
            statuses[status] = (statuses[status] ?? 0) + 1;
          }
          compared++;
          final want = jsonEncode(record['readings']);
          final got = jsonEncode(actual);
          if (want != got) {
            mismatches.add(
              '${record['date']} $diocese\n  web: $want\n  app: $got',
            );
          }
        }
      }
      if (Platform.environment['ORDO_PARITY_REPORT'] == '1') {
        File('reports/flutter-reading-references.json').writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert({'daysCompared': compared, 'mismatches': mismatches.length, 'optionsByStatus': statuses, 'examples': mismatches.take(10).toList()})}\n',
        );
      }
      expect(compared, 16068);
      expect(mismatches, isEmpty, reason: mismatches.take(5).join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
