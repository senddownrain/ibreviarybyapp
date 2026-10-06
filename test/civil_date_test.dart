// Calendar-day arithmetic across daylight-saving changes. Belarus keeps one
// offset all year, but readers abroad (Poland, Lithuania, …) do not: run
// also with `TZ=Europe/Warsaw flutter test test/civil_date_test.dart`.
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/utils/civil_date.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';

void main() {
  // EU 2026: summer time from 29 March, winter time from 25 October.
  final springChange = DateTime(2026, 3, 29);
  final autumnChange = DateTime(2026, 10, 25);

  test('next and previous day across both changes', () {
    for (final change in [springChange, autumnChange]) {
      final before = addCivilDays(change, -1);
      final after = addCivilDays(change, 1);
      expect(addCivilDays(before, 1), change);
      expect(addCivilDays(change, 1).day, change.day + 1);
      expect(addCivilDays(after, -1), change);
      expect(addCivilDays(before, 2), after);
      for (final date in [before, change, after]) {
        expect([date.hour, date.minute], [0, 0]);
      }
    }
  });

  test('a time of day is dropped: the date stays the date', () {
    final evening = DateTime(2026, 3, 28, 23, 30);
    expect(addCivilDays(evening, 1), DateTime(2026, 3, 29));
    expect(civilDay(evening), DateTime(2026, 3, 28));
  });

  test('days between dates count calendar days', () {
    expect(civilDaysBetween(DateTime(2026, 3, 1), DateTime(2026, 4, 30)), 60);
    expect(civilDaysBetween(DateTime(2026, 10, 1), DateTime(2026, 10, 31)), 30);
    expect(civilDaysBetween(DateTime(2026, 4, 30), DateTime(2026, 3, 1)), -60);
    // An evening and the next morning are one day apart.
    expect(
      civilDaysBetween(DateTime(2026, 3, 28, 23), DateTime(2026, 3, 29, 1)),
      1,
    );
  });

  test('a week of neighbouring days around a change has no gap or repeat', () {
    for (final change in [springChange, autumnChange]) {
      final days = [for (var i = -3; i <= 3; i++) addCivilDays(change, i)];
      expect(days.toSet(), hasLength(7));
      for (var i = 1; i < days.length; i++) {
        expect(civilDaysBetween(days[i - 1], days[i]), 1);
      }
    }
  });

  test('liturgical weeks are right on both sides of a change', () {
    final calendar = CalendarService();
    LiturgicalContext at(DateTime date) => computeLiturgicalContext(
      date,
      calendar.getYearOptionsCached(date.year),
      calendar.getYearOptionsCached(date.year + 1),
      calendar.getDynamicDatesCached(date.year),
    );
    // Palm Sunday 2026 is 29 March: the day of the change itself.
    expect(at(DateTime(2026, 3, 28)).periodType, 'lent');
    expect(at(DateTime(2026, 3, 28)).periodWeek, 5);
    expect(at(springChange).periodType, 'holyweek');
    expect(at(DateTime(2026, 3, 30)).periodType, 'holyweek');
    // XXX week of Ordinary Time: Sunday 25 October and the days around it.
    expect(at(DateTime(2026, 10, 24)).periodWeek, 29);
    expect(at(autumnChange).periodWeek, 30);
    expect(at(DateTime(2026, 10, 26)).periodWeek, 30);
  });
}
