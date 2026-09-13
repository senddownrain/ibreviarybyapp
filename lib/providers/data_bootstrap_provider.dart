import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/sync_plan.dart';
import 'package:mybrev_flutter/providers/cache_policy_provider.dart';
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
                targets: {...SyncTarget.values},
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

final homeDataLoadingProvider = Provider<bool>((ref) {
  ref.watch(dataBootstrapProvider);
  return ref.watch(selectedDateReadyProvider).isLoading;
});
