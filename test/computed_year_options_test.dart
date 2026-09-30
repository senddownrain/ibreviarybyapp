import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/utils/computed_year_options.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';

void main() {
  test('computed year options equal the web Ordo engine', () {
    final reference =
        jsonDecode(
              File(
                'test/fixtures/computed_year_options.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(reference, isNotEmpty);
    reference.forEach((year, expected) {
      final computed = computeYearOptions(int.parse(year));
      expect(computed.year, int.parse(year));
      (expected as Map<String, dynamic>).forEach((field, value) {
        expect(computed.data[field], value, reason: '$year $field');
      });
    });
  });

  test('the calendar is available synchronously for any year, no network', () {
    final calendar = CalendarService();
    for (final year in [2019, 2026, 2031, 2060, 2150]) {
      final options = calendar.getYearOptionsCached(year);
      expect(options, isNotNull);
      final dates = calendar.getDynamicDatesCached(year)!;
      expect(dates['easterSunday'], computeEasterSunday(year));
      expect(dates['pentecost']!.weekday, DateTime.sunday);
      expect(dates['christKing']!.weekday, DateTime.sunday);
      expect(dates['ascension']!.weekday, DateTime.thursday);
      expect(dates['corpusChristi']!.weekday, DateTime.thursday);
    }
    final context = computeLiturgicalContext(
      DateTime(2031, 3, 2),
      calendar.getYearOptionsCached(2031),
      calendar.getYearOptionsCached(2032),
      calendar.getDynamicDatesCached(2031),
    );
    expect(context.periodType, 'lent');
    expect(context.periodWeek, greaterThan(0));
  });

  test('daylight-saving changes never shift a computed date', () {
    // Easter 2027 is 28 March — the night the clocks change in Europe.
    expect(computeEasterSunday(2027), DateTime(2027, 3, 28));
    final options = computeYearOptions(2027);
    expect(options.data['pentecost'], '2027-05-16');
    expect(options.data['ashWednesday'], '2027-02-10');
    expect(options.data['firstAdventSunday'], '2027-11-28');
  });
}
