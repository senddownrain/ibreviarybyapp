/// Permanent rules of the temporal cycle and the movable celebrations (port
/// of mybrev `src/utils/ordo/movableFeasts.js`). Nothing is stored per year:
/// every date is computed from Easter, the first Sunday of Advent, Christmas
/// and Epiphany.
library;

import 'package:mybrev_flutter/ordo/dates.dart';

/// Gregorian computus (Meeus/Jones/Butcher).
String computeEasterSundayIso(int year) {
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
  final day = (h + l - 7 * m + 114) % 31 + 1;
  return isoFromParts(year, month, day);
}

/// First Sunday of Advent: the Sunday on or after 27 November.
String computeFirstAdventSundayIso(int year) {
  final nov27 = isoFromParts(year, 11, 27);
  return addDays(nov27, (7 - isoWeekday(nov27)) % 7);
}

/// Holy Family: the Sunday within the Christmas octave, else 30 December.
String computeHolyFamilyIso(int year) {
  final christmas = isoFromParts(year, 12, 25);
  if (isoWeekday(christmas) == 7) return isoFromParts(year, 12, 30);
  return nextSundayAfter(christmas);
}

/// Belarus keeps Epiphany on 6 January: the Baptism is the Sunday after it.
String computeBaptismOfLordIso(int year) =>
    nextSundayAfter(isoFromParts(year, 1, 6));

/// Year anchors (Belarus: Epiphany fixed, Ascension and Corpus Christi on
/// Thursday). `baptismOfLord` / `epiphany` refer to January of [year],
/// `holyFamily` to December.
class YearAnchors {
  YearAnchors._(this.year, this._dates);

  factory YearAnchors.compute(int year) {
    final easterSunday = computeEasterSundayIso(year);
    final pentecost = addDays(easterSunday, 49);
    final trinity = addDays(pentecost, 7);
    final firstAdventSunday = computeFirstAdventSundayIso(year);
    final sacredHeart = addDays(pentecost, 19);
    final ashWednesday = addDays(easterSunday, -46);
    return YearAnchors._(year, {
      'epiphany': isoFromParts(year, 1, 6),
      'baptismOfLord': computeBaptismOfLordIso(year),
      'ashWednesday': ashWednesday,
      'firstLentSunday': addDays(ashWednesday, 4),
      'palmSunday': addDays(easterSunday, -7),
      'holyThursday': addDays(easterSunday, -3),
      'goodFriday': addDays(easterSunday, -2),
      'holySaturday': addDays(easterSunday, -1),
      'easterSunday': easterSunday,
      'divineMercySunday': addDays(easterSunday, 7),
      'ascension': addDays(easterSunday, 39),
      'pentecost': pentecost,
      'maryMotherChurch': addDays(pentecost, 1),
      'christTheHighPriest': addDays(pentecost, 4),
      'trinity': trinity,
      'corpusChristi': addDays(trinity, 4),
      'sacredHeart': sacredHeart,
      'immaculateHeart': addDays(sacredHeart, 1),
      'christKing': addDays(firstAdventSunday, -7),
      'firstAdventSunday': firstAdventSunday,
      'christmas': isoFromParts(year, 12, 25),
      'holyFamily': computeHolyFamilyIso(year),
    });
  }

  final int year;
  final Map<String, String> _dates;

  /// Anchor by name (`easterSunday`, `pentecost` …), null when unknown.
  String? operator [](String name) => _dates[name];

  Map<String, String> get all => Map.unmodifiable(_dates);

  String get epiphany => _dates['epiphany']!;
  String get baptismOfLord => _dates['baptismOfLord']!;
  String get ashWednesday => _dates['ashWednesday']!;
  String get firstLentSunday => _dates['firstLentSunday']!;
  String get palmSunday => _dates['palmSunday']!;
  String get holyThursday => _dates['holyThursday']!;
  String get goodFriday => _dates['goodFriday']!;
  String get holySaturday => _dates['holySaturday']!;
  String get easterSunday => _dates['easterSunday']!;
  String get divineMercySunday => _dates['divineMercySunday']!;
  String get ascension => _dates['ascension']!;
  String get pentecost => _dates['pentecost']!;
  String get christKing => _dates['christKing']!;
  String get firstAdventSunday => _dates['firstAdventSunday']!;
  String get christmas => _dates['christmas']!;
}

final Map<int, YearAnchors> _anchorCache = {};

/// Memoized anchors of [year].
YearAnchors yearAnchors(int year) =>
    _anchorCache.putIfAbsent(year, () => YearAnchors.compute(year));
