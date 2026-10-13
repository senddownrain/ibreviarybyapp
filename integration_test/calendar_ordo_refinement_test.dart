import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mybrev_flutter/main.dart' as app;
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/screens/home_screen.dart';
import 'package:mybrev_flutter/screens/readings_screen.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/theme/app_theme_controller.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_disclosure.dart';
import 'package:mybrev_flutter/widgets/ordo/liturgical_month_calendar.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real Android calendar, shared dates and Ordo details',
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

      Future<void> reveal(Finder finder, [double alignment = .15]) async {
        await Scrollable.ensureVisible(
          tester.element(finder.first),
          alignment: alignment,
        );
        await settle();
      }

      Future<void> tap(Finder finder) async {
        await reveal(finder);
        await tester.tap(finder.first);
        await settle();
      }

      Future<void> top(Finder root) async {
        final scrollable = find
            .descendant(
              of: root,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              ),
            )
            .first;
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await settle();
      }

      Future<void> expand(Finder title) async {
        await reveal(title);
        final controller = ExpansibleController.of(tester.element(title));
        if (!controller.isExpanded) await tap(title);
      }

      Future<void> shot(String name) async {
        await settle();
        debugPrint('QUIET_BOOK_SCREEN::$name');
        await Future<void>.delayed(const Duration(seconds: 2));
        expect(tester.takeException(), isNull, reason: name);
      }

      Finder section(String id, String date, String label) => find
          .descendant(
            of: find.byKey(PageStorageKey('ordo-$id-$date')),
            matching: find.text(label),
          )
          .first;
      app.main();
      await waitFor(find.byKey(const Key('hours-hour-laudes')));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final navigation = container.read(liturgicalNavigationControllerProvider);
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        appThemeModeController.value = dark ? ThemeMode.dark : ThemeMode.light;
        router.go('/hours');
        navigation.openDate(DateTime(2026, 10, 9));
        await settle();
        await top(find.byType(HomeScreen));
        await shot('$theme-hours-9-date');
        await tap(find.byKey(const Key('hours-alternatives-control')));
        expect(
          tester
              .widget<LiturgicalCalendarDisclosure>(
                find.byType(LiturgicalCalendarDisclosure),
              )
              .expanded,
          isFalse,
        );
        await shot('$theme-hours-calendar-collapsed');
        await tap(find.byKey(const Key('liturgical-calendar-toggle')));
        await shot('$theme-hours-calendar-expanded');
        await tap(find.byKey(const Key('ordo-day-2026-10-10')));
        expect(
          find.byKey(const Key('liturgical-calendar-toggle')),
          findsOneWidget,
        );
        await tap(find.byKey(const Key('ordo-day-2026-10-09')));
        await tap(find.byKey(const Key('liturgical-calendar-toggle')));
        await tap(find.text('Гатова'));
        await tap(find.byKey(const Key('hours-date-action')));
        expect(find.byType(LiturgicalMonthCalendar), findsOneWidget);
        await tap(find.text('Гатова'));

        router.go('/readings');
        await settle();
        await top(find.byType(ReadingsScreen));
        await shot('$theme-readings-9-date');
        await tap(find.byKey(const Key('readings-alternatives-control')));
        expect(
          tester
              .widget<LiturgicalCalendarDisclosure>(
                find.byType(LiturgicalCalendarDisclosure),
              )
              .expanded,
          isFalse,
        );
        await shot('$theme-readings-calendar-collapsed');
        final alternative = container
            .read(hoursLiturgicalSelectionProvider)
            .sortedOptions
            .firstWhere((option) => option.ordo?.role == 'alternative');
        await tap(
          find.byKey(ValueKey('readings-celebration-${alternative.key}')),
        );
        expect(find.byKey(const Key('readings-options-sheet')), findsOneWidget);
        expect(
          tester
              .widget<LiturgicalCalendarDisclosure>(
                find.byType(LiturgicalCalendarDisclosure),
              )
              .expanded,
          isFalse,
        );
        await tap(find.byKey(const Key('readings-calendar-disclosure')));
        await shot('$theme-readings-calendar-expanded');
        await tap(find.byKey(const Key('ordo-day-2026-10-10')));
        expect(find.byKey(const Key('readings-options-sheet')), findsOneWidget);
        expect(
          tester
              .widget<LiturgicalCalendarDisclosure>(
                find.byType(LiturgicalCalendarDisclosure),
              )
              .expanded,
          isTrue,
        );
        await tap(find.byKey(const Key('ordo-day-2026-10-09')));
        await tap(find.byKey(const Key('readings-options-done')));
        await tap(find.byKey(const Key('readings-date-action')));
        expect(find.byType(LiturgicalMonthCalendar), findsOneWidget);
        await tap(find.byKey(const Key('readings-options-done')));

        router.go('/hours/ordo?date=2026-10-09');
        await settle(1200);
        await top(find.byKey(const Key('ordo-scroll')));
        await shot('$theme-ordo-9-date');
        await reveal(section('office', '2026-10-09', 'Літургія гадзінаў'));
        await shot('$theme-ordo-closed');
        router.go('/hours/ordo?date=2026-10-11');
        await settle(1200);
        await top(find.byKey(const Key('ordo-scroll')));
        expect(find.text('Іншыя святкаванні дня'), findsNothing);
        await shot('$theme-ordo-11');
        router.go('/hours/ordo?date=2026-04-04');
        await settle(1200);
        await top(find.byKey(const Key('ordo-scroll')));
        await shot('$theme-ordo-4-april-date');
        await tap(section('directions', '2026-04-04', 'Асаблівыя ўказанні'));
        await reveal(section('directions', '2026-04-04', 'Асаблівыя ўказанні'));
        await shot('$theme-ordo-directions');
        await tap(section('office', '2026-04-04', 'Літургія гадзінаў'));
        await reveal(section('office', '2026-04-04', 'Літургія гадзінаў'));
        await shot('$theme-ordo-two-sections');
        await tap(section('notes', '2026-04-04', 'Літургічныя заўвагі'));
        await reveal(section('notes', '2026-04-04', 'Літургічныя заўвагі'));
        await shot('$theme-ordo-notes');
        router.go('/hours/ordo?date=2026-10-11');
        await settle(1200);
        await expand(section('books', '2026-10-11', 'Літургічныя кнігі'));
        await reveal(section('books', '2026-10-11', 'Літургічныя кнігі'));
        await shot('$theme-ordo-books');
        await expand(section('office', '2026-10-11', 'Літургія гадзінаў'));
        await expand(section('directions', '2026-10-11', 'Асаблівыя ўказанні'));
        await expand(section('notes', '2026-10-11', 'Літургічныя заўвагі'));
        await reveal(section('office', '2026-10-11', 'Літургія гадзінаў'));
        await shot('$theme-ordo-all-open-top');
        await reveal(section('books', '2026-10-11', 'Літургічныя кнігі'));
        await shot('$theme-ordo-all-open-bottom');
      }
      debugPrint('QUIET_BOOK_FONT_SCALE::2');
      await Future<void>.delayed(const Duration(seconds: 3));
      appThemeModeController.value = ThemeMode.light;
      router.go('/hours');
      navigation.openDate(DateTime(2026, 4, 4));
      await settle();
      await top(find.byType(HomeScreen));
      await shot('large-hours-date');
      await tap(find.byKey(const Key('hours-date-action')));
      await tap(find.byKey(const Key('liturgical-calendar-toggle')));
      await shot('large-hours-calendar-collapsed');
      await tap(find.byKey(const Key('liturgical-calendar-toggle')));
      await shot('large-hours-calendar-expanded');
      await tap(find.text('Гатова'));
      router.go('/readings');
      await settle();
      await top(find.byType(ReadingsScreen));
      await shot('large-readings-date');
      await tap(find.byKey(const Key('readings-date-action')));
      await tap(find.byKey(const Key('readings-calendar-disclosure')));
      await shot('large-readings-calendar-collapsed');
      await tap(find.byKey(const Key('readings-calendar-disclosure')));
      await shot('large-readings-calendar-expanded');
      await tap(find.byKey(const Key('readings-options-done')));
      router.go('/hours/ordo?date=2026-04-04');
      await settle(1200);
      await top(find.byKey(const Key('ordo-scroll')));
      await shot('large-ordo-date');
      await expand(section('directions', '2026-04-04', 'Асаблівыя ўказанні'));
      await shot('large-ordo-directions');
      await expand(section('notes', '2026-04-04', 'Літургічныя заўвагі'));
      await shot('large-ordo-notes');
      router.go('/hours/ordo?date=2026-10-11');
      await settle(1200);
      await expand(section('books', '2026-10-11', 'Літургічныя кнігі'));
      await shot('large-ordo-books');
      debugPrint('QUIET_BOOK_FONT_SCALE::restore');
      await Future<void>.delayed(const Duration(seconds: 3));
      router.go('/hours');
      await settle();
      debugPrint('QUIET_BOOK_CAPTURE_DONE');
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
