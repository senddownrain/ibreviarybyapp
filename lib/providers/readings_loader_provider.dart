import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/data_log.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/utils/liturgical_cycle.dart';

class ReadingsLoadResult {
  const ReadingsLoadResult({
    required this.readings,
    required this.sundayCycle,
    required this.weekdayCycle,
    this.linkDayId = true,
    this.optionId,
  });

  final List<ParsedReading> readings;
  final String sundayCycle;
  final String weekdayCycle;

  /// Whether the readings linked to the route's day id open first. False
  /// for a memorial: its default readings are the weekday's (the engine
  /// order); its own readings stay a choice.
  final bool linkDayId;

  /// The legal Mass option the route stands for, whose readings open first;
  /// null for a memorial (weekday-first) or without an Ordo selection.
  final String? optionId;
}

/// Whether the readings linked to the route's day id open first: not for a
/// memorial (its default readings are the weekday's), not for an Office
/// that is not a Mass source of the date (2 November on a Sunday: the
/// Hours of the Sunday, the readings of All Souls).
bool _linksDayId(({String optionId, bool memorial, bool officeOnly})? s) =>
    s == null || !(s.memorial || s.officeOnly);

/// The diocese the Readings resolve in: the context of the Hours choice,
/// else the primary of Settings.
String readingsDiocese(Ref ref) =>
    ref.read(hoursLiturgicalSelectionProvider).diocese ??
    ref.read(dioceseSelectionProvider).primary;

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
    await ContentStore.instance.ensureLoaded(const ['readings', 'days']);
    return loadReadingsForDate(
          service: service,
          calendar: ref.read(calendarServiceProvider),
          date: date,
          dayId: dayId,
          diocese: readingsDiocese(ref),
        ) ??
        ReadingsLoadResult(
          readings: const [],
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
    final result = loadReadingsForDate(
      service: service,
      calendar: ref.read(calendarServiceProvider),
      date: date,
      dayId: dayId,
      diocese: readingsDiocese(ref),
    );
    if (result != null) DataLog.cacheHit(() => 'readings $dateStr');
    return result;
  };
});

/// The readings of a date for the Readings screen, synchronously: every
/// document of every legal option in the engine's order, the cycles of the
/// date and whether the route's day id links the readings. Null while the
/// content is not decoded yet. The ONE path of the screen (and of the web
/// parity test): both loaders above call it.
ReadingsLoadResult? loadReadingsForDate({
  required ParsedReadingsService service,
  required CalendarService calendar,
  required DateTime date,
  required String? dayId,
  required String diocese,
}) {
  final readings = service.cachedForDate(
    date,
    calendar.getYearOptionsCached(date.year),
    calendar.getYearOptionsCached(date.year + 1),
    calendar.getDynamicDatesCached(date.year),
    includeAlternatives: true,
    dayId: dayId,
    diocese: diocese,
  );
  if (readings == null) return null;
  final selection = service.ordoSelection(date, dayId: dayId, diocese: diocese);
  // The lectionary cycles of the date are the ENGINE's (the web
  // `readingCycle`), the same ones the plan was built with.
  final cycle = OrdoRuntime.engine.resolve(date, diocese: diocese).readingCycle;
  return ReadingsLoadResult(
    readings: readings,
    sundayCycle: cycle.sunday,
    weekdayCycle: cycle.weekday,
    linkDayId: _linksDayId(selection),
    // Without a chosen celebration (no day id) the default group applies
    // (the evening Mass of 24.12 / Holy Thursday / Pentecost Saturday).
    optionId: selection == null || selection.memorial || (dayId ?? '').isEmpty
        ? null
        : selection.optionId,
  );
}
