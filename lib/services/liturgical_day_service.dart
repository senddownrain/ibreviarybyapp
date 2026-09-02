import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';
import 'package:mybrev_flutter/utils/retry.dart';

const kDaysCollection = 'days';
const kLegacyDaysCollection = 'fixedDays';

/// Canonical period day ID (mirrors web `getPeriodDayDocumentId`).
String periodDayDocumentId(
  String periodType,
  int periodWeekNumber,
  int dayOfWeek,
) {
  final period = periodType.trim();
  if (period.isEmpty) return '';
  if (periodWeekNumber < 0) return '';
  if (dayOfWeek < 1 || dayOfWeek > 7) return '';
  return '$period-w$periodWeekNumber-d$dayOfWeek';
}

List<String> feastCodeVariants(String code) {
  final normalized = code.replaceFirst(RegExp(r'^feast-'), '');
  return [...{normalized, 'feast-$normalized'}];
}

/// Firestore access for canonical `days` collection (with `fixedDays` fallback).
class LiturgicalDayService {
  final FirebaseFirestore _db;

  LiturgicalDayService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection(name);

  Future<LiturgicalDay?> getDayById(String id) async {
    final cached = HiveService.daysBox.get(id);
    if (cached != null) {
      return LiturgicalDay.fromMap(Map<String, dynamic>.from(cached));
    }

    for (final collection in [kDaysCollection, kLegacyDaysCollection]) {
      try {
        final snap = await retryFirestore(() => _col(collection).doc(id).get());
        if (!snap.exists) continue;
        final data = {...snap.data()!, 'id': snap.id};
        await cacheDayDoc(snap.id, data);
        return LiturgicalDay.fromMap(data);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
            '[LiturgicalDayService] getDayById($id) in $collection: $e\n$st',
          );
        }
      }
    }
    return null;
  }

  /// Prefer canonical doc id, then string/number field queries (web parity).
  Future<LiturgicalDay?> findDayByPeriod(
    String periodType,
    int periodWeek,
    int dayOfWeek,
  ) async {
    final fromHive = _hiveFindPeriod(periodType, periodWeek, dayOfWeek);
    if (fromHive != null) return fromHive;

    final canonicalId = periodDayDocumentId(periodType, periodWeek, dayOfWeek);
    if (canonicalId.isNotEmpty) {
      final byId = await getDayById(canonicalId);
      if (byId != null) return byId;
    }

    for (final collection in [kDaysCollection, kLegacyDaysCollection]) {
      try {
        final results = await retryFirestore(() => Future.wait([
              _col(collection)
                  .where('_periodType', isEqualTo: periodType)
                  .where('_dayOfWeek', isEqualTo: '$dayOfWeek')
                  .where('_periodWeekNumber', isEqualTo: '$periodWeek')
                  .limit(1)
                  .get(),
              _col(collection)
                  .where('_periodType', isEqualTo: periodType)
                  .where('_dayOfWeek', isEqualTo: dayOfWeek)
                  .where('_periodWeekNumber', isEqualTo: periodWeek)
                  .limit(1)
                  .get(),
            ]));

        for (final snap in results) {
          if (snap.docs.isEmpty) continue;
          final doc = snap.docs.first;
          final data = {...doc.data(), 'id': doc.id};
          await cacheDayDoc(doc.id, data);
          return LiturgicalDay.fromMap(data);
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
            '[LiturgicalDayService] findDayByPeriod in $collection: $e\n$st',
          );
        }
      }
    }
    return null;
  }

  Future<List<LiturgicalDay>> findDaysByFeast(String feastCode) async {
    final results = <String, LiturgicalDay>{};
    for (final variant in feastCodeVariants(feastCode)) {
      for (final key in HiveService.daysBox.keys) {
        final raw = HiveService.daysBox.get(key);
        if (raw == null) continue;
        final data = Map<String, dynamic>.from(raw);
        if (data['_feast']?.toString() == variant) {
          results[data['id']?.toString() ?? key.toString()] =
              LiturgicalDay.fromMap(data);
        }
      }
    }
    if (results.isNotEmpty) return results.values.toList();

    for (final collection in [kDaysCollection, kLegacyDaysCollection]) {
      try {
        final snaps = await retryFirestore(() => Future.wait([
              for (final variant in feastCodeVariants(feastCode))
                _col(collection).where('_feast', isEqualTo: variant).get(),
            ]));
        for (final snap in snaps) {
          for (final doc in snap.docs) {
            final data = {...doc.data(), 'id': doc.id};
            await cacheDayDoc(doc.id, data);
            results[doc.id] = LiturgicalDay.fromMap(data);
          }
        }
        if (results.isNotEmpty) return results.values.toList();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
            '[LiturgicalDayService] findDaysByFeast in $collection: $e\n$st',
          );
        }
      }
    }
    return results.values.toList();
  }

  Future<List<LiturgicalDay>> findDaysByFixedDate(DateTime date) async {
    final dM = '${date.day}.${date.month}';
    final ddMm =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    final variants = {...{dM, ddMm}};

    final results = <String, LiturgicalDay>{};
    for (final key in HiveService.daysBox.keys) {
      final raw = HiveService.daysBox.get(key);
      if (raw == null) continue;
      final data = Map<String, dynamic>.from(raw);
      final stored = data['_date']?.toString();
      if (stored != null && variants.contains(stored)) {
        results[data['id']?.toString() ?? key.toString()] =
            LiturgicalDay.fromMap(data);
      }
    }
    if (results.isNotEmpty) return results.values.toList();

    for (final collection in [kDaysCollection, kLegacyDaysCollection]) {
      try {
        final snaps = await retryFirestore(() => Future.wait([
              for (final v in variants) _col(collection).where('_date', isEqualTo: v).get(),
            ]));
        for (final snap in snaps) {
          for (final doc in snap.docs) {
            final data = {...doc.data(), 'id': doc.id};
            await cacheDayDoc(doc.id, data);
            results[doc.id] = LiturgicalDay.fromMap(data);
          }
        }
        if (results.isNotEmpty) return results.values.toList();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
            '[LiturgicalDayService] findDaysByFixedDate in $collection: $e\n$st',
          );
        }
      }
    }
    return results.values.toList();
  }

  /// Prefetch all day variants needed for a calendar date.
  Future<void> prefetchForDate(
    DateTime date, {
    required String periodType,
    required int periodWeek,
    required int dayOfWeek,
    required List<String> feastCodes,
  }) async {
    await Future.wait([
      findDayByPeriod(periodType, periodWeek, dayOfWeek),
      findDaysByFixedDate(date),
      for (final code in feastCodes) findDaysByFeast(code),
    ]);
  }

  LiturgicalDay? _hiveFindPeriod(
    String periodType,
    int periodWeek,
    int dayOfWeek,
  ) {
    final weekStr = periodWeek.toString();
    final dayStr = dayOfWeek.toString();
    final canonicalId = periodDayDocumentId(periodType, periodWeek, dayOfWeek);
    if (canonicalId.isNotEmpty) {
      final raw = HiveService.daysBox.get(canonicalId);
      if (raw != null) {
        return LiturgicalDay.fromMap(Map<String, dynamic>.from(raw));
      }
    }
    for (final key in HiveService.daysBox.keys) {
      final raw = HiveService.daysBox.get(key);
      if (raw == null) continue;
      final data = Map<String, dynamic>.from(raw);
      final feast = data['_feast'];
      if (feast != null && feast.toString().isNotEmpty) continue;
      if (data['_periodType'] == periodType &&
          data['_periodWeekNumber']?.toString() == weekStr &&
          data['_dayOfWeek']?.toString() == dayStr) {
        return LiturgicalDay.fromMap(data);
      }
    }
    return null;
  }
}
