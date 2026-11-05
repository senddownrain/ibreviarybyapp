import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Web ↔ Flutter: all 27 daytime fields, 2025–2035 × four dioceses, '
      'original bundle and minimal reference-only patch', () async {
    final directory = await Directory.systemTemp.createTemp('daytime-parity-');
    try {
      await HiveService.init(path: directory.path, loadBundle: true);
      await ContentStore.instance.ensureLoaded(kLiturgicalCollections);
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
      expect(fixture['webCommit'], isNotEmpty);
      for (final state in ['baseline', 'patched']) {
        if (state == 'patched') {
          final plan =
              jsonDecode(
                    File(
                      'reports/liturgy/christ-high-priest-daytime-patch.json',
                    ).readAsStringSync(),
                  )
                  as Map;
          for (final raw in plan['updates'] as List) {
            final update = raw as Map;
            final id = update['id'] as String;
            final doc = {
              ...Map<String, dynamic>.from(HiveService.daysBox.get(id) as Map),
              ...Map<String, dynamic>.from(update['set'] as Map),
            };
            await HiveService.daysBox.applyUpdate(
              {id: doc},
              {id: documentHash(doc)},
              HiveService.daysBox.baselineVersion + 1000,
            );
          }
        }
        for (final raw in fixture['cases'] as List) {
          final row = raw as Map;
          final content = LiturgicalContentService().contentForDate(
            DateTime.parse(row['date'] as String),
            diocese: row['diocese'] as String,
          );
          expect(content.ordo.primary.id, row['primary']);
          final day = content.options
              .firstWhere((o) => o.optionId == row['primary'])
              .day!;
          for (final entry in (row[state] as Map).entries) {
            final field = entry.key as String;
            final hour = int.parse(field.substring(4, 5));
            expect(
              daytimeHourField(day, hour, field.substring(5)),
              entry.value,
              reason: '$state ${row['date']} ${row['diocese']} $field',
            );
          }
        }
      }
    } finally {
      await ContentStore.instance.idle();
      await Hive.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
