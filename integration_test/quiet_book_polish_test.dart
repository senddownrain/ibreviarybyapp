import 'package:mybrev_flutter/theme/app_theme_preference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mybrev_flutter/main.dart' as app;
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/screens/home_screen.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/theme/app_theme_controller.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/reader/hour_switcher_pill.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Quiet Book real Android light/dark scroll and page audit',
    (tester) async {
      Future<void> settle([int ms = 800]) async {
        for (var i = 0; i < ms; i += 100) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 180 && finder.evaluate().isEmpty; i++) {
          await settle(500);
        }
        expect(finder, findsWidgets);
      }

      Future<void> shot(String name) async {
        await settle();
        debugPrint('QUIET_BOOK_SCREEN::$name');
        await Future<void>.delayed(const Duration(seconds: 2));
        expect(tester.takeException(), isNull, reason: name);
      }

      ScrollPosition position(Finder root) => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: root,
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is Scrollable &&
                        w.axisDirection == AxisDirection.down,
                  ),
                )
                .first,
          )
          .position;
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder.first);
        await settle(200);
        await tester.tap(finder.first);
        await settle();
      }

      app.main();
      await waitFor(find.byKey(const Key('hours-hour-laudes')));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final auditDate = DateTime(2026, 10, 11);
      final calendarDate = DateUtils.isSameDay(auditDate, DateTime.now())
          ? DateTime(2026, 10, 12)
          : auditDate;
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        appThemePreferenceController.value = dark
            ? AppThemePreference.dark
            : AppThemePreference.light;
        router.go('/hours');
        await settle();
        container
            .read(liturgicalNavigationControllerProvider)
            .openDate(DateTime(2026, 10, 11));
        await settle();
        position(find.byType(HomeScreen)).jumpTo(0);
        await settle();
        await shot('$theme-hours-11');
        container
            .read(liturgicalNavigationControllerProvider)
            .openDate(calendarDate);
        await settle();
        await tap(find.byKey(const Key('hours-date-action')));
        await shot('$theme-calendar-today-selected');
        await tap(find.text('Гатова'));
        container
            .read(liturgicalNavigationControllerProvider)
            .openDate(auditDate);
        await settle();
        await tap(find.byKey(const Key('hours-hour-laudes')));
        await waitFor(find.byType(HourSwitcherPill));
        await shot('$theme-laudes-start');
        final reader = find.byType(ReaderScaffold);
        final scroll = position(reader);
        final title = find.byKey(const Key('reader-context-title-action'));
        final bottom = tester.getBottomLeft(title).dy;
        final safeTop = MediaQuery.paddingOf(tester.element(reader)).top;
        scroll.jumpTo(bottom - safeTop - 8);
        await settle();
        expect(
          tester
              .widget<AnimatedOpacity>(
                find.byKey(const Key('hour-switcher-opacity')),
              )
              .opacity,
          0,
        );
        await shot('$theme-laudes-transition');
        // A real gesture crosses the title's measured boundary.
        await tester.dragFrom(const Offset(190, 500), const Offset(0, -120));
        await settle();
        expect(
          tester
              .widget<AnimatedOpacity>(
                find.byKey(const Key('hour-switcher-opacity')),
              )
              .opacity,
          1,
        );
        await shot('$theme-laudes-scrolled');
        await tap(find.byKey(const Key('hour-switcher-pill')));
        await shot('$theme-hour-selector');
        await tester.binding.handlePopRoute();
        await settle();
        scroll.jumpTo(0);
        await settle();
        expect(
          tester
              .widget<AnimatedOpacity>(
                find.byKey(const Key('reader-top-protection-opacity')),
              )
              .opacity,
          0,
        );
        for (var i = 0; i < 4; i++) {
          scroll.jumpTo(scroll.maxScrollExtent);
          await settle(200);
        }
        expect(
          find.byKey(const Key('ora-next-hour')).hitTestable(),
          findsOneWidget,
        );
        expect(find.byKey(const Key('ora-source-footer')), findsNothing);
        await shot('$theme-laudes-end');
        await tap(find.byKey(const Key('ora-next-hour')));
        await shot('$theme-next-hour-start');
        expect(
          tester
              .widget<AnimatedOpacity>(
                find.byKey(const Key('hour-switcher-opacity')),
              )
              .opacity,
          0,
        );
        router.go('/readings');
        await settle();
        container
            .read(liturgicalNavigationControllerProvider)
            .openDate(DateTime(2026, 10, 9));
        await settle();
        await shot('$theme-readings-9');
        await tap(find.byKey(const Key('readings-alternatives-control')));
        await shot('$theme-readings-selector');
        await tap(find.byKey(const Key('readings-options-done')));
        for (final day in [11, 9]) {
          router.go(
            '/hours/ordo?date=2026-10-${day.toString().padLeft(2, '0')}',
          );
          await settle(1400);
          if (day == 11) {
            expect(find.text('Іншыя святкаванні дня'), findsNothing);
          }
          await shot('$theme-ordo-$day');
        }
      }
      debugPrint('QUIET_BOOK_FONT_SCALE::2');
      await Future<void>.delayed(const Duration(seconds: 3));
      appThemePreferenceController.value = AppThemePreference.light;
      router.go('/hours');
      container
          .read(liturgicalNavigationControllerProvider)
          .openDate(calendarDate);
      await settle();
      await tap(find.byKey(const Key('hours-date-action')));
      await shot('large-calendar-today-selected');
      await tap(find.text('Гатова'));
      container
          .read(liturgicalNavigationControllerProvider)
          .openDate(auditDate);
      await settle();
      await tap(find.byKey(const Key('hours-hour-laudes')));
      await shot('large-laudes-start');
      final largeScroll = position(find.byType(ReaderScaffold));
      largeScroll.jumpTo(600);
      await settle();
      await shot('large-laudes-scrolled');
      for (var i = 0; i < 4; i++) {
        largeScroll.jumpTo(largeScroll.maxScrollExtent);
        await settle(200);
      }
      await shot('large-laudes-end');
      await tap(find.byKey(const Key('ora-next-hour')));
      final longReader = find.byType(ReaderScaffold);
      final longTitle = find.byKey(const Key('reader-context-title-action'));
      final longTitleBottom = tester.getBottomLeft(longTitle).dy;
      final longSafeTop = MediaQuery.paddingOf(tester.element(longReader)).top;
      position(longReader).jumpTo(longTitleBottom - longSafeTop + 120);
      await settle();
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const Key('hour-switcher-opacity')),
            )
            .opacity,
        1,
      );
      await shot('large-long-hour-title');
      debugPrint('QUIET_BOOK_FONT_SCALE::restore');
      await Future<void>.delayed(const Duration(seconds: 3));
      appThemePreferenceController.value = AppThemePreference.light;
      router.go('/hours');
      await settle();
      debugPrint('QUIET_BOOK_CAPTURE_DONE');
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
