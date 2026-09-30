import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_day_service.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_cycle.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';
import 'package:mybrev_flutter/utils/reading_content.dart';
import 'package:mybrev_flutter/utils/reading_groups.dart';
import 'package:mybrev_flutter/utils/readings_index.dart';
import 'package:mybrev_flutter/utils/retry.dart';

const _kReadingsCollection = 'readings';

/// Fetches `readings` collection from Hive cache or Firestore on demand.
class ParsedReadingsService {
  final FirebaseFirestore _db;
  final LiturgicalDayService _days;

  ParsedReadingsService({FirebaseFirestore? db, LiturgicalDayService? days})
    : _db = db ?? FirebaseFirestore.instance,
      _days = days ?? LiturgicalDayService();

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection(name);

  Future<Map<String, dynamic>?> getReading(
    String docId, {
    bool forceRefresh = false,
  }) async {
    final cached = HiveService.readingsBox.get(docId);
    if (!forceRefresh && cached != null) {
      return Map<String, dynamic>.from(cached);
    }
    final snap = await retryFirestore(
      () => _col(
        _kReadingsCollection,
      ).doc(docId).get(const GetOptions(source: Source.server)),
    );
    if (snap.exists) {
      final data = snap.data()!;
      await cacheReadingDoc(docId, data);
      return data;
    }
    return cached == null ? null : Map<String, dynamic>.from(cached);
  }

  Future<List<ParsedReading>> fetchByLiturgicalKey(
    String period,
    int week,
    int day, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _filterWithContent(_getCachedByPeriod(period, week, day));
      if (cached.isNotEmpty) return cached;
    }

