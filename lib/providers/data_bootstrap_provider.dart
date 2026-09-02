import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/sync_provider.dart';
import 'package:mybrev_flutter/services/cache_warmup_service.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

class DataBootstrapState {
  final bool isRunning;
  final bool initialComplete;
  final String? phase;
  final String? error;

  const DataBootstrapState({
    this.isRunning = false,
    this.initialComplete = false,
    this.phase,
    this.error,
  });

  DataBootstrapState copyWith({
    bool? isRunning,
    bool? initialComplete,
    Object? phase = _unset,
    Object? error = _unset,
  }) =>
      DataBootstrapState(
        isRunning: isRunning ?? this.isRunning,
        initialComplete: initialComplete ?? this.initialComplete,
        phase: identical(phase, _unset) ? this.phase : phase as String?,
        error: identical(error, _unset) ? this.error : error as String?,
      );
}

const Object _unset = Object();

bool _sameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class DataBootstrapNotifier extends Notifier<DataBootstrapState> {
  Timer? _dateDebounce;
  bool _pendingRetry = false;
  bool _warmupInFlight = false;
  DateTime? _pendingWarmupDate;

  @override
  DataBootstrapState build() {
    ref.listen(connectivityProvider, (prev, next) {
      final wasOffline = prev?.value == false;
      final isOnline = next.value == true;
      if (wasOffline && isOnline && (_pendingRetry || !state.initialComplete)) {
        _pendingRetry = false;
        unawaited(_runInitialBootstrap());
      }
    });

    ref.listen(selectedDateProvider, (prev, next) {
      if (state.initialComplete && !_sameDay(prev, next)) {
        scheduleWarmupForDate(next);
      }
    });

    Future.microtask(_runInitialBootstrap);
    return const DataBootstrapState();
  }

  void scheduleWarmupForDate(DateTime date) {
    _dateDebounce?.cancel();
    _dateDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_warmupAround(date));
    });
  }

  Future<void> _runInitialBootstrap() async {
    if (state.isRunning) return;

    state = state.copyWith(
      isRunning: true,
      phase: HiveService.needsBootstrap() ? 'static' : 'warmup',
      error: null,
    );

    try {
      if (HiveService.needsBootstrap()) {
        await ref.read(syncStatusProvider.notifier).syncEssentialsIfEmpty();
      }

      state = state.copyWith(phase: 'warmup');
      await _warmupAround(ref.read(selectedDateProvider));

      state = state.copyWith(
        isRunning: false,
        initialComplete: true,
        phase: null,
        error: null,
      );
      _pendingRetry = false;

      // Month-ahead prefetch in background after first screen is usable.
      unawaited(_warmupExtended());
    } catch (e, st) {
      if (kDebugMode) debugPrint('[DataBootstrap] initial failed: $e\n$st');
      _pendingRetry = true;
      state = state.copyWith(
        isRunning: false,
        error: e.toString(),
        phase: null,
      );
    }
  }

  /// Warm date window; coalesce rapid date changes — last date wins.
  Future<void> _warmupAround(DateTime date) async {
    if (_warmupInFlight) {
      _pendingWarmupDate = date;
      return;
    }

    var target = date;
    _warmupInFlight = true;
    try {
      while (true) {
        _pendingWarmupDate = null;
        await CacheWarmupService().warmup(baseDate: target);
        ref.read(cacheEpochProvider.notifier).state++;

        final pending = _pendingWarmupDate;
        if (pending == null || _sameDay(pending, target)) break;
        target = pending;
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('[DataBootstrap] warmup failed: $e\n$st');
      _pendingRetry = true;
      rethrow;
    } finally {
      _warmupInFlight = false;
      final pending = _pendingWarmupDate;
      if (pending != null && !_sameDay(pending, target)) {
        unawaited(_warmupAround(pending));
      }
    }
  }

  Future<void> _warmupExtended() async {
    try {
      await CacheWarmupService().warmupExtended(
        baseDate: ref.read(selectedDateProvider),
      );
      ref.read(cacheEpochProvider.notifier).state++;
    } catch (e, st) {
      if (kDebugMode) debugPrint('[DataBootstrap] extended warmup: $e\n$st');
    }
  }
}

final dataBootstrapProvider =
    NotifierProvider<DataBootstrapNotifier, DataBootstrapState>(
  DataBootstrapNotifier.new,
);

/// True while first-load bootstrap or calendar prerequisites are pending.
final homeDataLoadingProvider = Provider<bool>((ref) {
  final bootstrap = ref.watch(dataBootstrapProvider);
  final calendar = ref.watch(calendarReadyProvider);
  if (!bootstrap.initialComplete) {
    return bootstrap.isRunning || calendar.isLoading;
  }
  return calendar.isLoading;
});
