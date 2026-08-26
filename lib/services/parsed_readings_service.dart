import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_cycle.dart';

/// Fetches parsedData readings from Hive cache or Firestore on demand.
class ParsedReadingsService {
  final FirebaseFirestore _db;

  ParsedReadingsService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Returns a parsed reading doc by its Firestore document id.
  Future<Map<String, dynamic>?> getReading(String docId) async {
    if (!true) {
      // forceRefresh = false: check cache first
    }
    final cached = HiveService.parsedDataBox.get(docId);
    if (cached != null) {
      return Map<String, dynamic>.from(cached);
    }
    final snap = await _db.collection('parsedData').doc(docId).get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    await HiveService.parsedDataBox.put(docId, data);
    return data;
  }

  /// Fetch readings for a liturgical period/week/day from Firestore.
  Future<List<ParsedReading>> fetchByLiturgicalKey(
    String period,
    int week,
    int day, {
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = _getCachedByPeriod(period, week, day);
      if (cached.isNotEmpty) return cached;
    }
    final snap = await _db
        .collection('parsedData')
        .where('_periodType', isEqualTo: period)
        .where('_periodWeekNumber', isEqualTo: week)
        .where('_dayOfWeek', isEqualTo: day)
        .get();
    final results = <ParsedReading>[];
    for (final doc in snap.docs) {
      final data = {...doc.data(), 'id': doc.id};
      await HiveService.parsedDataBox.put(doc.id, data);
      results.add(ParsedReading.fromMap(doc.id, data));
    }
    return results;
  }

  /// Fetch readings for a calendar date from Firestore.
  Future<List<ParsedReading>> fetchForDate(
    DateTime date,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates, {
    bool forceRefresh = false,
  }) async {
    final context = computeLiturgicalContext(date, opts, nextYearOpts, dynamicDates);
    final ddmm = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';

    // Check cache first
    if (!forceRefresh) {
      final byPeriod = _getCachedByPeriod(
          context.periodType, context.periodWeek, context.dayOfWeek);
      if (byPeriod.isNotEmpty) return byPeriod;
    }

    final results = <ParsedReading>[];

    // By period
    final periodSnap = await _db
        .collection('parsedData')
        .where('_periodType', isEqualTo: context.periodType)
        .where('_periodWeekNumber', isEqualTo: context.periodWeek)
        .where('_dayOfWeek', isEqualTo: context.dayOfWeek)
        .get();
    for (final doc in periodSnap.docs) {
      final data = {...doc.data(), 'id': doc.id};
      await HiveService.parsedDataBox.put(doc.id, data);
      results.add(ParsedReading.fromMap(doc.id, data));
    }

    // By fixed date (DD.MM)
    final dateSnap = await _db
        .collection('parsedData')
        .where('_date', isEqualTo: ddmm)
        .get();
    for (final doc in dateSnap.docs) {
      final data = {...doc.data(), 'id': doc.id};
      await HiveService.parsedDataBox.put(doc.id, data);
      // Avoid duplicate ids
      if (!results.any((r) => r.id == doc.id)) {
        results.add(ParsedReading.fromMap(doc.id, data));
      }
    }

    return results;
  }

  /// Returns the current lectionary cycle for a date.
  static String currentCycle(DateTime date, {int? dayOfWeek}) {
    // Sunday cycle A/B/C
    final catholic = dayOfWeek ?? (date.weekday == 7 ? 1 : date.weekday + 1);
    if (catholic == 1) {
      return getCycleForDate(date, dayOfWeek: dayOfWeek);
    }
    // Weekday cycle I/II
    return getWeekdayCycleForDate(date);
  }

  List<ParsedReading> _getCachedByPeriod(
      String periodType, int week, int day) {
    final box = HiveService.parsedDataBox;
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

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
