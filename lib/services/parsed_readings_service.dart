import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/reading_references.dart';
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
    return includeAlternatives
        ? _orderByOrdo(
            _sortForDate(cached, dayId: dayId),
            date,
            dayId: dayId,
            diocese: diocese,
          )
        : _selectActiveForDate(
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
  ({String optionId, bool memorial})? ordoSelection(
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
    final option = dayId == null || dayId.isEmpty
        ? null
        : content.optionOwning(dayId)?.ordo;
    final optionId = option?.optionId ?? content.ordo.primary.id;
    final kind = content.ordo.option(optionId)?.officeKind ?? '';
    return (
      optionId: optionId,
      memorial: kind == 'memorial' || kind == 'optional-memorial',
    );
  }

  /// The readings of the selected option first, in the engine's order
  /// (mybrev `orderReadingsByPlan`); the others keep their order.
  List<ParsedReading> _orderByOrdo(
    List<ParsedReading> docs,
    DateTime date, {
    String? dayId,
    required String diocese,
  }) {
    final selection = ordoSelection(date, dayId: dayId, diocese: diocese);
    if (selection == null) return docs;
    final content = LiturgicalContentService().contentForDate(
      date,
      diocese: diocese,
    );
    final first = orderedReadingIdsForOption(
      content.ordo,
      selection.optionId,
      docs,
    );
    if (first.isEmpty) return docs;
    final rank = {for (final (i, id) in first.indexed) id: i};
    final indexed = docs.indexed.toList()
      ..sort((a, b) {
        final left = rank[a.$2.id] ?? first.length + a.$1;
        final right = rank[b.$2.id] ?? first.length + b.$1;
        return left.compareTo(right);
      });
    return [for (final item in indexed) item.$2];
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

  List<ParsedReading> _sortForDate(List<ParsedReading> docs, {String? dayId}) {
    final indexed = docs.indexed.toList();
    indexed.sort((left, right) {
      int rank(ParsedReading reading) {
        if (dayId != null && dayId.isNotEmpty && _isLinked(reading, dayId)) {
          return 0;
        }
        if ((reading.feast ?? '').isNotEmpty) return 1;
        if ((reading.date ?? '').isNotEmpty) return 2;
        if ((reading.periodType ?? '').isNotEmpty) return 3;
        return 4;
      }

      final source = rank(left.$2).compareTo(rank(right.$2));
      return source != 0 ? source : left.$1.compareTo(right.$1);
    });
    return indexed.map((entry) => entry.$2).toList();
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
