import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';

const kDaysCollection = 'days';

/// Firestore access for canonical `days` collection.
class LiturgicalDayService {
  final FirebaseFirestore _db;

  LiturgicalDayService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(kDaysCollection);

  Future<LiturgicalDay?> getDayById(String id) async {
    final cached = HiveService.daysBox.get(id);
    if (cached != null) {
      return LiturgicalDay.fromMap(Map<String, dynamic>.from(cached));
    }
    try {
      final snap = await _col.doc(id).get();
      if (!snap.exists) return null;
      final data = {...snap.data()!, 'id': snap.id};
      await cacheDayDoc(snap.id, data);
      return LiturgicalDay.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  Future<LiturgicalDay?> findDayByPeriod(
    String periodType,
    int periodWeek,
    int dayOfWeek,
  ) async {
    final fromHive = _hiveFindPeriod(periodType, periodWeek, dayOfWeek);
    if (fromHive != null) return fromHive;

    final weekStr = periodWeek.toString();
    final dayStr = dayOfWeek.toString();
    try {
      final snap = await _col
          .where('_periodType', isEqualTo: periodType)
          .where('_dayOfWeek', isEqualTo: dayStr)
          .where('_periodWeekNumber', isEqualTo: weekStr)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      final data = {...doc.data(), 'id': doc.id};
      await cacheDayDoc(doc.id, data);
      return LiturgicalDay.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  LiturgicalDay? _hiveFindPeriod(
      String periodType, int periodWeek, int dayOfWeek) {
    final weekStr = periodWeek.toString();
    final dayStr = dayOfWeek.toString();
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
