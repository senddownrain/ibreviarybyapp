/// The picker «Знайсці дзень» on the canonical engine (port of the intent
/// of mybrev `ordoDatePicker.js`):
///
/// ```text
/// Перыяды → a liturgical position (period · week · day) → its civil date
/// Святы   → active calendar definitions, including impeded celebrations;
///           Ordo supplies dates and legal contexts for existing readers.
/// ```
///
/// No legacy `days` source and no second calendar algorithm.
library;

import 'dart:convert';

import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/engine.dart';
import 'package:mybrev_flutter/ordo/movable_feasts.dart';
import 'package:mybrev_flutter/ordo/season.dart';
import 'package:mybrev_flutter/ordo/year_plan.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';

/// One celebration of the year in the «Святы» list.
class PickerFeast {
  PickerFeast({
    required this.option,
    required this.date,
    required this.dioceses,
    this.nominalDate,
    this.hoursAllowed = false,
    this.readingsAllowed = false,
  });

  final OrdoOption option;

  /// Final ISO date (after transfers / year overrides).
  final String? date;
  final String? nominalDate;
  final bool hoursAllowed;
  final bool readingsAllowed;
  final List<String> dioceses;
  int _all = 1;

  String get id => option.id;
  String get title => option.title;

  bool allowedInYear({required bool readingsMode}) =>
      readingsMode ? readingsAllowed : hoursAllowed;

  String? get status => option.role == 'commemoration'
      ? 'Толькі памінанне'
      : !hoursAllowed && !readingsAllowed
      ? 'Не адзначаецца ў гэтым годзе'
      : hoursAllowed
      ? null
      : 'Толькі чытанні';

  bool get isDiocesan => option.dioceseId != null || option.layer == 'diocese';

  /// fixed | movable, independently of diocesan provenance.
  String get kind {
    return option.data['date'] is Map &&
            (option.data['date'] as Map)['type'] != 'fixed'
        ? 'movable'
        : 'fixed';
  }

  bool get transferred =>
      option.transferredFrom != null || option.movedFrom != null;

  List<String> get colors => {
    option.color,
    ...option.colorAlternatives,
  }.where(kLiturgicalColors.contains).toList();

  List<String> get badges => dioceses.length == _all
      ? const []
      : [for (final id in dioceses) kDioceseBadges[id] ?? id];
}

/// Full definitions for [dioceses], with dates and permissions from [year].
/// Different definitions or local permissions remain separate rows: a legal
/// choice in one diocese must never enable an impeded choice in another.
List<PickerFeast> pickerFeastsOfYear(
  OrdoEngine engine,
  int year,
  List<String> dioceses,
) {
  final rows = <String, PickerFeast>{};
  for (final diocese in dioceses.toSet()) {
    final definitions = buildCalendarLayers(
      engine.definitions,
      diocese: diocese,
    ).celebrations;
    final plan = engine.plan(year, diocese);
    final placements = <String, Placement>{
      for (final list in plan.removedByDate.values)
        for (final placement in list) placement.id: placement,
      for (final list in plan.byDate.values)
        for (final placement in list)
          if (!placement.transferredOut) placement.id: placement,
    };
    // Year-only additions supplement, rather than replace, full definitions.
    for (final entry in {...plan.celebrations, ...definitions}.entries) {
      final definition = entry.value;
      final placement = placements[entry.key];
      final date = placement?.date;
      final day = date == null ? null : engine.resolve(date, diocese: diocese);
      final resolved = day == null
          ? null
          : [
              ...day.options,
              ...day.commemorations,
              ...day.suppressed,
            ].where((option) => option.id == entry.key).firstOrNull;
      final effective = placement?.celebration ?? definition;
      final option = OrdoOption({
        ...effective,
        ...?resolved?.data,
        // Candidates default missing colours to white; search must not.
        'color': effective['color'] ?? '',
        'colorAlternatives': effective['colorAlternatives'] ?? const [],
      });
      final rule = definition['date'];
      final nominalDate = rule is Map && rule['type'] == 'fixed'
          ? '$year-${rule['month'].toString().padLeft(2, '0')}-'
                '${rule['day'].toString().padLeft(2, '0')}'
          : placement?.originalDate;
      final hoursAllowed =
          day?.officeOptions.any((o) => o.id == option.id) ?? false;
      final readingsAllowed =
          day?.options.any((o) => o.id == option.id) ?? false;
      final key = jsonEncode(
        _pickerVariantKey([
          for (final fields in [definition, effective])
            {
              for (final entry in fields.entries)
                if (!const [
                  'dioceseId',
                  'layerTrail',
                  'inheritedFrom',
                  'suppressedBy',
                ].contains(entry.key))
                  entry.key: entry.value,
            },
          option.rank,
          option.role,
          option.officeKind,
          nominalDate,
          date,
          hoursAllowed,
          readingsAllowed,
        ]),
      );
      (rows[key] ??= PickerFeast(
        option: option,
        date: date,
        nominalDate: nominalDate,
        hoursAllowed: hoursAllowed,
        readingsAllowed: readingsAllowed,
        dioceses: [],
      )).dioceses.add(diocese);
    }
  }
  final list = rows.values.toList();
  stableSort(
    list,
    (a, b) => (a.nominalDate ?? a.date ?? '9999').compareTo(
      b.nominalDate ?? b.date ?? '9999',
    ),
  );
  for (final row in list) {
    row._all = dioceses.toSet().length;
  }
  return list;
}

