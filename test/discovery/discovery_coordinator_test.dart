import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';

import 'support.dart';

void main() {
  late FakeDiscoveryClock clock;
  late MemoryDiscoveryStorage storage;
  late RecordingPresenter presenter;
  late DiscoveryRepository repo;
  late DiscoveryCoordinator coordinator;

  Future<void> boot() async {
    repo = await openRepo(storage, clock);
    coordinator = coordinatorFor(repo, clock, presenter);
  }

  setUp(() async {
    clock = FakeDiscoveryClock(t0);
    storage = MemoryDiscoveryStorage();
    presenter = RecordingPresenter();
    await boot();
  });

  test(
    'eligible is not shown: a display counts only after it mounts',
    () async {
      presenter.mounts = false;
      final visit = coordinator.beginVisit('readings');
      final result = await coordinator.request(readings(visit: visit));
      expect(result.label, 'readings.day_variants');
      expect(result.presented, isFalse);
      expect(repo.state.record('readings.day_variants').seenCount, 0);
      expect(repo.state.autoShownAtMs, isEmpty);

      presenter.mounts = true;
      final retry = await coordinator.request(readings(visit: visit));
      expect(retry.presented, isTrue);
      expect(repo.state.record('readings.day_variants').seenCount, 1);
      expect(repo.state.autoShownAtMs, [t0.millisecondsSinceEpoch]);
    },
  );

  test('one hint per visit, the second request is a no-op', () async {
    final visit = coordinator.beginVisit('readings');
    expect((await coordinator.request(readings(visit: visit))).presented, true);
    final again = await coordinator.request(readings(visit: visit));
    expect(again.presented, isFalse);
    expect(presenter.shown, ['readings.day_variants']);
  });

  test('concurrent requests present exactly one hint', () async {
    final gate = Completer<bool>();
    presenter.onPresent = (hint) {
      presenter.shown.add(hint.id);
      return gate.future;
    };
    final visit = coordinator.beginVisit('readings');
    final first = coordinator.request(readings(visit: visit));
    final second = coordinator.request(readings(visit: visit));
    gate.complete(true);
    final results = await Future.wait([first, second]);
    expect(results.where((r) => r.presented), hasLength(1));
    expect(presenter.shown, hasLength(1));
  });

  test('leaving the screen while the overlay builds shows nothing', () async {
    final gate = Completer<bool>();
    presenter.onPresent = (_) => gate.future;
    final visit = coordinator.beginVisit('readings');
    final pending = coordinator.request(readings(visit: visit));
    coordinator.endVisit(visit); // the person navigated away
    gate.complete(true);
    expect((await pending).presented, isFalse);
    expect(presenter.dismissals, greaterThan(0));
    expect(repo.state.record('readings.day_variants').seenCount, 0);
  });

  test('a stale event from an older visit cannot show a hint', () async {
    final old = coordinator.beginVisit('readings');
    coordinator.beginVisit('bible');
    final result = await coordinator.request(readings(visit: old));
    expect(result.presented, isFalse);
    expect(result.decision.reasons['*'], SuppressionReason.staleVisit);
    expect(presenter.shown, isEmpty);
  });

  test('a new visit removes the hint of the previous screen', () async {
    final visit = coordinator.beginVisit('readings');
    await coordinator.request(readings(visit: visit));
    expect(coordinator.presented, isNotNull);
    coordinator.beginVisit('hours');
    expect(coordinator.presented, isNull);
    expect(presenter.dismissals, 1);
  });

  test('success closes only its own hint', () async {
    final visit = coordinator.beginVisit('readings');
    await coordinator.request(readings(visit: visit));
    await coordinator.respond('readings.day_variants', HintResponse.acted);
    expect(repo.state.record('readings.day_variants').completed, isTrue);
    expect(repo.state.record('discover.bible').completed, isFalse);
    expect(coordinator.presented, isNull);
  });

  test('«Не паказваць» survives a fake restart and a version bump', () async {
    final visit = coordinator.beginVisit('readings');
    await coordinator.request(readings(visit: visit));
    await coordinator.respond('readings.day_variants', HintResponse.never);
    await repo.flush();

    await boot(); // restart over the same storage
    expect(repo.sessionIndex, 2);
    clock.advance(const Duration(days: 30));
    final next = coordinator.beginVisit('readings');
    final result = await coordinator.request(readings(visit: next));
    expect(result.label, 'none');
    expect(
      result.decision.reasons['readings.day_variants'],
      SuppressionReason.dismissed,
    );
  });

  test('global disable survives a restart', () async {
    await repo.setHintsEnabled(false);
    await repo.flush();
    await boot();
    final visit = coordinator.beginVisit('readings');
    expect((await coordinator.request(readings(visit: visit))).label, 'none');
    expect(repo.state.hintsEnabled, isFalse);
  });

  test(
    '«Пазней» hides it for the visit, returns on the next, max twice',
    () async {
      await boot(); // session 2: the first-session budget does not apply
      var visit = coordinator.beginVisit('readings');
      await coordinator.request(readings(visit: visit));
      await coordinator.respond('readings.day_variants', HintResponse.later);
      expect(repo.state.record('readings.day_variants').snoozeCount, 1);

      expect(coordinator.peek(readings(visit: visit)).label, 'none');
      clock.advance(const Duration(minutes: 6));
      visit = coordinator.beginVisit('readings');
      expect(
        (await coordinator.request(readings(visit: visit))).presented,
        true,
      );
      await coordinator.respond('readings.day_variants', HintResponse.later);
      expect(repo.state.record('readings.day_variants').snoozeCount, 2);

      clock.advance(const Duration(minutes: 6));
      visit = coordinator.beginVisit('readings');
      expect(
        (await coordinator.request(readings(visit: visit))).presented,
        true,
      );
      // A third «Пазней» is refused: the count stays at two.
      await coordinator.respond('readings.day_variants', HintResponse.later);
      expect(repo.state.record('readings.day_variants').snoozeCount, 2);
    },
  );

  test('a manual tour does not spend the automatic quota', () async {
    await repo.setTourStatus(TourStatus.inProgress);
    final visit = coordinator.beginVisit('readings');
    expect((await coordinator.request(readings(visit: visit))).label, 'none');
    await repo.setTourStatus(TourStatus.completed);
    expect(repo.state.autoShownAtMs, isEmpty);
    expect(repo.sessionAutoShown, 0);
    expect((await coordinator.request(readings(visit: visit))).presented, true);
  });

  test('first session stops at two automatic hints', () async {
    final catalog = HintCatalog([
      testHint('t.a', HintPriority.p0),
      testHint('t.b', HintPriority.p0),
      testHint('t.c', HintPriority.p0),
    ]);
    coordinator = coordinatorFor(repo, clock, presenter, catalog: catalog);
    final shown = <String>[];
    for (var i = 0; i < 4; i++) {
      final visit = coordinator.beginVisit('readings');
      final result = await coordinator.request(
        testContext(catalog.all, visit: visit),
      );
      if (result.presented) {
        shown.add(result.label);
        await coordinator.respond(result.label, HintResponse.acknowledged);
      }
      clock.advance(const Duration(minutes: 6));
    }
    expect(shown, ['t.a', 't.b']);
  });

  test('QA reset clears history only, not the global switch', () async {
    await repo.setHintsEnabled(false);
    await repo.dismiss('discover.bible');
    await repo.resetHistory();
    expect(repo.state.record('discover.bible').dismissed, isFalse);
    expect(repo.state.hintsEnabled, isFalse);
  });
}
