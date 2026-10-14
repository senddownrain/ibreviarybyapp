import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/widgets/app_overflow_menu.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

void main() {
  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('app-overflow-open')));
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester, Finder tile) => tester
      .widget<Switch>(find.descendant(of: tile, matching: find.byType(Switch)))
      .value;

  testWidgets(
    'Ora switches apply immediately and survive reopening the popup',
    (tester) async {
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
      final marker = find.byKey(const Key('overflow-psalm-marker-break'));
      final layout = find.byKey(const Key('overflow-psalm-aligned-left'));
      expect(switchValue(tester, marker), isFalse);
      expect(switchValue(tester, layout), isFalse);
      expect(find.text('Перанос пасля * і †'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(2));
      expect(find.byType(ChoiceChip), findsNothing);
      final semantics = tester.ensureSemantics();
      expect(
        tester
                .getSemantics(marker)
                .getSemanticsData()
                .flagsCollection
                .isToggled !=
            Tristate.none,
        isTrue,
      );
      expect(
        tester
                .getSemantics(marker)
                .getSemanticsData()
                .flagsCollection
                .isToggled ==
            Tristate.isTrue,
        isFalse,
      );

      await tester.tap(marker);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-overflow-content')), findsOneWidget);
      expect(
        container.read(settingsProvider).psalmMarkerBreakMode,
        PsalmMarkerBreakMode.breakAfterMarker,
      );
      expect(
        container.read(settingsProvider).psalmVerseLayout,
        PsalmVerseLayout.alternatingIndent,
      );
      await tester.tap(layout);
      await tester.pumpAndSettle();
      expect(switchValue(tester, marker), isTrue);
      expect(
        tester
                .getSemantics(marker)
                .getSemanticsData()
                .flagsCollection
                .isToggled ==
            Tristate.isTrue,
        isTrue,
      );
      expect(switchValue(tester, layout), isTrue);
      await tester.tapAt(const Offset(10, 500));
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(switchValue(tester, marker), isTrue);
      expect(switchValue(tester, layout), isTrue);
      semantics.dispose();
    },
  );

  testWidgets('font dismisses popup and opens only the saved size panel', (
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
    await tester.tap(find.text('Шрыфт'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-overflow-content')), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byKey(const Key('text-scale-slider')), findsOneWidget);
    await tester.tap(find.byKey(const Key('text-scale-increase')));
    await tester.pumpAndSettle();
    expect(find.text('110%'), findsOneWidget);
    expect(container.read(settingsProvider).fontSize, closeTo(17.6, .001));
    await tester.tap(find.byTooltip('Закрыць'));
    await tester.pumpAndSettle();
    await openMenu(tester);
    expect(find.byType(Switch), findsNWidgets(2));
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 360.0, 390.0, 430.0]) {
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

  testWidgets(
    'menu uses 15sp UI text independently of reader size and serif theme',
    (tester) async {
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith(_Settings.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(
              textTheme: ThemeData().textTheme.apply(fontFamily: 'Literata'),
            ),
            home: const Scaffold(
              body: AppOverflowMenu(showTextScale: true, showPsalmody: true),
            ),
          ),
        ),
      );
      await openMenu(tester);
      for (final size in [kMinReaderFontSize, kMaxReaderFontSize]) {
        container.read(settingsProvider.notifier).setFontSize(size);
        await tester.pumpAndSettle();
        for (final label in [
          'Шрыфт',
          'Перанос пасля * і †',
          'Па левым краі',
          'Налады',
          'Інфармацыя',
        ]) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.style!.fontSize, 15);
          expect(text.style!.fontFamily, 'Roboto');
          expect(text.style!.inherit, isFalse);
        }
      }
    },
  );

  testWidgets('popup accounts for asymmetric side cutouts', (tester) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.fromLTRB(28, 44, 40, 34),
            viewPadding: const EdgeInsets.fromLTRB(28, 44, 40, 34),
          ),
          child: child!,
        ),
        home: const ReaderScaffold(
          showTextScale: false,
          content: Text('Тэкст'),
        ),
      ),
    );
    final button = tester.getRect(find.byKey(const Key('app-overflow-open')));
    await openMenu(tester);
    final menu = tester.getRect(find.byKey(const Key('app-overflow-content')));
    expect(menu.left, greaterThanOrEqualTo(28 + 8));
    expect(menu.right, lessThanOrEqualTo(390 - 40 - 8));
    expect(menu.right, closeTo(button.right + .8, 1));
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

  for (final direction in TextDirection.values) {
    testWidgets(
      'open popup follows rotation, scaling and keyboard in $direction',
      (tester) async {
        tester.view.physicalSize = const Size(390, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final keyboard = ValueNotifier<double>(0);
        final scale = ValueNotifier<double>(1);
        addTearDown(keyboard.dispose);
        addTearDown(scale.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [settingsProvider.overrideWith(_Settings.new)],
            child: MaterialApp(
              builder: (context, child) => AnimatedBuilder(
                animation: Listenable.merge([keyboard, scale]),
                builder: (_, _) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 24, bottom: 16),
                    viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
                    viewInsets: EdgeInsets.only(bottom: keyboard.value),
                    textScaler: TextScaler.linear(scale.value),
                  ),
                  child: Directionality(
                    textDirection: direction,
                    child: child!,
                  ),
                ),
              ),
              home: const ReaderScaffold(
                showPsalmody: true,
                content: Text('Псальм'),
              ),
            ),
          ),
        );
        await openMenu(tester);
        Rect popup() =>
            tester.getRect(find.byKey(const Key('app-overflow-popup')));
        // This geometry fixture uses Flutter's Ahem test font. Real-font
        // compact widths are verified by menu_visual_preview_test.dart.
        final initialWidth = popup().width;
        expect(initialWidth, inInclusiveRange(316, 360));
        tester.view.physicalSize = const Size(640, 360);
        await tester.pumpAndSettle();
        final button = tester.getRect(
          find.byKey(const Key('app-overflow-open')),
        );
        expect(
          direction == TextDirection.ltr ? popup().right : popup().left,
          closeTo(
            direction == TextDirection.ltr
                ? button.right + .8
                : button.left - .8,
            1,
          ),
        );
        scale.value = 2;
        keyboard.value = 96;
        await tester.pumpAndSettle();
        expect(popup().width, greaterThanOrEqualTo(initialWidth));
        expect(popup().left, greaterThanOrEqualTo(8));
        expect(popup().right, lessThanOrEqualTo(640 - 8));
        expect(popup().top, greaterThanOrEqualTo(24 + 8));
        expect(popup().bottom, lessThanOrEqualTo(360 - 96 - 8));
        await tester.ensureVisible(find.text('Інфармацыя'));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('Інфармацыя')).bottom,
          lessThanOrEqualTo(360 - 96 - 8),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'compact popup stays inside the viewport near the bottom edge in $direction',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: const Scaffold(
                body: SafeArea(
                  minimum: EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: AppOverflowMenu(),
                  ),
                ),
              ),
            ),
          ),
        );
        await openMenu(tester);
        final popup = tester.getRect(
          find.byKey(const Key('app-overflow-popup')),
        );
        expect(popup.width, closeTo(256, .01));
        expect(popup.left, greaterThanOrEqualTo(8));
        expect(popup.right, lessThanOrEqualTo(360 - 8));
        expect(popup.top, greaterThanOrEqualTo(8));
        expect(popup.bottom, lessThanOrEqualTo(640 - 8));
        expect(find.text('Інфармацыя'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
      await tester.tap(find.byKey(const Key('overflow-psalm-marker-break')));
      await tester.pumpAndSettle();
      expect(scroll.offset, 400);
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
  Future<void> setPsalmMarkerBreakMode(PsalmMarkerBreakMode value) async {
    state = state.copyWith(psalmMarkerBreakMode: value);
  }

  @override
  Future<void> setPsalmVerseLayout(PsalmVerseLayout value) async {
    state = state.copyWith(psalmVerseLayout: value);
  }
}
