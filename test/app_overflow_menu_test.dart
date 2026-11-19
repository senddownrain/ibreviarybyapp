import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/widgets/app_overflow_menu.dart';
import 'package:mybrev_flutter/widgets/psalmody_mode_selector.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

void main() {
  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('app-overflow-open')));
    await tester.pumpAndSettle();
  }

  testWidgets('reader popup changes font size without opening a sheet', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_Settings.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: AppOverflowMenu(showTextScale: true, showPsalmody: true),
            ),
          ),
        ),
      ),
    );

    await openMenu(tester);
    expect(find.text('Шрыфт'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byKey(const Key('text-scale-inline-decrease')), findsOneWidget);
    expect(find.byKey(const Key('text-scale-inline-increase')), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(PsalmodyModeSelector), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('app-overflow-content'))).width,
      inInclusiveRange(280, 360),
    );

    await tester.tap(find.byKey(const Key('text-scale-inline-increase')));
    await tester.pumpAndSettle();
    expect(find.text('110%'), findsOneWidget);
    expect(container.read(settingsProvider).fontSize, closeTo(17.6, .001));
    expect(find.byKey(const Key('app-overflow-content')), findsOneWidget);
    expect(find.byKey(const Key('text-scale-slider')), findsNothing);

    await tester.tap(find.byKey(const Key('text-scale-inline-decrease')));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(container.read(settingsProvider).fontSize, closeTo(16.0, .001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline font buttons respect limits and keep the popup open', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_Settings.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: AppOverflowMenu(showTextScale: true, showPsalmody: true),
          ),
        ),
      ),
    );
    await openMenu(tester);
    container.read(settingsProvider.notifier).setFontSize(kMaxReaderFontSize);
    await tester.pumpAndSettle();
    expect(find.text('180%'), findsOneWidget);
    expect(
      tester.widget<IconButton>(
        find.byKey(const Key('text-scale-inline-increase')),
      ).onPressed,
      isNull,
    );
    container.read(settingsProvider.notifier).setFontSize(kMinReaderFontSize);
    await tester.pumpAndSettle();
    expect(find.text('70%'), findsOneWidget);
    expect(
      tester.widget<IconButton>(
        find.byKey(const Key('text-scale-inline-decrease')),
      ).onPressed,
      isNull,
    );
    expect(find.byKey(const Key('app-overflow-content')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 390.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          testWidgets(
            'popup fits $platform $brightness $width dp at $scale scale',
            (tester) async {
              tester.view.physicalSize = Size(width, 640);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [settingsProvider.overrideWith(_Settings.new)],
                  child: MaterialApp(
                    theme: ThemeData(
                      platform: platform,
                      brightness: brightness,
                    ),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                        padding: const EdgeInsets.only(top: 44, bottom: 34),
                        viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
                      ),
                      child: child!,
                    ),
                    home: const ReaderScaffold(
                      showPsalmody: true,
                      content: Text('Псальм'),
                    ),
                  ),
                ),
              );
              final button = tester.getRect(
                find.byKey(const Key('app-overflow-open')),
              );
              expect(
                tester.getSize(find.byType(AppOverflowMenu)),
                const Size(48, 48),
              );
              expect(button.width, greaterThanOrEqualTo(44));
              expect(button.height, greaterThanOrEqualTo(44));
              await openMenu(tester);
              final menu = tester.getRect(
                find.byKey(const Key('app-overflow-content')),
              );
              expect(menu.right, lessThanOrEqualTo(width - 8));
              expect(menu.left, greaterThanOrEqualTo(8));
              expect(menu.top, greaterThanOrEqualTo(44));
              await tester.ensureVisible(find.text('Інфармацыя'));
              await tester.pumpAndSettle();
              expect(
                tester.getRect(find.text('Інфармацыя')).bottom,
                lessThanOrEqualTo(640 - 34),
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  testWidgets('popup stays above an open keyboard on a small viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              padding: const EdgeInsets.only(top: 44),
              viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
              viewInsets: const EdgeInsets.only(bottom: 300),
            ),
            child: child!,
          ),
          home: const ReaderScaffold(
            showPsalmody: true,
            content: Text('Псальм'),
          ),
        ),
      ),
    );
    await openMenu(tester);
    await tester.ensureVisible(find.text('Інфармацыя'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Інфармацыя')).bottom, lessThan(340));
    expect(tester.takeException(), isNull);
  });

  testWidgets('root menu has no font and routes to settings and information', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: AppOverflowMenu()),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(body: Text('settings-page')),
        ),
        GoRoute(
          path: '/about',
          builder: (_, _) => const Scaffold(body: Text('about-page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    for (final label in ['Налады', 'Інфармацыя']) {
      await openMenu(tester);
      expect(find.text('Шрыфт'), findsNothing);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(
        find.text(label == 'Налады' ? 'settings-page' : 'about-page'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('app-overflow-content')), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('prayer error is last and short; categories absent', (
    tester,
  ) async {
    var reports = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
        child: MaterialApp(
          home: Scaffold(
            body: AppOverflowMenu(
              showTextScale: true,
              actions: [
                ReaderSecondaryAction(
                  label: 'Памылка',
                  icon: Icons.flag_outlined,
                  onSelected: () => reports++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await openMenu(tester);
    expect(find.text('Катэгорыі'), findsNothing);
    expect(find.text('Паведаміць пра памылку'), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('app-overflow-content'))).width,
      inInclusiveRange(280, 360),
    );
    expect(
      tester.getTopLeft(find.text('Памылка')).dy,
      greaterThan(tester.getTopLeft(find.text('Інфармацыя')).dy),
    );
    await tester.tap(find.text('Памылка'));
    await tester.pumpAndSettle();
    expect(reports, 1);
  });

  testWidgets('context action runs after popup closes', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppOverflowMenu(
            actions: [
              ReaderSecondaryAction(
                label: 'Рэдагаваць',
                icon: Icons.edit,
                onSelected: () => calls++,
              ),
            ],
          ),
        ),
      ),
    );
    await openMenu(tester);
    await tester.tap(find.text('Рэдагаваць'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byKey(const Key('app-overflow-content')), findsNothing);
  });

  testWidgets(
    'switching preserves reader scroll and hidden chrome dismisses popup',
    (tester) async {
      final mode = ReaderChromeModeController();
      final scroll = ScrollController();
      addTearDown(mode.dispose);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith(_Settings.new)],
          child: MaterialApp(
            home: ReaderChromeModeScope(
              controller: mode,
              child: ReaderScaffold(
                showPsalmody: true,
                scrollController: scroll,
                content: const SizedBox(height: 2400),
              ),
            ),
          ),
        ),
      );
      scroll.jumpTo(400);
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('text-scale-inline-increase')));
      await tester.pumpAndSettle();
      expect(scroll.offset, 400);
      expect(find.byKey(const Key('app-overflow-content')), findsOneWidget);
      mode.value = ReaderChromeMode.hidden;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-overflow-open')), findsNothing);
      expect(find.byKey(const Key('app-overflow-content')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();

  @override
  void setFontSize(double size) {
    state = state.copyWith(fontSize: normalizeReaderFontSize(size));
  }

  @override
  Future<void> setPsalmodyMode(PsalmodyMode value) async {
    state = state.copyWith(psalmodyMode: value);
  }
}
