// Runs the production app on Android. POLISH_SCREEN frames are captured by
// adb screencap on the host, including the real status/navigation bars.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mybrev_flutter/main.dart' as app;
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/screens/home_screen.dart';
import 'package:mybrev_flutter/screens/readings_screen.dart';
import 'package:mybrev_flutter/screens/ordo_screen.dart';
import 'package:mybrev_flutter/screens/ora_screen.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/theme/app_theme_controller.dart';
import 'package:mybrev_flutter/widgets/ordo/liturgical_month_calendar.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_sheet.dart';
import 'package:mybrev_flutter/widgets/hours_options_sheet.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'Android liturgical UX and native screenshots',
    (tester) async {
      Future<void> settle([int milliseconds = 900]) async {
        final until = DateTime.now().add(Duration(milliseconds: milliseconds));
        while (DateTime.now().isBefore(until)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 180 && finder.evaluate().isEmpty; i++) {
          await settle(500);
        }
        expect(finder, findsWidgets);
      }

      Future<void> tap(Finder finder) async {
        if (finder.evaluate().isEmpty) {
          final optionsScroll = find.byKey(
            const Key('readings-options-scroll'),
          );
          final vertical = optionsScroll.evaluate().isNotEmpty
              ? find
                    .descendant(
                      of: optionsScroll,
                      matching: find.byType(Scrollable),
                    )
                    .first
              : find
                    .byWidgetPredicate(
                      (w) =>
                          w is Scrollable &&
                          w.axisDirection == AxisDirection.down,
                    )
                    .hitTestable()
                    .last;
          tester.state<ScrollableState>(vertical).position.jumpTo(0);
          await settle(300);
          await tester.scrollUntilVisible(finder, 200, scrollable: vertical);
        }
        await waitFor(finder);
        await tester.ensureVisible(finder.first);
        await settle(300);
        await tester.tap(finder.first);
        await settle();
      }

      Future<void> shot(String name) async {
        await settle();
        debugPrint('POLISH_SCREEN::$name');
        await settle(8000);
        expect(tester.takeException(), isNull, reason: name);
      }

      Future<void> end() async {
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).hitTestable().first,
        );
        for (var i = 0; i < 5; i++) {
          scroll.position.jumpTo(scroll.position.maxScrollExtent);
          await settle(300);
        }
      }

      app.main();
      await waitFor(find.byKey(const Key('hours-hour-invitatorium')));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final savedDioceses = container.read(dioceseSelectionProvider);
      Future<void> homeTop() async {
        final scrolls = find.descendant(
          of: find.byType(HomeScreen),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        );
        if (scrolls.evaluate().isNotEmpty) {
          tester.state<ScrollableState>(scrolls.first).position.jumpTo(0);
          await settle();
        }
      }

      Future<void> date(DateTime value, {String? dayId}) async {
        container
            .read(liturgicalNavigationControllerProvider)
            .openDate(value, dayId: dayId);
        await settle();
        await homeTop();
      }

      Future<void> go(String location) async {
        router.go(location);
        await settle(1500);
        await homeTop();
        final ordo = find.byKey(const Key('ordo-scroll'));
        if (ordo.evaluate().isNotEmpty) {
          tester
              .state<ScrollableState>(
                find
                    .descendant(of: ordo, matching: find.byType(Scrollable))
                    .first,
              )
              .position
              .jumpTo(0);
          await settle();
        }
      }

      for (final dark in [false, true]) {
        appThemeModeController.value = dark ? ThemeMode.dark : ThemeMode.light;
        final theme = dark ? 'dark' : 'light';
        await go('/hours');
        await date(DateTime(2026, 10, 9));
        await shot('$theme-hours-9');
        await tap(find.byKey(const Key('hours-alternatives-control')));
        expect(find.byType(LiturgicalMonthCalendar), findsNothing);
        await shot('$theme-hours-options');
        final options = container
            .read(hoursLiturgicalSelectionProvider)
            .sortedOptions;
        final dionysius = options.firstWhere(
          (o) => o.title.contains('Дыянісія'),
        );
        await tap(find.byKey(ValueKey('hours-celebration-${dionysius.key}')));
        expect(find.byType(HoursOptionsSheet), findsOneWidget);
        await tap(find.text('Гатова'));
        await homeTop();
        await shot('$theme-hours-long-title');
        await tap(find.byKey(const Key('hours-date-action')));
        expect(find.byType(LiturgicalMonthCalendar), findsOneWidget);
        await shot('$theme-hours-date-calendar');
        await tap(find.byKey(const Key('ordo-day-2026-10-07')));
        expect(find.byType(LiturgicalCalendarSheet), findsOneWidget);
        final rosary = container
            .read(hoursLiturgicalSelectionProvider)
            .selected!;
        await tap(
          find.byKey(ValueKey('hours-template-${rosary.templates.last.id}')),
        );
        await shot('$theme-hours-rosary-formular');
        await tap(find.text('Гатова'));

        await go('/readings');
        await date(DateTime(2026, 10, 9));
        await waitFor(find.byType(ReadingsScreen));
        await shot('$theme-readings-9');
        await tap(find.byKey(const Key('readings-alternatives-control')));
        await shot('$theme-readings-options');
        await tap(
          find.byKey(ValueKey('readings-celebration-${dionysius.key}')),
        );
        expect(find.byKey(const Key('readings-options-sheet')), findsOneWidget);
        await shot('$theme-readings-dionysius-open');
        final weekday = options.firstWhere((o) => o.ordo?.kind == 'temporal');
        await tap(find.byKey(ValueKey('readings-celebration-${weekday.key}')));
        await tap(find.byKey(const ValueKey('readings-cycle-1')));
        expect(find.byKey(const Key('readings-options-sheet')), findsOneWidget);
        await shot('$theme-readings-year1-open');
        await tap(find.byKey(const Key('readings-options-done')));
        await tap(find.byKey(const Key('readings-date-action')));
        expect(find.byType(LiturgicalMonthCalendar), findsOneWidget);
        await shot('$theme-readings-date-calendar');
        await tap(find.byKey(const Key('ordo-day-2026-10-10')));
        expect(find.byKey(const Key('readings-options-sheet')), findsOneWidget);
        final marian = container
            .read(hoursLiturgicalSelectionProvider)
            .sortedOptions
            .where((o) => o.ordo != null && o.ordo?.kind != 'temporal')
            .last;
        await tap(find.byKey(ValueKey('readings-celebration-${marian.key}')));
        await shot('$theme-readings-10-selection-open');
        await tap(find.byKey(const Key('readings-options-done')));

        await go('/hours/ordo?date=2026-10-09');
        await shot('$theme-ordo-9');
        await tap(find.byKey(const Key('ordo-date-action')));
        await tap(find.byKey(const Key('ordo-day-2026-10-10')));
        expect(find.byType(OrdoScreen), findsOneWidget);
        expect(
          find.byKey(const Key('compact-liturgical-calendar')),
          findsNothing,
        );
        await go('/hours/ordo?date=2026-08-26');
        expect(find.text('26 жніўня 2026'), findsOneWidget);
        await tap(find.byKey(const Key('ordo-dioceses')));
        for (final id in ['grodno', 'vitebsk']) {
          if (!container.read(dioceseSelectionProvider).contains(id)) {
            await tap(find.byKey(Key('ordo-diocese-$id')));
          }
        }
        await shot('$theme-ordo-dioceses');
        await tap(find.text('Гатова'));
        await shot('$theme-ordo-differences');
        await go('/settings');
        await tap(find.byKey(const Key('settings-diocese-vitebsk')));
        expect(
          container.read(dioceseSelectionProvider).contains('vitebsk'),
          isFalse,
        );
        await tap(find.byKey(const Key('settings-diocese-vitebsk')));
        await shot('$theme-settings-dioceses');
        await go('/hours/ordo/month?date=2026-08-26');
        await shot('$theme-ordo-month');

        await go('/hours');
        await date(DateTime(2026, 10, 1));
        await shot('$theme-hours-teresa');
        await date(DateTime(2026, 10, 7));
        await tap(find.byKey(const Key('hours-hour-invitatorium')));
        await shot('$theme-hour-header');
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).hitTestable().first,
        );
        scroll.position.jumpTo(600);
        await settle();
        await shot('$theme-hour-scrolled');
        await tap(find.byKey(const Key('hour-switcher-pill')));
        await shot('$theme-hour-picker');
        await tester.binding.handlePopRoute();
        await settle();
        await tap(find.byKey(const Key('text-scale-open')));
        await shot('$theme-hour-aa');
        await tester.binding.handlePopRoute();
        await settle();
        await end();
        await shot('$theme-hour-end');
        expect(
          find.byKey(const Key('ora-next-hour')).hitTestable(),
          findsOneWidget,
        );
        await tap(find.byKey(const Key('ora-next-hour')));
        await shot('$theme-hour-next');
        final nextHour = tester.widget<OraScreen>(find.byType(OraScreen));
        expect(nextHour.oraType, isNot('invitatorium'));
        expect(
          DateUtils.isSameDay(nextHour.date, DateTime(2026, 10, 7)),
          isTrue,
        );
        await tap(find.byKey(const Key('reader-chrome-back')));
        await go('/readings?date=2026-12-25');
        await tap(find.byKey(const Key('readings-alternatives-control')));
        await shot('$theme-christmas-sets');
        await tap(find.byKey(const Key('readings-options-done')));
      }
      debugPrint('POLISH_FONT_SCALE::2');
      await settle(6000);
      await go('/hours');
      await date(DateTime(2026, 10, 1));
      await shot('large-hours-teresa');
      await tap(find.byKey(const Key('hours-date-action')));
      await shot('large-hours-calendar');
      await tap(find.text('Гатова'));
      await go('/readings');
      await date(DateTime(2026, 10, 9));
      await tap(find.byKey(const Key('readings-date-action')));
      await shot('large-readings-calendar');
      await tap(find.byKey(const Key('readings-options-done')));
      await go('/hours');
      await date(DateTime(2026, 10, 7));
      await tap(find.byKey(const Key('hours-hour-invitatorium')));
      tester
          .state<ScrollableState>(find.byType(Scrollable).hitTestable().first)
          .position
          .jumpTo(600);
      await shot('large-hour-scrolled');
      await end();
      await shot('large-hour-end');
      await tap(find.byKey(const Key('ora-next-hour')));
      tester
          .state<ScrollableState>(find.byType(Scrollable).hitTestable().first)
          .position
          .jumpTo(700);
      await shot('large-hour-long-label');
      debugPrint('POLISH_FONT_SCALE::1');
      await settle(6000);
      // Restore the emulator's saved calendar selection after the audit.
      final notifier = container.read(dioceseSelectionProvider.notifier);
      notifier.setPrimary(savedDioceses.primary);
      for (final id in [...container.read(dioceseSelectionProvider).selected]) {
        if (!savedDioceses.contains(id)) notifier.toggle(id);
      }
      for (final id in savedDioceses.selected) {
        if (!container.read(dioceseSelectionProvider).contains(id)) {
          notifier.toggle(id);
        }
      }
      appThemeModeController.value = ThemeMode.light;
      await go('/hours');
      await shot('finished-hours');
      debugPrint('POLISH_DONE');
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
