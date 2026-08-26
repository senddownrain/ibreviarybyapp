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
        completedCollections: completedCollections ?? this.completedCollections,
        totalCollections: totalCollections ?? this.totalCollections,
        currentDocCount: currentDocCount ?? this.currentDocCount,
        error: error ?? this.error,
      );
}

/// Collections to sync from Firestore → Hive.
/// Key is the Firestore collection name; value is the UI label.
const _kSyncCollections = [
  ('prayers', 'Малітвы'),
  ('fixedDays', 'Дні'),
  ('yearOptions', 'Гады'),
  ('parsedData', 'Чытанні'),
  ('invitatoriums', 'Закліц'),
  ('completoriums', 'Камплета'),
];

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncStatus();

  Future<void> forceSyncAll() async {
    // ignore: avoid_print
    print('[SyncProvider] forceSyncAll called, isSyncing=${state.isSyncing}');
    if (state.isSyncing) return;
    state = SyncStatus(
      isSyncing: true,
      totalCollections: _kSyncCollections.length,
    );
    // ignore: avoid_print
    print('[SyncProvider] state set to isSyncing=true');

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
        // ignore: avoid_print
        print('[SyncProvider] fetching $collection...');
        final box = _boxFor(collection);
        final snap = await db
            .collection(collection)
            .get(const GetOptions(source: Source.server));
        // ignore: avoid_print
        print('[SyncProvider] $collection: ${snap.docs.length} docs');
        await box.clear();
        for (final doc in snap.docs) {
          final data = _toStorable(doc.data()..['id'] = doc.id);
          await box.put(doc.id, data);
        }
        await HiveService.setLastSync(collection, DateTime.now());
        state = state.copyWith(currentDocCount: snap.docs.length);
      } catch (e, st) {
        // ignore: avoid_print
        print('[SyncProvider] ERROR in $collection: $e\n$st');
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

  // Recursively convert Firestore-specific types to plain Dart so Hive can store them.
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
        'prayers'      => HiveService.prayersBox,
        'fixedDays'    => HiveService.daysBox,
        'yearOptions'  => HiveService.yearOptionsBox,
        'parsedData'   => HiveService.parsedDataBox,
        'invitatoriums'=> HiveService.invitatoriumsBox,
        'completoriums'=> HiveService.completoriumsBox,
        _              => throw ArgumentError('Unknown collection: $collection'),
      };
}

final syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);
