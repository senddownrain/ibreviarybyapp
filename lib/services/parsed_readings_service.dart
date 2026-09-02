import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_day_service.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_cycle.dart';
import 'package:mybrev_flutter/utils/reading_content.dart';
import 'package:mybrev_flutter/utils/readings_index.dart';
import 'package:mybrev_flutter/utils/retry.dart';

const _kReadingsCollection = 'readings';
const _kLegacyReadingsCollection = 'parsedData';

/// Fetches `readings` collection from Hive cache or Firestore on demand.
class ParsedReadingsService {
  final FirebaseFirestore _db;
  final LiturgicalDayService _days;

  ParsedReadingsService({
    FirebaseFirestore? db,
    LiturgicalDayService? days,
  })  : _db = db ?? FirebaseFirestore.instance,
        _days = days ?? LiturgicalDayService();

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection(name);

  Future<Map<String, dynamic>?> getReading(String docId) async {
    final cached = HiveService.readingsBox.get(docId);
    if (cached != null) {
      return Map<String, dynamic>.from(cached);
    }
    for (final collection in [_kReadingsCollection, _kLegacyReadingsCollection]) {
      final snap = await retryFirestore(() => _col(collection).doc(docId).get());
      if (!snap.exists) continue;
      final data = snap.data()!;
      await cacheReadingDoc(docId, data);
      return data;
    }
    return null;
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
    for (final collection in [_kReadingsCollection, _kLegacyReadingsCollection]) {
      await _mergeFromQueries(
        _periodQueries(collection, period, week, day),
        merged,
      );
      if (merged.isNotEmpty) break;
    }
    return merged.values.toList();
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
    final context =
        computeLiturgicalContext(date, opts, nextYearOpts, dynamicDates);
    final ddmm =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    final cycle = getCycleForDate(date, dayOfWeek: context.dayOfWeek);

    if (!forceRefresh) {
      final cached = _filterWithContent(
        _getCachedForDate(context, ddmm, dynamicDates, date, dayId: dayId),
      );
      if (cached.isNotEmpty) {
        return includeAlternatives
            ? cached
            : _selectByCycle(cached, cycle, context.dayOfWeek);
      }
    }

    final feastCodes = getDynamicFeastCodesForDate(date, dynamicDates);
    final dayIds = await _collectDayIds(
      date,
      context,
      feastCodes,
      explicitDayId: dayId,
    );

    final merged = <String, ParsedReading>{};
    for (final collection in [_kReadingsCollection, _kLegacyReadingsCollection]) {
      final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

      for (final id in dayIds) {
        queries.add(_col(collection).where('_dayId', isEqualTo: id).get());
        queries.add(
          _col(collection).where('_dayIds', arrayContains: id).get(),
        );
      }

      for (final code in feastCodes) {
        for (final variant in _feastVariants(code)) {
          queries.add(_col(collection).where('_feast', isEqualTo: variant).get());
        }
      }

      queries.add(_col(collection).where('_date', isEqualTo: ddmm).get());
      queries.addAll(_periodQueries(
        collection,
        context.periodType,
        context.periodWeek,
        context.dayOfWeek,
      ));

      await _mergeFromQueries(queries, merged);
      if (merged.isNotEmpty) break;
    }

    final all = _filterWithContent(merged.values.toList());
    return includeAlternatives
        ? all
        : _selectByCycle(all, cycle, context.dayOfWeek);
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
    );
    if (periodDay != null && periodDay.id.isNotEmpty) {
      ids.add(periodDay.id);
    }

    for (final code in feastCodes) {
      final feastDays = await _days.findDaysByFeast(code);
      ids.addAll(feastDays.map((d) => d.id).where((id) => id.isNotEmpty));
    }

    final fixedDays = await _days.findDaysByFixedDate(date);
    ids.addAll(fixedDays.map((d) => d.id).where((id) => id.isNotEmpty));

