import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';
import 'package:mybrev_flutter/utils/liturgical_psalter.dart';
import 'package:mybrev_flutter/utils/retry.dart';

const kDaysCollection = 'days';
const kLegacyDaysCollection = 'fixedDays';

/// Canonical period day ID (mirrors web `getPeriodDayDocumentId`).
List<String> feastCodeVariants(String code) {
  final normalized = code.replaceFirst(RegExp(r'^feast-'), '');
  return [
    ...{normalized, 'feast-$normalized'},
  ];
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
    if (fromHive != null) {
      return _withPeriodPsalterFallback(
        fromHive,
        periodType,
        periodWeek,
        dayOfWeek,
      );
    }

    final canonicalId = periodDayDocumentId(periodType, periodWeek, dayOfWeek);
    if (canonicalId.isNotEmpty) {
      final byId = await getDayById(canonicalId);
      if (byId != null) {
        return _withPeriodPsalterFallback(
          byId,
          periodType,
          periodWeek,
          dayOfWeek,
        );
      }
    }

    for (final collection in [kDaysCollection, kLegacyDaysCollection]) {
      try {
        final results = await retryFirestore(
          () => Future.wait([
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
          ]),
        );

        for (final snap in results) {
          if (snap.docs.isEmpty) continue;
          final doc = snap.docs.first;
          final data = {...doc.data(), 'id': doc.id};
          await cacheDayDoc(doc.id, data);
          return _withPeriodPsalterFallback(
            LiturgicalDay.fromMap(data),
            periodType,
            periodWeek,
            dayOfWeek,
          );
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
        final snaps = await retryFirestore(
          () => Future.wait([
            for (final variant in feastCodeVariants(feastCode))
              _col(collection).where('_feast', isEqualTo: variant).get(),
          ]),
        );
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
    final variants = {
      ...{dM, ddMm},
    };

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
        final snaps = await retryFirestore(
          () => Future.wait([
            for (final v in variants)
              _col(collection).where('_date', isEqualTo: v).get(),
          ]),
        );
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
      getDayById('office-for-dead'),
      if (seasonalDateExceptionId(date, periodType) case final id?)
        getDayById(id),
    ]);
  }

  /// Resolve the selected route day against its period/psalter template.
  /// This is the Flutter counterpart of `useResolvedLiturgicalDay`.
  Future<LiturgicalDay?> resolveDayForDate(
    DateTime date,
    String dayId,
    LiturgicalContext context,
    List<String> feastCodes,
  ) async {
    await prefetchForDate(
      date,
      periodType: context.periodType,
      periodWeek: context.periodWeek,
      dayOfWeek: context.dayOfWeek,
      feastCodes: feastCodes,
    );
    final selected = await getDayById(dayId);
    if (selected == null) return null;
    var period = await findDayByPeriod(
      context.periodType,
      context.periodWeek,
      context.dayOfWeek,
    );
    if (period == null && context.periodType == 'christmas') {
      final psalterWeek = calculatePsalterWeek(
        date: date,
        periodType: context.periodType,
        periodWeek: context.periodWeek,
      );
      if (psalterWeek != null) {
        period = await findDayByPeriod(
          'advent',
          psalterWeek,
          context.dayOfWeek,
        );
      }
    }
    final seasonalId = seasonalDateExceptionId(date, context.periodType);
    LiturgicalDay? resolved;
    if (seasonalId == dayId) {
      resolved = context.periodType == 'christmas'
          ? resolveChristmasDateAgainstPeriod(selected, period)
          : resolveDayAgainstPeriod(selected, period, fillMissing: true);
      resolved = applySeasonalWeekdayAntiphons(resolved!, context.dayOfWeek);
    } else if (selected.date != null && selected.date!.isNotEmpty) {
      resolved = resolveDayAgainstPeriod(selected, period, fillMissing: true);
    } else {
      resolved = resolveDayAgainstPeriod(selected, period);
    }
    final data = resolved!.toMap()
      ..['_periodType'] = context.periodType
      ..['_periodWeekNumber'] = context.periodWeek
      ..['_dayOfWeek'] = context.dayOfWeek
      ..['_calendarDate'] =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
      ..['_contextPeriodType'] = context.periodType;
    return LiturgicalDay.fromMap(data);
  }

  Future<LiturgicalDay> _withPeriodPsalterFallback(
    LiturgicalDay day,
    String periodType,
    int periodWeek,
    int dayOfWeek,
  ) async {
    var resolved = resolveDayAgainstPeriod(day, null)!;
    if (periodType == 'christmas') return resolved;
    if (periodType != 'advent' && !hasMissingDaytimeFields(resolved)) {
      return resolved;
    }
    final fallbackId = periodType == 'ordinary'
        ? periodPsalterDayDocumentId(periodType, periodWeek, dayOfWeek)
        : ordinaryPsalterDayDocumentId(periodWeek, dayOfWeek);
    if (fallbackId.isEmpty || fallbackId == resolved.id) return resolved;
    final fallback = await getDayById(fallbackId);
    if (fallback == null) return resolved;
    if (periodType == 'advent') {
      return resolveDayAgainstPeriod(resolved, fallback, fillMissing: true)!;
    }
    return resolvePeriodDayAgainstPsalter(resolved, fallback)!;
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
