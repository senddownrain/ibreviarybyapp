import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';
import 'package:mybrev_flutter/utils/liturgical_office.dart';
import 'package:mybrev_flutter/utils/liturgical_psalter.dart';

LiturgicalDay day(Map<String, dynamic> data) => LiturgicalDay.fromMap(data);

void main() {
  test('resolves explicit from-day and missing proper fields', () {
    final period = day({
      'id': 'ordinary-w2-d3',
      '_periodType': 'ordinary',
      'laudesHymn': 'period hymn',
      'laudesAnt1': 'period ant 1',
      'laudesAnt2': 'period ant 2',
      'laudesAnt3': 'period ant 3',
    });
    final proper = day({
      'id': 'saint',
      '_date': '03.09',
      'laudesHymn': '[from-day]',
      'laudesAnt1': 'one proper antiphon',
      'laudesAnt2': '',
      'laudesAnt3': '',
    });

    final resolved = resolveDayAgainstPeriod(
      proper,
      period,
      fillMissing: true,
    )!;
    expect(resolved.id, 'saint');
    expect(resolved.field('laudesHymn'), 'period hymn');
    expect(resolved.field('laudesAnt1'), 'one proper antiphon');
    expect(resolved.field('laudesAnt2'), '');
    expect(resolved.field('laudesAnt3'), '');
  });

  test('daytime hours inherit individual fields from Terce', () {
    final value = day({
      'id': 'day',
      'sext1Hymn': 'common hymn',
      'sext1R': 'common reading',
      'sext2Hymn': 'own Sext hymn',
      'sext2R': 'from-day',
    });
    expect(daytimeHourField(value, 2, 'Hymn'), 'own Sext hymn');
    expect(daytimeHourField(value, 2, 'R'), 'common reading');
    expect(daytimeHourField(value, 3, 'Hymn'), 'common hymn');
  });

  test('expands seasonal weekday antiphons into Lauds and Vespers', () {
    final value = day({
      'id': 'advent-17-12',
      'thursday': '<p>A</p><p>B</p><p>C</p>',
    });
    final resolved = applySeasonalWeekdayAntiphons(value, 5);
    expect(resolved.field('laudesAnt1'), '<p>A</p>');
    expect(resolved.field('laudesAnt3'), '<p>C</p>');
    expect(resolved.field('vesperAnt2'), '<p>B</p>');
  });

  test(
    'Completorium uses Sunday only for solemnities and aliases Holy Week',
    () {
      final feast = day({'id': 'f', '_rank': 'festum'});
      final solemnity = day({'id': 's', '_rank': 'solemnitas'});
      expect(completoriumId('ordinary', 4, feast), 'ordinary-d4');
      expect(completoriumId('ordinary', 4, solemnity), 'ordinary-d1');
      expect(completoriumId('holyweek', 6, feast), 'lent-d6');
    },
  );

  test('Te Deum follows rank, octave and Sunday rules', () {
    expect(shouldShowTeDeum(day({'id': 'f', '_rank': 'festum'})), isTrue);
    expect(
      shouldShowTeDeum(
        day({
          'id': 'palm',
          '_periodType': 'holyweek',
          '_periodWeekNumber': 1,
          '_dayOfWeek': 1,
          '_feast': 'feast-palmsunday',
        }),
      ),
      isFalse,
    );
    expect(
      shouldShowTeDeum(
        day({
          'id': 'easter-weekday',
          '_periodType': 'easter',
          '_periodWeekNumber': 1,
          '_dayOfWeek': 3,
        }),
      ),
      isTrue,
    );
  });

  test('Christmas psalter keeps Advent IV until the first Sunday', () {
    expect(
      calculatePsalterWeek(
        date: DateTime(2026, 12, 26),
        periodType: 'christmas',
        periodWeek: 1,
      ),
      4,
    );
    expect(
      calculatePsalterWeek(
        date: DateTime(2026, 12, 27),
        periodType: 'christmas',
        periodWeek: 1,
      ),
      1,
    );
  });
}
