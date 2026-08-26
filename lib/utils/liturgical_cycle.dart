import 'package:mybrev_flutter/models/year_options.dart';

/// Returns the Sunday lectionary cycle for a date: 'A', 'B', or 'C'.
/// The cycle is determined by the liturgical year, which begins on the
/// first Sunday of Advent (late November / early December of the civil year).
String getCycleForDate(DateTime date, {int? dayOfWeek}) {
  // Liturgical year starts in Advent of the previous civil year.
  // Year N (liturgical) uses Sunday cycle based on: (N % 3):
  //   0 → C, 1 → A, 2 → B
  // Advent starts on the 4th Sunday before Dec 25.
  final liturgicalYear = _liturgicalYear(date);
  final rem = liturgicalYear % 3;
  if (rem == 1) return 'A';
  if (rem == 2) return 'B';
  return 'C';
}

/// Returns the weekday cycle for a date: 'I' (odd liturgical year) or 'II' (even).
String getWeekdayCycleForDate(DateTime date) {
  final year = _liturgicalYear(date);
  return (year % 2 == 1) ? 'I' : 'II';
}

/// Returns list of dynamic feast codes that fall on the given date.
List<String> getDynamicFeastCodesForDate(
    DateTime date, DynamicDates? dynamicDates) {
  if (dynamicDates == null) return [];
  final codes = <String>[];
  for (final entry in dynamicDates.entries) {
    final feastDate = entry.value;
    if (feastDate.year == date.year &&
        feastDate.month == date.month &&
        feastDate.day == date.day) {
      codes.add(entry.key);
    }
  }
  return codes;
}

/// Liturgical year in which the date falls.
/// E.g. date=2024-12-01 → liturgical year 2025 (Advent of 2024 starts year 2025).
int _liturgicalYear(DateTime date) {
  final advent = _firstSundayOfAdvent(date.year);
  if (!date.isBefore(advent)) return date.year + 1;
  return date.year;
}

/// First Sunday of Advent = 4 Sundays before Dec 25 of the given civil year.
DateTime _firstSundayOfAdvent(int year) {
  final christmas = DateTime(year, 12, 25);
  final weekday = christmas.weekday; // 1=Mon … 7=Sun
  // Days since the last Sunday before or on Christmas
  final daysToLastSunday = weekday % 7; // 0 if Sunday
  final lastSundayBeforeXmas =
      christmas.subtract(Duration(days: daysToLastSunday));
  // 4th Sunday before Christmas
  return lastSundayBeforeXmas.subtract(const Duration(days: 21));
}
