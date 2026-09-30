import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/sync_plan.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/cache_policy_provider.dart';
import 'package:mybrev_flutter/providers/data_activity_provider.dart';
import 'package:mybrev_flutter/services/data_log.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/sync_provider.dart';
import 'package:mybrev_flutter/services/cache_warmup_service.dart';

class DataBootstrapState {
  const DataBootstrapState({
    this.isRunning = false,
    this.initialComplete = false,
    this.phase,
    this.error,
  });
  final bool isRunning;
  final bool initialComplete;
  final String? phase;
  final String? error;
}

class DataBootstrapNotifier extends Notifier<DataBootstrapState> {
  bool _disposed = false;
  bool _backgroundRunning = false;
  bool _backgroundAgain = false;

  @override
  DataBootstrapState build() {
    ref.onDispose(() => _disposed = true);
    ref.listen(connectivityProvider, (prev, next) {
      if (prev?.value == false && next.value == true) {
        if (!state.initialComplete) {
          ref.invalidate(selectedDateReadyProvider);
          unawaited(_runInitialBootstrap());
        } else {
          unawaited(_background());
        }
      }
    });
    ref.listen(cachePolicyProvider, (prev, next) {
      if (!next.enabled) {
        ref.read(syncStatusProvider.notifier).cancelBackground();
      }
      if (state.initialComplete && next.enabled) unawaited(_background());
    });
    // «Probable next action»: once a day is on screen, its neighbours are
    // prepared silently (tomorrow first — Vespers may need it).
    ref.listen(selectedDateReadyProvider, (prev, next) {
      if (next.hasValue && !next.isLoading) {
        unawaited(_prefetchAround(ref.read(selectedDateProvider)));
      }
    });
    Future.microtask(_runInitialBootstrap);
    return const DataBootstrapState();
  }

  Future<void> resume() async {
    if (_disposed) return;
    if (state.initialComplete) {
      await _background();
    } else {
      ref.invalidate(selectedDateReadyProvider);
      await _runInitialBootstrap();
    }
  }

  Future<void> _runInitialBootstrap() async {
    if (state.isRunning) return;
    state = const DataBootstrapState(isRunning: true, phase: 'today');
    try {
      await ref.read(selectedDateReadyProvider.future);
      if (_disposed) return;
      state = const DataBootstrapState(initialComplete: true);
      unawaited(_background());
    } catch (e) {
      if (!_disposed) state = DataBootstrapState(error: e.toString());
    }
  }

  /// Neighbouring days of the day being read. Silent: no progress UI, no
  /// page state; an already cached or already requested date costs nothing.
  Future<void> _prefetchAround(DateTime date) async {
    if (_disposed || !ref.read(cachePolicyProvider).enabled) return;
    if (ref.read(isOfflineProvider)) return;
    final counter = ref.read(backgroundPrefetchCountProvider.notifier);
    for (final offset in const [1, -1]) {
      final day = DateTime(date.year, date.month, date.day + offset);
      if (CacheWarmupService.isDateReady(day)) continue;
      DataLog.prefetch(() => 'date ${day.year}-${day.month}-${day.day}');
      counter.state++;
      try {
        final service = ref.read(selectedDateWarmupServiceProvider);
        if (await service.warmupDate(day) && !_disposed) {
          ref.read(cacheEpochProvider.notifier).state++;
        }
      } catch (error) {
        // Optional work: a failed prefetch is never an error of the screen.
        DataLog.networkError(() => 'prefetch: $error');
      } finally {
        if (!_disposed) counter.state--;
      }
      if (_disposed) return;
    }
  }

  /// Date changes are loaded by selectedDateReadyProvider immediately.
  void scheduleWarmupForDate(DateTime date) {
    ref.invalidate(selectedDateReadyProvider);
  }

  Future<void> _background() async {
    if (_backgroundRunning) {
      _backgroundAgain = true;
      return;
    }
    _backgroundRunning = true;
    try {
      do {
        _backgroundAgain = false;
        if (_disposed) return;
        final policy = ref.read(cachePolicyProvider);
        if (!policy.enabled) return;
        await ref
            .read(syncStatusProvider.notifier)
            .synchronize(
              SyncPlan(
                targets: kAutomaticSyncTargets,
                dates: CacheWarmupService.buildDateOrder(
                  DateTime.now(),
                  behind: policy.behind,
                  ahead: policy.ahead,
                ),
                forceRefresh: false,
                background: true,
              ),
            );
      } while (_backgroundAgain && !_disposed);
    } finally {
      _backgroundRunning = false;
    }
  }
}

final dataBootstrapProvider =
    NotifierProvider<DataBootstrapNotifier, DataBootstrapState>(
      DataBootstrapNotifier.new,
    );

/// The selected day could not be loaded (and may have nothing to show).
final homeDataFailedProvider = Provider<bool>((ref) {
  ref.watch(dataBootstrapProvider);
  final ready = ref.watch(selectedDateReadyProvider);
  return ready.hasError && !ready.isLoading;
});

final homeDataLoadingProvider = Provider<bool>((ref) {
  ref.watch(dataBootstrapProvider);
  return ref.watch(selectedDateReadyProvider).isLoading;
});
