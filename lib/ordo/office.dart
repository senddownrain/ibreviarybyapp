/// Office resolution descriptors (port of mybrev `src/utils/ordo/office.js`).
///
/// A descriptor tells the assembler WHERE each component may come from; it
/// never contains texts.
///
/// - `chain`: ordered sources (Proper → Common …) — a fallback, not a choice;
/// - `choice`: a genuine rubrical choice (memorial: the day ↔ a Common).
///
/// Sources: `proper`, `common`, `current-day`, `sunday-week-1`,
/// `complementary`, `proper-of-season`, `office-for-dead`.
library;

import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/season.dart';

const kSundayWeek1Source = 'sunday-week-1';
const kCurrentDaySource = 'current-day';

/// One component of an hour.
class OfficeSlot {
  const OfficeSlot(this.chain, {this.choice = const [], this.choiceDefault});
  final List<String> chain;

  /// Options the rubrics allow after the chain (memorial: day ↔ Common).
  final List<String> choice;
  final String? choiceDefault;
}

/// Te Deum by calendar rule (not by content fields).
bool teDeumFor(String officeKind, Season season) {
  switch (officeKind) {
    case 'solemnity':
    case 'feast':
    case 'easter-octave':
    case 'christmas-octave':
      return true;
    case 'sunday':
      return season.period != 'lent' && season.period != 'holyweek';
  }
  return false;
}

/// I Vespers by liturgical right — independent of `vesper1*` texts.
bool hasFirstVespersByRight(Json candidate, Season season) {
  final rules = candidate['rules'];
  if (rules is Map && rules['firstVespers'] == false) return false;
  if (rules is Map && rules['firstVespers'] == true) return true;
  if (season.date == season.anchors.easterSunday) return false;
  final kind = candidate['officeKind'];
  if (kind == 'solemnity' || kind == 'sunday') return true;
  // GNLYC 13: a feast of the Lord replacing a Sunday of Christmas time or
  // Ordinary Time.
  if (kind == 'feast') {
    return season.isSunday &&
        candidate['category'] == 'lord' &&
        (season.period == 'ordinary' || season.period == 'christmas');
  }
  return false;
}

bool _inChristmasOctave(Season season) =>
    season.period == 'christmas' && season.periodPhase == 'octave';

String complineFor(String officeKind, Season season) {
  if (officeKind == 'solemnity' ||
      officeKind == 'sunday' ||
      officeKind == 'triduum') {
    return 'sunday-after-second-vespers';
  }
  if (officeKind == 'easter-octave' || _inChristmasOctave(season)) {
    return 'sunday-after-first-or-second-vespers';
  }
  if (officeKind == 'feast' && season.isSunday) {
    return 'sunday-after-second-vespers';
  }
  return 'current-weekday';
}

typedef OfficeHours = Map<String, Map<String, OfficeSlot>>;

const _properCommon = OfficeSlot(['proper', 'common']);
OfficeSlot _single(String source) => OfficeSlot([source]);

OfficeHours _properHours(
  OfficeSlot daytimePsalms,
  OfficeSlot daytimeAntiphons,
) {
  Map<String, OfficeSlot> hour() => {
    for (final c in const [
      'hymn',
      'psalmody',
      'antiphons',
      'reading',
      'responsory',
      'canticleAntiphon',
      'intercessions',
      'prayer',
    ])
      c: _properCommon,
  };
  return {
    'invitatory': {'antiphon': _properCommon},
    'officeOfReadings': {
      for (final c in const [
        'hymn',
        'psalmody',
        'antiphons',
        'versicle',
        'reading1',
        'reading2',
        'prayer',
      ])
        c: _properCommon,
    },
    'lauds': {...hour(), 'psalmody': _single(kSundayWeek1Source)},
    'daytime': {
      'hymn': _single(kCurrentDaySource),
      'psalmody': daytimePsalms,
      'antiphons': daytimeAntiphons,
      'reading': _properCommon,
      'prayer': _properCommon,
    },
    'vespers': hour(),
  };
}

