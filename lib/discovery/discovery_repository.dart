import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/discovery/discovery_clock.dart';
import 'package:mybrev_flutter/discovery/discovery_state.dart';
import 'package:mybrev_flutter/discovery/discovery_storage.dart';
import 'package:mybrev_flutter/discovery/hint_definition.dart';
import 'package:mybrev_flutter/discovery/hint_eligibility.dart';

/// Holds the persisted state and the counters of the running session.
/// Writes are serialized; a failing storage never throws into the UI.
class DiscoveryRepository {
  DiscoveryRepository._(
    this._storage,
    this._clock,
    this._state,
    this.sessionIndex,
  );

  /// Loads the state and starts a new session (increments `sessionCount`).
  static Future<DiscoveryRepository> open({
    required DiscoveryStorage storage,
    required DiscoveryClock clock,
    DiscoveryPolicyConfig policy = const DiscoveryPolicyConfig(),
  }) async {
    var state = DiscoveryState.empty;
    try {
      state = DiscoveryState.decode(await storage.read());
    } catch (_) {
      // Unreadable storage: run on defaults for this session.
    }
    state = state.clampFuture(clock.now(), skew: policy.futureSkew);
    if (!state.fromNewerSchema) {
      state = state.copyWith(sessionCount: state.sessionCount + 1);
    }
    final repository = DiscoveryRepository._(
      storage,
      clock,
      state,
      state.fromNewerSchema ? 1 : state.sessionCount,
    );
    await repository._persist();
    return repository;
  }

  final DiscoveryStorage _storage;
  final DiscoveryClock _clock;
  final _changes = StreamController<DiscoveryState>.broadcast();
  Future<void> _writes = Future.value();
  DiscoveryState _state;

  /// 1-based number of this app session on the profile.
  final int sessionIndex;

  /// Automatic hints shown during this session (memory only).
  int sessionAutoShown = 0;

  DiscoveryState get state => _state;

  Stream<DiscoveryState> get changes => _changes.stream;

  Future<void> _persist() {
    if (_state.fromNewerSchema) return Future.value();
    final payload = _state.encode();
    return _writes = _writes.then((_) async {
      try {
        await _storage.write(payload);
      } catch (error) {
        debugPrint('[Discovery] state not saved: $error');
      }
    });
  }

  Future<void> _update(DiscoveryState Function(DiscoveryState) change) {
    _state = change(_state);
    _changes.add(_state);
    return _persist();
  }

  Future<void> recordShown(HintDefinition hint, {required bool automatic}) {
    if (automatic) sessionAutoShown++;
    return _update(
      (s) => s.shown(
        hint.id,
        version: hint.version,
        now: _clock.now(),
        automatic: automatic,
      ),
    );
  }

  /// The person entered a section; counts toward «ещё не знаком».
  Future<void> recordVisit(String key) => _update((s) => s.visited(key));

  Future<void> dismiss(String id) => _update((s) => s.dismissedHint(id));

  Future<void> complete(String id) => _update((s) => s.completedHint(id));

  Future<void> snooze(String id, {required int visitId}) =>
      _update((s) => s.snoozedHint(id, session: sessionIndex, visit: visitId));

  Future<void> setHintsEnabled(bool enabled) =>
      _update((s) => s.copyWith(hintsEnabled: enabled));

  Future<void> setTourStatus(TourStatus status) =>
      _update((s) => s.copyWith(tourStatus: status));

  /// Clears hint history only (test profile / explicit user reset).
  Future<void> resetHistory() {
    sessionAutoShown = 0;
    return _update((s) => s.historyReset());
  }

  /// Completes once every queued write has finished.
  Future<void> flush() => _writes;

  Future<void> dispose() async {
    await _writes;
    await _changes.close();
  }
}