    return ids.toList();
  }

  List<ParsedReading> _getCachedForDate(
    LiturgicalContext context,
    String ddmm,
    DynamicDates? dynamicDates,
    DateTime date, {
    String? dayId,
  }) {
    final feastSet = getDynamicFeastCodesForDate(date, dynamicDates)
        .expand(_feastVariants)
        .toSet();

    final ids = ReadingsIndex.lookupForDateContext(
      periodType: context.periodType,
      periodWeek: context.periodWeek,
      dayOfWeek: context.dayOfWeek,
      ddmm: ddmm,
      feastVariants: feastSet,
    );

    if (ids.isEmpty) {
      return _scanCachedForDate(context, ddmm, feastSet, dayId: dayId);
    }

    final box = HiveService.readingsBox;
    final results = <String, ParsedReading>{};
    for (final id in ids) {
      final raw = box.get(id);
      if (raw == null) continue;
      results[id] = ParsedReading.fromMap(id, Map<String, dynamic>.from(raw));
    }

    if (dayId != null && dayId.isNotEmpty) {
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw == null) continue;
        final data = Map<String, dynamic>.from(raw);
        final linked = data['_dayId']?.toString();
        final linkedMany = data['_dayIds'];
        final matchesLinked = linked == dayId ||
            (linkedMany is List && linkedMany.map((e) => e.toString()).contains(dayId));
        if (matchesLinked) {
          results[key as String] = ParsedReading.fromMap(key, data);
        }
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

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      final data = Map<String, dynamic>.from(raw);
      final feast = data['_feast'] as String?;
      final matchesFeast = feast != null && feastSet.contains(feast);
      final matchesDate = data['_date'] == ddmm;
      final matchesPeriod = data['_periodType'] == context.periodType &&
          _toInt(data['_periodWeekNumber']) == context.periodWeek &&
          _toInt(data['_dayOfWeek']) == context.dayOfWeek;
      final linked = data['_dayId']?.toString();
      final linkedMany = data['_dayIds'];
      final matchesDayId = dayId != null &&
          dayId.isNotEmpty &&
          (linked == dayId ||
              (linkedMany is List &&
                  linkedMany.map((e) => e.toString()).contains(dayId)));
      if (matchesFeast || matchesDate || matchesPeriod || matchesDayId) {
        results[key as String] = ParsedReading.fromMap(key, data);
      }
    }
    return results.values.toList();
  }

  List<ParsedReading> _getCachedByPeriod(
      String periodType, int week, int day) {
    final ids = ReadingsIndex.lookupByPeriod(periodType, week, day);
    if (ids.isNotEmpty) {
      final box = HiveService.readingsBox;
      return ids
          .map((id) => box.get(id))
          .whereType<Map>()
          .map((raw) => ParsedReading.fromMap(
                raw['id']?.toString() ?? '',
                Map<String, dynamic>.from(raw),
              ))
          .where((r) => r.id.isNotEmpty)
          .toList();
    }
    final box = HiveService.readingsBox;
    final results = <ParsedReading>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      final data = Map<String, dynamic>.from(raw);
      if (data['_periodType'] == periodType &&
          _toInt(data['_periodWeekNumber']) == week &&
          _toInt(data['_dayOfWeek']) == day) {
        results.add(ParsedReading.fromMap(key as String, data));
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
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
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

  List<ParsedReading> _selectByCycle(
    List<ParsedReading> docs,
    String cycle,
    int dayOfWeek,
  ) {
    if (docs.isEmpty) return docs;
    final withCycle = docs.where((r) => r.year == cycle).toList();
    if (withCycle.isNotEmpty) return withCycle;
    final withoutCycle = docs.where((r) => r.year == null || r.year!.isEmpty);
    if (withoutCycle.isNotEmpty) return withoutCycle.toList();
    return docs;
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
    int day,
  ) {
    final weekValues = week == 0 ? <Object?>[0, '0', null] : <Object?>[week, '$week'];
    final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

    for (final weekValue in weekValues) {
      if (weekValue == null) {
        queries.add(
          _col(collection)
              .where('_periodType', isEqualTo: periodType)
              .where('_periodWeekNumber', isNull: true)
              .where('_dayOfWeek', isEqualTo: '$day')
              .get(),
        );
        queries.add(
          _col(collection)
              .where('_periodType', isEqualTo: periodType)
              .where('_periodWeekNumber', isNull: true)
              .where('_dayOfWeek', isEqualTo: day)
              .get(),
        );
        continue;
      }

      queries.add(
        _col(collection)
            .where('_periodType', isEqualTo: periodType)
            .where('_periodWeekNumber', isEqualTo: '$weekValue')
            .where('_dayOfWeek', isEqualTo: '$day')
            .get(),
      );
      queries.add(
        _col(collection)
            .where('_periodType', isEqualTo: periodType)
            .where('_periodWeekNumber', isEqualTo: weekValue)
            .where('_dayOfWeek', isEqualTo: day)
            .get(),
      );
    }

    return queries;
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
