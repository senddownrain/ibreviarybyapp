import 'package:mybrev_flutter/models/year_options.dart';

/// Year anchors of the liturgical calendar, computed on the device.
///
/// Every field of [YearOptions] follows from the date of Easter and the
/// first Sunday of Advent, so the calendar never waits for the network and
/// works for any year, online or offline. Port of `toYearOptions()` in
/// `mybrev/src/utils/ordo/movableFeasts.js` (Belarus: Epiphany on 6 January,
/// Ascension and Corpus Christi on Thursday).

/// Gregorian computus (Meeus/Jones/Butcher).
DateTime computeEasterSunday(int year) {
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

/// First Sunday of Advent: the Sunday falling on or after 27 November.
DateTime computeFirstAdventSunday(int year) {
  final start = DateTime(year, 11, 27);
  return _addDays(start, (DateTime.sunday - start.weekday) % 7);
}

/// Holy Family: the Sunday within the Christmas octave, else 30 December.
DateTime computeHolyFamily(int year) {
  final christmas = DateTime(year, 12, 25);
  if (christmas.weekday == DateTime.sunday) return DateTime(year, 12, 30);
  return _addDays(christmas, DateTime.sunday - christmas.weekday);
}

/// Baptism of the Lord: the Sunday after 6 January.
DateTime computeBaptismOfLord(int year) {
  final epiphany = DateTime(year, 1, 6);
  final days = epiphany.weekday == DateTime.sunday
      ? 7
      : DateTime.sunday - epiphany.weekday;
  return _addDays(epiphany, days);
}

// Calendar arithmetic by civil days (never by 24-hour durations, which
// drift across daylight-saving changes).
DateTime _addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

int _daysBetween(DateTime later, DateTime earlier) => DateTime.utc(
  later.year,
  later.month,
  later.day,
).difference(DateTime.utc(earlier.year, earlier.month, earlier.day)).inDays;

String _iso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

final Map<int, YearOptions> _cache = {};

/// Computed [YearOptions] of a civil year (memoized).
YearOptions computeYearOptions(int year) => _cache.putIfAbsent(year, () {
  final easter = computeEasterSunday(year);
  final pentecost = _addDays(easter, 49);
  final trinity = _addDays(pentecost, 7);
  final firstAdvent = computeFirstAdventSunday(year);
  final christKing = _addDays(firstAdvent, -7);
  final ash = _addDays(easter, -46);
  final baptism = computeBaptismOfLord(year);
  final sundayBeforeAsh = _addDays(ash, -3);
  return YearOptions(
    year: year,
    data: {
      'year': year,
      'easterSunday': _iso(easter),
      'pentecost': _iso(pentecost),
      'firstAdventSunday': _iso(firstAdvent),
      'ashWednesday': _iso(ash),
      'holyFamily': _iso(computeHolyFamily(year)),
      'baptismOfLord': _iso(baptism),
      'ascension': _iso(_addDays(easter, 39)),
      'corpusChristi': _iso(_addDays(trinity, 4)),
      'ordintaryStart1': _iso(_addDays(baptism, 1)),
      'ordintaryWeeks1': _daysBetween(sundayBeforeAsh, baptism) ~/ 7 + 1,
      'ordintaryWeeks2': 34 - _daysBetween(christKing, pentecost) ~/ 7,
    },
  );
});
