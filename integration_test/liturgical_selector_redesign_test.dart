import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mybrev_flutter/main.dart' as app;
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/screens/home_screen.dart';
import 'package:mybrev_flutter/screens/ora_screen.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/theme/app_theme_controller.dart';
import 'package:mybrev_flutter/widgets/hours_options_sheet.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_disclosure.dart';
import 'package:mybrev_flutter/widgets/selection_option_card.dart';

/// Uses the actual application and bundled Ordo. Chrome screenshots are taken
/// by Flutter's WebDriver; Android screenshots use host adb after rendering.
void main() {
  const focusOnly = bool.fromEnvironment('SELECTOR_FOCUS_ONLY');
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'shared liturgical selectors on the running application',
    (tester) async {
      Future<void> settle([int milliseconds = 600]) async {
        for (var elapsed = 0; elapsed < milliseconds; elapsed += 100) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> waitFor(Finder finder) async {
        for (
          var attempt = 0;
          attempt < 180 && finder.evaluate().isEmpty;
          attempt++
        ) {
          await settle(500);
        }
        expect(finder, findsWidgets);
      }

      Future<void> tap(Key key) async {
        final finder = find.byKey(key);
        await waitFor(finder);
        if (finder.hitTestable().evaluate().isEmpty) {
          await Scrollable.ensureVisible(
            tester.element(finder.first),
            alignment: .5,
          );
          await settle();
        }
        await tester.tap(finder.first);
        await settle();
        expect(tester.takeException(), isNull, reason: '$key');
      }

      Future<void> done() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Гатова'));
        await settle();
      }

      final width =
          (tester.view.physicalSize.width / tester.view.devicePixelRatio)
              .round()
              .toString();
      final platform = kIsWeb ? 'chrome' : 'android';
      var nativeScale = '';
      late final ProviderContainer container;

      Future<void> shot(String name) async {
        if (focusOnly &&
            ![
              'office-variants',
              'readings-two-cycles',
              'readings-three-cycles',
              'multiple-mass-sets',
            ].any(name.endsWith)) {
          return;
        }
        if (focusOnly) {
          final focus = name.endsWith('office-variants')
              ? find.byKey(
                  ValueKey(
                    'hours-template-${container.read(hoursLiturgicalSelectionProvider).selected!.templates.last.id}',
                  ),
                )
              : name.endsWith('readings-two-cycles')
              ? find.byKey(const ValueKey('readings-cycle-2'))
              : name.endsWith('readings-three-cycles')
              ? find.byKey(const ValueKey('readings-cycle-A'))
              : find.byKey(const ValueKey('readings-mass-set-second'));
          await Scrollable.ensureVisible(tester.element(focus), alignment: .6);
        }
        await settle();
        expect(tester.takeException(), isNull, reason: name);
        final footer = find.widgetWithText(FilledButton, 'Гатова');
        if (footer.evaluate().isNotEmpty) {
          final view = tester.view;
          final safeBottom =
              (view.physicalSize.height - view.viewPadding.bottom) /
              view.devicePixelRatio;
          expect(
            tester.getRect(footer).bottom,
            lessThanOrEqualTo(safeBottom + .5),
          );
          expect(tester.getSize(footer).height, greaterThanOrEqualTo(48));
          expect(footer.hitTestable(), findsOneWidget);
        }

        final screenshotName = '$platform-$width$nativeScale-$name';
        final metrics = <String, Object?>{
          'viewportWidth':
              tester.view.physicalSize.width / tester.view.devicePixelRatio,
          'viewportHeight':
              tester.view.physicalSize.height / tester.view.devicePixelRatio,
          'bottomInset':
              tester.view.viewPadding.bottom / tester.view.devicePixelRatio,
          'textScaleAt16':
              MediaQuery.textScalerOf(
                tester.element(find.byType(Scaffold).first),
              ).scale(16) /
              16,
        };
        // Android uses whole-device adb captures without converting its surface.
        // The SDK image-view conversion can stall capture after repeated routes.
        if (kIsWeb) await binding.takeScreenshot(screenshotName, metrics);
        binding.reportData ??= <String, dynamic>{};
        final states =
            binding.reportData!.putIfAbsent(
                  'selector_states',
                  () => <String, Object?>{},
                )
                as Map<String, Object?>;
        states[screenshotName] = metrics;
        if (!kIsWeb) {
          // Keep the real Flutter surface and allow the host to capture system bars.
          debugPrint('SELECTOR_NATIVE_SCREENSHOT_READY:$name');
          await settle(3000);
        }
      }

      app.main();
      await waitFor(find.byKey(const Key('hours-hour-laudes')));
      container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final navigation = container.read(liturgicalNavigationControllerProvider);
      if (!kIsWeb) {
        final nativeNavigation =
            tester.view.viewPadding.bottom / tester.view.devicePixelRatio >= 40
            ? 'threebutton'
            : 'gesture';
        nativeScale =
            '-system-text-${MediaQuery.textScalerOf(tester.element(find.byType(HomeScreen))).scale(1)}-nav-$nativeNavigation';
        if (focusOnly) nativeScale += '-focused';
      }
      final originalTheme = appThemeModeController.value;
      final originalDioceses = container.read(dioceseSelectionProvider);
      try {
        for (final dark in [false, true]) {
          appThemeModeController.value = dark
              ? ThemeMode.dark
              : ThemeMode.light;
          final theme = dark ? 'dark' : 'light';
          router.go('/hours');
          navigation.openDate(DateTime(2026, 10, 9));
          await settle(1200);
          await tap(const Key('hours-alternatives-control'));
          expect(
            tester
                .widget<LiturgicalCalendarDisclosure>(
                  find.byType(LiturgicalCalendarDisclosure),
                )
                .expanded,
            isFalse,
          );
          await shot('$theme-hours-collapsed');
          if (!kIsWeb && !focusOnly) {
            await tester.tap(find.byTooltip('Закрыць').last);
            await settle();
            expect(find.byType(LiturgicalCalendarDisclosure), findsNothing);
            await tap(const Key('hours-alternatives-control'));
            debugPrint('SELECTOR_NATIVE_BACK_READY');
            for (
              var attempt = 0;
              attempt < 100 &&
                  find
                      .byType(LiturgicalCalendarDisclosure)
                      .evaluate()
                      .isNotEmpty;
              attempt++
            ) {
              await settle(100);
            }
            expect(find.byType(LiturgicalCalendarDisclosure), findsNothing);
            await tap(const Key('hours-alternatives-control'));
            final sheet = tester.getRect(find.byType(BottomSheet));
            await tester.dragFrom(
              Offset(sheet.center.dx, sheet.top + 18),
              const Offset(0, 500),
            );
            await settle();
            expect(find.byType(LiturgicalCalendarDisclosure), findsNothing);
            await tap(const Key('hours-alternatives-control'));
          }

          if (!focusOnly) {
            await tap(const Key('liturgical-calendar-toggle'));
            await shot('$theme-hours-expanded');
            await tap(const Key('ordo-jump-month'));
            expect(find.byKey(const Key('ordo-day-2026-10-09')), findsNothing);
            await shot('$theme-month-picker');
            await tap(const Key('ordo-pick-year'));
            await shot('$theme-year-picker');
            await tap(const Key('ordo-year-2026'));
            await tap(const Key('ordo-month-12'));
            expect(container.read(selectedDateProvider), DateTime(2026, 10, 9));
            await tap(const Key('ordo-next-month'));
            expect(
              find.byKey(const Key('ordo-day-2027-01-01')),
              findsOneWidget,
            );
            await tap(const Key('ordo-previous-month'));
            await tap(const Key('ordo-jump-month'));
            await tap(const Key('ordo-month-10'));
            await tap(const Key('ordo-day-2026-10-07'));
            await tap(const Key('liturgical-calendar-toggle'));
          } else {
            navigation.openDate(DateTime(2026, 10, 7));
            await settle(1200);
          }
          final memorial = container
              .read(hoursLiturgicalSelectionProvider)
              .selected!;
          if (focusOnly) {
            await tap(
              ValueKey('hours-template-${memorial.templates.first.id}'),
            );
          }
          await shot('$theme-office-variants');
          await tap(ValueKey('hours-template-${memorial.templates.last.id}'));
          expect(
            container.read(hoursLiturgicalSelectionProvider).dayId,
            memorial.templates.last.id,
          );
          await done();

          if (focusOnly) {
            await tap(const Key('hours-hour-laudes'));
            await waitFor(find.byType(OraScreen));
            expect(
              tester.widget<OraScreen>(find.byType(OraScreen)).dayId,
              memorial.templates.last.id,
            );
            await waitFor(
              find.descendant(
                of: find.byType(OraScreen),
                matching: find.byType(Html),
              ),
            );
            debugPrint(
              'SELECTOR_OFFICE_READER:${router.routeInformationProvider.value.uri}',
            );
            router.go('/hours');
            await settle(1200);
          }
          navigation.openDate(DateTime(2026, 10, 13));
          router.go('/readings');
          await settle(1200);
          await tap(const Key('readings-alternatives-control'));
          await shot('$theme-readings-two-cycles');
          final office = container.read(hoursLiturgicalSelectionProvider).dayId;
          await tap(const ValueKey('readings-cycle-1'));
          expect(
            container.read(hoursLiturgicalSelectionProvider).dayId,
            office,
          );
          await tap(const Key('readings-cycle-automatic'));
          expect(
            tester
                .widget<SelectionOptionCard>(
                  find.byKey(const ValueKey('readings-cycle-2')),
                )
                .selected,
            isTrue,
          );
          await done();
          navigation.openDate(DateTime(2026, 10, 11));
          await settle(1200);
          await tap(const Key('readings-alternatives-control'));
          for (final cycle in ['A', 'B', 'C']) {
            expect(
              find.byKey(ValueKey('readings-cycle-$cycle')),
              findsOneWidget,
            );
            if (focusOnly) {
              await tap(ValueKey('readings-cycle-$cycle'));
              expect(
                tester
                    .widget<SelectionOptionCard>(
                      find.byKey(ValueKey('readings-cycle-$cycle')),
                    )
                    .selected,
                isTrue,
              );
            }
          }
          await shot('$theme-readings-three-cycles');
          await done();
          navigation.openDate(DateTime(2025, 11, 2));
          await settle(1200);
          await tap(const Key('readings-alternatives-control'));
          for (final set in ['first', 'second', 'third']) {
            expect(
              find.byKey(ValueKey('readings-mass-set-$set')),
              findsOneWidget,
            );
          }
          await tap(const ValueKey('readings-mass-set-second'));
          await shot('$theme-multiple-mass-sets');
          await done();

          if (focusOnly) continue;
          final dioceses = container.read(dioceseSelectionProvider.notifier);
          for (final id in kDioceseNames.keys) {
            if (!container.read(dioceseSelectionProvider).contains(id)) {
              dioceses.toggle(id);
            }
          }
          router.go('/hours/ordo?date=2026-10-09');
          await settle(1200);
          await shot('$theme-ordo-alternatives');
          await tap(const Key('ordo-date-action'));
          expect(find.byType(HoursOptionsSheet), findsNothing);
          expect(find.text('СВЯТКАВАННЕ'), findsNothing);
          await shot('$theme-ordo-date-only');
          await tap(const Key('ordo-day-2026-10-10'));
          expect(
            find.byKey(const Key('compact-liturgical-calendar')),
            findsOneWidget,
          );
          expect(container.read(selectedDateProvider), DateTime(2026, 10, 10));
          await done();
        }
        if (kIsWeb) {
          for (final scale in [1.5, 2.0]) {
            router.go('/hours');
            navigation.openDate(DateTime(2026, 10, 9));
            await settle(1200);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await settle();
            await tap(const Key('hours-alternatives-control'));
            await shot('text-$scale-hours');
            await tap(const Key('liturgical-calendar-toggle'));
            await shot('text-$scale-calendar');
            await done();
            router.go('/hours/ordo?date=2026-10-09');
            await settle(1200);
            await shot('text-$scale-ordo');
            expect(tester.takeException(), isNull);
          }
        }
      } finally {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        appThemeModeController.value = originalTheme;
        final notifier = container.read(dioceseSelectionProvider.notifier);
        for (final id in originalDioceses.selected) {
          if (!container.read(dioceseSelectionProvider).contains(id)) {
            notifier.toggle(id);
          }
        }
        for (final id in kDioceseNames.keys) {
          if (!originalDioceses.contains(id) &&
              container.read(dioceseSelectionProvider).contains(id)) {
            notifier.toggle(id);
          }
        }
        notifier.setPrimary(originalDioceses.primary);
        expect(
          container.read(dioceseSelectionProvider).selected,
          unorderedEquals(originalDioceses.selected),
        );
        expect(
          container.read(dioceseSelectionProvider).primary,
          originalDioceses.primary,
        );
        expect(appThemeModeController.value, originalTheme);
        binding.reportData?['preferences_restored'] = true;
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
