import 'dart:async';

import 'package:hive/hive.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

/// In-memory secondary index of the cached `days` documents.
///
/// A liturgical date needs «the documents of 12.11», «the documents of
/// feast-ascension» and «the period day advent/2/3». Without an index every
/// one of those lookups walked the whole box and copied every document —
/// several times per date change, on the UI isolate. The index reads the
/// four selector fields once and answers lookups with document ids.
///
/// It is rebuilt lazily after any write to the box (Hive notifies watchers
/// synchronously), so it can never serve a stale answer.
class DaysIndex {
  DaysIndex._();

  static Box? _box;
  static StreamSubscription<BoxEvent>? _subscription;
  static bool _dirty = true;
  static final Map<String, List<String>> _byDate = {};
  static final Map<String, List<String>> _byFeast = {};
  static final Map<String, String> _byPeriod = {};

  /// Number of rebuilds (diagnostics and tests).
  static int rebuilds = 0;

  static List<String> idsByDate(Iterable<String> dateKeys) {
    _ensure();
    return [for (final key in dateKeys) ...?_byDate[key]];
  }

  static List<String> idsByFeast(Iterable<String> feastCodes) {
    _ensure();
    return [for (final code in feastCodes) ...?_byFeast[code]];
  }

  /// Period day without a feast code, when its id is not the canonical one.
  static String? idByPeriod(String periodType, int week, int dayOfWeek) {
    _ensure();
    return _byPeriod['$periodType|$week|$dayOfWeek'];
  }

  static void _ensure() {
    final box = HiveService.daysBox;
    if (!identical(box, _box)) {
      unawaited(_subscription?.cancel());
      _box = box;
      _subscription = box.watch().listen((_) => _dirty = true);
      _dirty = true;
    }
    if (!_dirty) return;
    _byDate.clear();
    _byFeast.clear();
    _byPeriod.clear();
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final id = raw['id']?.toString() ?? key.toString();
      final date = raw['_date']?.toString();
      if (date != null && date.isNotEmpty) {
        (_byDate[date] ??= []).add(id);
      }
      final feast = raw['_feast']?.toString().trim() ?? '';
      if (feast.isNotEmpty) {
        (_byFeast[feast] ??= []).add(id);
        continue;
      }
      final period = raw['_periodType']?.toString();
      final week = raw['_periodWeekNumber']?.toString();
      final day = raw['_dayOfWeek']?.toString();
      if (period != null && week != null && day != null) {
        _byPeriod.putIfAbsent('$period|$week|$day', () => id);
      }
    }
    _dirty = false;
    rebuilds++;
  }
}
