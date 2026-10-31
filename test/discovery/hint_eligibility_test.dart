import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';
import 'package:mybrev_flutter/discovery/hints/p0_hints.dart';

import 'support.dart';

HintDecision decide(
  DiscoveryContext context, {
  DiscoveryState state = DiscoveryState.empty,
  DateTime? now,
  int session = 1,
  int sessionShown = 0,
  bool visitShown = false,
  bool busy = false,
  Iterable<HintDefinition>? catalog,
}) => const HintPolicy().decide(
  catalog: catalog ?? HintCatalog.standard().all,
  context: context,
  state: state,
  now: now ?? t0,
  sessionIndex: session,
  sessionAutoShown: sessionShown,
  autoShownThisVisit: visitShown,
  presenterBusy: busy,
);

DiscoveryState shownAt(String id, List<DateTime> times, {int version = 1}) {
  var state = DiscoveryState.empty;
  for (final time in times) {
    state = state.shown(id, version: version, now: time, automatic: true);
  }
  return state;
}

void main() {
  group('data and anchors', () {
    test('2+ day variants with a real anchor show readings.day_variants', () {
      expect(decide(readings()).label, 'readings.day_variants');
    });

    test('a single variant is not an alternative: none', () {
      expect(decide(readings(variants: 1)).label, 'none');
    });

    test('A/B/C/D are different facts and are never summed', () {
      // Five allowed alternatives (B) must not satisfy day variants (A),
      // and cycle availability (C) must not satisfy B.
      final onlyB = readings(
        variants: 0,
        anchors: {variantsAnchor, 'readings.alternatives.button'},
        extra: {kFactAllowedAlternativeCount: 5},
      );
      expect(decide(onlyB).label, 'readings.allowed_alternatives');
      final onlyC = readings(
        variants: 0,
        anchors: {'readings.cycle.button'},
        extra: {kFactOtherCycleLoaded: true},
      );
      expect(decide(onlyC).label, 'readings.other_year');
      final dayVariantsOnly = readings(
        variants: 2,
        extra: {kFactAllowedAlternativeCount: 0},
      );
      expect(decide(dayVariantsOnly).label, 'readings.day_variants');
    });

    test('loading, error and unknown data are a soft no-op', () {
      for (final status in [
        DiscoveryDataStatus.loading,
        DiscoveryDataStatus.error,
        DiscoveryDataStatus.unknown,
      ]) {
        final decision = decide(readings(status: status));
        expect(decision.label, 'none', reason: '$status');
        expect(
          decision.reasons['readings.day_variants'],
          SuppressionReason.dataNotReady,
        );
      }
    });

    test('an unknown source (empty screen id) is a no-op', () {
      final decision = decide(readings(screen: ''));
      expect(decision.label, 'none');
      expect(
        decision.reasons['readings.day_variants'],
        SuppressionReason.unknownSource,
      );
    });

    test('a missing fact is unknown, not zero', () {
      final decision = decide(readings(variants: null));
      expect(decision.label, 'none');
      expect(
        decision.reasons['readings.day_variants'],
        SuppressionReason.factMissing,
      );
    });

    test('a missing anchor is a no-op', () {
      final decision = decide(readings(anchors: const {}));
      expect(decision.label, 'none');
      expect(
        decision.reasons['readings.day_variants'],
        SuppressionReason.anchorMissing,
      );
    });

    test('a hint of another screen never shows', () {
      expect(decide(readings(screen: 'bible')).label, 'none');
    });

    test('a deferred hint is never eligible', () {
      const deferred = HintDefinition(
        id: 'x.deferred',
        version: 1,
        priority: HintPriority.p0,
        screenId: 'readings',
        anchorId: 'a',
        copyBe: 'c',
        status: HintStatus.deferred,
      );
      final decision = decide(readings(anchors: {'a'}), catalog: [deferred]);
      expect(decision.label, 'none');
      expect(decision.reasons['x.deferred'], SuppressionReason.deferred);
    });
  });

  group('priority and one at a time', () {
    final p0 = testHint('t.p0', HintPriority.p0);
    final p1 = testHint('t.p1', HintPriority.p1);
    final p2 = testHint('t.p2', HintPriority.p2);

    test('P0 beats P1 beats P2 whatever the catalog order', () {
      final all = [p2, p1, p0];
      expect(decide(testContext(all), catalog: all).label, 't.p0');
      expect(decide(testContext([p1, p2]), catalog: [p2, p1]).label, 't.p1');
    });

    test('losers are reported as lowerPriority, only one wins', () {
      final decision = decide(testContext([p0, p1, p2]), catalog: [p1, p0, p2]);
      expect(decision.hint!.id, 't.p0');
      expect(decision.reasons['t.p1'], SuppressionReason.lowerPriority);
      expect(decision.reasons['t.p2'], SuppressionReason.lowerPriority);
    });

    test('a busy presenter blocks a second hint', () {
      expect(decide(readings(), busy: true).label, 'none');
    });
  });

  group('screen situation', () {
    test('scroll, reading, drag, keyboard, modal, transition each block', () {
      const blockers = [
        DiscoveryUiState(scrolling: true),
        DiscoveryUiState(activeReading: true),
        DiscoveryUiState(dragging: true),
        DiscoveryUiState(keyboardVisible: true),
        DiscoveryUiState(modalOpen: true),
        DiscoveryUiState(transitioning: true),
      ];
      for (final ui in blockers) {
        final decision = decide(readings(ui: ui));
        expect(decision.label, 'none');
        expect(
          decision.reasons['readings.day_variants'],
          SuppressionReason.uiBusy,
        );
      }
      expect(decide(readings(ui: DiscoveryUiState.calm)).label, isNot('none'));
    });
  });

  group('quotas and cooldown', () {
    test('one automatic hint per screen visit', () {
      expect(decide(readings(), visitShown: true).label, 'none');
    });

    test('first session allows two, then stops', () {
      expect(decide(readings(), sessionShown: 1).label, isNot('none'));
      final blocked = decide(readings(), sessionShown: 2);
      expect(
        blocked.reasons['readings.day_variants'],
        SuppressionReason.sessionQuota,
      );
    });

    test('later sessions: three per rolling 7 days', () {
      final stamps = [
        t0.subtract(const Duration(days: 6)),
        t0.subtract(const Duration(days: 3)),
        t0.subtract(const Duration(hours: 1)),
      ];
      final state = shownAt('other.hint', stamps);
      final blocked = decide(readings(), state: state, session: 2);
      expect(
        blocked.reasons['readings.day_variants'],
        SuppressionReason.rollingQuota,
      );
      // Once the oldest leaves the 168-hour window there is room again.
      final later = decide(
        readings(),
        state: state,
        session: 2,
        now: t0.add(const Duration(days: 1)),
      );
      expect(later.label, 'readings.day_variants');
    });

    test('the window is 168 absolute hours, not calendar days (DST-proof)', () {
      final edge = t0.subtract(const Duration(days: 7));
      final stamps = [
        edge.add(const Duration(minutes: 1)),
        edge.add(const Duration(minutes: 2)),
        edge.add(const Duration(minutes: 3)),
      ];
      final state = shownAt('o', stamps);
      expect(decide(readings(), state: state, session: 2).label, 'none');
      final aged = shownAt('o', [
        edge.subtract(const Duration(minutes: 3)),
        edge.subtract(const Duration(minutes: 2)),
        edge.subtract(const Duration(minutes: 1)),
      ]);
      expect(decide(readings(), state: aged, session: 2).label, isNot('none'));
      // The same instant given as local time gives the same answer.
      final local = t0.toLocal();
      expect(
        decide(readings(), state: state, session: 2, now: local).label,
        'none',
      );
    });

    test('5 minutes between automatic hints', () {
      final state = shownAt('o', [t0]);
      final soon = decide(
        readings(),
        state: state,
        session: 2,
        now: t0.add(const Duration(minutes: 4, seconds: 59)),
      );
      expect(soon.reasons['readings.day_variants'], SuppressionReason.cooldown);
      final ok = decide(
        readings(),
        state: state,
        session: 2,
        now: t0.add(const Duration(minutes: 5)),
      );
      expect(ok.label, 'readings.day_variants');
    });

    test('P2 has a stronger cooldown than P0/P1', () {
      final p2 = testHint('t.p2', HintPriority.p2);
      final state = shownAt('o', [t0]);
      final later = t0.add(const Duration(hours: 2));
      expect(
        decide(
          testContext([p2]),
          catalog: [p2],
          state: state,
          session: 2,
          now: later,
        ).label,
        'none',
      );
      expect(
        decide(
          testContext([p2]),
          catalog: [p2],
          state: state,
          session: 2,
          now: t0.add(const Duration(hours: 24)),
        ).label,
        't.p2',
      );
    });

    test('clock moved back keeps the cooldown (no spam)', () {
      final state = shownAt('o', [t0]);
      final decision = decide(
        readings(),
        state: state,
        session: 2,
        now: t0.subtract(const Duration(hours: 3)),
      );
      expect(
        decision.reasons['readings.day_variants'],
        SuppressionReason.cooldown,
      );
    });

    test('a stamp far in the future is clamped, not a months-long lock', () {
      final state = shownAt('o', [t0.add(const Duration(days: 400))]);
      final clamped = state.clampFuture(t0, skew: const Duration(days: 1));
      expect(clamped.lastAutoShownAtMs, t0.millisecondsSinceEpoch);
      final decision = decide(
        readings(),
        state: clamped,
        session: 2,
        now: t0.add(const Duration(minutes: 6)),
      );
      expect(decision.label, 'readings.day_variants');
    });
  });

  group('switches and responses', () {
    test('global disable silences everything', () {
      final off = DiscoveryState.empty.copyWith(hintsEnabled: false);
      final decision = decide(readings(), state: off);
      expect(decision.label, 'none');
      expect(
        decision.reasons['readings.day_variants'],
        SuppressionReason.hintsDisabled,
      );
    });

    test('a running tour blocks automatic hints', () {
      final tour = DiscoveryState.empty.copyWith(
        tourStatus: TourStatus.inProgress,
      );
      expect(decide(readings(), state: tour).label, 'none');
    });

    test('dismissed and completed hints stay silent', () {
      final dismissed = DiscoveryState.empty.dismissedHint(
        'readings.day_variants',
      );
      expect(decide(readings(), state: dismissed).label, 'none');
      final done = DiscoveryState.empty.completedHint('readings.day_variants');
      expect(decide(readings(), state: done).label, 'none');
    });

    test('a new hintVersion never revives a dismissal', () {
      const v2 = HintDefinition(
        id: 'x',
        version: 2,
        priority: HintPriority.p0,
        screenId: 'readings',
        anchorId: 'a',
        copyBe: 'c',
      );
      final context = readings(anchors: {'a'});
      final dismissed = DiscoveryState.empty
          .shown('x', version: 1, now: t0, automatic: true)
          .dismissedHint('x');
      expect(
        decide(context, state: dismissed, catalog: [v2], session: 2).label,
        'none',
      );
    });

    test('maxShows caps repeats, a new version restarts the count', () {
      final v1 = testHint('t.a', HintPriority.p0, maxShows: 2);
      final v2 = testHint('t.a', HintPriority.p0, version: 2, maxShows: 2);
      final state = shownAt('t.a', [
        t0.subtract(const Duration(days: 20)),
        t0.subtract(const Duration(days: 19)),
      ]);
      final context = testContext([v1]);
      expect(
        decide(context, state: state, session: 2, catalog: [v1]).label,
        'none',
      );
      expect(
        decide(context, state: state, session: 2, catalog: [v2]).label,
        't.a',
      );
    });

    test('«Пазней» is limited to two repeats and needs a new visit', () {
      const policy = HintPolicy();
      final hint = HintCatalog.standard().byId('readings.day_variants')!;
      var state = DiscoveryState.empty;
      expect(policy.canSnooze(hint, state.record(hint.id)), isTrue);
      state = state.snoozedHint(hint.id, session: 2, visit: 7);
      expect(policy.canSnooze(hint, state.record(hint.id)), isTrue);
      // Same visit: still hidden. New visit: back.
      expect(
        decide(readings(visit: 7), state: state, session: 2).reasons[hint.id],
        SuppressionReason.snoozedThisVisit,
      );
      expect(
        decide(readings(visit: 8), state: state, session: 2).label,
        hint.id,
      );
      state = state.snoozedHint(hint.id, session: 2, visit: 8);
      expect(policy.canSnooze(hint, state.record(hint.id)), isFalse);
    });
  });
}
