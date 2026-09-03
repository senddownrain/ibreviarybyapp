int? normalizePsalterWeek(int? week) {
  if (week == null || week < 1) return null;
  return (week - 1) % 4 + 1;
}

int? calculatePsalterWeek({
  required DateTime date,
  required String periodType,
  required int periodWeek,
}) {
  if (const {'ordinary', 'advent', 'easter'}.contains(periodType)) {
    return normalizePsalterWeek(periodWeek);
  }
  if (periodType == 'lent') {
    return periodWeek == 0 ? 4 : normalizePsalterWeek(periodWeek);
  }
  if (periodType == 'holyweek') return 2;
  if (periodType != 'christmas') return null;

  final christmasYear = date.month == 1 ? date.year - 1 : date.year;
  final christmas = DateTime(christmasYear, 12, 25);
  final daysToSunday = christmas.weekday == DateTime.sunday
      ? 0
      : DateTime.sunday - christmas.weekday;
  final firstChristmasSunday = christmas.add(Duration(days: daysToSunday));
  if (date.isBefore(firstChristmasSunday)) return 4;
  final christmasWeek = date.difference(firstChristmasSunday).inDays ~/ 7 + 1;
  return normalizePsalterWeek(christmasWeek);
}
