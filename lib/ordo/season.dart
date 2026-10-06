/// Temporal cycle of a date (port of mybrev `src/utils/ordo/season.js`):
/// period, week, weekday, phase, psalter week and lectionary cycles. Period
/// keys and week numbering are those of the `days` period documents
/// (`<period>-w<week>-d<day>`).
library;

import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/movable_feasts.dart';
import 'package:mybrev_flutter/utils/liturgical_psalter.dart';

/// Lectionary cycles of the liturgical year containing a date.
class ReadingCycle {
  const ReadingCycle(this.liturgicalYear, this.sunday, this.weekday);
  final int liturgicalYear;

  /// `A` | `B` | `C`.
  final String sunday;

  /// `1` | `2`.
  final String weekday;
}

class Season {
  const Season({
    required this.date,
    required this.period,
    required this.periodWeek,
    required this.dayOfWeek,
    required this.periodPhase,
    required this.isSunday,
    required this.psalterWeek,
    required this.readingCycle,
    required this.anchors,
  });

  final String date;
  final String period;
  final int periodWeek;

  /// 1 = Sunday … 7 = Saturday (Ash Wednesday days: 4…7 of week 0).
  final int dayOfWeek;
  final String periodPhase;
  final bool isSunday;
  final int? psalterWeek;
  final ReadingCycle readingCycle;
  final YearAnchors anchors;
}

ReadingCycle _lectionaryCycles(String iso, YearAnchors anchors) {
  final liturgicalYear = iso.compareTo(anchors.firstAdventSunday) >= 0
      ? anchors.year + 1
      : anchors.year;
  return ReadingCycle(
    liturgicalYear,
    const ['A', 'B', 'C'][(liturgicalYear - 1) % 3],
    liturgicalYear % 2 == 1 ? '1' : '2',
  );
}

int _christmasWeek(String iso, String christmas) {
  final firstSunday = nextSundayAfter(christmas);
  if (iso.compareTo(firstSunday) < 0) return 1;
  return diffDays(iso, firstSunday) ~/ 7 + 1;
}

Season computeSeason(String iso) {
  final p = parseIso(iso);
  final a = yearAnchors(p.year);
  final weekday = liturgicalDayOfWeek(iso);
  Season base(String period, int periodWeek, int dayOfWeek, String phase) =>
      Season(
        date: iso,
        period: period,
        periodWeek: periodWeek,
        dayOfWeek: dayOfWeek,
        periodPhase: phase,
        isSunday: weekday == 1,
        psalterWeek: calculatePsalterWeek(
          date: dateOfIso(iso),
          periodType: period,
          periodWeek: periodWeek,
        ),
        readingCycle: _lectionaryCycles(iso, a),
        anchors: a,
      );
  bool before(String x, String y) => x.compareTo(y) < 0;
  bool notBefore(String x, String y) => x.compareTo(y) >= 0;

  // Advent: first Sunday of Advent up to 24 December.
  if (notBefore(iso, a.firstAdventSunday) && before(iso, a.christmas)) {
    final diff = diffDays(iso, a.firstAdventSunday);
    return base(
      'advent',
      diff ~/ 7 + 1,
      diff % 7 + 1,
      p.month == 12 && p.day >= 17 ? 'dec17-24' : 'advent-weekdays',
    );
  }

  // Christmas: 25 December to the Baptism of the Lord inclusive.
  final christmasStart = p.month == 12
      ? a.christmas
      : isoFromParts(p.year - 1, 12, 25);
  final christmasEnd = p.month == 12
      ? yearAnchors(p.year + 1).baptismOfLord
      : a.baptismOfLord;
  if (notBefore(iso, christmasStart) && !before(christmasEnd, iso)) {
    final octaveEnd = addDays(christmasStart, 7);
    final epiphany = p.month == 12
        ? yearAnchors(p.year + 1).epiphany
        : a.epiphany;
    final phase = !before(octaveEnd, iso)
        ? 'octave'
        : before(iso, epiphany)
        ? 'before-epiphany'
        : 'after-epiphany';
    return base(
      'christmas',
      _christmasWeek(iso, christmasStart),
      weekday,
      phase,
    );
  }

  // Lent and Holy Week.
  if (notBefore(iso, a.ashWednesday) && before(iso, a.easterSunday)) {
    if (before(iso, a.firstLentSunday)) {
      return base(
        'lent',
        0,
        7 + diffDays(iso, a.firstLentSunday) + 1,
        'ash-days',
      );
    }
    if (notBefore(iso, a.palmSunday)) {
      final dayOfWeek = diffDays(iso, a.palmSunday) + 1;
      final phase = dayOfWeek == 1
          ? 'palm-sunday'
          : notBefore(iso, a.holyThursday)
          ? 'triduum'
          : 'holy-week';
      return base('holyweek', 1, dayOfWeek, phase);
    }
    final diff = diffDays(iso, a.firstLentSunday);
    return base('lent', diff ~/ 7 + 1, diff % 7 + 1, 'lent-weeks');
  }

  // Easter: Easter Sunday to Pentecost inclusive.
  if (notBefore(iso, a.easterSunday) && !before(a.pentecost, iso)) {
    final diff = diffDays(iso, a.easterSunday);
    var phase = 'before-ascension';
    if (diff <= 7) {
      phase = 'octave';
    } else if (iso == a.pentecost) {
      phase = 'pentecost';
    } else if (before(a.ascension, iso)) {
      phase = 'after-ascension';
    }
    return base('easter', diff ~/ 7 + 1, diff % 7 + 1, phase);
  }

  // Ordinary Time before Lent: week I starts the Monday after the Baptism.
  if (before(a.baptismOfLord, iso) && before(iso, a.ashWednesday)) {
    final diff = diffDays(iso, a.baptismOfLord);
    return base('ordinary', diff ~/ 7 + 1, weekday, 'before-lent');
  }

  // Ordinary Time after Pentecost, counted back from Christ the King (34).
  final weeksBefore = diffDays(a.christKing, sundayOnOrBefore(iso)) ~/ 7;
  return base('ordinary', 34 - weeksBefore, weekday, 'after-pentecost');
}

/// Row of the Table of Liturgical Days (GNLYC 59) of the temporal day itself.
int temporalPrecedence(Season season) {
  final a = season.anchors;
  final date = season.date;
  if (date == a.goodFriday ||
      date == a.holySaturday ||
      date == a.easterSunday) {
    return 1;
  }
  if (season.period == 'holyweek') return 2;
  if (date == a.ashWednesday) return 2;
  if (season.period == 'easter' && season.periodPhase == 'octave') return 2;
  if (season.isSunday &&
      const {'advent', 'lent', 'easter'}.contains(season.period)) {
    return 2;
  }
  if (season.isSunday) return 6;
  if (season.period == 'advent' && season.periodPhase == 'dec17-24') return 9;
  if (season.period == 'christmas' && season.periodPhase == 'octave') return 9;
  if (season.period == 'lent') return 9;
  return 13;
}

bool isPrivilegedWeekday(Season season) => temporalPrecedence(season) == 9;
