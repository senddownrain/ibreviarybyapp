/// Base liturgical year used by web (`liturgicalCycle.js`).
const int kCycleBaseYear = 2025;

/// Sunday lectionary cycle: 'A', 'B', or 'C'.
String getCycleForDate(DateTime date, {int? dayOfWeek}) {
  final liturgicalYear = _liturgicalYear(date);
  final dow = dayOfWeek ?? (date.weekday == 7 ? 1 : date.weekday + 1);
  if (dow != 1) return getWeekdayCycleForDate(date);
  final cycleIndex = ((liturgicalYear - kCycleBaseYear) % 3 + 3) % 3;
  return const ['C', 'A', 'B'][cycleIndex];
}

/// Weekday lectionary cycle: '1' or '2' (Firestore `year` field).
String getWeekdayCycleForDate(DateTime date) {
  final year = _liturgicalYear(date);
  final cycleIndex = ((year - kCycleBaseYear) % 2 + 2) % 2;
  return cycleIndex == 0 ? '1' : '2';
}

int _liturgicalYear(DateTime date) {
  final advent = _firstSundayOfAdvent(date.year);
  if (!date.isBefore(advent)) return date.year + 1;
  return date.year;
}

DateTime _firstSundayOfAdvent(int year) {
  final christmas = DateTime(year, 12, 25);
  final weekday = christmas.weekday;
  final daysToLastSunday = weekday % 7;
  final lastSundayBeforeXmas = christmas.subtract(
    Duration(days: daysToLastSunday),
  );
  return lastSundayBeforeXmas.subtract(const Duration(days: 21));
}
