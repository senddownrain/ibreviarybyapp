import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';
import 'package:mybrev_flutter/discovery/tour/discovery_settings_section.dart';
import 'package:mybrev_flutter/discovery/tour/tour_host.dart';
import 'package:mybrev_flutter/discovery/tour/tour_policy.dart';
import 'package:mybrev_flutter/discovery/tour/tour_steps.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';

import 'support.dart';

class FakeShell extends ChangeNotifier implements TourShell {
  FakeShell({
    this.branch = AppBranch.hours,
    this.atBranchRoot = true,
    this.dockVisible = true,
    this.missing = const {},
  });

  @override
  AppBranch branch;
  @override
  bool atBranchRoot;
  @override
  bool dockVisible;

  /// Anchor keys the fake app does not render.
  Set<String> missing;
  final switched = <AppBranch>[];

  @override
  Listenable get changes => this;

  @override
  void selectBranch(AppBranch next) {
    switched.add(next);
    branch = next;
    notifyListeners();
  }

  void touch() => notifyListeners();
}

/// A screen with one marker per real anchor, shown only for its section.
class FakeApp extends StatelessWidget {
  const FakeApp({super.key, required this.shell});

  final FakeShell shell;

  Widget marker(String key, AppBranch? branch, Alignment at) {
    if (shell.missing.contains(key)) return const SizedBox.shrink();
    final box = Align(
      alignment: at,
      child: SizedBox(
        width: 120,
        height: 44,
        child: ColoredBox(color: Colors.teal, key: Key(key)),
      ),
    );
    return branch == null
        ? box
        : Offstage(offstage: shell.branch != branch, child: box);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: shell,
    builder: (context, _) => Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: Center(child: Text('Малітва'))),
          marker('hours-calendar-action', AppBranch.hours, Alignment.topLeft),
          marker('app-overflow-open', null, Alignment.topRight),
          marker(
            'readings-alternatives-control',
            AppBranch.readings,
            const Alignment(0, -0.6),
          ),
          marker('app-dock-full', null, const Alignment(0, 1)),
          marker(
            'app-destination-Малітоўнік',
            null,
            const Alignment(-0.5, 0.9),
          ),
          marker('app-destination-Біблія', null, const Alignment(0.5, 0.9)),
        ],
      ),
    ),
  );
}

Widget app(
  FakeShell shell,
  MemoryDiscoveryStorage storage, {
  DiscoveryClock? clock,
  List<Override> overrides = const [],
  Widget Function(Widget child)? wrap,
}) {
  final host = TourHost(
    shell: shell,
    child: FakeApp(shell: shell),
  );
  return ProviderScope(
    overrides: [
      tourEnabledProvider.overrideWithValue(true),
      discoveryStorageProvider.overrideWithValue(storage),
      discoveryClockProvider.overrideWithValue(clock ?? FakeDiscoveryClock(t0)),
      ...overrides,
    ],
    child: MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: wrap == null ? host : wrap(host),
    ),
  );
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(kTourInviteSettle + const Duration(milliseconds: 100));
  await tester.pump();
}

Future<void> stepForward(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tour-next')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

DiscoveryState saved(MemoryDiscoveryStorage storage) =>
    DiscoveryState.decode(storage.value);

String progress(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('tour-progress'))).data!;

