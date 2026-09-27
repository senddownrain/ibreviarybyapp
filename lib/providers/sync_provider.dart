import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/sync_plan.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/services/cache_warmup_service.dart';
import 'package:mybrev_flutter/services/compendium_repository.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';
import 'package:mybrev_flutter/utils/readings_index.dart';
import 'package:mybrev_flutter/utils/retry.dart';

class SyncStatus {
  const SyncStatus({
    this.isSyncing = false,
    this.progress = 0,
    this.currentLabel,
    this.currentCollection,
    this.completedCollections = 0,
    this.totalCollections = 0,
    this.currentDocCount,
    this.error,
    this.downloadedBytes = 0,
    this.background = false,
    this.cancelled = false,
  });
  final bool isSyncing;
  final double progress;
  final String? currentLabel;
  final String? currentCollection;
  final int completedCollections;
  final int totalCollections;
  final int? currentDocCount;
  final String? error;
  final int downloadedBytes;
  final bool background;
  final bool cancelled;
}

const kEssentialSyncCollections = [
  ('prayers', 'Малітвы'),
  ('yearOptions', 'Гады'),
  ('invitatoriums', 'Заклік'),
  ('completoriums', 'Камплета'),
  ('prayerCategories', 'Катэгорыі малітваў'),
];

class SyncStatusNotifier extends Notifier<SyncStatus> {
  Future<void> _queue = Future.value();
  bool _cancel = false;

  @override
  SyncStatus build() => const SyncStatus();

  void cancel() {
    _cancel = true;
  }

  void cancelBackground() {
    if (state.background) cancel();
  }

  Future<void> forceSyncAll() => synchronize(
    const SyncPlan(targets: {...SyncTarget.values}, period: SyncPeriod.all),
  );

  Future<void> syncEssentialsIfEmpty() => synchronize(
    const SyncPlan(
      targets: {
        SyncTarget.prayers,
        SyncTarget.years,
        SyncTarget.invitatoriums,
        SyncTarget.completoriums,
        SyncTarget.prayerCategories,
      },
      forceRefresh: false,
      background: true,
    ),
  );

