import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';

void main() {
  final options = YearOptions.fromMap({
    'year': 2026,
    'easterSunday': '2026-04-05',
    'pentecost': '2026-05-24',
    'firstAdventSunday': '2026-11-29',
    'ashWednesday': '2026-02-18',
    'ordintaryWeeks1': 6,
    'ordintaryWeeks2': 9,
  });

  LiturgicalContext context(String iso, {DynamicDates? dynamicDates}) =>
      computeLiturgicalContext(
        DateTime.parse(iso),
        options,
        null,
        dynamicDates,
      );

  test('computes Christmas through the Baptism of the Lord', () {
    final beforeBaptism = context('2026-01-10');
    expect(beforeBaptism.periodType, 'christmas');
    expect(beforeBaptism.periodWeek, 2);
    expect(beforeBaptism.dayOfWeek, 7);

    final baptism = context('2026-01-11');
    expect(baptism.periodType, 'christmas');
    expect(baptism.dayOfWeek, 1);
  });

  test('computes pre-Lent, Palm Sunday, Easter and Pentecost exactly', () {
    final ash = context('2026-02-18');
    expect((ash.periodType, ash.periodWeek, ash.dayOfWeek), ('lent', 0, 4));

    final palm = context('2026-03-29');
    expect(
      (palm.periodType, palm.periodWeek, palm.dayOfWeek),
      ('holyweek', 1, 1),
    );

    final easter = context('2026-04-05');
    expect(
      (easter.periodType, easter.periodWeek, easter.dayOfWeek),
      ('easter', 1, 1),
    );

    final pentecost = context('2026-05-24');
    expect(
      (pentecost.periodType, pentecost.periodWeek, pentecost.dayOfWeek),
      ('easter', 8, 1),
    );
  });

  test('numbers late Ordinary Time backwards from Advent', () {
    final saturday = context('2026-11-28');
    expect(
      (saturday.periodType, saturday.periodWeek, saturday.dayOfWeek),
      ('ordinary', 34, 7),
    );

    final advent = context('2026-11-29');
    expect(
      (advent.periodType, advent.periodWeek, advent.dayOfWeek),
      ('advent', 1, 1),
    );
  });

  test('attaches the matching dynamic feast code', () {
    final dates = <String, DateTime>{'pentecost': DateTime(2026, 5, 24)};
    final value = context('2026-05-24', dynamicDates: dates);
    expect(value.feast, isNotNull);
    expect(
      getDynamicFeastCodesForDate(DateTime(2026, 5, 24), dates),
      contains(value.feast),
    );
  });

  test('converts picker period coordinates back to a calendar date', () {
    expect(
      calculateDateForContext(2026, 'advent', 1, 1, options, null),
      DateTime(2026, 11, 29),
    );
    expect(
      calculateDateForContext(2026, 'ordinary', 34, 7, options, null),
      DateTime(2026, 11, 28),
    );
    expect(
      calculateDateForContext(2026, 'holyweek', 1, 5, options, null),
      DateTime(2026, 4, 2),
    );
  });
}
