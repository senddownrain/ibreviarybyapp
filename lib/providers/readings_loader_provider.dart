import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/services/data_log.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/utils/liturgical_cycle.dart';

class ReadingsLoadResult {
  const ReadingsLoadResult({
    required this.readings,
    required this.sundayCycle,
    required this.weekdayCycle,
  });

  final List<ParsedReading> readings;
  final String sundayCycle;
  final String weekdayCycle;
}

typedef ReadingsLoader =
    Future<ReadingsLoadResult> Function({
      required String? dateStr,
      required String? liturgicalKey,
      required String? dayId,
    });

/// Testable boundary around the readings service (waits for the content to
/// be decoded; never the network).
final readingsLoaderProvider = Provider<ReadingsLoader>((ref) {
  return ({required dateStr, required liturgicalKey, required dayId}) async {
    final service = ParsedReadingsService();
    if (liturgicalKey != null) {
      final parts = liturgicalKey.split('/');
      final period = parts[0];
      final week = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
      final day = int.tryParse(parts.length > 2 ? parts[2] : '1') ?? 1;
      final readings = await service.fetchByLiturgicalKey(period, week, day);
      final today = DateTime.now();
      return ReadingsLoadResult(
        readings: readings,
        sundayCycle: getCycleForDate(today, dayOfWeek: 1),
        weekdayCycle: getWeekdayCycleForDate(today),
      );
    }

    final date = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();
    final calendar = ref.read(calendarServiceProvider);
    final readings = await service.fetchForDate(
      date,
      calendar.getYearOptionsCached(date.year),
      calendar.getYearOptionsCached(date.year + 1),
      calendar.getDynamicDatesCached(date.year),
      includeAlternatives: true,
      dayId: dayId,
    );
    return ReadingsLoadResult(
      readings: readings,
      sundayCycle: getCycleForDate(date, dayOfWeek: 1),
      weekdayCycle: getWeekdayCycleForDate(date),
    );
  };
});

typedef ReadingsLocalLoader =
    ReadingsLoadResult? Function({
      required String? dateStr,
      required String? liturgicalKey,
      required String? dayId,
    });

/// Readings on the device, synchronously — or null while the content is
/// still being decoded at launch. The screen asks this first; only then it
/// waits on [readingsLoaderProvider].
final readingsLocalLoaderProvider = Provider<ReadingsLocalLoader>((ref) {
  return ({required dateStr, required liturgicalKey, required dayId}) {
    final service = ParsedReadingsService();
    if (liturgicalKey != null) {
      final parts = liturgicalKey.split('/');
      final readings = service.cachedByLiturgicalKey(
        parts[0],
        int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1,
        int.tryParse(parts.length > 2 ? parts[2] : '1') ?? 1,
      );
      if (readings == null) return null;
      final today = DateTime.now();
      return ReadingsLoadResult(
        readings: readings,
        sundayCycle: getCycleForDate(today, dayOfWeek: 1),
        weekdayCycle: getWeekdayCycleForDate(today),
      );
    }
    final date = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();
    final calendar = ref.read(calendarServiceProvider);
    final readings = service.cachedForDate(
      date,
      calendar.getYearOptionsCached(date.year),
      calendar.getYearOptionsCached(date.year + 1),
      calendar.getDynamicDatesCached(date.year),
      includeAlternatives: true,
      dayId: dayId,
    );
    if (readings == null) return null;
    DataLog.cacheHit(() => 'readings $dateStr');
    return ReadingsLoadResult(
      readings: readings,
      sundayCycle: getCycleForDate(date, dayOfWeek: 1),
      weekdayCycle: getWeekdayCycleForDate(date),
    );
  };
});
