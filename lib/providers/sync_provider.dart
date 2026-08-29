import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

class SyncStatus {
  final bool isSyncing;
  final double progress;
  final String? currentLabel;
  final String? currentCollection;
  final int completedCollections;
  final int totalCollections;
  final int? currentDocCount;
  final String? error;

  const SyncStatus({
    this.isSyncing = false,
    this.progress = 0.0,
    this.currentLabel,
    this.currentCollection,
    this.completedCollections = 0,
    this.totalCollections = 0,
    this.currentDocCount,
    this.error,
  });

  SyncStatus copyWith({
    bool? isSyncing,
    double? progress,
    String? currentLabel,
    String? currentCollection,
    int? completedCollections,
    int? totalCollections,
    int? currentDocCount,
    String? error,
  }) =>
      SyncStatus(
        isSyncing: isSyncing ?? this.isSyncing,
        progress: progress ?? this.progress,
        currentLabel: currentLabel ?? this.currentLabel,
        currentCollection: currentCollection ?? this.currentCollection,
        completedCollections:
            completedCollections ?? this.completedCollections,
        totalCollections: totalCollections ?? this.totalCollections,
        currentDocCount: currentDocCount ?? this.currentDocCount,
        error: error ?? this.error,
      );
}

/// Canonical Firestore collections (same as web) → Hive.
const _kSyncCollections = [
  ('prayers', 'Малітвы'),
  ('days', 'Дні'),
  ('yearOptions', 'Гады'),
  ('readings', 'Чытанні'),
  ('invitatoriums', 'Закліц'),
  ('completoriums', 'Камплета'),
];

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncStatus();

  Future<void> forceSyncAll() async {
    if (state.isSyncing) return;
    state = SyncStatus(
      isSyncing: true,
      totalCollections: _kSyncCollections.length,
    );

    final db = FirebaseFirestore.instance;

    for (var i = 0; i < _kSyncCollections.length; i++) {
      final (collection, label) = _kSyncCollections[i];
      state = state.copyWith(
        currentCollection: collection,
        currentLabel: label,
        completedCollections: i,
        progress: i / _kSyncCollections.length,
        currentDocCount: null,
        error: null,
      );

      try {
        final box = _boxFor(collection);
        final snap = await db
            .collection(collection)
            .get(const GetOptions(source: Source.server));
        await box.clear();
        for (final doc in snap.docs) {
          final data = _toStorable(doc.data()..['id'] = doc.id);
          if (collection == 'yearOptions') {
            final year = data['year'];
            await box.put(year?.toString() ?? doc.id, data);
          } else {
            await box.put(doc.id, data);
          }
        }
        await HiveService.setLastSync(collection, DateTime.now());
        state = state.copyWith(currentDocCount: snap.docs.length);
      } catch (e) {
        state = state.copyWith(error: '$label: $e');
        break;
      }
    }

    state = state.copyWith(
      isSyncing: false,
      progress: 1.0,
      completedCollections: _kSyncCollections.length,
      currentLabel: null,
      currentCollection: null,
    );
  }

  static Map<String, dynamic> _toStorable(Map<String, dynamic> data) =>
      data.map((k, v) => MapEntry(k, _convertValue(v)));

  static dynamic _convertValue(dynamic v) {
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    if (v is DocumentReference) return v.path;
    if (v is GeoPoint) return {'lat': v.latitude, 'lng': v.longitude};
    if (v is Map) {
      return (v as Map<Object?, Object?>)
          .map((k, val) => MapEntry(k.toString(), _convertValue(val)));
    }
    if (v is List) return v.map(_convertValue).toList();
    return v;
  }

  dynamic _boxFor(String collection) => switch (collection) {
        'prayers' => HiveService.prayersBox,
        'days' => HiveService.daysBox,
        'yearOptions' => HiveService.yearOptionsBox,
        'readings' => HiveService.readingsBox,
        'invitatoriums' => HiveService.invitatoriumsBox,
        'completoriums' => HiveService.completoriumsBox,
        _ => throw ArgumentError('Unknown collection: $collection'),
      };
}

final syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);
