import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/engine.dart';
import 'package:mybrev_flutter/ordo/readings_runtime.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/services/days_index.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_cycle.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';
import 'package:mybrev_flutter/utils/reading_content.dart';
import 'package:mybrev_flutter/utils/reading_groups.dart';
import 'package:mybrev_flutter/utils/readings_index.dart';

/// Readings of a date or a period day from the content on the device
/// (bundled, plus any newer documents). No network: every date is local.
class ParsedReadingsService {
  ParsedReadingsService();

  /// Loads the readings (and the days they link to), then reads them.
  Future<List<ParsedReading>> fetchByLiturgicalKey(
    String period,
    int week,
    int day,
  ) async {
    await ContentStore.instance.ensureLoaded(const ['readings', 'days']);
    return cachedByLiturgicalKey(period, week, day) ?? const [];
  }

  /// Readings of a date, or null when the content is not loaded yet.
  /// Synchronous: a screen renders without a loading frame.
  List<ParsedReading>? cachedForDate(
    DateTime date,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates, {
    bool includeAlternatives = false,
    String? dayId,
    String diocese = kDefaultDiocese,
  }) {
    if (!ContentStore.instance.areLoaded(const ['readings', 'days'])) {
      return null;
    }
    if (includeAlternatives) {
      // The ENGINE's plan: every document the lookups of every legal Mass
      // option name, in the engine's order, each remembering its option.
      // Nothing else of the date (another diocese's cathedral dedication,
      // the weekday readings of a solemnity) is offered.
      if (!ContentStore.instance.areLoaded(const ['liturgicalCelebrations'])) {
        return null;
      }
      final day = OrdoRuntime.engine.resolve(date, diocese: diocese);
      final plan = day.readingsPlan;
      // The route's day id never ADDS a document: a document linked to the
      // Hours day but named by no lookup of a legal option (the seasonal
      // date document of a Sunday, an obsolete copy) is not a reading of
      // the day. The selected option is found by its tag instead.
      final ordered = orderReadingsByPlan(
        plan,
        fetchReadingDocuments(plan),
        dayOfWeek: day.dayOfWeek,
      );
      return ordered.isEmpty ? null : ordered;
    }
    final context = computeLiturgicalContext(
      date,
      opts,
      nextYearOpts,
      dynamicDates,
    );
    final ddmm =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    final cached = _filterWithContent(
      _getCachedForDate(context, ddmm, dynamicDates, date, dayId: dayId),
    );
    if (cached.isEmpty) return null;
    return _selectActiveForDate(
      cached,
      date: date,
      context: context,
      feastCodes: getDynamicFeastCodesForDate(date, dynamicDates),
      dayId: dayId,
    );
  }

  /// Readings of a period day from the device, or null.
  List<ParsedReading>? cachedByLiturgicalKey(String period, int week, int day) {
    final cached = _filterWithContent(_getCachedByPeriod(period, week, day));
    return cached.isEmpty ? null : cached;
  }

  /// Readings of a date once the content is loaded.
  Future<List<ParsedReading>> fetchForDate(
    DateTime date,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates, {
    bool includeAlternatives = false,
    String? dayId,
    String diocese = kDefaultDiocese,
  }) async {
    await ContentStore.instance.ensureLoaded(const ['readings', 'days']);
    return cachedForDate(
          date,
          opts,
          nextYearOpts,
          dynamicDates,
          includeAlternatives: includeAlternatives,
          dayId: dayId,
          diocese: diocese,
        ) ??
        const [];
  }

  /// The legal option of the date a Readings route stands for: the option
  /// owning [dayId] (Hours / Ordo identity), else the primary.
  ///
  /// `officeOnly`: [dayId] is an Office that is not a legal Mass option of
  /// the date — see [isOfficeOnlySource].
  ({String optionId, bool memorial, bool officeOnly})? ordoSelection(
    DateTime date, {
    String? dayId,
    String diocese = kDefaultDiocese,
  }) {
    if (!ContentStore.instance.areLoaded(const ['liturgicalCelebrations'])) {
      return null;
    }
    final content = LiturgicalContentService().contentForDate(
      date,
      diocese: diocese,
    );
    final owning = dayId == null || dayId.isEmpty
        ? null
        : content.optionOwning(dayId)?.ordo;
    final officeOnly = isOfficeOnlySource(content.ordo, owning?.optionId);
    final optionId =
        (officeOnly ? null : owning?.optionId) ?? content.ordo.primary.id;
    final kind = content.ordo.option(optionId)?.officeKind ?? '';
    return (
      optionId: optionId,
      memorial: kind == 'memorial' || kind == 'optional-memorial',
      officeOnly: officeOnly,
    );
  }

  /// Readings hook for split Office / Mass sources (mybrev Ordo
  /// `sources.office` / `sources.mass`, final phase §11.1): on 2 November
  /// falling on a Sunday the Hours are of the Sunday, the Mass and its
  /// readings of All Souls. An Office option that is not a legal Mass
  /// option of the date ([OrdoDay.options] = the Mass options) never chooses
  /// the readings: they follow the engine's primary (the Mass source).
  ///
  /// Uses only what the engine exposes today; when the engine reports
  /// `sources` explicitly, this is the one place to read them.
  static bool isOfficeOnlySource(OrdoDay day, String? officeOptionId) {
    if (officeOptionId == null || officeOptionId.isEmpty) return false;
    return !day.options.any((option) => option.id == officeOptionId);
  }

  static String currentCycle(DateTime date, {int? dayOfWeek}) {
    final catholic = dayOfWeek ?? (date.weekday == 7 ? 1 : date.weekday + 1);
    if (catholic == 1) {
      return getCycleForDate(date, dayOfWeek: dayOfWeek);
    }
    return getWeekdayCycleForDate(date);
  }

