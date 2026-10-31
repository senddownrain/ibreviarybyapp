import 'package:flutter/foundation.dart' show immutable;
import 'package:mybrev_flutter/discovery/discovery_context.dart';
import 'package:mybrev_flutter/discovery/discovery_state.dart';
import 'package:mybrev_flutter/discovery/hint_definition.dart';

/// Tunable policy numbers; defaults are the contract in `03-state-contract.md`.
@immutable
class DiscoveryPolicyConfig {
  const DiscoveryPolicyConfig({
    this.minInterval = const Duration(minutes: 5),
    this.p2MinInterval = const Duration(hours: 24),
    this.firstSessionLimit = 2,
    this.rollingLimit = 3,
    this.rollingWindow = const Duration(days: 7),
    this.maxSnoozes = 2,
    this.futureSkew = const Duration(days: 1),
  });

  /// Minimum gap between two automatic hints.
  final Duration minInterval;

  /// Stronger gap for P2 hints.
  final Duration p2MinInterval;
  final int firstSessionLimit;
  final int rollingLimit;
  final Duration rollingWindow;

  /// «Пазней» repeats allowed per hint.
  final int maxSnoozes;

  /// How far ahead a stored stamp may be before it counts as corrupt.
  final Duration futureSkew;
}

/// Why a hint did not qualify. For logs, tests and the QA harness only.
enum SuppressionReason {
  hintsDisabled,
  tourRunning,
  deferred,
  unknownSource,
  wrongScreen,
  staleVisit,
  dataNotReady,
  factMissing,
  conditionFalse,
  anchorMissing,
  dismissed,
  completed,
  maxShows,
  snoozedThisVisit,
  uiBusy,
  visitQuota,
  sessionQuota,
  rollingQuota,
  cooldown,
  presenterBusy,
  lowerPriority,
}

@immutable
class HintDecision {
  const HintDecision.show(HintDefinition this.hint, this.reasons);

  const HintDecision.none(this.reasons) : hint = null;

  /// The hint to present, or null for `none`.
  final HintDefinition? hint;

  /// Reason per catalog ID that did not win.
  final Map<String, SuppressionReason> reasons;

  bool get isNone => hint == null;

  /// `hint_id` or the literal `none`.
  String get label => hint?.id ?? 'none';
}

/// Pure policy: the same inputs always give the same answer; time arrives as
/// an argument and nothing is read from the platform.
class HintPolicy {
  const HintPolicy([this.config = const DiscoveryPolicyConfig()]);

  final DiscoveryPolicyConfig config;

  /// Whether the hint offers «Пазней» now.
  bool canSnooze(HintDefinition hint, HintRecord record) =>
      hint.allowSnooze && record.snoozeCount < config.maxSnoozes;

  /// Rules that depend only on the screen state and the hint itself.
  SuppressionReason? hintReason({
    required HintDefinition hint,
    required DiscoveryContext context,
    required DiscoveryState state,
    required int sessionIndex,
  }) {
    if (hint.status == HintStatus.deferred) return SuppressionReason.deferred;
    if (context.screenId.isEmpty) return SuppressionReason.unknownSource;
    if (context.screenId != hint.screenId) return SuppressionReason.wrongScreen;
    if (context.status != DiscoveryDataStatus.ready) {
      return SuppressionReason.dataNotReady;
    }
    for (final requirement in hint.requirements) {
      if (!context.facts.containsKey(requirement.key)) {
        return SuppressionReason.factMissing;
      }
      if (!requirement.test(context.facts[requirement.key])) {
        return SuppressionReason.conditionFalse;
      }
    }
    if (!context.anchors.contains(hint.anchorId)) {
      return SuppressionReason.anchorMissing;
    }
    final record = state.record(hint.id);
    if (record.dismissed) return SuppressionReason.dismissed;
    if (record.completed) return SuppressionReason.completed;
    // A new copy version restarts counting, but never revives a dismissal.
    final fresh = hint.version > record.hintVersion && record.seenCount > 0;
    if (!fresh && record.seenCount >= hint.maxShows) {
      return SuppressionReason.maxShows;
    }
    if (record.snoozedSession == sessionIndex &&
        record.snoozedVisit == context.visitId) {
      return SuppressionReason.snoozedThisVisit;
    }
    return null;
  }

  /// Rules shared by every hint: switches, calm UI, quotas, cooldown.
  SuppressionReason? globalReason({
    required DiscoveryContext context,
    required DiscoveryState state,
    required DateTime now,
    required int sessionIndex,
    required int sessionAutoShown,
    required bool autoShownThisVisit,
    required bool presenterBusy,
    required HintPriority priority,
  }) {
    if (!state.hintsEnabled) return SuppressionReason.hintsDisabled;
    if (state.tourStatus == TourStatus.inProgress) {
      return SuppressionReason.tourRunning;
    }
    if (!context.ui.isCalm) return SuppressionReason.uiBusy;
    if (presenterBusy) return SuppressionReason.presenterBusy;
    if (autoShownThisVisit) return SuppressionReason.visitQuota;
    if (sessionIndex <= 1 && sessionAutoShown >= config.firstSessionLimit) {
      return SuppressionReason.sessionQuota;
    }
    final nowMs = now.millisecondsSinceEpoch;
    if (sessionIndex > 1) {
      final cutoff = nowMs - config.rollingWindow.inMilliseconds;
      final inWindow = state.autoShownAtMs.where((s) => s > cutoff).length;
      if (inWindow >= config.rollingLimit) {
        return SuppressionReason.rollingQuota;
      }
    }
    final last = state.lastAutoShownAtMs;
    if (last != null) {
      final gap = priority == HintPriority.p2
          ? config.p2MinInterval
          : config.minInterval;
      // A negative difference (clock moved back) is also inside the cooldown.
      if (nowMs - last < gap.inMilliseconds) {
        return SuppressionReason.cooldown;
      }
    }
    return null;
  }

  /// Picks the single hint to show, or none. Highest priority wins; ties go
  /// to the catalog order.
  HintDecision decide({
    required Iterable<HintDefinition> catalog,
    required DiscoveryContext context,
    required DiscoveryState state,
    required DateTime now,
    int sessionIndex = 1,
    int sessionAutoShown = 0,
    bool autoShownThisVisit = false,
    bool presenterBusy = false,
  }) {
    final reasons = <String, SuppressionReason>{};
    HintDefinition? winner;
    for (final hint in catalog) {
      final reason =
          hintReason(
            hint: hint,
            context: context,
            state: state,
            sessionIndex: sessionIndex,
          ) ??
          globalReason(
            context: context,
            state: state,
            now: now,
            sessionIndex: sessionIndex,
            sessionAutoShown: sessionAutoShown,
            autoShownThisVisit: autoShownThisVisit,
            presenterBusy: presenterBusy,
            priority: hint.priority,
          );
      if (reason != null) {
        reasons[hint.id] = reason;
      } else if (winner == null ||
          hint.priority.index < winner.priority.index) {
        if (winner != null) {
          reasons[winner.id] = SuppressionReason.lowerPriority;
        }
        winner = hint;
      } else {
        reasons[hint.id] = SuppressionReason.lowerPriority;
      }
    }
    return winner == null
        ? HintDecision.none(reasons)
        : HintDecision.show(winner, reasons);
  }
}