OfficeHours _memorialHours() {
  // Own texts stay own; everything else is of the current day by default.
  // Where the rubrics allow the Common, it is a quick user choice.
  const properOrChoice = OfficeSlot(
    ['proper'],
    choice: [kCurrentDaySource, 'common'],
    choiceDefault: kCurrentDaySource,
  );
  const properDay = OfficeSlot(['proper', kCurrentDaySource]);
  final currentDay = _single(kCurrentDaySource);
  Map<String, OfficeSlot> hour() => {
    'hymn': properOrChoice,
    'psalmody': properDay,
    'antiphons': properDay,
    'reading': properOrChoice,
    'responsory': properOrChoice,
    'canticleAntiphon': properOrChoice,
    'intercessions': properOrChoice,
    'prayer': _properCommon,
  };
  return {
    'invitatory': {'antiphon': properOrChoice},
    'officeOfReadings': {
      'hymn': properOrChoice,
      'psalmody': properDay,
      'antiphons': properDay,
      'versicle': properDay,
      'reading1': currentDay,
      'reading2': properOrChoice,
      'prayer': _properCommon,
    },
    'lauds': hour(),
    'daytime': {
      for (final c in const [
        'hymn',
        'psalmody',
        'antiphons',
        'reading',
        'prayer',
      ])
        c: currentDay,
    },
    'vespers': hour(),
  };
}

OfficeHours _temporalHours(String source) {
  final slot = _single(source);
  Map<String, OfficeSlot> all() => {
    for (final c in const [
      'hymn',
      'psalmody',
      'antiphons',
      'reading',
      'responsory',
      'canticleAntiphon',
      'intercessions',
      'prayer',
    ])
      c: slot,
  };
  return {
    'invitatory': {'antiphon': slot},
    'officeOfReadings': {
      for (final c in const [
        'hymn',
        'psalmody',
        'antiphons',
        'versicle',
        'reading1',
        'reading2',
        'prayer',
      ])
        c: slot,
    },
    'lauds': all(),
    'daytime': {
      for (final c in const [
        'hymn',
        'psalmody',
        'antiphons',
        'reading',
        'prayer',
      ])
        c: slot,
    },
    'vespers': all(),
  };
}

OfficeHours officeHoursFor(String officeKind, Season season) {
  switch (officeKind) {
    case 'solemnity':
      // Daytime Prayer: complementary psalmody; on a Sunday, the Sunday's.
      return _properHours(
        _single(season.isSunday ? kSundayWeek1Source : 'complementary'),
        const OfficeSlot(['proper', 'common', kCurrentDaySource]),
      );
    case 'feast':
      return _properHours(
        _single(kCurrentDaySource),
        const OfficeSlot(['proper', kCurrentDaySource]),
      );
    case 'memorial':
    case 'optional-memorial':
      return _memorialHours();
    case 'triduum':
      return _temporalHours('proper-of-season');
    case 'all-souls':
      return _temporalHours('office-for-dead');
  }
  return _temporalHours(kCurrentDaySource);
}

/// Descriptor of one legal Office option (primary or alternative).
class OfficeDescriptor {
  const OfficeDescriptor({
    required this.optionId,
    required this.officeKind,
    required this.teDeum,
    required this.firstVespersByRight,
    required this.compline,
    required this.hours,
    required this.notes,
  });

  final String optionId;
  final String officeKind;
  final bool teDeum;
  final bool firstVespersByRight;
  final String compline;
  final OfficeHours hours;
  final List<String> notes;

  OfficeSlot? slot(String hour, String component) => hours[hour]?[component];

  /// Does the Office let the user choose between the day and a Common?
  bool get hasDayChoice => hours.values.any(
    (components) => components.values.any(
      (slot) => slot.choice.contains(kCurrentDaySource),
    ),
  );
}

OfficeDescriptor buildOfficeDescriptor(Json candidate, Season season) {
  final officeKind = candidate['officeKind'] as String;
  final a = season.anchors;
  return OfficeDescriptor(
    optionId: candidate['id'] as String,
    officeKind: officeKind,
    teDeum: teDeumFor(officeKind, season),
    firstVespersByRight: hasFirstVespersByRight(candidate, season),
    compline: complineFor(officeKind, season),
    hours: officeHoursFor(officeKind, season),
    notes: [
      if (officeKind == 'triduum' && season.date == a.holyThursday)
        'Нешпары адмаўляюць толькі тыя, хто не ўдзельнічае ў вячэрняй Імшы Апошняй Вячэры.',
      if (officeKind == 'triduum' && season.date == a.goodFriday)
        'Нешпары адмаўляюць толькі тыя, хто не ўдзельнічае ў Літургіі Мукі Пана.',
      if (candidate['officeOnly'] == true)
        'Успамін усіх памерлых у нядзелю: літургія гадзінаў — з нядзелі; Імша і чытанні — Успаміну ўсіх памерлых.',
    ],
  );
}

