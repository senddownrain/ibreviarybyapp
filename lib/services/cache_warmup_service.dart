import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/services/liturgical_day_service.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';

const kCacheDaysBehind = 1;
const kCacheDaysAhead = 7;

/// Prefetch calendar + liturgical data around today (mirrors web cacheWarmup).
class CacheWarmupService {
  final CalendarService _calendar;
  final ParsedReadingsService _readings;
  final LiturgicalDayService _days;

  CacheWarmupService({
    CalendarService? calendar,
    ParsedReadingsService? readings,
    LiturgicalDayService? days,
  })  : _calendar = calendar ?? CalendarService(),
        _readings = readings ?? ParsedReadingsService(),
        _days = days ?? LiturgicalDayService();

  static List<DateTime> buildDateOrder(
    DateTime base, {
    int behind = kCacheDaysBehind,
    int ahead = kCacheDaysAhead,
  }) {
    final start = DateTime(base.year, base.month, base.day);
    final offsets = <int>[0];
    final maxDist = behind > ahead ? behind : ahead;
    for (var d = 1; d <= maxDist; d++) {
      if (d <= ahead) offsets.add(d);
      if (d <= behind) offsets.add(-d);
    }
    return offsets
        .map((o) => start.add(Duration(days: o)))
        .toList();
  }

  Future<void> warmup({DateTime? baseDate}) async {
    final base = baseDate ?? DateTime.now();
    final year = base.year;

    await Future.wait([
      _calendar.ensureYearOptions(year),
      _calendar.ensureYearOptions(year + 1),
      _calendar.ensureDynamicDates(year),
      _calendar.ensureDynamicDates(year + 1),
    ]);

    final dates = buildDateOrder(base);
    for (final date in dates) {
      try {
        final opts = _calendar.getYearOptionsCached(date.year);
        final nextOpts = _calendar.getYearOptionsCached(date.year + 1);
        final dynamicDates = _calendar.getDynamicDatesCached(date.year);
        final context =
            computeLiturgicalContext(date, opts, nextOpts, dynamicDates);

        await Future.wait([
          _readings.fetchForDate(date, opts, nextOpts, dynamicDates),
          _days.findDayByPeriod(
            context.periodType,
            context.periodWeek,
            context.dayOfWeek,
          ),
        ]);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[CacheWarmup] skip ${date.toIso8601String()}: $e\n$st');
        }
      }
    }
  }
}