  /// Serialize writes. A user request is queued, never silently discarded.
  Future<void> synchronize(SyncPlan plan) {
    final next = _queue.then((_) => _run(plan));
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _run(SyncPlan plan) async {
    _cancel = false;
    final targets = SyncTarget.values.where(plan.targets.contains).toList();
    final collections = <(String, String)>[];
    final ranged = plan.period != SyncPeriod.all;
    for (final target in targets) {
      if (ranged &&
          (target == SyncTarget.days || target == SyncTarget.readings)) {
        continue;
      }
      collections.add((target.collection, target.label));
    }
    final includeDays = ranged && targets.contains(SyncTarget.days);
    final includeReadings = ranged && targets.contains(SyncTarget.readings);
    final total =
        collections.length + (includeDays ? 1 : 0) + (includeReadings ? 1 : 0);
    var completed = 0;
    var docs = 0;
    final bytesAtStart = HiveService.receivedBytes;
    final docsAtStart = HiveService.receivedDocuments;
    final errors = <String>[];
    final rangeSucceeded = <SyncTarget>{};
    void report(String collection, String label, {double fraction = 0}) {
      docs = HiveService.receivedDocuments - docsAtStart;
      state = SyncStatus(
        isSyncing: true,
        background: plan.background,
        currentCollection: collection,
        currentLabel: label,
        completedCollections: completed,
        totalCollections: total,
        progress: total == 0 ? 0 : (completed + fraction) / total,
        currentDocCount: docs,
        downloadedBytes: HiveService.receivedBytes - bytesAtStart,
      );
    }

    report('', 'Падрыхтоўка загрузкі');
    try {
      final dates =
          plan.dates ?? plan.period.dates(plan.baseDate ?? DateTime.now());
      final warmup = includeDays || includeReadings
          ? ref.read(syncWarmupServiceProvider)
          : null;
      for (final target in [
        if (includeDays) SyncTarget.days,
        if (includeReadings) SyncTarget.readings,
      ]) {
        try {
          report(target.collection, target.label);
          await warmup!.syncDates(
            dates,
            includeDays: target == SyncTarget.days,
            includeReadings: target == SyncTarget.readings,
            forceRefresh: plan.forceRefresh,
            shouldCancel: () => _cancel,
            onProgress: (done, dateCount) => report(
              target.collection,
              '${target.label} · $done / $dateCount дзён',
              fraction: done / dateCount,
            ),
          );
          if (_cancel) break;
          await HiveService.setLastSync(target.collection, DateTime.now());
          rangeSucceeded.add(target);
          completed++;
          ref.read(cacheEpochProvider.notifier).state++;
        } catch (e) {
          errors.add("${target.label}: $e");
        }
      }
      if (!_cancel && rangeSucceeded.length == 2 && dates.isNotEmpty) {
        final sorted = [...dates]..sort();
        await HiveService.setWarmupCoverage(sorted.first, sorted.last);
      }
      for (final (collection, label) in collections) {
        if (_cancel) break;
        try {
          report(collection, label);
          final box = HiveService.boxFor(collection);
          final last = HiveService.getLastSync(collection);
          final fresh =
              last != null &&
              DateTime.now().difference(last) < const Duration(days: 1);
          final compendium = collection == SyncTarget.compendium.collection;
          // An empty Compendium box is normal: the bundled dataset is used
          // until Firestore has a newer version.
          if (!plan.forceRefresh && fresh && (box.isNotEmpty || compendium)) {
            completed++;
            continue;
          }
          if (compendium) {
            await ref
                .read(compendiumSyncProvider)
                .run(shouldCancel: () => _cancel);
            report(collection, label);
          } else {
            await _syncCollection(collection, (documentCount) {
              report(collection, label);
            });
          }
          if (_cancel) break;
          await HiveService.setLastSync(collection, DateTime.now());
          if (collection.startsWith('bible_')) {
            BibleRepository.loadCachedVersion(collection.substring(6));
          }
          if (collection == 'yearOptions') {
            ref.invalidate(calendarServiceProvider);
            ref.invalidate(calendarReadyProvider);
          }
          completed++;
          ref.read(cacheEpochProvider.notifier).state++;
        } catch (e) {
          errors.add("$label: $e");
        }
      }
      state = SyncStatus(
        error: errors.isEmpty ? null : errors.join('\n'),
        progress: _cancel || errors.isNotEmpty ? state.progress : 1,
        completedCollections: completed,
        totalCollections: total,
        currentDocCount: docs,
        background: plan.background,
        cancelled: _cancel,
        downloadedBytes: HiveService.receivedBytes - bytesAtStart,
      );
    } catch (e) {
      state = SyncStatus(
        error: '${state.currentLabel}: $e',
        progress: state.progress,
        completedCollections: completed,
        totalCollections: total,
        currentDocCount: docs,
        background: plan.background,
        downloadedBytes: HiveService.receivedBytes - bytesAtStart,
      );
    } finally {
      // Also expose any successfully saved pages after cancellation or failure.
      ref.read(cacheEpochProvider.notifier).state++;
    }
  }

  /// Persist pages as they arrive. Remove obsolete entries only after the last
  /// page succeeds, preserving usable offline content after interruption.
  Future<void> _syncCollection(
    String collection,
    void Function(int) onPage,
  ) async {
    final box = HiveService.boxFor(collection);
    final seen = <String>{};
    final originalKeys = box.keys.toList();
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    var count = 0;
    while (!_cancel) {
      Query<Map<String, dynamic>> query = ref
          .read(syncFirestoreProvider)
          .collection(collection)
          .orderBy(FieldPath.documentId)
          .limit(50);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final page = await retryFirestore(
        () => query.get(const GetOptions(source: Source.server)),
      );
      if (_cancel) return;
      for (final doc in page.docs) {
        final data = firestoreToStorable({...doc.data(), 'id': doc.id});
        final key = collection == 'yearOptions'
            ? data['year']?.toString() ?? doc.id
            : doc.id;
        seen.add(key);
        if (collection == 'readings') {
          await cacheReadingDoc(doc.id, data);
        } else {
          await HiveService.putCached(collection, key, data);
        }
        count++;
      }
      onPage(count);
      if (page.docs.length < 50) break;
      cursor = page.docs.last;
      await Future<void>.delayed(Duration.zero);
    }
    if (_cancel) return;
    for (final key in originalKeys) {
      if (!seen.contains(key.toString())) {
        if (collection == 'readings') {
          final raw = box.get(key);
          if (raw is Map) {
            await ReadingsIndex.removeDoc(
              key.toString(),
              Map<String, dynamic>.from(raw),
            );
          }
        }
        await HiveService.removeCached(collection, key);
      }
    }
    if (collection == 'days' || collection == 'readings') {
      await HiveService.setMetaFlag('fullCache_$collection', true);
    }
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);

final syncFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Compendium refresh (meta check, then units only when newer and valid).
final compendiumSyncProvider = Provider<CompendiumSync>(
  (ref) => CompendiumSync(
    remote: FirestoreCompendiumRemote(ref.read(syncFirestoreProvider)),
    bundledVersion: CompendiumRepository.bundledContentVersion,
  ),
);
final syncWarmupServiceProvider = Provider<CacheWarmupService>(
  (ref) => CacheWarmupService(),
);
