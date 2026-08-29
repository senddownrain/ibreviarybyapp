import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/services/cache_warmup_service.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_cycle.dart';

const _kReadingsCollection = 'readings';

/// Fetches `readings` collection from Hive cache or Firestore on demand.
class ParsedReadingsService {
  final FirebaseFirestore _db;

  ParsedReadingsService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_kReadingsCollection);

  Future<Map<String, dynamic>?> getReading(String docId) async {
    final cached = HiveService.readingsBox.get(docId);
    if (cached != null) {
      return Map<String, dynamic>.from(cached);
    }
    final snap = await _col.doc(docId).get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    await cacheReadingDoc(docId, data);
    return data;
  }

  Future<List<ParsedReading>> fetchByLiturgicalKey(
    String period,
    int week,
    int day, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _getCachedByPeriod(period, week, day);
      if (cached.isNotEmpty) return cached;
    }
    final snap = await _col
        .where('_periodType', isEqualTo: period)
        .where('_periodWeekNumber', isEqualTo: week)
        .where('_dayOfWeek', isEqualTo: day)
        .get();
    return _storeDocs(snap.docs);
  }

  Future<List<ParsedReading>> fetchForDate(
    DateTime date,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates, {
    bool forceRefresh = false,
    bool includeAlternatives = false,
  }) async {
    final context =
        computeLiturgicalContext(date, opts, nextYearOpts, dynamicDates);
    final ddmm =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    final cycle = getCycleForDate(date, dayOfWeek: context.dayOfWeek);

    if (!forceRefresh) {
      final cached = _getCachedForDate(context, ddmm, dynamicDates, date);
      if (cached.isNotEmpty) {
        return includeAlternatives
            ? cached
            : _selectByCycle(cached, cycle, context.dayOfWeek);
      }
    }

    final feastCodes = getDynamicFeastCodesForDate(date, dynamicDates);
    final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

    for (final code in feastCodes) {
      for (final variant in _feastVariants(code)) {
        queries.add(_col.where('_feast', isEqualTo: variant).get());
      }
    }
    queries.add(_col.where('_date', isEqualTo: ddmm).get());
    queries.add(
      _col
          .where('_periodType', isEqualTo: context.periodType)
          .where('_periodWeekNumber', isEqualTo: context.periodWeek)
          .where('_dayOfWeek', isEqualTo: context.dayOfWeek)
          .get(),
    );

    final snaps = await Future.wait(queries);
    final merged = <String, ParsedReading>{};
    for (final snap in snaps) {
      for (final r in _storeDocs(snap.docs)) {
        merged[r.id] = r;
      }
    }

    final all = merged.values.toList();
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

  List<ParsedReading> _getCachedForDate(
    LiturgicalContext context,
    String ddmm,
    DynamicDates? dynamicDates,
    DateTime date,
  ) {
    final box = HiveService.readingsBox;
    final feastCodes = getDynamicFeastCodesForDate(date, dynamicDates);
    final feastSet = feastCodes
        .expand(_feastVariants)
        .toSet();
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
      if (matchesFeast || matchesDate || matchesPeriod) {
        results[key as String] = ParsedReading.fromMap(key, data);
      }
    }
    return results.values.toList();
  }

  List<ParsedReading> _getCachedByPeriod(
      String periodType, int week, int day) {
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

  List<ParsedReading> _storeDocs(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final results = <ParsedReading>[];
    for (final doc in docs) {
      final data = {...doc.data(), 'id': doc.id};
      cacheReadingDoc(doc.id, data);
      results.add(ParsedReading.fromMap(doc.id, data));
    }
    return results;
  }

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

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

final cacheWarmupProvider = FutureProvider<void>((ref) async {
  await CacheWarmupService().warmup();
});