/// Evening of a date: II Vespers of today vs I Vespers of tomorrow
/// (GNLYC 61): the higher row wins; with equal rows today's are kept —
/// except that a Sunday always begins with its I Vespers against a weekday
/// of the same row.
class OrdoEvening {
  const OrdoEvening({
    required this.vespersType,
    required this.celebrationId,
    required this.date,
    required this.title,
    required this.compline,
    this.complineSolemnityPrayer = false,
    this.omittedFirstVespers,
    this.conflict,
  });

  /// `first` (tomorrow), `second` or `of-the-day`.
  final String vespersType;
  final String? celebrationId;
  final String date;
  final String title;
  final String compline;
  final bool complineSolemnityPrayer;
  final String? omittedFirstVespers;
  final Json? conflict;
}

OrdoEvening resolveEvening(
  Json todayPrimary,
  Season todaySeason,
  Json tomorrowPrimary,
  Season tomorrowSeason,
) {
  final tomorrowHasFirst = hasFirstVespersByRight(
    tomorrowPrimary,
    tomorrowSeason,
  );
  final todayPrecedence = todayPrimary['precedence'] as int;
  final tomorrowPrecedence = tomorrowPrimary['precedence'] as int;
  final sundayTie =
      tomorrowPrecedence == todayPrecedence &&
      tomorrowSeason.isSunday &&
      !todaySeason.isSunday;
  // GNLYC 33, 39: Advent ends before Christmas I Vespers, even
  // when 24 December is the fourth Sunday of Advent.
  final christmasBoundary =
      todaySeason.period == 'advent' &&
      tomorrowPrimary['id'] == 'nativity-lord';
  final tomorrowWins =
      tomorrowHasFirst &&
      (tomorrowPrecedence < todayPrecedence || sundayTie || christmasBoundary);
  final todayKind = todayPrimary['officeKind'] as String;
  final todaySecond =
      todayKind == 'solemnity' ||
      todayKind == 'sunday' ||
      todayKind == 'easter-octave' ||
      (todayKind == 'feast' && todaySeason.isSunday) ||
      _inChristmasOctave(todaySeason);
  var compline = complineFor(todayKind, todaySeason);
  final tomorrowKind = tomorrowPrimary['officeKind'];
  if (tomorrowWins &&
      (tomorrowKind == 'solemnity' ||
          tomorrowKind == 'sunday' ||
          tomorrowKind == 'feast')) {
    compline = 'sunday-after-first-vespers';
  }
  return tomorrowWins
      ? OrdoEvening(
          vespersType: 'first',
          celebrationId: tomorrowPrimary['id'] as String?,
          date: tomorrowSeason.date,
          title: '${tomorrowPrimary['title']}',
          compline: compline,
          complineSolemnityPrayer:
              tomorrowKind == 'solemnity' && !tomorrowSeason.isSunday,
          conflict: {
            'today': todayPrimary['id'],
            'tomorrow': tomorrowPrimary['id'],
            'winner': 'tomorrow',
          },
        )
      : OrdoEvening(
          vespersType: todaySecond ? 'second' : 'of-the-day',
          celebrationId: todayPrimary['kind'] == 'temporal'
              ? null
              : todayPrimary['id'] as String?,
          date: todaySeason.date,
          title: '${todayPrimary['title']}',
          compline: compline,
          omittedFirstVespers: tomorrowHasFirst
              ? tomorrowPrimary['id'] as String?
              : null,
          conflict: tomorrowHasFirst
              ? {
                  'today': todayPrimary['id'],
                  'tomorrow': tomorrowPrimary['id'],
                  'winner': 'today',
                }
              : null,
        );
}

const _complineDay = {
  'sunday-after-second-vespers': 1,
  'sunday-after-first-or-second-vespers': 1,
  // Compline after I Vespers of Sunday is the Saturday text (Ps 4, 134).
  'sunday-after-first-vespers': 7,
};

/// `completoriums` weekday (1 = Sunday … 7) for a Compline descriptor.
int complineWeekday(String compline, int dayOfWeek) =>
    _complineDay[compline] ?? dayOfWeek;
