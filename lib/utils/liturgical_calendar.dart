import 'package:mybrev_flutter/utils/civil_date.dart';
import 'package:mybrev_flutter/constants/liturgical_feasts_map.dart';
import 'package:mybrev_flutter/models/year_options.dart';

class LiturgicalContext {
  final String periodType;
  final int periodWeek;

  /// Liturgical numbering: 1=Sunday, 2=Monday, … 7=Saturday.
  final int dayOfWeek;
  final String? feast;

  const LiturgicalContext({
    required this.periodType,
    required this.periodWeek,
    required this.dayOfWeek,
    this.feast,
  });

  LiturgicalContext copyWith({
    String? periodType,
    int? periodWeek,
    int? dayOfWeek,
    String? feast,
  }) => LiturgicalContext(
    periodType: periodType ?? this.periodType,
    periodWeek: periodWeek ?? this.periodWeek,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    feast: feast ?? this.feast,
  );
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime? _parseDate(dynamic value) {
  if (value is DateTime) return _day(value);
  if (value is int) return _day(DateTime.fromMillisecondsSinceEpoch(value));
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return _day(parsed);
  }
  return null;
}

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

int _catholicWeekday(DateTime date) => date.weekday % 7 + 1;

DateTime calculateHolyFamilyDate(int year) {
  final christmas = DateTime(year, 12, 25);
  if (christmas.weekday == DateTime.sunday) return DateTime(year, 12, 30);
  return addCivilDays(christmas, DateTime.sunday - christmas.weekday);
}

DateTime calculateBaptismOfLordDate(int year) {
  final epiphany = DateTime(year, 1, 6);
  final days = epiphany.weekday == DateTime.sunday
      ? 7
      : DateTime.sunday - epiphany.weekday;
  return addCivilDays(epiphany, days);
}

DateTime _firstSundayAfterChristmas(DateTime christmas) {
  final days = christmas.weekday == DateTime.sunday
      ? 7
      : DateTime.sunday - christmas.weekday;
  return addCivilDays(christmas, days);
}

int calculateChristmasPeriodWeek(DateTime value) {
  final date = _day(value);
  if (date.month != 12 && date.month != 1) return -1;
  final christmasYear = date.month == 1 ? date.year - 1 : date.year;
  final christmas = DateTime(christmasYear, 12, 25);
  if (date.isBefore(christmas)) return -1;
  final firstSunday = _firstSundayAfterChristmas(christmas);
  if (date.isBefore(firstSunday)) return 1;
  return civilDaysBetween(firstSunday, date) ~/ 7 + 1;
}

/// Exact port of `mybrev/src/utils/liturgicalCalendar.js`.
LiturgicalContext computeLiturgicalContext(
  DateTime value,
  YearOptions? opts,
  YearOptions? nextYearOpts,
  DynamicDates? dynamicDates,
) {
  final date = _day(value);
  String? feast;
  for (final entry in feastNameMap.entries) {
    final feastDate = dynamicDates?[entry.key];
    if (feastDate != null && _sameDay(feastDate, date)) {
      feast = entry.value;
      break;
    }
  }

  var context = LiturgicalContext(
    periodType: 'ordinary',
    periodWeek: -1,
    dayOfWeek: _catholicWeekday(date),
    feast: feast,
  );
  if (opts == null) return context;

  final advent = _parseDate(opts.data['firstAdventSunday']);
  final easter = _parseDate(opts.data['easterSunday']);
  final ash = _parseDate(opts.data['ashWednesday']);
  final pentecost = _parseDate(opts.data['pentecost']);
  if (advent == null || easter == null || ash == null || pentecost == null) {
    return context;
  }
  final christmas = DateTime(date.year, 12, 25);

  if (!date.isBefore(advent) && date.isBefore(christmas)) {
    final diff = civilDaysBetween(advent, date);
    return context.copyWith(
      periodType: 'advent',
      periodWeek: diff ~/ 7 + 1,
      dayOfWeek: diff % 7 + 1,
    );
  }

  final startsThisYear = !date.isBefore(christmas);
  final startsPreviousYear = date.month == 1;
  if (startsThisYear || startsPreviousYear) {
    final start = startsThisYear ? christmas : DateTime(date.year - 1, 12, 25);
    final end = calculateBaptismOfLordDate(start.year + 1);
    if (!date.isBefore(start) && !date.isAfter(end)) {
      return context.copyWith(
        periodType: 'christmas',
        periodWeek: calculateChristmasPeriodWeek(date),
      );
    }
  }

  if (!date.isBefore(ash) && date.isBefore(easter)) {
    final firstLentSunday = addCivilDays(ash, 4);
    final palmSunday = addCivilDays(easter, -7);
    final startDiff = civilDaysBetween(firstLentSunday, date);
    final endDiff = civilDaysBetween(palmSunday, date);
    if (startDiff < 0) {
      return context.copyWith(
        periodType: 'lent',
        periodWeek: 0,
        dayOfWeek: 8 + startDiff,
      );
    }
    if (endDiff > 0 && endDiff < 8) {
      return context.copyWith(
        periodType: 'holyweek',
        periodWeek: 1,
        dayOfWeek: endDiff + 1,
      );
    }
    if (endDiff == 0) {
      return LiturgicalContext(
        periodType: 'holyweek',
        periodWeek: 1,
        dayOfWeek: 1,
        feast: feastNameMap['palmSunday'],
      );
    }
    return context.copyWith(
      periodType: 'lent',
      periodWeek: startDiff ~/ 7 + 1,
      dayOfWeek: startDiff % 7 + 1,
    );
  }

  if (!date.isBefore(easter) && !date.isAfter(pentecost)) {
    final diff = civilDaysBetween(easter, date);
    return context.copyWith(
      periodType: 'easter',
      periodWeek: diff ~/ 7 + 1,
      dayOfWeek: diff % 7 + 1,
    );
  }

  final firstOrdinaryWeeks = _asInt(opts.data['ordintaryWeeks1']);
  if (firstOrdinaryWeeks != null) {
    final firstOrdinary = addCivilDays(ash, -3 - (firstOrdinaryWeeks - 1) * 7);
    if (!date.isBefore(firstOrdinary) && date.isBefore(ash)) {
      final diff = civilDaysBetween(firstOrdinary, date);
      return context.copyWith(
        periodType: 'ordinary',
        periodWeek: diff ~/ 7 + 1,
        dayOfWeek: diff % 7 + 1,
      );
    }
  }

  if (date.isAfter(pentecost) && date.isBefore(advent)) {
    final lastOrdinarySunday = addCivilDays(advent, -7);
    final currentSunday = addCivilDays(date, -(context.dayOfWeek - 1));
    final weeksBefore34 =
        civilDaysBetween(currentSunday, lastOrdinarySunday) ~/ 7;
    return context.copyWith(
      periodType: 'ordinary',
      periodWeek: 34 - weeksBefore34,
    );
  }

  return context;
}

