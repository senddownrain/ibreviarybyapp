import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_day_service.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_psalter.dart';
import 'package:mybrev_flutter/utils/readings_index.dart';

const kCacheDaysBehind = 7;
const kCacheDaysAhead = 30;
const kExtendedDaysBehind = 14;
const kExtendedDaysAhead = 60;
const kDateBatchSize = 3;

/// Prefetch calendar + liturgical data around today (mirrors web cacheWarmup).
class CacheWarmupService {
  final CalendarService _calendar;
  final ParsedReadingsService _readings;
  final LiturgicalDayService _days;

  CacheWarmupService({
    CalendarService? calendar,
    ParsedReadingsService? readings,
    LiturgicalDayService? days,
  }) : _calendar = calendar ?? CalendarService(),
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
    return offsets.map((o) => start.add(Duration(days: o))).toList();
  }

  Future<void> warmup({DateTime? baseDate}) async {
    final base = baseDate ?? DateTime.now();
    await ReadingsIndex.ensureBuilt();

    final year = base.year;
    await Future.wait([
      _calendar.ensureYearOptions(year),
      _calendar.ensureYearOptions(year + 1),
      _calendar.ensureDynamicDates(year),
      _calendar.ensureDynamicDates(year + 1),
    ]);

    final dates = buildDateOrder(base);
    var loaded = 0;

    for (var index = 0; index < dates.length; index += kDateBatchSize) {
      final batch = dates.skip(index).take(kDateBatchSize).toList();
      final results = await Future.wait(
        batch.map(warmupDate),
        eagerError: false,
      );
      loaded += results.where((ok) => ok).length;
    }

    if (dates.isNotEmpty) {
      final sorted = [...dates]..sort((a, b) => a.compareTo(b));
      await HiveService.setWarmupCoverage(sorted.first, sorted.last);
    }

    if (kDebugMode) {
      debugPrint('[CacheWarmup] date window ready: $loaded/${dates.length}');
    }
  }

  /// Wider background prefetch (month ahead) — does not block UI.
  Future<void> warmupExtended({DateTime? baseDate}) async {
    final base = baseDate ?? DateTime.now();
    await ReadingsIndex.ensureBuilt();

    final year = base.year;
    await Future.wait([
      _calendar.ensureYearOptions(year),
      _calendar.ensureYearOptions(year + 1),
      _calendar.ensureDynamicDates(year),
    ]);

    final dates = buildDateOrder(
      base,
      behind: kExtendedDaysBehind,
      ahead: kExtendedDaysAhead,
    );
    var loaded = 0;

    for (var index = 0; index < dates.length; index += kDateBatchSize) {
      final batch = dates.skip(index).take(kDateBatchSize).toList();
      final results = await Future.wait(
        batch.map(warmupDate),
        eagerError: false,
      );
      loaded += results.where((ok) => ok).length;
    }

    if (dates.isNotEmpty) {
      final sorted = [...dates]..sort((a, b) => a.compareTo(b));
      await HiveService.setWarmupCoverage(sorted.first, sorted.last);
    }

    if (kDebugMode) {
      debugPrint(
        '[CacheWarmup] extended window ready: $loaded/${dates.length}',
      );
    }
  }

  Future<bool> warmupDate(DateTime date) async {
    try {
      final opts = _calendar.getYearOptionsCached(date.year);
      final nextOpts = _calendar.getYearOptionsCached(date.year + 1);
      final dynamicDates = _calendar.getDynamicDatesCached(date.year);
      final context = computeLiturgicalContext(
        date,
        opts,
        nextOpts,
        dynamicDates,
      );
      final feastCodes = getDynamicFeastCodesForDate(date, dynamicDates);

      final requests = <Future<dynamic>>[
        _readings.fetchForDate(
          date,
          opts,
          nextOpts,
          dynamicDates,
          includeAlternatives: true,
        ),
        _days.prefetchForDate(
          date,
          periodType: context.periodType,
          periodWeek: context.periodWeek,
          dayOfWeek: context.dayOfWeek,
          feastCodes: feastCodes,
        ),
      ];
      if (context.periodType == 'christmas') {
        final psalterWeek = calculatePsalterWeek(
          date: date,
          periodType: context.periodType,
          periodWeek: context.periodWeek,
        );
        if (psalterWeek != null) {
          requests.add(
            _days.findDayByPeriod('advent', psalterWeek, context.dayOfWeek),
          );
        }
      }
      await Future.wait(requests);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CacheWarmup] skip ${date.toIso8601String()}: $e\n$st');
      }
      return false;
    }
  }
}
