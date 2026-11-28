import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/novena/novena_schedule.dart';
import 'package:mybrev_flutter/novena/novena_strings.dart';
import 'package:mybrev_flutter/novena/ui/novena_day_watcher.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/engine.dart';
import 'package:mybrev_flutter/utils/civil_date.dart';

import 'support.dart';

List<Map<String, dynamic>> _documents(String name) => [
  for (final MapEntry(:key, :value) in bundledDocs(name).entries)
    {...value, 'id': key},
];

void main() {
  late NovenaFeastDate feasts;
  setUpAll(() {
    feasts = novenaFeastDates(
      OrdoEngine(
        OrdoDefinitions.fromDocuments(
          celebrations: _documents('liturgicalCelebrations'),
          dioceseOverrides: _documents('liturgicalDioceseOverrides'),
          yearOverrides: _documents('liturgicalYearOverrides'),
        ),
      ),
    );
  });

  Map schedule(String id) =>
      readyDefinitions().firstWhere((d) => d['novenaId'] == id)['schedule']
          as Map;

  bool starts(Map rule, String day, [List<String> dioceses = const []]) =>
      novenaStartsOn(
        rule,
        day,
        dioceses: dioceses.isEmpty ? ['minsk-mohilev'] : dioceses,
        feastDate: feasts,
      );

  List<String> startDays(
    Map rule,
    int year, [
    String diocese = 'minsk-mohilev',
  ]) => [
    for (
      var date = DateTime(year);
      date.year == year;
      date = addCivilDays(date, 1)
    )
      if (starts(rule, date.toIso8601String().substring(0, 10), [diocese]))
        date.toIso8601String().substring(0, 10),
  ];

  Map moving(String event, [int offset = -9]) => {
    'enabled': true,
    'extraDates': [],
    'type': 'liturgical',
    'event': event,
    'offsetDays': offset,
  };

  test('control starts of 2027 from the bundled calendar', () {
    const expected = {
      'good-friday': '2027-03-26',
      'pentecost': '2027-05-07',
      'trinity': '2027-05-14',
      'corpus-christi': '2027-05-18',
      'sacred-heart': '2027-05-26',
      'immaculate-heart': '2027-05-27',
      'christ-king': '2027-11-12',
      'holy-family': '2027-12-17',
    };
    for (final MapEntry(key: event, value: day) in expected.entries) {
      for (final diocese in kDioceses) {
        expect(
          startDays(
            moving(event, event == 'good-friday' ? 0 : -9),
            2027,
            diocese,
          ),
          [day],
          reason: '$event $diocese',
        );
      }
    }
  });

  test('fixed feasts count calendar days, also across a leap year', () {
    final casimir = schedule('a8tYTDVjR2Ni75PjzOyz');
    expect(startDays(casimir, 2027), ['2027-02-23']);
    expect(startDays(casimir, 2028), ['2028-02-24']);
    expect(startDays(schedule('cn_05b28c5bea797880'), 2027), ['2027-03-10']);
    expect(startDays(schedule('cn_20424a9d8b687461'), 2027), ['2027-11-25']);
    expect(startDays(schedule('edc7LXLBYXd8qxqOaqrZ'), 2027), ['2027-11-29']);
    // A January feast starts in the previous civil year.
    final january = {
      'enabled': true,
      'type': 'fixedFeast',
      'month': 1,
      'day': 2,
      'offsetDays': -9,
    };
    expect(starts(january, '2026-12-24'), isTrue);
    // 29 February never becomes 1 March.
    final leapDay = {...january, 'month': 2, 'day': 29, 'offsetDays': 0};
    expect(startDays(leapDay, 2027), isEmpty);
    expect(startDays(leapDay, 2028), ['2028-02-29']);
  });

  test('fixed start, extra dates, scope and disabled rules', () {
    final rule = {
      'enabled': true,
      'extraDates': ['2027-06-01'],
      'type': 'fixedStart',
      'month': 7,
      'day': 3,
    };
    expect(startDays(rule, 2027), ['2027-06-01', '2027-07-03']);
    expect(startDays({...rule, 'enabled': false}, 2027), isEmpty);
    // A fixed start has no offset; the scope covers the extra dates too.
    expect(startDays({...rule, 'offsetDays': -9}, 2027), [
      '2027-06-01',
      '2027-07-03',
    ]);
    expect(startDays({...rule, 'type': 'manual'}, 2027), ['2027-06-01']);
    expect(
      startDays({
        ...rule,
        'dioceses': ['grodno'],
      }, 2027),
      isEmpty,
    );
    expect(
      startDays(
        {
          ...rule,
          'dioceses': ['grodno'],
        },
        2027,
        'grodno',
      ),
      hasLength(2),
    );
  });

  test('an unknown event gives no suggestion', () {
    expect(startDays(moving('no-such-feast'), 2027), isEmpty);
    expect(
      novenaStartsOn(
        moving('pentecost'),
        '2027-05-07',
        dioceses: ['minsk-mohilev'],
        feastDate: (_, _, _) => null,
      ),
      isFalse,
    );
  });

  test('every published schedule starts at most twice a year', () {
    for (final data in readyDefinitions()) {
      final rule = data['schedule'] as Map;
      final days = startDays(rule, 2027);
      expect(
        days.length,
        rule['type'] == 'manual' ? 0 : 1,
        reason: '${data['novenaId']}',
      );
    }
  });

  test('the next local day is a calendar step, capped for clock changes', () {
    expect(
      NovenaDayWatcher.untilNextDay(DateTime(2027, 3, 28, 23, 55)),
      const Duration(minutes: 5, seconds: 1),
    );
    expect(
      NovenaDayWatcher.untilNextDay(DateTime(2027, 3, 28, 1)),
      NovenaDayWatcher.maxWait,
    );
    // Run also under TZ=Europe/Warsaw: DST begins on 28 March 2027.
    expect(
      civilDaysBetween(DateTime(2027, 3, 27), DateTime(2027, 3, 29)),
      2,
      reason: 'time zone ${Platform.environment['TZ']}',
    );
  });

  test('Belarusian forms', () {
    expect(novenaRemaining(1), 'Застаўся 1 дзень');
    expect(novenaRemaining(3), 'Засталося 3 дні');
    expect(novenaRemaining(7), 'Засталося 7 дзён');
    expect(daysWord(11), 'дзён');
    expect(daysWord(21), 'дзень');
    expect(novenaDoneOf(2, 9), 'Завершана 2 з 9 дзён');
    expect(novenaDoneOf(0, 21), 'Завершана 0 з 21 дня');
    expect(novenaDate('2027-03-12'), '12 сакавіка');
  });
}
