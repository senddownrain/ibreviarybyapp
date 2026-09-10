import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
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
      required bool forceRefresh,
    });

/// Testable boundary around the existing production readings service.
final readingsLoaderProvider = Provider<ReadingsLoader>((ref) {
  return ({
    required dateStr,
    required liturgicalKey,
    required dayId,
    required forceRefresh,
  }) async {
    final service = ParsedReadingsService();
    if (liturgicalKey != null) {
      final parts = liturgicalKey.split('/');
      final period = parts[0];
      final week = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
      final day = int.tryParse(parts.length > 2 ? parts[2] : '1') ?? 1;
      final readings = await service.fetchByLiturgicalKey(
        period,
        week,
        day,
        forceRefresh: forceRefresh,
      );
      final today = DateTime.now();
      return ReadingsLoadResult(
        readings: readings,
        sundayCycle: getCycleForDate(today, dayOfWeek: 1),
        weekdayCycle: getWeekdayCycleForDate(today),
      );
    }

    final date = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();
    final calendar = ref.read(calendarServiceProvider);
    await calendar.ensureYearOptions(date.year);
    await calendar.ensureYearOptions(date.year + 1);
    await calendar.ensureDynamicDates(date.year);
    final readings = await service.fetchForDate(
      date,
      calendar.getYearOptionsCached(date.year),
      calendar.getYearOptionsCached(date.year + 1),
      calendar.getDynamicDatesCached(date.year),
      forceRefresh: forceRefresh,
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