    final merged = <String, ParsedReading>{};
    await _mergeFromQueries(
      _periodQueries(
        _kReadingsCollection,
        period,
        week,
        day,
        forceRefresh: forceRefresh,
      ),
      merged,
    );
    return merged.values.toList();
  }

  /// Readings of a date from the device, or null when the date is not
  /// completely cached. Synchronous: a screen can render without a loading
  /// frame and without touching the network.
  List<ParsedReading>? cachedForDate(
    DateTime date,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates, {
    bool includeAlternatives = false,
    String? dayId,
  }) {
    if (!HiveService.isDateCached('readings', date)) return null;
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
        ? _sortForDate(cached, dayId: dayId)
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

  Future<List<ParsedReading>> fetchForDate(
    DateTime date,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates, {
    bool forceRefresh = false,
    bool includeAlternatives = false,
    String? dayId,
  }) async {
    forceRefresh = forceRefresh || !HiveService.isDateCached('readings', date);
    final context = computeLiturgicalContext(
      date,
      opts,
      nextYearOpts,
      dynamicDates,
    );
    final ddmm =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    if (!forceRefresh) {
      final cached = _filterWithContent(
        _getCachedForDate(context, ddmm, dynamicDates, date, dayId: dayId),
      );
      if (cached.isNotEmpty) {
        return includeAlternatives
            ? _sortForDate(cached, dayId: dayId)
            : _selectActiveForDate(
                cached,
                date: date,
                context: context,
                feastCodes: getDynamicFeastCodesForDate(date, dynamicDates),
                dayId: dayId,
              );
      }
    }

    final feastCodes = getDynamicFeastCodesForDate(date, dynamicDates);
    final dayIds = await _collectDayIds(
      date,
      context,
      feastCodes,
      explicitDayId: dayId,
      forceRefresh: forceRefresh,
    );

    final merged = <String, ParsedReading>{};
    final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

    for (final id in dayIds) {
      queries.add(
        _getQuery(
          _col(_kReadingsCollection).where('_dayId', isEqualTo: id),
          forceRefresh: forceRefresh,
        ),
      );
      queries.add(
        _getQuery(
          _col(_kReadingsCollection).where('_dayIds', arrayContains: id),
          forceRefresh: forceRefresh,
        ),
      );
    }

    for (final code in feastCodes) {
      for (final variant in _feastVariants(code)) {
        queries.add(
          _getQuery(
            _col(_kReadingsCollection).where('_feast', isEqualTo: variant),
            forceRefresh: forceRefresh,
          ),
        );
      }
    }

    queries.add(
      _getQuery(
        _col(_kReadingsCollection).where('_date', isEqualTo: ddmm),
        forceRefresh: forceRefresh,
      ),
    );
    final fixedDateOnly =
        isSeasonalDateException(date, context.periodType) ||
        isChristmasDateExceptionExclusion(date);
    if (!fixedDateOnly) {
      queries.addAll(
        _periodQueries(
          _kReadingsCollection,
          context.periodType,
          context.periodWeek,
          context.dayOfWeek,
          forceRefresh: forceRefresh,
        ),
      );
    }

    await _mergeFromQueries(queries, merged);
    await HiveService.markDateCached('readings', date);

    final all = _filterWithContent(merged.values.toList());
    return includeAlternatives
        ? _sortForDate(all, dayId: dayId)
        : _selectActiveForDate(
            all,
            date: date,
            context: context,
            feastCodes: feastCodes,
            dayId: dayId,
          );
  }

  static String currentCycle(DateTime date, {int? dayOfWeek}) {
    final catholic = dayOfWeek ?? (date.weekday == 7 ? 1 : date.weekday + 1);
    if (catholic == 1) {
      return getCycleForDate(date, dayOfWeek: dayOfWeek);
    }
    return getWeekdayCycleForDate(date);
  }

  Future<List<String>> _collectDayIds(
    DateTime date,
    LiturgicalContext context,
    List<String> feastCodes, {
    String? explicitDayId,
    bool forceRefresh = false,
  }) async {
    final ids = <String>{};
    if (explicitDayId != null && explicitDayId.trim().isNotEmpty) {
      ids.add(explicitDayId.trim());
    }

    final canonical = periodDayDocumentId(
      context.periodType,
      context.periodWeek,
      context.dayOfWeek,
    );
    if (canonical.isNotEmpty) ids.add(canonical);

    final periodDay = await _days.findDayByPeriod(
      context.periodType,
      context.periodWeek,
      context.dayOfWeek,
      forceRefresh: forceRefresh,
    );
    if (periodDay != null && periodDay.id.isNotEmpty) {
      ids.add(periodDay.id);
    }

    for (final code in feastCodes) {
      final feastDays = await _days.findDaysByFeast(
        code,
        forceRefresh: forceRefresh,
      );
      ids.addAll(feastDays.map((d) => d.id).where((id) => id.isNotEmpty));
    }

    final calendarDays = await _days.findDaysByFixedDate(
      date,
      forceRefresh: forceRefresh,
    );
    ids.addAll(calendarDays.map((d) => d.id).where((id) => id.isNotEmpty));

    return ids.toList();
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

    if (ReadingsIndex.isBuilt) {
      // The index also knows the readings linked to a day by `_dayId(s)`.
      for (final id in [
        if (dayId != null && dayId.isNotEmpty)
          ...ReadingsIndex.lookupByDayId(dayId),
      ]) {
        final raw = box.get(id);
        if (raw == null) continue;
        results[id] = ParsedReading.fromMap(id, Map<String, dynamic>.from(raw));
      }
    } else {
      // Index not built yet (first run after an update): one pass without
      // copying documents.
      for (final reading in _scanCachedForDate(
        context,
        ddmm,
        feastSet,
        dayId: dayId,
      )) {
        results[reading.id] = reading;
      }
    }

    return results.values.toList();
  }

  List<ParsedReading> _scanCachedForDate(
    LiturgicalContext context,
    String ddmm,
    Set<String> feastSet, {
    String? dayId,
  }) {
    final box = HiveService.readingsBox;
    final results = <String, ParsedReading>{};

    // Selector fields are read in place; only a matching document is copied.
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final feast = raw['_feast'];
      final matchesFeast = feast is String && feastSet.contains(feast);
      final matchesDate = raw['_date'] == ddmm;
      final matchesPeriod =
          raw['_periodType'] == context.periodType &&
          _toInt(raw['_periodWeekNumber']) == context.periodWeek &&
          _toInt(raw['_dayOfWeek']) == context.dayOfWeek;
      final linked = raw['_dayId']?.toString();
      final linkedMany = raw['_dayIds'];
      final matchesDayId =
          dayId != null &&
          dayId.isNotEmpty &&
          (linked == dayId ||
              (linkedMany is List &&
                  linkedMany.any((item) => item.toString() == dayId)));
      if (matchesFeast || matchesDate || matchesPeriod || matchesDayId) {
        results[key as String] = ParsedReading.fromMap(
          key,
          Map<String, dynamic>.from(raw),
        );
      }
    }
    return results.values.toList();
  }

  List<ParsedReading> _getCachedByPeriod(String periodType, int week, int day) {
    final ids = ReadingsIndex.lookupByPeriod(periodType, week, day);
    if (ids.isNotEmpty) {
      final box = HiveService.readingsBox;
      return ids
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
    final box = HiveService.readingsBox;
    final results = <ParsedReading>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      if (raw['_periodType'] == periodType &&
          _toInt(raw['_periodWeekNumber']) == week &&
          _toInt(raw['_dayOfWeek']) == day) {
        results.add(
          ParsedReading.fromMap(key as String, Map<String, dynamic>.from(raw)),
        );
      }
    }
    return results;
  }

  Future<void> _mergeFromQueries(
    List<Future<QuerySnapshot<Map<String, dynamic>>>> queries,
    Map<String, ParsedReading> merged,
  ) async {
    if (queries.isEmpty) return;
    final snaps = await retryFirestore(() => Future.wait(queries));
    for (final snap in snaps) {
      for (final r in await _storeDocs(snap.docs)) {
        if (hasReadingDocumentContent(r)) {
          merged[r.id] = r;
        }
      }
    }
  }

  Future<List<ParsedReading>> _storeDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final results = <ParsedReading>[];
    for (final doc in docs) {
      final data = {...doc.data(), 'id': doc.id};
      if (!hasReadingMapContent(data)) continue;
      await cacheReadingDoc(doc.id, data);
      results.add(ParsedReading.fromMap(doc.id, data));
    }
    return results;
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

  /// Firestore may store period fields as strings or ints (web parity).
  List<Future<QuerySnapshot<Map<String, dynamic>>>> _periodQueries(
    String collection,
    String periodType,
    int week,
    int day, {
    bool forceRefresh = false,
  }) {
    final weekValues = week == 0
        ? <Object?>[0, '0', null]
        : <Object?>[week, '$week'];
    final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

    for (final weekValue in weekValues) {
      if (weekValue == null) {
        queries.add(
          _getQuery(
            _col(collection)
                .where('_periodType', isEqualTo: periodType)
                .where('_periodWeekNumber', isNull: true)
                .where('_dayOfWeek', isEqualTo: '$day'),
            forceRefresh: forceRefresh,
          ),
        );
        queries.add(
          _getQuery(
            _col(collection)
                .where('_periodType', isEqualTo: periodType)
                .where('_periodWeekNumber', isNull: true)
                .where('_dayOfWeek', isEqualTo: day),
            forceRefresh: forceRefresh,
          ),
        );
        continue;
      }

      queries.add(
        _getQuery(
          _col(collection)
              .where('_periodType', isEqualTo: periodType)
              .where('_periodWeekNumber', isEqualTo: '$weekValue')
              .where('_dayOfWeek', isEqualTo: '$day'),
          forceRefresh: forceRefresh,
        ),
      );
      queries.add(
        _getQuery(
          _col(collection)
              .where('_periodType', isEqualTo: periodType)
              .where('_periodWeekNumber', isEqualTo: weekValue)
              .where('_dayOfWeek', isEqualTo: day),
          forceRefresh: forceRefresh,
        ),
      );
    }

    return queries;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getQuery(
    Query<Map<String, dynamic>> query, {
    required bool forceRefresh,
  }) => query.get(const GetOptions(source: Source.server));

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
