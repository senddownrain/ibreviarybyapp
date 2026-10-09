/// Ordo notes: selector evaluation (port of mybrev `src/utils/ordo/notes.js`).
///
/// The notes are the canonical normalized `liturgicalOrdoNotes`; the app
/// only reads them — no note generalization happens here.
library;

import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';

const _noteCelebrationAliases = {'naradzhenne-pana': 'nativity-lord'};

/// What a selector sees of a resolved day.
class NoteDayView {
  const NoteDayView({
    required this.date,
    required this.period,
    required this.periodPhase,
    required this.week,
    required this.dayOfWeek,
    required this.primary,
    required this.alternatives,
    required this.commemorations,
    required this.suppressed,
  });
  final String date;
  final String period;
  final String periodPhase;
  final int week;
  final int dayOfWeek;
  final Json primary;
  final List<Json> alternatives;
  final List<Json> commemorations;
  final List<Json> suppressed;
}

bool _nthWeekdayMatches(String iso, Map selector) {
  final p = parseIso(iso);
  if (selector['month'] != null && _num(selector['month']) != p.month) {
    return false;
  }
  if (isoWeekday(iso) != _num(selector['weekday'] ?? selector['isoWeekday'])) {
    return false;
  }
  final nth = _num(selector['nth']);
  if (nth == -1) return parseIso(addDays(iso, 7)).month != p.month;
  return (p.day / 7).ceil() == nth;
}

int? _num(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}');

bool _phaseMatches(String phase, NoteDayView day) {
  if (phase == day.periodPhase) return true;
  final dow = day.dayOfWeek;
  switch ('${day.period}:$phase') {
    case 'advent:before-dec17':
      return day.periodPhase == 'advent-weekdays';
    case 'christmas:after-octave':
      return day.periodPhase != 'octave';
    case 'lent:ash-wednesday-week':
      return day.periodPhase == 'ash-days';
    case 'holyweek:holy-week':
      return dow <= 4 && day.periodPhase != 'triduum';
    case 'holyweek:holy-thursday':
      return dow == 5;
    case 'holyweek:triduum':
      return day.periodPhase == 'triduum' && dow >= 6;
    case 'easter:after-octave':
      return day.periodPhase != 'octave';
  }
  return false;
}

Set<String> _celebrationIds(NoteDayView day, String role) {
  final ids = <String>{};
  void add(Json? item) {
    if (item == null) return;
    ids.add('${item['id']}');
    final code = item['feastCode'];
    if (code != null) {
      ids
        ..add('$code')
        ..add('$code'.replaceFirst(RegExp('^feast-'), ''));
    }
  }

  add(day.primary);
  if (role == 'celebrated' || role == 'any') {
    day.alternatives.forEach(add);
    day.commemorations.forEach(add);
  }
  if (role == 'any') day.suppressed.forEach(add);
  return ids;
}

/// Final (post-transfer) dates of a celebration around the day.
typedef DateOfCelebration = List<String> Function(String celebrationId);

bool matchesSelector(
  Object? selector,
  NoteDayView day,
  DateOfCelebration dateOfCelebration,
) {
  if (selector is! Map) return false;
  final p = parseIso(day.date);
  switch (selector['type']) {
    case 'fixed-date':
      return _num(selector['month']) == p.month &&
          _num(selector['day']) == p.day;
    case 'exact-date':
      return selector['date'] == day.date;
    case 'months':
      return ((selector['months'] as List?) ?? const [])
          .map(_num)
          .contains(p.month);
    case 'celebration':
      final raw = '${selector['celebrationId']}';
      final id = _noteCelebrationAliases[raw] ?? raw;
      return _celebrationIds(
        day,
        (selector['role'] ?? 'celebrated') as String,
      ).contains(id);
    case 'period':
      return selector['period'] == day.period &&
          (selector['dayOfWeek'] == null ||
              _num(selector['dayOfWeek']) == day.dayOfWeek);
    case 'day-of-month':
      final months = (selector['months'] as List?) ?? const [];
      return _num(selector['day']) == p.day &&
          (months.isEmpty || months.map(_num).contains(p.month));
    case 'period-phase':
      return selector['period'] == day.period &&
          _phaseMatches('${selector['phase']}', day);
    case 'period-day':
      return selector['period'] == day.period &&
          (selector['week'] == null || _num(selector['week']) == day.week) &&
          (selector['dayOfWeek'] == null ||
              _num(selector['dayOfWeek']) == day.dayOfWeek);
    case 'relative':
    case 'relative-to-celebration':
      final raw = '${selector['celebrationId']}';
      final id = _noteCelebrationAliases[raw] ?? raw;
      final from = _num(selector['offsetDays']) ?? 0;
      final through = selector['throughOffsetDays'] == null
          ? from
          : _num(selector['throughOffsetDays']) ?? from;
      final low = from < through ? from : through;
      final high = from < through ? through : from;
      for (final date in dateOfCelebration(id)) {
        for (var offset = low; offset <= high; offset++) {
          if (addDays(date, offset) == day.date) return true;
        }
      }
      return false;
    case 'nth-weekday-of-month':
      return _nthWeekdayMatches(day.date, selector);
    case 'all':
      return ((selector['selectors'] as List?) ?? const []).every(
        (item) => matchesSelector(item, day, dateOfCelebration),
      );
    case 'any':
      return ((selector['selectors'] as List?) ?? const []).any(
        (item) => matchesSelector(item, day, dateOfCelebration),
      );
    case 'not':
      return !matchesSelector(selector['selector'], day, dateOfCelebration);
  }
  return false;
}