  List<ParsedReading> _getCachedForDate(
    LiturgicalContext context,
    String ddmm,
    DynamicDates? dynamicDates,
    DateTime date, {
    String? dayId,
  }) {
    final feastSet = getDynamicFeastCodesForDate(
      date,
      dynamicDates,
    ).expand(_feastVariants).toSet();

    final ids = ReadingsIndex.lookupForDateContext(
      periodType: context.periodType,
      periodWeek: context.periodWeek,
      dayOfWeek: context.dayOfWeek,
      ddmm: ddmm,
      feastVariants: feastSet,
    );

    final box = HiveService.readingsBox;
    final results = <String, ParsedReading>{};
    for (final id in ids) {
      final raw = box.get(id);
      if (raw == null) continue;
      results[id] = ParsedReading.fromMap(id, Map<String, dynamic>.from(raw));
    }

    // Readings linked by `_dayId(s)` to the selected day or to any day
    // document of this date (period day, feast, fixed date).
    final dayIds = <String>{
      if (dayId != null && dayId.isNotEmpty) dayId,
      periodDayDocumentId(
        context.periodType,
        context.periodWeek,
        context.dayOfWeek,
      ),
      ?DaysIndex.idByPeriod(
        context.periodType,
        context.periodWeek,
        context.dayOfWeek,
      ),
      ...DaysIndex.idsByFeast(feastSet),
      ...DaysIndex.idsByDate({'${date.day}.${date.month}', ddmm}),
    }..remove('');
    for (final id in [
      for (final linked in dayIds) ...ReadingsIndex.lookupByDayId(linked),
    ]) {
      final raw = box.get(id);
      if (raw == null) continue;
      results[id] = ParsedReading.fromMap(id, Map<String, dynamic>.from(raw));
    }

    return results.values.toList();
  }

  List<ParsedReading> _getCachedByPeriod(String periodType, int week, int day) {
    final box = HiveService.readingsBox;
    return ReadingsIndex.lookupByPeriod(periodType, week, day)
        .map((id) => box.get(id))
        .whereType<Map>()
        .map(
          (raw) => ParsedReading.fromMap(
            raw['id']?.toString() ?? '',
            Map<String, dynamic>.from(raw),
          ),
        )
        .where((r) => r.id.isNotEmpty)
        .toList();
  }

  List<ParsedReading> _filterWithContent(List<ParsedReading> docs) =>
      docs.where(hasReadingDocumentContent).toList();

  List<ParsedReading> _selectLectionaryVariants(
    List<ParsedReading> docs,
    DateTime date,
  ) {
    final groups = <String, List<ParsedReading>>{};
    for (final reading in docs) {
      groups.putIfAbsent(readingCelebrationKey(reading), () => []).add(reading);
    }
    final sundayCycle = getCycleForDate(date, dayOfWeek: 1);
    final weekdayCycle = getWeekdayCycleForDate(date);
    return groups.values.expand((group) {
      final cycles = availableCyclesForGroup(group);
      final desired = cycles.any(const {'A', 'B', 'C'}.contains)
          ? sundayCycle
          : weekdayCycle;
      final exact = group
          .where((reading) => normalizeReadingCycle(reading.year) == desired)
          .toList();
      if (exact.isNotEmpty) return exact;
      final shared = group
          .where((reading) => normalizeReadingCycle(reading.year).isEmpty)
          .toList();
      return shared.isNotEmpty ? shared : group;
    }).toList();
  }

  List<ParsedReading> _selectCalendarDayVariants(
    List<ParsedReading> docs,
    int dayOfWeek,
  ) {
    final exact = docs
        .where((reading) => reading.calendarDayOfWeek == dayOfWeek)
        .toList();
    if (exact.isNotEmpty) return exact;
    return docs.where((reading) => reading.calendarDayOfWeek == null).toList();
  }

  List<ParsedReading> _selectActiveForDate(
    List<ParsedReading> docs, {
    required DateTime date,
    required LiturgicalContext context,
    required List<String> feastCodes,
    String? dayId,
  }) {
    if (dayId != null && dayId.isNotEmpty) {
      final linked = docs
          .where((reading) => _isLinked(reading, dayId))
          .toList();
      if (linked.isNotEmpty) {
        return _selectLectionaryVariants(linked, date);
      }
    }
    final feastVariants = feastCodes.expand(_feastVariants).toSet();
    if (feastVariants.isNotEmpty) {
      final feast = docs
          .where((reading) => feastVariants.contains(reading.feast))
          .toList();
      if (feast.isNotEmpty) {
        return _selectLectionaryVariants(feast, date);
      }
    }
    final fixedOnly =
        isSeasonalDateException(date, context.periodType) ||
        isChristmasDateExceptionExclusion(date);
    final fixed = _selectCalendarDayVariants(
      docs.where((reading) => reading.date != null).toList(),
      context.dayOfWeek,
    );
    if (fixedOnly && fixed.isNotEmpty) {
      return _selectLectionaryVariants(fixed, date);
    }
    final period = docs.where((reading) => reading.date == null).toList();
    return [
      ..._selectLectionaryVariants(fixed, date),
      ..._selectLectionaryVariants(period, date),
    ];
  }

  bool _isLinked(ParsedReading reading, String dayId) {
    final raw = HiveService.readingsBox.get(reading.id);
    if (raw is! Map) return false;
    final data = Map<String, dynamic>.from(raw);
    if (data['_dayId']?.toString() == dayId) return true;
    final many = data['_dayIds'];
    return many is List && many.map((item) => item.toString()).contains(dayId);
  }

  static List<String> _feastVariants(String code) {
    final normalized = code.replaceFirst(RegExp(r'^feast-'), '');
    return [normalized, 'feast-$normalized'];
  }
}
