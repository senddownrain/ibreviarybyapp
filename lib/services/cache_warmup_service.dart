import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_day_service.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_psalter.dart';
import 'package:mybrev_flutter/utils/readings_index.dart';

const kCacheDaysBehind = 7;
const kCacheDaysAhead = 7;
const kExtendedDaysBehind = 7;
const kExtendedDaysAhead = 7;
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

  Future<void> prepareDate(DateTime date) async {
    await ReadingsIndex.ensureBuilt();
    await Future.wait([
      _calendar.ensureYearOptions(date.year),
      _calendar.ensureYearOptions(date.year + 1),
    ]);
    await _calendar.ensureDynamicDates(date.year);
  }

  Future<void> warmup({DateTime? baseDate, bool forceRefresh = false}) =>
      syncDates(
        buildDateOrder(baseDate ?? DateTime.now()),
        forceRefresh: forceRefresh,
      );

  Future<void> warmupExtended({
    DateTime? baseDate,
    bool forceRefresh = false,
  }) => warmup(baseDate: baseDate, forceRefresh: forceRefresh);

  Future<void> syncDates(
    List<DateTime> dates, {
    bool includeDays = true,
    bool includeReadings = true,
    bool forceRefresh = false,
    bool Function()? shouldCancel,
    void Function(int completed, int total)? onProgress,
  }) async {
    var completed = 0;
    for (final date in dates) {
      if (shouldCancel?.call() == true) return;
      await prepareDate(date);
      final ok = await warmupDate(
        date,
        forceRefresh: forceRefresh,
        includeDays: includeDays,
        includeReadings: includeReadings,
      );
      if (!ok) {
        throw StateError(
          'Не ўдалося загрузіць ${date.day}.${date.month}.${date.year}',
        );
      }
      onProgress?.call(++completed, dates.length);
      // Yield between dates so calendar navigation and foreground reads run first.
      await Future<void>.delayed(Duration.zero);
    }
    // Coverage is a successfully loaded window, never an optimistic range.
    if (dates.isNotEmpty && includeDays && includeReadings) {
      final sorted = [...dates]..sort();
      await HiveService.setWarmupCoverage(sorted.first, sorted.last);
    }
  }

  Future<bool> warmupDate(
    DateTime date, {
    bool forceRefresh = false,
    bool includeDays = true,
    bool includeReadings = true,
  }) async {
    try {
      await prepareDate(date);
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
        if (includeReadings &&
            (forceRefresh || !HiveService.isDateCached('readings', date)))
          _readings.fetchForDate(
            date,
            opts,
            nextOpts,
            dynamicDates,
            forceRefresh: forceRefresh,
            includeAlternatives: true,
          ),
        if (includeDays &&
            (forceRefresh || !HiveService.isDateCached('days', date)))
          _days.prefetchForDate(
            date,
            periodType: context.periodType,
            periodWeek: context.periodWeek,
            dayOfWeek: context.dayOfWeek,
            feastCodes: feastCodes,
            forceRefresh:
                forceRefresh || !HiveService.isDateCached('days', date),
          ),
      ];
      if (includeDays && context.periodType == 'christmas') {
        final psalterWeek = calculatePsalterWeek(
          date: date,
          periodType: context.periodType,
          periodWeek: context.periodWeek,
        );
        if (psalterWeek != null) {
          requests.add(
            _days.findDayByPeriod(
              'advent',
              psalterWeek,
              context.dayOfWeek,
              forceRefresh: forceRefresh,
            ),
          );
        }
      }
      await Future.wait(requests);
      if (includeDays) await HiveService.markDateCached('days', date);
      if (includeReadings) await HiveService.markDateCached('readings', date);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CacheWarmup] skip ${date.toIso8601String()}: $e\n$st');
      }
      return false;
    }
  }
}
