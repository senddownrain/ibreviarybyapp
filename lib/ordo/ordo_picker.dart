/// The picker «Знайсці дзень» on the canonical engine (port of the intent
/// of mybrev `ordoDatePicker.js`):
///
/// ```text
/// Перыяды → a liturgical position (period · week · day) → its civil date
/// Святы   → every celebration actually kept in the chosen year, on its
///           final date (transfers, year overrides, selected dioceses)
/// ```
///
/// No legacy `days` source, no second calendar algorithm: both lists are
/// read from the resolved days of the year.
library;

import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/engine.dart';
import 'package:mybrev_flutter/ordo/movable_feasts.dart';
import 'package:mybrev_flutter/ordo/season.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';

/// Years of the selector: strictly ascending, a window around today, and
/// the selected year always included (also outside the window).
List<int> pickerYears(
  int selected, {
  int? today,
  int before = 6,
  int after = 12,
}) {
  final now = today ?? DateTime.now().year;
  final years = {
    for (var year = now - before; year <= now + after; year++) year,
    selected,
  }.toList()..sort();
  return years;
}

/// One celebration of the year in the «Святы» list.
class PickerFeast {
  PickerFeast({
    required this.option,
    required this.date,
    required this.dioceses,
  });

  final OrdoOption option;

  /// Final ISO date (after transfers / year overrides).
  final String date;
  final List<String> dioceses;
  int _all = 1;

  String get id => option.id;
  String get title => option.title;

  /// fixed | movable | diocesan
  String get kind {
    if (option.dioceseId != null || option.layer == 'diocese') {
      return 'diocesan';
    }
    final dateRule = option.daysRef?['source'];
    return dateRule == 'dynamic' || option.feastCode != null
        ? 'movable'
        : 'fixed';
  }

  bool get transferred =>
      option.transferredFrom != null || option.movedFrom != null;

  List<String> get colors => [option.color, ...option.colorAlternatives];

  List<String> get badges => dioceses.length == _all
      ? const []
      : [for (final id in dioceses) kDioceseBadges[id] ?? id];
}

/// Every celebration kept in [year] for [dioceses] (primary first), in
/// date order. A celebration that is only suppressed (impeded, omitted) is
/// not kept that year and is not listed; one with another rank in another
/// diocese is its own row.
List<PickerFeast> pickerFeastsOfYear(
  OrdoEngine engine,
  int year,
  List<String> dioceses,
) {
  final rows = <String, PickerFeast>{};
  for (final diocese in dioceses) {
    for (final day in engine.year(year, diocese: diocese)) {
      for (final option in [...day.options, ...day.commemorations]) {
        if (option.isTemporal) continue;
        if (option.kind == 'votive-memorial') continue;
        final key = '${option.id}|${option.rank}|${day.date}';
        (rows[key] ??= PickerFeast(
          option: option,
          date: day.date,
          dioceses: [],
        )).dioceses.add(diocese);
      }
    }
  }
  final list = rows.values.toList();
  stableSort(list, (a, b) => a.date.compareTo(b.date));
  for (final row in list) {
    row._all = dioceses.length;
  }
  return list;
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
      return [
        for (final week in pickerPositions(year, period).values) ...week.values,
      ]..sort();
    case 'lent':
      final ash = yearAnchors(year).ashWednesday;
      return [for (var day = 0; day < 4; day++) addDays(ash, day)];
  }
  return const [];
}
