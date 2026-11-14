import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/liturgical_vespers.dart';
import 'support/ordo_fixture.dart';
import 'hours_parity_test.dart' show officeHash;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('approved-office-');
    await HiveService.init(path: dir.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  test('reviewed Advent sources match the independent Web Office oracle', () {
    final days = ordoParityFixture()['days'] as Map;
    for (final diocese in ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk']) {
      for (final date in [
        '2026-12-21',
        '2025-12-24',
        '2028-12-24',
        '2026-12-19',
      ]) {
        final expected =
            (days[diocese] as List).cast<Map>().singleWhere(
                  (d) => d['date'] == date,
                )['hours']
                as List;
        final actual = LiturgicalContentService()
            .contentForDate(DateTime.parse(date), diocese: diocese)
            .options;
        for (var i = 0; i < actual.length; i++) {
          final templates = (expected[i] as Map)['templates'] as List;
          for (var j = 0; j < actual[i].templates.length; j++) {
            expect(
              officeHash(actual[i].templates[j].day),
              (templates[j] as Map)['hash'],
              reason: '$date/$diocese/${actual[i].templates[j].id}',
            );
          }
        }
      }
    }
  });
  test(
    'I Vespers keeps missing fields from the Proper and tonight\'s O antiphon',
    () {
      final tomorrow = LiturgicalDay.fromMap({
        'id': 'advent-20-12',
        '_periodType': 'advent',
        'vesper1Hymn': 'first hymn',
        'vesperPs1': 'proper psalm',
        'vesperAntMag': 'tomorrow O',
      });
      final civil = LiturgicalDay.fromMap({
        'id': 'advent-19-12',
        '_periodType': 'advent',
        'vesperAntMag': 'tonight O',
      });
      final result = assembleFirstVespers(tomorrow, civilDay: civil);
      expect(result.field('vesperHymn'), 'first hymn');
      expect(result.field('vesperPs1'), 'proper psalm');
      expect(result.field('vesperAntMag'), 'tonight O');
    },
  );
}
