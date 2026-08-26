import 'package:mybrev_flutter/models/year_options.dart';

class LiturgicalContext {
  final String periodType;
  final int periodWeek;
  /// Day of week: 1=Sunday, 2=Monday … 7=Saturday
  final int dayOfWeek;

  const LiturgicalContext({
    required this.periodType,
    required this.periodWeek,
    required this.dayOfWeek,
  });
}

/// Computes the liturgical context for a date.
/// [opts] — YearOptions for the current liturgical year.
/// [nextYearOpts] — YearOptions for the next liturgical year (may be null).
/// [dynamicDates] — dynamic feast dates (Easter, Pentecost, etc.).
LiturgicalContext computeLiturgicalContext(
  DateTime date,
  YearOptions? opts,
  YearOptions? nextYearOpts,
  DynamicDates? dynamicDates,
) {
  final dayOfWeek = _toCatholicDayOfWeek(date.weekday); // 1=Sun … 7=Sat

  // Extract Easter from dynamicDates (or opts)
  final easter = _getEaster(date, dynamicDates, opts);

  if (easter != null) {
    final period = _getPeriodFromEaster(date, easter, dynamicDates);
    if (period != null) return LiturgicalContext(
      periodType: period.type,
      periodWeek: period.week,
      dayOfWeek: dayOfWeek,
    );
  }

  // Advent
  final advent = _getAdventStart(date.year);
  if (!date.isBefore(advent)) {
    final week = _weekNumber(date, advent);
    return LiturgicalContext(
        periodType: 'advent', periodWeek: week, dayOfWeek: dayOfWeek);
  }

  // Christmas (Dec 25 – Jan 12 approx)
  if ((date.month == 12 && date.day >= 25) ||
      (date.month == 1 && date.day <= 12)) {
    return LiturgicalContext(
        periodType: 'christmas', periodWeek: 0, dayOfWeek: dayOfWeek);
  }
  if (date.month == 1 && date.day <= 24) {
    return LiturgicalContext(
        periodType: 'ordinary', periodWeek: 1, dayOfWeek: dayOfWeek);
  }

  // Fallback: ordinary time
  final epiphany = DateTime(date.year, 1, 6);
  final epiphanyWeek = _weekNumber(date, epiphany);
  return LiturgicalContext(
      periodType: 'ordinary', periodWeek: epiphanyWeek.clamp(1, 34), dayOfWeek: dayOfWeek);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

DateTime? _getEaster(
    DateTime date, DynamicDates? dynamicDates, YearOptions? opts) {
  // Try dynamicDates first
  if (dynamicDates != null) {
    final e = dynamicDates['easter'] ?? dynamicDates['easterSunday'];
    if (e != null) return e;
  }
  // Try yearOptions data
  if (opts?.data['easter'] != null) {
    final raw = opts!.data['easter'];
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is DateTime) return raw;
  }
  // Computus (Gregorian Easter)
  return _computeEaster(date.year);
}

class _Period {
  final String type;
  final int week;
  _Period(this.type, this.week);
}

_Period? _getPeriodFromEaster(
    DateTime date, DateTime easter, DynamicDates? dynamicDates) {
  final diff = date.difference(easter).inDays;

  // Lent: ~46 days before Easter (Ash Wednesday = -46)
  if (diff >= -46 && diff < 0) {
    // Holy Week: last 7 days before Easter
    if (diff >= -7) {
      return _Period('holyweek', 0);
    }
    // Lent weeks
    final week = ((diff + 46) ~/ 7) + 1;
    return _Period('lent', week.clamp(1, 6));
  }

  // Paschal (Easter to Pentecost = +49 days)
  if (diff >= 0 && diff <= 49) {
    final week = (diff ~/ 7) + 1;
    return _Period('easter', week.clamp(1, 7));
  }

  // After Pentecost: ordinary time
  if (diff > 49) {
    // Ordinary time weeks after Pentecost (week 9 onwards roughly)
    final pentecost = easter.add(const Duration(days: 49));
    final afterPentecost = date.difference(pentecost).inDays;
    // Ordinary time continues numbering from where it left off after Epiphany
    // Rough estimate: Pentecost week ≈ ordinary week 10
    final week = 10 + (afterPentecost ~/ 7);
    return _Period('ordinary', week.clamp(1, 34));
  }

  return null;
}

DateTime _getAdventStart(int year) {
  final christmas = DateTime(year, 12, 25);
  final weekday = christmas.weekday;
  final daysToLastSunday = weekday % 7;
  final lastSunday = christmas.subtract(Duration(days: daysToLastSunday));
  return lastSunday.subtract(const Duration(days: 21));
}

int _weekNumber(DateTime date, DateTime start) {
  final diff = date.difference(start).inDays;
  return (diff ~/ 7) + 1;
}

/// Flutter weekday: 1=Mon … 7=Sun → Catholic: 1=Sun, 2=Mon … 7=Sat
int _toCatholicDayOfWeek(int flutterWeekday) {
  return flutterWeekday % 7 + 1;
}

/// Gregorian Easter algorithm (Anonymous Gregorian).
DateTime _computeEaster(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}
