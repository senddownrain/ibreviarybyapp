import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';
import 'package:mybrev_flutter/utils/retry.dart';

class StaticLiturgicalService {
  final FirebaseFirestore _db;

  StaticLiturgicalService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getInvitatoriums() =>
      _getCollection('invitatoriums');

  Future<List<Map<String, dynamic>>> getCompletoriums() =>
      _getCollection('completoriums');

  Future<Map<String, dynamic>?> getCompletoriumById(String id) async {
    final cached = HiveService.completoriumsBox.get(id);
    if (cached != null) return Map<String, dynamic>.from(cached as Map);
    await _getCollection('completoriums');
    final loaded = HiveService.completoriumsBox.get(id);
    return loaded == null ? null : Map<String, dynamic>.from(loaded as Map);
  }

  Future<List<Map<String, dynamic>>> _getCollection(String name) async {
    final box = name == 'invitatoriums'
        ? HiveService.invitatoriumsBox
        : HiveService.completoriumsBox;
    if (box.isNotEmpty) {
      return box.values
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
    }
    try {
      final snapshot = await retryFirestore(
        () => _db.collection(name).get(const GetOptions(source: Source.server)),
      );
      for (final doc in snapshot.docs) {
        await HiveService.putCached(
          name,
          doc.id,
          firestoreToStorable({...doc.data(), 'id': doc.id}),
        );
      }
    } catch (_) {
      // Offline-first: a concurrent sync or Firestore's local persistence may
      // still have populated Hive; return whatever is safely available.
    }
    return box.values
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
  }
}