// Ignore provenance of the diocese itself, but preserve source, title, rank,
// colour, date rule and content references (including nested source fields).
Object? _pickerVariantKey(Object? value) {
  if (value is List) return value.map(_pickerVariantKey).toList();
  if (value is! Map) return value;
  final keys = value.keys.cast<String>().toList()..sort();
  return {for (final key in keys) key: _pickerVariantKey(value[key])};
}

// Compare the definition, excluding computed placement and diocesan provenance.
String _pickerTextKey(Map<String, dynamic> fields) => jsonEncode(
  _pickerVariantKey({
    for (final key in const [
      'id',
      'title',
      'rank',
      'category',
      'layer',
      'date',
      'source',
      'daysRef',
      'readingsRef',
      'fallbackDaysRefs',
      'templates',
      'defaultTemplate',
      'feastCode',
      'properKind',
      'readingsReference',
      'contentStatus',
    ])
      if (fields.containsKey(key)) key: fields[key],
    'color': fields['color'] ?? '',
    'colorAlternatives': fields['colorAlternatives'] ?? const [],
    'rules': fields['rules'] ?? const {},
  }),
);

/// Real legal occurrences of exactly this definition in the same diocese.
/// Search readers may use another year; the current calendar stays unchanged.
Iterable<OrdoDay> pickerFeastTextDays(
  OrdoEngine engine,
  PickerFeast feast,
  int year,
  String diocese, {
  required bool readingsMode,
}) sync* {
  if (!feast.dioceses.contains(diocese)) return;
  final first = kCalendarFirstDate.year;
  final last = kCalendarLastDate.year;
  final center = year.clamp(first, last);
  final identity = _pickerTextKey(feast.option.data);
  for (var offset = 0; offset <= last - first; offset++) {
    for (final candidate in [
      center + offset,
      if (offset > 0) center - offset,
    ]) {
      if (candidate < first || candidate > last) continue;
      final plan = engine.plan(candidate, diocese);
      final date = plan.celebrationDates[feast.id];
      if (date == null) continue;
      final placement = plan.byDate[date]
          ?.where((p) => p.id == feast.id && !p.transferredOut)
          .firstOrNull;
      if (placement == null ||
          _pickerTextKey(placement.celebration) != identity) {
        continue;
      }
      final day = engine.resolve(date, diocese: diocese);
      final options = readingsMode ? day.options : day.officeOptions;
      if (options.any((o) => o.id == feast.id)) yield day;
    }
  }
}

/// Liturgical positions of a period that exist in the chosen year:
/// week → (day of week → ISO date). Advent and Christmas are those
/// beginning in December of [year]; the other periods lie in [year].
Map<int, Map<int, String>> pickerPositions(int year, String period) {
  final result = <int, Map<int, String>>{};
  final List<String> dates;
  if (period == 'christmas') {
    final end = yearAnchors(year + 1).baptismOfLord;
    dates = [
      for (
        var iso = isoFromParts(year, 12, 25);
        iso.compareTo(end) <= 0;
        iso = addDays(iso, 1)
      )
        iso,
    ];
  } else {
    dates = daysOfYear(year);
  }
  for (final iso in dates) {
    final season = computeSeason(iso);
    if (season.period != period) continue;
    (result[season.periodWeek] ??= {}).putIfAbsent(season.dayOfWeek, () => iso);
  }
  return result;
}

/// The civil date of a position, or null when it does not exist that year
/// (never a date of a neighbouring period).
String? pickerDateForPosition(int year, String period, int week, int day) =>
    pickerPositions(year, period)[week]?[day];

/// Calendar dates that are their own liturgical days: 17–24 December,
/// 25 December – Baptism, Ash Wednesday – Saturday.
List<String> pickerExactDates(int year, String period) {
  switch (period) {
    case 'advent':
      return [for (var day = 17; day <= 24; day++) isoFromParts(year, 12, day)];
    case 'christmas':
      // Calendar dates must not collapse into repeated week/weekday positions.
      final end = yearAnchors(year + 1).baptismOfLord;
      return [
        for (
          var iso = isoFromParts(year, 12, 25);
          iso.compareTo(end) <= 0;
          iso = addDays(iso, 1)
        )
          if (computeSeason(iso).period == period) iso,
      ];
    case 'lent':
      final ash = yearAnchors(year).ashWednesday;
      return [for (var day = 0; day < 4; day++) addDays(ash, day)];
  }
  return const [];
}
