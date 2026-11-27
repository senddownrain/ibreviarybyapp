/// Recommended start dates (shared contract §4). Pure: civil dates only; the
/// movable celebrations come from the existing Ordo engine.
library;

import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/engine.dart';
import 'package:mybrev_flutter/ordo/movable_feasts.dart';

/// The date of a celebration in a civil [year], null when unknown.
typedef NovenaFeastDate =
    String? Function(String event, int year, String diocese);

/// Good Friday anchors the year itself; the other events are celebrations of
/// the selected diocese's calendar (after transfers).
NovenaFeastDate novenaFeastDates(OrdoEngine engine) =>
    (event, year, diocese) => event == 'good-friday'
    ? yearAnchors(year).goodFriday
    : engine.plan(year, diocese).celebrationDates[event];

/// Whether [today] (`YYYY-MM-DD`) is a recommended start of [schedule].
/// Only that very day: a missed start is never offered afterwards.
bool novenaStartsOn(
  Map schedule,
  String today, {
  required Iterable<String> dioceses,
  required NovenaFeastDate feastDate,
}) {
  if (schedule['enabled'] != true) return false;
  final scope = schedule['dioceses'];
  final applicable = scope is List && scope.isNotEmpty
      ? dioceses.where(scope.contains).toList()
      : dioceses.toList();
  if (applicable.isEmpty) return false;
  final extra = schedule['extraDates'];
  if (extra is List && extra.contains(today)) return true;

  final now = parseIso(today);
  final years = [now.year - 1, now.year, now.year + 1];
  final offset = (schedule['offsetDays'] as num?)?.toInt() ?? 0;
  final month = (schedule['month'] as num?)?.toInt();
  final day = (schedule['day'] as num?)?.toInt();

  switch (schedule['type']) {
    case 'fixedStart':
      return month == now.month && day == now.day;
    case 'fixedFeast':
      if (month == null || day == null) return false;
      return years.any((year) {
        final feast = isoFromParts(year, month, day);
        // 29 February does not roll over into March.
        if (parseIso(feast).month != month) return false;
        return addDays(feast, offset) == today;
      });
    case 'liturgical':
      final event = schedule['event'];
      if (event is! String) return false;
      return applicable.any(
        (diocese) => years.any((year) {
          final feast = feastDate(event, year, diocese);
          return feast != null && addDays(feast, offset) == today;
        }),
      );
    default:
      return false;
  }
}