void main() {
  group('policy', () {
    test('only a fresh, enabled, calm branch root gets the invitation', () {
      const calm = TourScreenFacts();
      expect(tourOfferBlock(DiscoveryState.empty, calm), isNull);
      for (final status in [
        TourStatus.declined,
        TourStatus.completed,
        TourStatus.skipped,
        TourStatus.inProgress,
      ]) {
        expect(
          tourOfferBlock(DiscoveryState(tourStatus: status), calm),
          TourOfferBlock.alreadyAnswered,
        );
      }
      expect(
        tourOfferBlock(const DiscoveryState(hintsEnabled: false), calm),
        TourOfferBlock.hintsDisabled,
      );
      expect(
        tourOfferBlock(
          DiscoveryState.empty,
          const TourScreenFacts(atBranchRoot: false),
        ),
        TourOfferBlock.notBranchRoot,
      );
      for (final busy in [
        const TourScreenFacts(routeIsCurrent: false),
        const TourScreenFacts(keyboardVisible: true),
        const TourScreenFacts(scrolling: true),
        const TourScreenFacts(hintOnScreen: true),
      ]) {
        expect(tourOfferBlock(DiscoveryState.empty, busy), TourOfferBlock.busy);
      }
    });

    test('a manual tour ignores answers and the hints switch', () {
      expect(manualTourCanStart(const TourScreenFacts()), isTrue);
      expect(
        manualTourCanStart(const TourScreenFacts(keyboardVisible: true)),
        isFalse,
      );
    });

    test('a manual tour starts over an automatic hint', () {
      expect(
        manualTourCanStart(const TourScreenFacts(hintOnScreen: true)),
        isTrue,
      );
      expect(
        manualTourCanStart(const TourScreenFacts(tourRunning: true)),
        isFalse,
      );
    });

    test('session drops missing steps and renumbers', () {
      final session = TourSession(defaultTourSteps);
      expect(session.progressBe, '1 з 6');
      session.next();
      expect(session.progressBe, '2 з 6');
      expect(session.dropCurrent(forward: true), isTrue);
      expect(session.progressBe, '2 з 5');
      expect(session.back(), isTrue);
      expect(session.dropCurrent(forward: false), isTrue);
      expect(session.total, 4);
      expect(session.index, 0);
    });
  });

  group('invitation', () {
    testWidgets('first run: quiet card, nothing dimmed; «Не зараз» frees the '
        'app and is never repeated', (tester) async {
      final storage = MemoryDiscoveryStorage();
      final shell = FakeShell();
      await tester.pumpWidget(app(shell, storage));
      await tester.pump();
      expect(find.byKey(const Key('tour-invitation')), findsNothing);

      await settle(tester);
      expect(find.byKey(const Key('tour-invitation')), findsOneWidget);
      expect(find.text('Паказаць'), findsOneWidget);
      expect(find.text('Не зараз'), findsOneWidget);
      expect(find.byKey(const Key('tour-layer')), findsNothing);
      // The offer is used up the moment it is shown.
      expect(saved(storage).tourStatus, TourStatus.declined);

      await tester.tap(find.byKey(const Key('tour-invite-decline')));
      await tester.pump();
      expect(find.byKey(const Key('tour-invitation')), findsNothing);
      expect(saved(storage).tourStatus, TourStatus.declined);

      // «Restart»: same storage, new app.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(shell, storage));
      await settle(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(find.byKey(const Key('tour-invitation')), findsNothing);
    });

    testWidgets('ignoring the card and restarting does not bring it back', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      final shell = FakeShell();
      await tester.pumpWidget(app(shell, storage));
      await settle(tester);
      expect(find.byKey(const Key('tour-invitation')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(shell, storage));
      await settle(tester);
      expect(find.byKey(const Key('tour-invitation')), findsNothing);
    });

    testWidgets('blocked while a keyboard is up, a dialog is open, inside a '
        'reader, with hints off or without a dock', (tester) async {
      final storage = MemoryDiscoveryStorage();
      final shell = FakeShell(atBranchRoot: false);
      await tester.pumpWidget(app(shell, storage));
      await settle(tester);
      expect(find.byKey(const Key('tour-invitation')), findsNothing);

      shell
        ..atBranchRoot = true
        ..dockVisible = false
        ..touch();
      await settle(tester);
      expect(find.byKey(const Key('tour-invitation')), findsNothing);

      shell
        ..dockVisible = true
        ..touch();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await settle(tester);
      expect(find.byKey(const Key('tour-invitation')), findsNothing);
      tester.view.resetViewInsets();

      final context = tester.element(find.byType(FakeApp));
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('Дыялог')),
      );
      await settle(tester);
      expect(find.byKey(const Key('tour-invitation')), findsNothing);
      expect(saved(storage).tourStatus, TourStatus.notOffered);
    });

    testWidgets('hints switched off: no invitation', (tester) async {
      final storage = MemoryDiscoveryStorage()
        ..value = const DiscoveryState(hintsEnabled: false).encode();
      await tester.pumpWidget(app(FakeShell(), storage));
      await settle(tester);
      expect(find.byKey(const Key('tour-invitation')), findsNothing);
    });

    testWidgets('no automatic hint next to the invitation or during the tour', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      await tester.pumpWidget(app(FakeShell(), storage));
      await settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FakeApp)),
      );
      final coordinator = await container.read(
        discoveryCoordinatorProvider.future,
      );
      expect(coordinator.automaticBlocked, isTrue);
      await tester.tap(find.byKey(const Key('tour-invite-decline')));
      await tester.pump();
      expect(coordinator.automaticBlocked, isFalse);
    });
  });

  group('tour', () {
    Future<void> startFromInvitation(WidgetTester tester) async {
      await settle(tester);
      await tester.tap(find.byKey(const Key('tour-invite-accept')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('«Паказаць» runs six steps, then restores the section', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      final shell = FakeShell(branch: AppBranch.prayerbook);
      await tester.pumpWidget(app(shell, storage));
      await startFromInvitation(tester);

      expect(find.byKey(const Key('tour-layer')), findsOneWidget);
      expect(saved(storage).tourStatus, TourStatus.inProgress);
      final seen = <String>[];
      for (var i = 0; i < 6; i++) {
        seen.add(progress(tester));
        expect(find.byKey(const Key('tour-skip')), findsOneWidget);
        expect(
          find.byKey(const Key('tour-back')),
          i == 0 ? findsNothing : findsOneWidget,
        );
        await stepForward(tester);
      }
      expect(seen, [for (var i = 1; i <= 6; i++) '$i з 6']);
      expect(find.byKey(const Key('tour-layer')), findsNothing);
      expect(saved(storage).tourStatus, TourStatus.completed);
      expect(shell.branch, AppBranch.prayerbook, reason: 'origin restored');
      expect(shell.switched, [
        AppBranch.hours,
        AppBranch.readings,
        AppBranch.prayerbook,
      ]);
    });

    testWidgets('back goes to the previous step; last step says «Гатова»', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      await tester.pumpWidget(app(FakeShell(), storage));
      await startFromInvitation(tester);
      await stepForward(tester);
      await stepForward(tester);
      expect(progress(tester), '3 з 6');
      await tester.tap(find.byKey(const Key('tour-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(progress(tester), '2 з 6');
      for (var i = 0; i < 4; i++) {
        await stepForward(tester);
      }
      expect(progress(tester), '6 з 6');
      expect(find.text('Гатова'), findsOneWidget);
    });

    testWidgets('«Прапусціць» ends the tour as skipped; restart is quiet', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      final shell = FakeShell(branch: AppBranch.bible);
      await tester.pumpWidget(app(shell, storage));
      await startFromInvitation(tester);
      await stepForward(tester);
      await stepForward(tester);
      await tester.tap(find.byKey(const Key('tour-skip')));
      await tester.pump();
      expect(find.byKey(const Key('tour-layer')), findsNothing);
      expect(saved(storage).tourStatus, TourStatus.skipped);
      expect(shell.branch, AppBranch.bible);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(shell, storage));
      await settle(tester);
      expect(find.byKey(const Key('tour-invitation')), findsNothing);
      expect(find.byKey(const Key('tour-layer')), findsNothing);
    });

    testWidgets('a run cut off by the system is not resumed or re-offered', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage()
        ..value = const DiscoveryState(
          tourStatus: TourStatus.inProgress,
        ).encode();
      await tester.pumpWidget(app(FakeShell(), storage));
      await settle(tester);
      await tester.pump();
      expect(find.byKey(const Key('tour-layer')), findsNothing);
      expect(find.byKey(const Key('tour-invitation')), findsNothing);
      expect(saved(storage).tourStatus, TourStatus.skipped);
    });

    testWidgets('missing anchors drop their steps; counts stay honest', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      final shell = FakeShell(missing: {'hours-calendar-action'});
      await tester.pumpWidget(app(shell, storage));
      await startFromInvitation(tester);
      expect(progress(tester), '1 з 6');
      await stepForward(tester);
      await tester.pump(kTourAnchorWaitInPlace);
      await tester.pump(const Duration(milliseconds: 100));
      // The calendar button is absent: step 2 is the text/menu step.
      expect(find.text('Памер тэксту і псалмы'), findsOneWidget);
      expect(progress(tester), '2 з 5');
      expect(tester.takeException(), isNull);
    });

    testWidgets('only the dock exists: one step, then completed', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      final shell = FakeShell(
        missing: {
          'hours-calendar-action',
          'app-overflow-open',
          'readings-alternatives-control',
          'app-destination-Малітоўнік',
          'app-destination-Біблія',
        },
      );
      await tester.pumpWidget(app(shell, storage));
      await startFromInvitation(tester);
      expect(progress(tester), '1 з 6');
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await stepForward(tester);
      // Remaining steps look for 2.5 s each and are dropped.
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('tour-layer')), findsNothing);
      expect(saved(storage).tourStatus, TourStatus.completed);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a control that disappears mid-step skips the step', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      final shell = FakeShell();
      await tester.pumpWidget(app(shell, storage));
      await startFromInvitation(tester);
      await stepForward(tester);
      expect(find.text('Дата і літургічны каляндар'), findsOneWidget);
      shell
        ..missing = {'hours-calendar-action'}
        ..touch();
      tester.view.physicalSize = const Size(900, 700);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(kTourAnchorWaitInPlace);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Памер тэксту і псалмы'), findsOneWidget);
    });

    testWidgets('system back skips the tour instead of leaving', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      await tester.pumpWidget(app(FakeShell(), storage));
      await startFromInvitation(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byKey(const Key('tour-layer')), findsNothing);
      expect(saved(storage).tourStatus, TourStatus.skipped);
    });

    testWidgets('taps behind the tour are swallowed', (tester) async {
      final storage = MemoryDiscoveryStorage();
      var taps = 0;
      final shell = FakeShell();
      await tester.pumpWidget(
        app(
          shell,
          storage,
          wrap: (host) => Stack(
            children: [
              host,
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  key: const Key('behind'),
                  onPressed: () => taps++,
                  child: const Text('Пад турам'),
                ),
              ),
            ],
          ),
        ),
      );
      // Not under the host: sanity that the button works at all.
      await tester.tap(find.byKey(const Key('behind')));
      expect(taps, 1);
    });

    testWidgets('manual start works with hints off and after «Не зараз»', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage()
        ..value = const DiscoveryState(
          hintsEnabled: false,
          tourStatus: TourStatus.declined,
          sessionCount: 3,
          autoShownAtMs: [123],
        ).encode();
      await tester.pumpWidget(app(FakeShell(), storage));
      await settle(tester);
      expect(find.byKey(const Key('tour-invitation')), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FakeApp)),
      );
      container.read(tourRequestProvider.notifier).state++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('tour-layer')), findsOneWidget);
      expect(progress(tester), '1 з 6');
      await tester.tap(find.byKey(const Key('tour-skip')));
      await tester.pump();

      final after = saved(storage);
      expect(after.hintsEnabled, isFalse, reason: 'switch untouched');
      expect(after.autoShownAtMs, [123], reason: 'quota untouched');
      expect(after.records, isEmpty);
      expect(after.tourStatus, TourStatus.skipped);
    });

    testWidgets('manual start waits for the keyboard to go away', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      await tester.pumpWidget(app(FakeShell(), storage));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FakeApp)),
      );
      container.read(tourRequestProvider.notifier).state++;
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('tour-layer')), findsNothing);
      tester.view.resetViewInsets();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('tour-layer')), findsOneWidget);
    });
  });

  group('looks', () {
    testWidgets('200% text on a small phone: the card stays on screen and '
        'its buttons work, light and dark', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final mode in [Brightness.light, Brightness.dark]) {
        tester.platformDispatcher.platformBrightnessTestValue = mode;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final storage = MemoryDiscoveryStorage();
        await tester.pumpWidget(app(FakeShell(), storage));
        await settle(tester);
        final invite = tester.getRect(find.byKey(const Key('tour-invitation')));
        expect(invite.left, greaterThanOrEqualTo(0));
        expect(invite.right, lessThanOrEqualTo(360));
        expect(invite.top, greaterThanOrEqualTo(0));
        await tester.tap(find.byKey(const Key('tour-invite-accept')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        for (var i = 0; i < 6; i++) {
          final card = tester.getRect(find.byKey(const Key('tour-card')));
          expect(card.left, greaterThanOrEqualTo(0), reason: 'step $i');
          expect(card.right, lessThanOrEqualTo(360), reason: 'step $i');
          expect(card.top, greaterThanOrEqualTo(0), reason: 'step $i');
          expect(card.bottom, lessThanOrEqualTo(640), reason: 'step $i');
          expect(find.byKey(const Key('tour-next')), findsOneWidget);
          await stepForward(tester);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('semantics: card is a named scope with progress and header, '
        'buttons are labelled', (tester) async {
      final handle = tester.ensureSemantics();
      final storage = MemoryDiscoveryStorage();
      await tester.pumpWidget(app(FakeShell(), storage));
      await settle(tester);
      expect(find.bySemanticsLabel('Паказаць'), findsOneWidget);
      expect(find.bySemanticsLabel('Не зараз'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tour-invite-accept')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.bySemanticsLabel('Тур па дадатку, крок 1 з 6'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Крок 1 з 6'), findsOneWidget);
      expect(find.bySemanticsLabel('Далей'), findsOneWidget);
      expect(find.bySemanticsLabel('Прапусціць'), findsOneWidget);
      final title = tester.getSemantics(find.text('Раздзелы дадатку'));
      // ignore: deprecated_member_use
      expect(title.hasFlag(SemanticsFlag.isHeader), isTrue);
      // The app behind the tour is hidden from the screen reader.
      expect(find.byType(BlockSemantics), findsWidgets);
      handle.dispose();
    });
  });

  group('settings', () {
    Widget settingsApp(MemoryDiscoveryStorage storage) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (_, _) =>
                    const Scaffold(body: DiscoverySettingsSection()),
              ),
            ],
          ),
        ],
        initialLocation: '/settings',
      );
      return ProviderScope(
        overrides: [
          discoveryStorageProvider.overrideWithValue(storage),
          discoveryClockProvider.overrideWithValue(FakeDiscoveryClock(t0)),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('switch, manual tour and a confirmed reset', (tester) async {
      final storage = MemoryDiscoveryStorage()
        ..value = DiscoveryState(
          tourStatus: TourStatus.declined,
          sessionCount: 4,
          records: const {'a': HintRecord(seenCount: 2, dismissed: true)},
          autoShownAtMs: const [5],
        ).encode();
      await tester.pumpWidget(settingsApp(storage));
      await tester.pumpAndSettle();
      expect(find.text('Паказваць падказкі'), findsOneWidget);
      expect(find.text('Як карыстацца дадаткам'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-hints-enabled')));
      await tester.pumpAndSettle();
      expect(saved(storage).hintsEnabled, isFalse);
      await tester.tap(find.byKey(const Key('settings-hints-enabled')));
      await tester.pumpAndSettle();
      expect(saved(storage).hintsEnabled, isTrue);

      // Cancel keeps the history.
      await tester.tap(find.byKey(const Key('settings-hints-reset')));
      await tester.pumpAndSettle();
      expect(find.text('Скінуць падказкі?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('discovery-reset-cancel')));
      await tester.pumpAndSettle();
      expect(saved(storage).records, isNotEmpty);

      // Confirm clears hint history only.
      await tester.tap(find.byKey(const Key('settings-hints-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('discovery-reset-confirm')));
      await tester.pumpAndSettle();
      final after = saved(storage);
      expect(after.records, isEmpty);
      expect(after.autoShownAtMs, isEmpty);
      expect(after.tourStatus, TourStatus.declined);
      expect(after.sessionCount, greaterThanOrEqualTo(4));
      expect(after.hintsEnabled, isTrue);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiscoverySettingsSection)),
      );
      expect(container.read(tourRequestProvider), 0);
      await tester.tap(find.byKey(const Key('settings-tour-start')));
      await tester.pumpAndSettle();
      expect(container.read(tourRequestProvider), 1);
      expect(find.text('home'), findsOneWidget, reason: 'back to the app');
    });
  });
}
