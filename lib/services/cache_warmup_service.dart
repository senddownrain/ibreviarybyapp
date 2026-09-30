import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/services/data_log.dart';
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

  /// Requests in flight, shared by every instance: the selected date, the
  /// neighbour prefetch, Vespers of tomorrow and the background window never
  /// download the same date twice at the same time.
  static final Map<String, Future<bool>> _inFlight = {};

  /// Number of date loads that actually started (diagnostics and tests).
  static int startedLoads = 0;

  static bool isDateReady(DateTime date) =>
      HiveService.isDateCached('days', date) &&
      HiveService.isDateCached('readings', date);

  Future<bool> warmupDate(
    DateTime date, {
    bool forceRefresh = false,
    bool includeDays = true,
    bool includeReadings = true,
  }) {
    final needsDays =
        includeDays &&
        (forceRefresh || !HiveService.isDateCached('days', date));
    final needsReadings =
        includeReadings &&
        (forceRefresh || !HiveService.isDateCached('readings', date));
    // Christmas weekdays take their psalter from an Advent document that a
    // «ready» date may still lack; that lookup is local when it is cached.
    if (!needsDays && !needsReadings && !forceRefresh) {
      DataLog.cacheHit(() => 'date ${_dayKey(date)}');
    }
    final key = '${_dayKey(date)}|$includeDays|$includeReadings|$forceRefresh';
    final running = _inFlight[key];
    if (running != null) return running;
    final request =
        _warmupDate(
          date,
          forceRefresh: forceRefresh,
          includeDays: includeDays,
          includeReadings: includeReadings,
          network: needsDays || needsReadings,
        ).whenComplete(() {
          // A block body: `remove` returns the future itself, and returning it
          // from `whenComplete` would make the request wait for itself.
          _inFlight.remove(key);
        });
    _inFlight[key] = request;
    return request;
  }

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  Future<bool> _warmupDate(
    DateTime date, {
    required bool forceRefresh,
    required bool includeDays,
    required bool includeReadings,
    required bool network,
  }) async {
    if (network) {
      startedLoads++;
      DataLog.fetchStart(() => 'date ${_dayKey(date)}');
    }
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
      if (network) DataLog.fetchEnd(() => 'date ${_dayKey(date)}');
      return true;
    } catch (e, st) {
      DataLog.networkError(() => 'date ${_dayKey(date)}: $e');
      if (kDebugMode) {
        debugPrint('[CacheWarmup] skip ${date.toIso8601String()}: $e\n$st');
      }
      return false;
    }
  }
}
