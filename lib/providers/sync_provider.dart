import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/services/cache_warmup_service.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';
import 'package:mybrev_flutter/utils/retry.dart';

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
    Object? currentLabel = _unset,
    Object? currentCollection = _unset,
    int? completedCollections,
    int? totalCollections,
    Object? currentDocCount = _unset,
    Object? error = _unset,
  }) =>
      SyncStatus(
        isSyncing: isSyncing ?? this.isSyncing,
        progress: progress ?? this.progress,
        currentLabel: identical(currentLabel, _unset)
            ? this.currentLabel
            : currentLabel as String?,
        currentCollection: identical(currentCollection, _unset)
            ? this.currentCollection
            : currentCollection as String?,
        completedCollections:
            completedCollections ?? this.completedCollections,
        totalCollections: totalCollections ?? this.totalCollections,
        currentDocCount: identical(currentDocCount, _unset)
            ? this.currentDocCount
            : currentDocCount as int?,
        error: identical(error, _unset) ? this.error : error as String?,
      );
}

const Object _unset = Object();

/// Small collections safe to download in full (same approach as web static sync).
/// `days` and `readings` are huge — loaded on demand via [CacheWarmupService].
const kEssentialSyncCollections = [
  ('prayers', 'Малітвы'),
  ('yearOptions', 'Гады'),
  ('invitatoriums', 'Закліц'),
  ('completoriums', 'Камплета'),
];

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncStatus();

  /// Auto-bootstrap: sync static collections only when Hive is empty.
  Future<void> syncEssentialsIfEmpty() async {
    if (!HiveService.needsBootstrap()) return;
    await _syncCollections(kEssentialSyncCollections);
    ref.read(cacheEpochProvider.notifier).state++;
  }

  Future<void> forceSyncAll() async {
    if (state.isSyncing) return;

    const warmupStep = 1;
    final totalSteps = kEssentialSyncCollections.length + warmupStep;

    state = SyncStatus(
      isSyncing: true,
      totalCollections: totalSteps,
      error: null,
      currentDocCount: null,
    );

    try {
      await _syncCollections(
        kEssentialSyncCollections,
        onProgress: (i, collection, label, docCount) {
          state = state.copyWith(
            currentCollection: collection,
            currentLabel: label,
            completedCollections: i,
            progress: i / totalSteps,
            currentDocCount: docCount,
            error: null,
          );
        },
      );
      ref.read(cacheEpochProvider.notifier).state++;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
        currentLabel: null,
        currentCollection: null,
      );
      return;
    }

    state = state.copyWith(
      currentCollection: 'warmup',
      currentLabel: 'Дні і чытанні (актуальныя)',
      completedCollections: kEssentialSyncCollections.length,
      progress: kEssentialSyncCollections.length / totalSteps,
      currentDocCount: null,
      error: null,
    );

    try {
      await CacheWarmupService().warmup();
      await HiveService.setLastSync('days', DateTime.now());
      await HiveService.setLastSync('readings', DateTime.now());
      ref.read(cacheEpochProvider.notifier).state++;
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] warmup failed: $e');
      state = state.copyWith(
        isSyncing: false,
        error: 'Дні і чытанні: $e',
        currentLabel: null,
        currentCollection: null,
      );
      return;
    }

    state = state.copyWith(
      isSyncing: false,
      progress: 1.0,
      completedCollections: totalSteps,
      currentLabel: null,
      currentCollection: null,
      currentDocCount: null,
      error: null,
    );

    unawaited(() async {
      try {
        await CacheWarmupService().warmupExtended();
        ref.read(cacheEpochProvider.notifier).state++;
      } catch (e) {
        if (kDebugMode) debugPrint('[Sync] extended warmup failed: $e');
      }
    }());
  }

  Future<void> _syncCollections(
    List<(String, String)> collections, {
    void Function(int index, String collection, String label, int count)?
        onProgress,
  }) async {
    final db = FirebaseFirestore.instance;

    for (var i = 0; i < collections.length; i++) {
      final (collection, label) = collections[i];
      try {
        final count = await _syncCollection(db, collection);
        await HiveService.setLastSync(collection, DateTime.now());
        onProgress?.call(i, collection, label, count);
      } catch (e) {
        throw '$label: $e';
      }
    }
  }

  /// Download collection into memory first, then replace Hive — never leave
  /// an empty box if the network call fails mid-way.
  Future<int> _syncCollection(FirebaseFirestore db, String collection) async {
    final box = _boxFor(collection);
    final snap = await retryFirestore(() => db
        .collection(collection)
        .get(const GetOptions(source: Source.server)));

    final entries = <MapEntry<dynamic, Map<String, dynamic>>>[];
    for (final doc in snap.docs) {
      final data = firestoreToStorable({...doc.data(), 'id': doc.id});
      if (collection == 'yearOptions') {
        final year = data['year'];
        entries.add(MapEntry(year?.toString() ?? doc.id, data));
      } else {
        entries.add(MapEntry(doc.id, data));
      }
    }

    await box.clear();
    for (final e in entries) {
      await box.put(e.key, e.value);
    }
    return entries.length;
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