List<String> getDynamicFeastCodesForDate(
  DateTime date,
  DynamicDates? dynamicDates,
) {
  if (dynamicDates == null) return const [];
  final result = <String>[];
  for (final entry in feastNameMap.entries) {
    final feastDate = dynamicDates[entry.key];
    if (feastDate != null && _sameDay(feastDate, date)) result.add(entry.value);
  }
  return result;
}

DateTime? calculateDateForContext(
  int year,
  String periodType,
  int periodWeek,
  int dayOfWeek,
  YearOptions? opts,
  YearOptions? nextYearOpts,
) {
  if (opts == null) return null;
  final advent = _parseDate(opts.data['firstAdventSunday']);
  final easter = _parseDate(opts.data['easterSunday']);
  final ash = _parseDate(opts.data['ashWednesday']);
  if (advent == null || easter == null || ash == null) return null;
  final christmas = DateTime(year, 12, 25);
  DateTime? base;
  var adjustedWeek = periodWeek;

  switch (periodType) {
    case 'advent':
      base = advent;
      break;
    case 'christmas':
      if (periodWeek != 1 && periodWeek != 2) return null;
      final targetWeekday = dayOfWeek == 1 ? 7 : dayOfWeek - 1;
      final baptism = calculateBaptismOfLordDate(year + 1);
      final weekStart = addCivilDays(
        _firstSundayAfterChristmas(christmas),
        (periodWeek - 1) * 7,
      );
      final result = addCivilDays(weekStart, targetWeekday % 7);
      return result.isBefore(baptism) ? result : null;
    case 'lent':
      base = addCivilDays(ash, 4);
      break;
    case 'holyweek':
      base = addCivilDays(easter, -7);
      break;
    case 'easter':
      base = easter;
      break;
    case 'ordinary':
      final firstLastWeek = _asInt(opts.data['ordintaryWeeks1']);
      final secondFirstWeek = _asInt(opts.data['ordintaryWeeks2']);
      if (firstLastWeek == null || secondFirstWeek == null) return null;
      final firstOrdinary = addCivilDays(ash, -3 - (firstLastWeek - 1) * 7);
      if (periodWeek <= firstLastWeek) {
        base = firstOrdinary;
      } else if (periodWeek >= secondFirstWeek) {
        final lastOrdinarySunday = addCivilDays(advent, -7);
        base = addCivilDays(lastOrdinarySunday, -(34 - periodWeek) * 7);
        adjustedWeek = 1;
      } else {
        return null;
      }
      break;
    default:
      return null;
  }

  final baseDay = _catholicWeekday(base);
  final daysToAdd = (adjustedWeek - 1) * 7 + (dayOfWeek - baseDay);
  return addCivilDays(base, daysToAdd);
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