bool noteInScope(Json note, String diocese) {
  final scope = (note['scope'] as Map?) ?? const {'level': 'universal'};
  switch (scope['level']) {
    case 'universal':
    case 'belarus':
      return true;
    case 'diocese':
      if (diocese.isEmpty) return false;
      final ids = [scope['dioceseId'], ...?(scope['dioceseIds'] as List?)];
      return ids.any(
        (id) => id != null && normalizeDioceseId('$id') == diocese,
      );
  }
  return false;
}

/// The notes of [notes] that apply to the resolved day.
List<Json> selectOrdoNotes(
  Iterable<Json> notes,
  NoteDayView day, {
  required String diocese,
  required DateOfCelebration dateOfCelebration,
}) => [
  for (final note in notes)
    if (noteInScope(note, diocese) &&
        (note['validFrom'] == null ||
            day.date.compareTo('${note['validFrom']}') >= 0) &&
        (note['validUntil'] == null ||
            day.date.compareTo('${note['validUntil']}') <= 0) &&
        matchesSelector(note['selector'], day, dateOfCelebration))
      {...note, 'displayOnly': note['displayOnly'] ?? note['effect'] == null},
];

// ── Books (final phase §13.1) ───────────────────────────────────────────

/// Lectionary / Liturgy of the Hours volumes of a day: notes of the
/// category `books` carry `books: {lectionaryVolume?, hoursVolume?}`; they
/// are day metadata, not «Асаблівыя заўвагі».
class OrdoBooks {
  const OrdoBooks({
    this.lectionaryVolume,
    this.hoursVolume,
    this.noteIds = const [],
  });

  /// Roman numeral of the Lectionary volume («III»), or null.
  final String? lectionaryVolume;

  /// Roman numeral of the Liturgy of the Hours volume, or null.
  final String? hoursVolume;

  /// The notes the volumes come from.
  final List<String> noteIds;

  /// «Лекцыянарый т. III · Літургія гадзін т. III» (mybrev `booksLabel`).
  String get label => [
    if (lectionaryVolume != null) 'Лекцыянарый т. $lectionaryVolume',
    if (hoursVolume != null) 'Літургія гадзінаў т. $hoursVolume',
  ].join(' · ');

  Json toJson() => {
    'lectionaryVolume': lectionaryVolume,
    'hoursVolume': hoursVolume,
    'noteIds': noteIds,
  };
}

/// The most specific selector wins per field (celebration → day → period
/// phase → period).
const _bookSelectorRank = {
  'celebration': 0,
  'exact-date': 1,
  'fixed-date': 1,
  'period-day': 1,
  'relative': 1,
  'all': 2,
  'period-phase': 3,
  'period': 4,
};

bool isBooksNote(Json note) =>
    note['category'] == 'books' && note['books'] is Map;

/// The volumes of the selected notes, or null (port of `booksFromNotes`).
OrdoBooks? booksFromNotes(Iterable<Json> notes) {
  final ranked = [
    for (final note in notes.where(isBooksNote))
      (note, _bookSelectorRank[(note['selector'] as Map?)?['type']] ?? 5),
  ];
  stableSort(ranked, (a, b) {
    final rank = a.$2.compareTo(b.$2);
    return rank != 0 ? rank : '${a.$1['id']}'.compareTo('${b.$1['id']}');
  });
  final values = <String, String>{};
  final ids = <String>[];
  for (final field in const ['lectionaryVolume', 'hoursVolume']) {
    for (final (note, _) in ranked) {
      final value = (note['books'] as Map)[field];
      if (value == null || value == '' || value == false) continue;
      values[field] = '$value';
      if (!ids.contains('${note['id']}')) ids.add('${note['id']}');
      break;
    }
  }
  if (ids.isEmpty) return null;
  return OrdoBooks(
    lectionaryVolume: values['lectionaryVolume'],
    hoursVolume: values['hoursVolume'],
    noteIds: ids,
  );
}
