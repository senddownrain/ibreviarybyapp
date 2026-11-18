import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/review/app_review_controller.dart';
import 'package:mybrev_flutter/review/app_review_policy.dart';
import 'package:mybrev_flutter/review/app_review_settings_section.dart';
import 'package:mybrev_flutter/review/app_review_state.dart';
import 'package:mybrev_flutter/review/app_review_storage.dart';
import 'package:mybrev_flutter/review/native_review_adapter.dart';

class _Adapter implements NativeReviewAdapter {
  int requests = 0;
  int stores = 0;
  bool storeOk = true;

  @override
  Future<bool> requestReview() async {
    requests++;
    return true;
  }

  @override
  Future<bool> openStoreListing() async {
    stores++;
    return storeOk;
  }
}

void main() {
  const policy = AppReviewPolicy();
  final t0 = DateTime(2026, 1, 1, 9);
  List<String> days(int n) => [
    for (var i = 0; i < n; i++)
      AppReviewController.dayKey(t0.add(Duration(days: i))),
  ];
  AppReviewState state({
    DateTime? first,
    int usage = 5,
    List<DateTime> attempts = const [],
    bool off = false,
  }) => AppReviewState(
    firstLaunchMs: (first ?? t0).millisecondsSinceEpoch,
    usageDays: days(usage),
    attemptsMs: [for (final a in attempts) a.millisecondsSinceEpoch],
    attemptVersions: [for (var i = 0; i < attempts.length; i++) '0.$i'],
    autoPromptDisabled: off,
  );
  ReviewBlock? eval(AppReviewState s, DateTime now, [String v = '1.0+6']) =>
      policy.evaluate(s, now: now, version: v);

  group('policy', () {
    test('exactly 7 days is eligible, a minute less is not', () {
      expect(eval(state(), t0.add(const Duration(days: 7))), isNull);
      expect(
        eval(
          state(),
          t0.add(const Duration(days: 7)).subtract(const Duration(minutes: 1)),
        ),
        ReviewBlock.tooEarly,
      );
    });

    test('needs 5 distinct days; five launches on one day are one day', () {
      final now = t0.add(const Duration(days: 8));
      expect(eval(state(usage: 4), now), ReviewBlock.tooFewDays);
      final sameDay = AppReviewState(
        firstLaunchMs: t0.millisecondsSinceEpoch,
        usageDays: [
          '2026-01-01',
          '2026-01-01',
          '2026-01-01',
          '2026-01-01',
          '2026-01-01',
        ],
      );
      expect(eval(sameDay, now), ReviewBlock.tooFewDays);
      expect(AppReviewState().withUsageDay('d').withUsageDay('d').usageDays, [
        'd',
      ]);
    });

    test('120-day cooldown, boundary inclusive', () {
      final a = t0.add(const Duration(days: 10));
      final s = state(attempts: [a]);
      expect(
        eval(
          s,
          a.add(const Duration(days: 120)).subtract(const Duration(seconds: 1)),
        ),
        ReviewBlock.cooldown,
      );
      expect(eval(s, a.add(const Duration(days: 120))), isNull);
    });

    test('at most 2 attempts in a rolling 365 days', () {
      final a1 = t0.add(const Duration(days: 10));
      final a2 = a1.add(const Duration(days: 130));
      final s = state(attempts: [a1, a2]);
      expect(
        eval(s, a2.add(const Duration(days: 130)), '9'),
        ReviewBlock.yearlyLimit,
      );
      // First attempt has left the window.
      expect(eval(s, a1.add(const Duration(days: 366)), '9'), isNull);
    });

    test('one attempt per app version', () {
      final a = t0.add(const Duration(days: 10));
      final s = AppReviewState(
        firstLaunchMs: t0.millisecondsSinceEpoch,
        usageDays: days(5),
        attemptsMs: [a.millisecondsSinceEpoch],
        attemptVersions: ['1.0+6'],
      );
      expect(
        eval(s, a.add(const Duration(days: 200)), '1.0+6'),
        ReviewBlock.sameVersion,
      );
      expect(eval(s, a.add(const Duration(days: 200)), '1.1+7'), isNull);
    });

    test('the switch blocks; unknown first launch blocks', () {
      final now = t0.add(const Duration(days: 30));
      expect(eval(state(off: true), now), ReviewBlock.disabledBySetting);
      expect(eval(const AppReviewState(), now), ReviewBlock.firstLaunchUnknown);
    });

    test('clock set back blocks until it catches up', () {
      final a = t0.add(const Duration(days: 40));
      expect(
        eval(state(attempts: [a]), t0.add(const Duration(days: 20))),
        ReviewBlock.clockRolledBack,
      );
      expect(
        eval(state(), t0.subtract(const Duration(days: 1))),
        ReviewBlock.clockRolledBack,
      );
    });
  });

  group('state', () {
    test('round-trips and survives garbage', () {
      final s = state(attempts: [t0]).withUsageDay('2026-02-02');
      final back = AppReviewState.decode(s.encode());
      expect(back.encode(), s.encode());
      expect(AppReviewState.decode('not json').firstLaunchMs, isNull);
      expect(AppReviewState.decode('[1,2]').usageDays, isEmpty);
      expect(AppReviewState.decode(null).autoPromptDisabled, isFalse);
    });
  });

  group('controller', () {
    late MemoryAppReviewStorage storage;
    late _Adapter adapter;
    late DateTime now;
    AppReviewController make() => AppReviewController(
      storage: storage,
      adapter: adapter,
      clock: () => now,
      version: () async => '1.0+6',
    );

    setUp(() {
      storage = MemoryAppReviewStorage();
      adapter = _Adapter();
      now = t0;
    });

    Future<AppReviewController> aged() async {
      final c = make();
      for (var d = 0; d < 8; d++) {
        now = t0.add(Duration(days: d));
        await c.recordUse();
      }
      return c;
    }

    test('not eligible on first run; eligible after 8 days of use', () async {
      final c = make();
      await c.recordUse();
      expect(await c.eligibility(), ReviewBlock.tooEarly);
      final aged0 = await aged();
      expect(await aged0.eligibility(), isNull);
    });

    test(
      'asks once; the double trigger and the same version do not repeat',
      () async {
        final c = await aged();
        final results = await Future.wait([
          c.maybeRequest(calm: () => true),
          c.maybeRequest(calm: () => true),
        ]);
        expect(results.where((r) => r).length, 1);
        expect(adapter.requests, 1);
        expect(await c.maybeRequest(calm: () => true), isFalse);
        expect(adapter.requests, 1);
      },
    );

    test(
      'a busy screen at fire time means no call and no attempt stored',
      () async {
        final c = await aged();
        expect(await c.maybeRequest(calm: () => false), isFalse);
        expect(adapter.requests, 0);
        expect(c.state.attemptsMs, isEmpty);
      },
    );

    test(
      'the switch stops automatic requests but not the store link',
      () async {
        final c = await aged();
        await c.setAutoPromptDisabled(true);
        expect(await c.maybeRequest(calm: () => true), isFalse);
        expect(adapter.requests, 0);
        expect(await c.openStore(), isTrue);
        expect(adapter.stores, 1);
        expect(
          adapter.requests,
          0,
          reason: 'manual link never calls requestReview',
        );
      },
    );

    test('state survives a restart (new controller, same storage)', () async {
      final c = await aged();
      await c.maybeRequest(calm: () => true);
      await c.setAutoPromptDisabled(true);
      final again = make();
      await again.load();
      expect(again.state.attemptsMs, hasLength(1));
      expect(again.autoPromptDisabled, isTrue);
      expect(again.state.firstLaunchMs, t0.millisecondsSinceEpoch);
    });
  });

  testWidgets('settings: store link, error snackbar, switch', (tester) async {
    final storage = MemoryAppReviewStorage();
    final adapter = _Adapter()..storeOk = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appReviewStorageProvider.overrideWithValue(storage),
          nativeReviewAdapterProvider.overrideWithValue(adapter),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AppReviewSettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-rate-app')));
    await tester.pumpAndSettle();
    expect(adapter.stores, 1);
    expect(adapter.requests, 0);
    expect(find.byKey(const Key('settings-rate-app-error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-review-optout')));
    await tester.pumpAndSettle();
    expect(AppReviewState.decode(storage.value).autoPromptDisabled, isTrue);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('settings-review-optout')),
          )
          .value,
      isTrue,
    );
  });
}
