import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/discovery/discovery_context.dart';
import 'package:mybrev_flutter/discovery/discovery_coordinator.dart';
import 'package:mybrev_flutter/discovery/discovery_providers.dart';
import 'package:mybrev_flutter/discovery/discovery_qa_mode.dart';
import 'package:mybrev_flutter/discovery/ui/inline_hint_presenter.dart';
import 'package:mybrev_flutter/discovery/ui/integrated_presenter.dart';

/// How long a screen must stay calm before the engine is asked.
final discoverySettleDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 1500),
);

/// Things the person did in this app session; memory only, never stored.
class DiscoverySessionSignals {
  /// «Папярэдні / Наступны дзень» taps.
  int dayArrowTaps = 0;

  /// The date control or the calendar was opened on purpose.
  bool dateControlUsed = false;

  /// Calendar sheets opened (Hours + Readings).
  int calendarOpens = 0;
}

final discoverySessionSignalsProvider = Provider<DiscoverySessionSignals>(
  (ref) => DiscoverySessionSignals(),
);

/// One screen visit of one screen: begins the engine visit, waits until the
/// screen has been calm for the settle delay, then asks for a hint. Inert
/// (no Hive, no timers) unless the real presenter is installed.
class DiscoveryVisit {
  DiscoveryVisit(this._ref, this.screenId);

  final WidgetRef _ref;
  final String screenId;

  DiscoveryCoordinator? _coordinator;
  int? _visitId;
  Timer? _settle;
  bool _disposed = false;
  int _generation = 0;

  DiscoveryContext? Function(int visitId)? _lastSnapshot;
  InlineHintPresenter? _presenter;

  bool get enabled => inlineOf(_ref.read(hintPresenterProvider)) != null;

  /// Of [wanted], the anchors whose slot is really mounted right now.
  Set<String> mounted(Set<String> wanted) {
    final presenter = inlineOf(_ref.read(hintPresenterProvider));
    if (presenter == null) return const {};
    return wanted.intersection(presenter.mountedAnchors);
  }

  void _slotMounted() {
    final snapshot = _lastSnapshot;
    if (_disposed || snapshot == null) return;
    if (_coordinator?.presented != null) return;
    schedule(snapshot);
  }

  /// A new visit (screen opened, or the date/diocese changed). Whatever was
  /// shown for the previous one is removed.
  Future<void> begin() async {
    if (!enabled || _disposed) return;
    if (_presenter == null) {
      _presenter = inlineOf(_ref.read(hintPresenterProvider))!;
      _presenter!.slotMounted.addListener(_slotMounted);
    }
    final generation = ++_generation;
    _settle?.cancel();
    final DiscoveryCoordinator coordinator;
    final known = _coordinator;
    if (known != null) {
      coordinator = known;
    } else {
      coordinator = await _ref.read(discoveryCoordinatorProvider.future);
      _coordinator = coordinator;
    }
    if (_disposed || generation != _generation) return;
    _visitId = coordinator.beginVisit(screenId);
  }

  /// Ask for a hint after the settle delay. [snapshot] is evaluated when the
  /// delay ends, so it always reflects the screen as it is then; returning
  /// null means "not calm / not ready".
  void schedule(DiscoveryContext? Function(int visitId) snapshot) {
    if (!enabled || _disposed) return;
    _lastSnapshot = snapshot;
    _settle?.cancel();
    _settle = Timer(_ref.read(discoverySettleDelayProvider), () async {
      final coordinator = _coordinator;
      var visit = _visitId;
      if (_disposed || coordinator == null || visit == null) return;
      // Another surface (a calendar sheet) may have taken the visit over.
      if (!coordinator.isCurrentVisit(visit, screenId)) {
        visit = _visitId = coordinator.beginVisit(screenId);
      }
      final context = snapshot(visit);
      if (context == null) return;
      final result = await coordinator.request(context);
      if (discoveryQaActive) {
        debugPrint(
          '[DiscoveryQA] $screenId -> ${result.label}'
          '${result.presented ? ' (shown)' : ''}'
          ' ${result.decision.reasons.map((k, v) => MapEntry(k, v.name))}',
        );
      }
    });
  }

  /// The person is busy again (scroll, sheet): cancel a pending request.
  void interrupt() => _settle?.cancel();

  /// The person used the anchor control themselves.
  Future<void> acted(String hintId) async {
    final coordinator = _coordinator;
    if (coordinator == null || coordinator.presented?.id != hintId) return;
    await coordinator.respond(hintId, HintResponse.acted);
  }

  /// The person opened the panel the shown hint points at.
  Future<void> actedOnPresented() async {
    final shown = _coordinator?.presented;
    if (shown != null) await acted(shown.id);
  }

  void end() {
    _disposed = true;
    _presenter?.slotMounted.removeListener(_slotMounted);
    _settle?.cancel();
    final visit = _visitId;
    if (visit != null) _coordinator?.endVisit(visit);
  }
}
