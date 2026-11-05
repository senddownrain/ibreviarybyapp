import 'dart:io';
import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart' as production;
import 'package:mybrev_flutter/screens/ora_screen.dart';
import 'package:mybrev_flutter/screens/home_screen.dart';
import 'package:mybrev_flutter/widgets/hours_options_sheet.dart';
import 'package:mybrev_flutter/screens/ordo_screen.dart';
import 'package:mybrev_flutter/screens/readings_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/widgets/ambient_date_picker.dart';
import 'package:mybrev_flutter/widgets/ordo/liturgical_month_calendar.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_sheet.dart';
import 'package:mybrev_flutter/screens/liturgical_picker_screen.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';

class _Idle extends ContentUpdatesNotifier {
  @override
  ContentUpdateState build() => const ContentUpdateState();
  @override
  Future<void> checkIfDue() async {}
}

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
  @override
  void rememberLastSection(String section) {}
}

class _AllDioceses extends DioceseSelectionNotifier {
  @override
  DioceseSelection build() => const DioceseSelection(
    selected: ['grodno', 'vitebsk'],
    primary: 'vitebsk',
  );
}

class _MinskDiocese extends DioceseSelectionNotifier {
  @override
  DioceseSelection build() => const DioceseSelection(
    selected: ['minsk-mohilev'],
    primary: 'minsk-mohilev',
  );
}

TapGestureRecognizer? _tapIn(InlineSpan span) {
  if (span is! TextSpan) return null;
  if (span.recognizer is TapGestureRecognizer) {
    return span.recognizer as TapGestureRecognizer;
  }
  for (final child in span.children ?? <InlineSpan>[]) {
    final tap = _tapIn(child);
    if (tap != null) return tap;
  }
  return null;
}

void main() {
  final date = DateTime(2026, 10, 7);
  final service = LiturgicalContentService();
  late Directory directory;
  DayOption rosary() => service
      .contentForDate(date)
      .options
      .singleWhere((o) => o.optionId == 'our-lady-rosary');

  setUpAll(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('ordo-flow-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('Rosary memorial has default weekday and assembled Marian Office', () {
    final ordo = OrdoRuntime.engine.resolve('2026-10-07');
    expect(ordo.primary.id, 'our-lady-rosary');
    expect(ordo.primary.rank, 'memoria');
    expect(ordo.office(ordo.primary.id)!.officeKind, 'memorial');
    final option = rosary();
    expect(
      option.templates.map((t) => t.label),
      containsAll(['З дня', 'Пра Найсвяцейшую Панну Марыю']),
    );
    final automatic = resolveHoursLiturgicalSelection([option]);
    expect(automatic.template!.label, 'З дня');
    expect(automatic.hasCelebrationAlternatives, isFalse);
    expect(automatic.hasOfficeTemplates, isTrue);
    expect(automatic.hasLiturgicalChoices, isTrue);
    final common = option.templates.singleWhere(
      (t) => t.choice == 'blessed-virgin-mary',
    );
    final selected = resolveHoursLiturgicalSelection([
      option,
    ], selectedDayId: common.id);
    expect(selected.template, common);
    expect(
      selected.day!.data['_assembly'],
      containsPair('choice', 'blessed-virgin-mary'),
    );
    final resolved = service.resolveDayLocal(
      date,
      common.id,
      null,
      null,
      null,
    )!;
    expect(resolved.id, common.id);
    expect(resolved.data['_assembly'], common.day.data['_assembly']);
    expect(resolved.field('laudesHymn'), common.day.field('laudesHymn'));
    final commonData = HiveService.templates()['blessed-virgin-mary']!;
    // The Marian Common carries `_mainSection` (docs/common-office-web-parity.md,
    // PR #22): a memorial assembles its main hymn, not every alternative.
    final main = commonData['_mainSection'] as Map;
    expect(
      common.day.field('officeOfReadingsHymn'),
      main['officeOfReadingsHymn'],
    );
  });

  test('Office assemblies share memorial readings in ORDO order', () {
    final readings = ParsedReadingsService();
    final calendar = CalendarService();
    final selections = rosary().templates.map(
      (t) => readings.ordoSelection(date, dayId: t.id)!,
    );
    expect(selections.every((s) => s.memorial), isTrue);
    for (final template in rosary().templates) {
      final docs = readings.cachedForDate(
        date,
        calendar.getYearOptionsCached(2026),
        calendar.getYearOptionsCached(2027),
        calendar.getDynamicDatesCached(2026),
        dayId: template.id,
        includeAlternatives: true,
      )!;
      expect(docs.first.id, startsWith('ordinary-w27-d4--'));
      expect(
        docs.map((d) => d.id),
        containsAll(
          readings
              .cachedForDate(
                date,
                calendar.getYearOptionsCached(2026),
                calendar.getYearOptionsCached(2027),
                calendar.getDynamicDatesCached(2026),
                dayId: rosary().dayId,
                includeAlternatives: true,
              )!
              .map((d) => d.id),
        ),
      );
    }
  });

  Future<(GoRouter, ProviderContainer)> start(
    WidgetTester tester, {
    String location = '/hours',
    double scale = 1,
    double width = 360,
    bool onlyRosary = false,
    bool onlyMinsk = false,
    DateTime? selectedDate,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        selectedDateProvider.overrideWith((ref) => selectedDate ?? date),
        if (onlyRosary) dayOptionsProvider.overrideWithValue([rosary()]),
        if (onlyMinsk) dioceseSelectionProvider.overrideWith(_MinskDiocese.new),
        liturgicalContentReadyProvider.overrideWith((ref) async {}),
        contentUpdatesProvider.overrideWith(_Idle.new),
        settingsProvider.overrideWith(_Settings.new),
      ],
    );
    final router = GoRouter(
      initialLocation: location,
      navigatorKey: production.rootNavigatorKey,
      routes: production.router.configuration.routes,
    );
    addTearDown(() async {
      // Remove metric observers and consumers before releasing their scope.
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(
            platform: TargetPlatform.android,
            brightness: brightness,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewPadding: const EdgeInsets.only(bottom: 24),
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (router, container);
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      final vertical = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last;
      tester.state<ScrollableState>(vertical).position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(target, 200, scrollable: vertical);
    }
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> checkPalette(WidgetTester tester) async {
    final text = find.byWidgetPredicate(
      (widget) => widget is RichText && _tapIn(widget.text) != null,
    );
    final target = text.first;
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pumpAndSettle();
    _tapIn(tester.widget<RichText>(target).text)!.onTap!();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('readings-highlight-palette')), findsOneWidget);
    expect(find.byKey(const Key('app-dock-android')), findsNothing);
    expect(
      find.byKey(const Key('readings-highlight-amber')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('readings-highlight-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-dock-android')), findsOneWidget);
  }

  // ORDO is a separate route. Header calendar actions now open the shared
  // month sheet; these tests enter ORDO explicitly to exercise its own flow.
  Future<void> openOrdo(WidgetTester tester) async {
    final context = tester.element(find.byType(HomeScreen));
    final container = ProviderScope.containerOf(context);
    final selected = container.read(hoursLiturgicalSelectionProvider);
    GoRouter.of(context).push(
      Uri(
        path: '/hours/ordo',
        queryParameters: {
          'date': liturgicalDateKey(container.read(selectedDateProvider)),
          if (selected.dayId != null) 'dayId': selected.dayId!,
          if (selected.diocese != null) 'diocese': selected.diocese!,
        },
      ).toString(),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Hours exposes both Office choices even with one celebration', (
    tester,
  ) async {
    final (router, container) = await start(tester, onlyRosary: true);
    await tapVisible(
      tester,
      find.byKey(const Key('hours-alternatives-control')),
    );
    final sheet = find.byType(HoursOptionsSheet);
    expect(
      find.descendant(of: sheet, matching: find.text(rosary().title)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('СВЯТКАВАННЕ')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('hours-celebration-${rosary().key}')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('hours-single-celebration')), findsNothing);
    final option = rosary();
    for (final template in option.templates) {
      await tapVisible(
        tester,
        find.byKey(Key('hours-template-${template.id}')),
      );
      expect(
        container.read(hoursLiturgicalSelectionProvider).dayId,
        template.id,
      );
    }
    await tester.tap(find.byTooltip('Закрыць').last);
    await tester.pumpAndSettle();
    await openOrdo(tester);
    expect(find.byType(OrdoScreen), findsOneWidget);
    expect(
      tester.widget<OrdoScreen>(find.byType(OrdoScreen)).dayId,
      option.templates.last.id,
    );
    expect(find.byKey(const Key('app-dock-full')), findsNothing);
    expect(find.text('Ютрань'), findsNothing);
    await tapVisible(tester, find.byKey(const Key('ordo-open-hours')));
    await tapVisible(
      tester,
      find.byKey(ValueKey('ordo-hour-template-${option.templates.last.id}')),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      container.read(hoursLiturgicalSelectionProvider).dayId,
      option.templates.last.id,
    );
    await tapVisible(tester, find.text('Ютрань'));
    expect(
      tester.widget<OraScreen>(find.byType(OraScreen)).dayId,
      option.templates.last.id,
    );
    router.pop();
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.byKey(const Key('hours-alternatives-control')),
    );
    await tapVisible(
      tester,
      find.byKey(Key('hours-template-${option.templates.first.id}')),
    );
    await tester.tap(find.byTooltip('Закрыць').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Ютрань'));
    expect(
      tester.widget<OraScreen>(find.byType(OraScreen)).dayId,
      option.templates.first.id,
    );
  });

  testWidgets('October 9 selector and ORDO keep the chosen memorial Office', (
    tester,
  ) async {
    final (_, container) = await start(
      tester,
      selectedDate: DateTime(2026, 10, 9),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('hours-alternatives-control')),
    );
    final sheet = find.byType(HoursOptionsSheet);
    expect(
      find.descendant(
        of: sheet,
        matching: find.byType(LiturgicalMonthCalendar),
      ),
      findsNothing,
    );
    final option = container
        .read(hoursLiturgicalSelectionProvider)
        .sortedOptions
        .singleWhere((o) => o.title.contains('Леанардзі'));
    await tapVisible(
      tester,
      find.byKey(ValueKey('hours-celebration-${option.key}')),
    );
    final template = option.templates.last;
    await tapVisible(
      tester,
      find.byKey(ValueKey('hours-template-${template.id}')),
    );
    await tester.tap(find.byTooltip('Закрыць').last);
    await tester.pumpAndSettle();
    expect(find.byType(HoursOptionsSheet), findsNothing);
    expect(container.read(hoursLiturgicalSelectionProvider).dayId, template.id);
    await openOrdo(tester);
    await tapVisible(tester, find.text('Літургія гадзінаў').first);
    expect(find.text(template.label), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(Key('ordo-template-${template.id}')),
        matching: find.text('Абрана'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ordo-open-readings')), findsOneWidget);
    expect(find.byType(RadioListTile<String>), findsNothing);
    await tapVisible(tester, find.byKey(const Key('ordo-open-hours')));
    await tapVisible(
      tester,
      find.byKey(ValueKey('ordo-hour-template-${template.id}')),
    );
    expect(container.read(hoursLiturgicalSelectionProvider).dayId, template.id);
    expect(container.read(selectedDateProvider), DateTime(2026, 10, 9));
  });

  testWidgets('Day → ORDO → Month → Day → back preserves month cursor', (
    tester,
  ) async {
    final (router, container) = await start(tester);
    await openOrdo(tester);
    expect(find.byType(LiturgicalMonthCalendar), findsNothing);
    expect(find.byKey(const Key('app-dock-full')), findsNothing);
    await tapVisible(tester, find.byKey(const Key('ordo-open-month')));
    expect(find.byType(LiturgicalMonthCalendar), findsNothing);
    expect(find.byKey(const Key('ordo-month-list')), findsOneWidget);
    expect(
      production
          .appShellState
          .activeController
          .activeDescriptor
          .showsNavigationDock,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('ordo-next-month')));
    await tester.pumpAndSettle();
    final monthScroll = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('ordo-month-list')),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .pixels;
    expect(
      find.byKey(const Key('ordo-day-2026-11-02')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ordo-day-2026-11-02')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OrdoScreen>(find.byType(OrdoScreen))
          .initialDate
          .toIso8601String()
          .substring(0, 10),
      '2026-11-02',
    );
    expect(container.read(selectedDateProvider), DateTime(2026, 11, 2));
    await tester.tap(find.byTooltip('Назад').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ordo-day-2026-11-02')), findsOneWidget);
    expect(
      tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const Key('ordo-month-list')),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .pixels,
      monthScroll,
    );
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(LiturgicalMonthCalendar), findsNothing);
    expect(find.byType(OrdoScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Назад').last);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(container.read(selectedDateProvider), DateTime(2026, 11, 2));
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('month taps and Back $brightness $scale', (tester) async {
        final (_, container) = await start(
          tester,
          selectedDate: DateTime(2026, 10, 31),
          width: scale == 1.5 ? 320 : 390,
          brightness: brightness,
          scale: scale,
        );
        await openOrdo(tester);
        await tapVisible(tester, find.byKey(const Key('ordo-open-month')));
        await tester.tap(find.byKey(const Key('ordo-next-month')));
        await tester.pumpAndSettle();
        final first = find.byKey(const Key('ordo-day-2026-11-01'));
        expect(first.hitTestable(), findsOneWidget);
        await tester.tap(first);
        await tester.pumpAndSettle();
        expect(container.read(selectedDateProvider), DateTime(2026, 11, 1));
        await tapVisible(tester, find.byKey(const Key('ordo-next-day')));
        expect(container.read(selectedDateProvider), DateTime(2026, 11, 2));
        await tapVisible(tester, find.byKey(const Key('ordo-previous-day')));
        expect(container.read(selectedDateProvider), DateTime(2026, 11, 1));
        await tester.tap(find.byTooltip('Назад').last);
        await tester.pumpAndSettle();
        expect(first.hitTestable(), findsOneWidget);

        // Scroll and return from a later day to check a nonzero month cursor.
        final later = find.byKey(const Key('ordo-day-2026-11-15'));
        await Scrollable.ensureVisible(tester.element(later), alignment: .25);
        await tester.pumpAndSettle();
        final scroll = tester.state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('ordo-month-list')),
            matching: find.byType(Scrollable),
          ),
        );
        final offset = scroll.position.pixels;
        expect(offset, greaterThan(0));
        expect(later.hitTestable(), findsOneWidget);
        await tester.tap(later);
        await tester.pumpAndSettle();
        expect(container.read(selectedDateProvider), DateTime(2026, 11, 15));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, offset);
        expect(later.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('ORDO actions preserve date, option and temporary diocese', (
    tester,
  ) async {
    final (router, container) = await start(
      tester,
      location: '/hours/ordo?date=2026-10-07&diocese=pinsk',
    );
    final primaryDiocese = container.read(dioceseSelectionProvider).primary;
    await tapVisible(tester, find.byKey(const Key('ordo-open-readings')));
    final query = GoRouterState.of(
      tester.element(find.byType(ReadingsScreen)),
    ).uri.queryParameters;
    expect(query['date'], '2026-10-07');
    expect(query['dayId'], rosary().dayId);
    expect(query['diocese'], 'pinsk');
    expect(query['option'], 'our-lady-rosary');
    expect(container.read(dioceseSelectionProvider).primary, primaryDiocese);
    router.pop();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('ordo-open-hours')));
    await tapVisible(
      tester,
      find.byKey(ValueKey('ordo-hour-template-${rosary().dayId}')),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(container.read(selectedDateProvider), date);
    expect(
      container.read(hoursLiturgicalSelectionProvider).dayId,
      rosary().dayId,
    );
    expect(
      container.read(hoursLiturgicalOverridesProvider)['2026-10-07']?.diocese,
      'pinsk',
    );
    expect(container.read(dioceseSelectionProvider).primary, primaryDiocese);
  });

  testWidgets(
    'Readings keep the selected assembly identity and celebration plan',
    (tester) async {
      final common = rosary().templates.last;
      await start(
        tester,
        location:
            '/hours/ordo?date=2026-10-07&diocese=pinsk&dayId=${common.id}',
      );
      await tapVisible(tester, find.byKey(const Key('ordo-open-readings')));
      final query = GoRouterState.of(
        tester.element(find.byType(ReadingsScreen)),
      ).uri.queryParameters;
      expect(query['dayId'], common.id);
      expect(query['option'], 'our-lady-rosary');
      expect(query['diocese'], 'pinsk');
      expect(
        ParsedReadingsService()
            .ordoSelection(date, dayId: query['dayId'], diocese: 'pinsk')!
            .memorial,
        isTrue,
      );
    },
  );

  testWidgets('An alternative celebration keeps its reading route context', (
    tester,
  ) async {
    await start(
      tester,
      location:
          '/hours/ordo?date=2026-10-06&diocese=pinsk&dayId=06-10-sv-bruno',
    );
    await tapVisible(tester, find.byKey(const Key('ordo-open-readings')));
    final query = GoRouterState.of(
      tester.element(find.byType(ReadingsScreen)),
    ).uri.queryParameters;
    expect(query['date'], '2026-10-06');
    expect(query['dayId'], '06-10-sv-bruno');
    expect(query['option'], 'sv-bruno');
    expect(query['diocese'], 'pinsk');
  });

  testWidgets('Hours date action updates the visible selected day', (
    tester,
  ) async {
    final (_, container) = await start(tester);
    await tester.tap(find.byKey(const Key('hours-date-action')));
    await tester.pumpAndSettle();
    expect(find.byType(LiturgicalMonthCalendar), findsOneWidget);
    await tester.tap(find.byKey(const Key('ordo-day-2026-10-08')));
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), DateTime(2026, 10, 8));
    expect(
      find.byKey(ValueKey('hours-root-${DateTime(2026, 10, 8)}')),
      findsOneWidget,
    );
    expect(find.byType(OrdoScreen), findsNothing);
    expect(find.byType(LiturgicalCalendarSheet), findsOneWidget);
    expect(find.byKey(const Key('compact-liturgical-calendar')), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('ORDO reused route adopts its new date and source', (
    tester,
  ) async {
    final (router, container) = await start(
      tester,
      location: '/hours/ordo?date=2026-10-09',
    );
    await tapVisible(tester, find.byKey(const Key('ordo-next-day')));
    expect(container.read(selectedDateProvider), DateTime(2026, 10, 10));
    router.go('/hours/ordo?date=2026-08-26&diocese=grodno');
    await tester.pumpAndSettle();
    expect(find.byType(OrdoScreen), findsOneWidget);
    expect(find.text('26 жніўня 2026'), findsOneWidget);
    expect(container.read(selectedDateProvider), DateTime(2026, 8, 26));
    expect(container.read(hoursLiturgicalSelectionProvider).diocese, 'grodno');
  });

  testWidgets('Hours calendar icon opens the day; arrows keep one route', (
    tester,
  ) async {
    final (router, container) = await start(tester);
    await tapVisible(tester, find.byKey(const Key('hours-calendar-action')));
    expect(find.byType(OrdoScreen), findsOneWidget);
    expect(find.byType(LiturgicalCalendarSheet), findsNothing);
    final location = router.routeInformationProvider.value.uri;
    await tapVisible(tester, find.byKey(const Key('ordo-next-day')));
    expect(container.read(selectedDateProvider), DateTime(2026, 10, 8));
    expect(
      container.read(readingsBranchStateProvider).date,
      DateTime(2026, 10, 8),
    );
    expect(find.text('8 кастрычніка 2026'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri, location);
    await tapVisible(tester, find.byKey(const Key('ordo-previous-day')));
    expect(find.text(rosary().title), findsOneWidget);
    expect(container.read(selectedDateProvider), date);
  });

  testWidgets(
    'ORDO date-only calendar applies without closing and preserves shared dioceses',
    (tester) async {
      final (_, container) = await start(
        tester,
        location: '/hours/ordo?date=2026-10-06&diocese=pinsk',
        selectedDate: DateTime(2026, 10, 6),
      );
      final settings = container.read(dioceseSelectionProvider);
      await tapVisible(tester, find.byKey(const Key('ordo-date-action')));
      await tapVisible(tester, find.byKey(const Key('ordo-day-2026-10-07')));
      expect(
        find.byKey(const Key('compact-liturgical-calendar')),
        findsOneWidget,
      );
      expect(find.byType(OrdoScreen), findsOneWidget);
      expect(container.read(selectedDateProvider), DateTime(2026, 10, 7));
      expect(container.read(dioceseSelectionProvider), same(settings));
      expect(find.byType(HoursOptionsSheet), findsNothing);
      await tester.tap(find.text('Гатова'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('ordo-open-hours')));
      await tapVisible(
        tester,
        find.byKey(
          ValueKey('ordo-hour-template-${rosary().templates.last.id}'),
        ),
      );
      expect(
        container.read(hoursLiturgicalSelectionProvider).dayId,
        rosary().templates.last.id,
      );
      expect(
        container.read(hoursLiturgicalSelectionProvider).diocese,
        settings.primary,
      );
    },
  );

  testWidgets(
    'ORDO dioceses persist through the shared settings and Month context',
    (tester) async {
      final (_, container) = await start(
        tester,
        location: '/hours/ordo?date=2026-08-26&diocese=minsk-mohilev',
      );
      final settings = container.read(dioceseSelectionProvider);
      await tapVisible(tester, find.byKey(const Key('ordo-dioceses')));
      Future<void> toggleDiocese(String id) async {
        // Dispatch these callbacks in the real IO zone: the production
        // notifier persists to Hive as soon as the checkbox changes.
        await tester.runAsync(
          () => tester.tap(find.byKey(Key('ordo-diocese-$id'))),
        );
        await tester.pumpAndSettle();
      }

      await toggleDiocese('grodno');
      await toggleDiocese('vitebsk');
      expect(find.text('Падрабязны кантэкст'), findsNothing);
      for (final id in settings.selected.where(
        (id) => id != 'grodno' && id != 'vitebsk',
      )) {
        await toggleDiocese(id);
      }
      final shared = container.read(dioceseSelectionProvider);
      expect(shared.selected, ['grodno', 'vitebsk']);
      expect(
        DioceseSelectionNotifier.read(Hive.box('settings')).selected,
        shared.selected,
      );
      await tapVisible(tester, find.text('Гатова'));
      expect(
        find.textContaining('Выбраныя дыяцэзіі адрозніваюцца'),
        findsOneWidget,
      );
      await tapVisible(tester, find.byKey(const Key('ordo-open-readings')));
      final query = GoRouterState.of(
        tester.element(find.byType(ReadingsScreen)),
      ).uri.queryParameters;
      expect(query['diocese'], shared.primary);
      expect(container.read(dioceseSelectionProvider), same(shared));
      // Hive writes use real file IO; let the widget test drain them before
      // closing the box in tearDownAll.
      await tester.runAsync(() => Hive.box('settings').flush());
    },
  );

  for (final inset in [24.0, 48.0]) {
    testWidgets(
      'ORDO last action clears Android bottom obstruction $inset at 200 percent text',
      (tester) async {
        await start(tester, location: '/hours/ordo?date=2026-10-09', scale: 2);
        tester.view.physicalSize = const Size(320, 720);
        tester.view.viewPadding = FakeViewPadding(bottom: inset);
        tester.view.systemGestureInsets = FakeViewPadding(bottom: inset);
        await tester.pumpAndSettle();
        final action = find.byKey(const Key('ordo-bottom-month'));
        await tester.scrollUntilVisible(
          action,
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(
          find.byKey(const Key('ordo-scroll')),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        expect(action.hitTestable(), findsOneWidget);
        expect(
          tester.getBottomRight(action).dy,
          lessThanOrEqualTo(720 - inset),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Hours calendar search reaches the existing period and feast picker',
    (tester) async {
      final (router, _) = await start(tester);
      await tapVisible(tester, find.byKey(const Key('hours-date-action')));
      await tapVisible(
        tester,
        find.byKey(const Key('liturgical-calendar-picker')),
      );
      expect(find.byType(LiturgicalCalendarSheet), findsNothing);
      expect(find.byType(LiturgicalPickerScreen), findsOneWidget);
      expect(find.text('Перыяды'), findsOneWidget);
      expect(find.text('Святы'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  for (final readingsMode in [false, true]) {
    final branch = readingsMode ? 'readings' : 'hours';
    testWidgets(
      '$branch search opens impeded Nicholas texts and keeps search on Back',
      (tester) async {
        final (router, container) = await start(
          tester,
          location: '/$branch/picker',
          selectedDate: DateTime(2026, 12, 6),
          onlyMinsk: true,
        );
        final settings = container.read(dioceseSelectionProvider);
        await tester.tap(find.text('Святы'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('picker-feast-filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('picker-filter-fixed')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('picker-feast-search')),
          '06.12',
        );
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.byKey(const Key('picker-feast-sv-nicholas-2026-12-06')),
        );
        if (readingsMode) {
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.text('Скасаваць'));
          await tester.pumpAndSettle();
          expect(find.byType(LiturgicalPickerScreen), findsOneWidget);
          await tapVisible(
            tester,
            find.byKey(const Key('picker-feast-sv-nicholas-2026-12-06')),
          );
          await tester.tap(find.text('Адкрыць чытанні дня'));
          await tester.pumpAndSettle();
        }
        final uri = GoRouterState.of(
          tester.element(
            find.byType(readingsMode ? ReadingsScreen : HomeScreen).last,
          ),
        ).uri;
        if (readingsMode) {
          expect(uri.queryParameters['diocese'], 'minsk-mohilev');
        }
        if (readingsMode) {
          expect(uri.queryParameters['date'], '2027-12-06');
          expect(uri.queryParameters['option'], 'sv-nicholas');
          await checkPalette(tester);
          expect(find.byType(ReadingsScreen), findsWidgets);
          expect(find.byType(AlertDialog), findsNothing);
          final dayId = uri.queryParameters['dayId']!;
          final docs = ParsedReadingsService().cachedForDate(
            DateTime(2027, 12, 6),
            null,
            null,
            null,
            includeAlternatives: true,
            dayId: dayId,
          )!;
          expect(
            docs.any(
              (r) => r.ordoOptionRoles['sv-nicholas']?.purpose == 'weekday',
            ),
            isTrue,
          );
        } else {
          expect(uri.path, '/hours');
          final picked = container.read(hoursLiturgicalSelectionProvider);
          expect(container.read(selectedDateProvider), DateTime(2027, 12, 6));
          expect(picked.diocese, 'minsk-mohilev');
          expect(picked.selected!.optionId, 'sv-nicholas');
          expect(picked.day!.field('laudesHymn'), isNotEmpty);
          expect(
            picked.selected!.templates.map((t) => t.label),
            contains('Пра пастыраў'),
          );
          expect(
            find.textContaining('Адкрыты тэксты за 2027 год.'),
            findsOneWidget,
          );
          await tapVisible(tester, find.text('Ютрань'));
          expect(find.byType(OraScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
          router.pop();
          await tester.pumpAndSettle();
        }
        if (readingsMode) {
          await tester.tap(find.byTooltip('Назад').last);
        } else {
          router.pop();
        }
        await tester.pumpAndSettle();
        expect(find.byType(LiturgicalPickerScreen), findsOneWidget);
        final search = tester.widget<TextField>(
          find.byKey(const Key('picker-feast-search')),
        );
        expect(search.controller!.text, '06.12');
        expect(find.byTooltip('Фільтр: Нерухомыя'), findsOneWidget);
        expect(
          container.read(dioceseSelectionProvider).selected,
          settings.selected,
        );
        expect(
          container.read(dioceseSelectionProvider).primary,
          settings.primary,
        );
        expect(
          OrdoRuntime.engine
              .resolve('2026-12-06')
              .officeOptions
              .any((o) => o.id == 'sv-nicholas'),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$branch periods keep Ordinary II Tuesday navigation', (
      tester,
    ) async {
      final (router, container) = await start(
        tester,
        location: '/$branch/picker',
        selectedDate: DateTime(2026, 10, 7),
      );
      await tapVisible(tester, find.byKey(const Key('picker-period-ordinary')));
      await tapVisible(tester, find.byKey(const Key('picker-week-2')));
      await tapVisible(tester, find.byKey(const Key('picker-day-3')));
      if (readingsMode) await checkPalette(tester);
      expect(router.routeInformationProvider.value.uri.path, '/$branch');
      expect(container.read(selectedDateProvider), DateTime(2026, 1, 20));
      expect(find.byType(LiturgicalPickerScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final januaryDay in [1, 2]) {
      final iso = '2027-01-0$januaryDay';
      testWidgets('$branch Christmas opens $iso on its canonical day', (
        tester,
      ) async {
        final (router, container) = await start(
          tester,
          location: '/$branch/picker',
          selectedDate: DateTime(2026, 12, 26),
          onlyMinsk: true,
        );
        await tapVisible(
          tester,
          find.byKey(const Key('picker-period-christmas')),
        );
        await tapVisible(tester, find.byKey(Key('picker-date-$iso')));
        final date = DateTime(2027, 1, januaryDay);
        expect(router.routeInformationProvider.value.uri.path, '/$branch');
        expect(container.read(selectedDateProvider), date);
        expect(find.byType(LiturgicalPickerScreen), findsNothing);
        final canonical = OrdoRuntime.engine.resolve(iso);
        expect(canonical.period, 'christmas');
        if (readingsMode) {
          final screen = tester.widget<ReadingsScreen>(
            find.byType(ReadingsScreen),
          );
          expect(screen.dateStr, iso);
          expect(
            ParsedReadingsService()
                .ordoSelection(date, dayId: screen.dayId)!
                .optionId,
            canonical.primary.id,
          );
        } else {
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(
            service
                .contentForDate(date)
                .options
                .any((o) => o.optionId == canonical.primary.id),
            isTrue,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'movable feast search opens its proper readings in the existing reader',
    (tester) async {
      final (_, container) = await start(
        tester,
        location: '/readings/picker',
        selectedDate: DateTime(2026, 10, 7),
      );
      await tester.tap(find.text('Святы'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('picker-feast-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('picker-filter-movable')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('picker-feast-search')),
        '05.04',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Рухомае'), findsWidgets);
      await tapVisible(
        tester,
        find.byKey(const Key('picker-feast-easter-sunday-2026-04-05')),
      );
      final screen = tester.widget<ReadingsScreen>(
        find.byType(ReadingsScreen).last,
      );
      expect(screen.dateStr, '2026-04-05');
      final selection = ParsedReadingsService().ordoSelection(
        DateTime(2026, 4, 5),
        dayId: screen.dayId,
      )!;
      expect(selection.optionId, 'easter-sunday');
      final docs = ParsedReadingsService().cachedForDate(
        DateTime(2026, 4, 5),
        null,
        null,
        null,
        includeAlternatives: true,
        dayId: screen.dayId,
      )!;
      expect(
        docs.any(
          (r) => r.ordoOptionRoles['easter-sunday']?.purpose == 'proper',
        ),
        isTrue,
      );
      expect(container.read(readingsMassSetSelectionProvider), isNotEmpty);
      expect(find.textContaining('Уласных чытанняў няма.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Grodno impeded in 2027 opens Grodno in 2028, preserving Settings',
    (tester) async {
      final (router, container) = await start(
        tester,
        location: '/hours/picker',
        selectedDate: DateTime(2027, 12, 6),
      );
      final selection = container.read(dioceseSelectionProvider);
      await tester.tap(find.text('Святы'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('picker-feast-search')),
        '06.12',
      );
      await tester.pumpAndSettle();
      final rows = find.byKey(const Key('picker-feast-sv-nicholas-2027-12-06'));
      expect(rows, findsNWidgets(2));
      await tapVisible(tester, rows.last);
      expect(find.byType(HomeScreen), findsOneWidget);
      final picked = container.read(hoursLiturgicalSelectionProvider);
      expect(picked.diocese, 'grodno');
      expect(container.read(selectedDateProvider), DateTime(2028, 12, 6));
      expect(picked.selected!.optionId, 'sv-nicholas');
      expect(
        find.textContaining('Адкрыты тэксты за 2028 год.'),
        findsOneWidget,
      );
      expect(
        container.read(dioceseSelectionProvider).selected,
        selection.selected,
      );
      expect(
        OrdoRuntime.engine
            .resolve('2027-12-06', diocese: 'grodno')
            .options
            .any((o) => o.id == 'sv-nicholas'),
        isFalse,
      );
      expect(router.canPop(), isTrue);
    },
  );

  testWidgets('Hours search confirms day readings before changing tabs', (
    tester,
  ) async {
    final (_, container) = await start(
      tester,
      location: '/hours/picker',
      selectedDate: DateTime(2026, 12, 6),
      onlyMinsk: true,
    );
    await tester.tap(find.text('Святы'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('picker-feast-search')),
      '06.12',
    );
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.byKey(const Key('picker-feast-sv-nicholas-2026-12-06')),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-destination-Чытанні')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Скасаваць'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-destination-Чытанні')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Адкрыць чытанні дня'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadingsScreen), findsOneWidget);
    expect(container.read(selectedDateProvider), DateTime(2027, 12, 6));
    await checkPalette(tester);
    expect(tester.takeException(), isNull);
  });

  for (final prefix in ['/hora', '/hours/hora']) {
    testWidgets(
      '$prefix preserves encoded id and rejects an unavailable Office',
      (tester) async {
        final id = rosary().templates.last.id;
        final (router, container) = await start(
          tester,
          location: Uri(
            pathSegments: [
              '',
              ...prefix.substring(1).split('/'),
              '2026-10-07',
              id,
            ],
            queryParameters: {'diocese': 'minsk-mohilev'},
          ).toString(),
        );
        expect(router.routeInformationProvider.value.uri.path, '/hours');
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(container.read(hoursLiturgicalSelectionProvider).dayId, id);
        router.go(
          Uri(
            pathSegments: [
              '',
              ...prefix.substring(1).split('/'),
              '2026-10-07',
              'missing/id',
            ],
            queryParameters: {'diocese': 'grodno'},
          ).toString(),
        );
        await tester.pumpAndSettle();
        expect(
          container.read(hoursLiturgicalSelectionProvider).selected,
          isNull,
        );
        expect(find.text('Няма літургічнага дня'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'production route tree hides dock and hit-tests readings palette',
    (tester) async {
      final (router, _) = await start(
        tester,
        location: '/readings?date=2026-10-07',
      );
      expect(find.byKey(const Key('app-dock-android')), findsOneWidget);
      final text = find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text is TextSpan &&
            _tapIn(widget.text) != null,
      );
      await Scrollable.ensureVisible(
        tester.element(text.first),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      _tapIn(tester.widget<RichText>(text.first).text)!.onTap!();
      await tester.pumpAndSettle();
      final palette = find.byKey(const Key('readings-highlight-palette'));
      expect(palette, findsOneWidget);
      expect(find.byKey(const Key('app-dock-android')), findsNothing);
      // Query normalization reuses the same live reader and its selection.
      router.go('/readings?date=2026-10-07&option=our-lady-rosary');
      await tester.pumpAndSettle();
      production.appShellState.notifyListeners();
      await tester.pumpAndSettle();
      expect(palette, findsOneWidget);
      expect(find.byKey(const Key('app-dock-android')), findsNothing);
      expect(
        find.byKey(const Key('readings-highlight-amber')).hitTestable(),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('readings-highlight-amber')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(palette, findsNothing);
      expect(find.byKey(const Key('app-dock-android')), findsOneWidget);
      final saved = HiveService.settingsBox.keys.where(
        (key) => key.toString().startsWith('readingsHighlight:'),
      );
      expect(
        saved.any(
          (key) => (HiveService.settingsBox.get(key) as Map).values.contains(
            'amber',
          ),
        ),
        isTrue,
      );
      _tapIn(tester.widget<RichText>(text.first).text)!.onTap!();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(palette, findsNothing);
      expect(find.byKey(const Key('app-dock-android')), findsOneWidget);
      _tapIn(tester.widget<RichText>(text.first).text)!.onTap!();
      await tester.pumpAndSettle();
      router.go('/readings?date=2026-10-08');
      await tester.pumpAndSettle();
      expect(palette, findsNothing);
      expect(find.byKey(const Key('app-dock-android')), findsOneWidget);
      router.go('/readings?date=2026-10-07');
      await tester.pumpAndSettle();
      await checkPalette(tester);
      expect(tester.takeException(), isNull);
    },
  );

  for (final year in [2025, 2031]) {
    testWidgets(
      'All Souls Sunday $year keeps Mass and Office sources in day routes',
      (tester) async {
        final (router, container) = await start(
          tester,
          location: '/hours/ordo?date=$year-11-02',
          selectedDate: DateTime(year, 11, 2),
        );
        expect(
          find.byKey(const Key('ordo-row-all-faithful-departed-primary')),
          findsOneWidget,
        );
        await tapVisible(tester, find.text('Літургія гадзінаў').first);
        expect(find.byKey(const Key('ordo-office-split')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('ordo-mass-set-first')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('ordo-mass-set-second')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('ordo-mass-set-third')),
          findsOneWidget,
        );
        await tapVisible(tester, find.byKey(const Key('ordo-open-readings')));
        await tapVisible(
          tester,
          find.byKey(const ValueKey('ordo-reading-set-second')),
        );
        final query = GoRouterState.of(
          tester.element(find.byType(ReadingsScreen)),
        ).uri.queryParameters;
        expect(query['option'], 'all-faithful-departed');
        expect(query['date'], '$year-11-02');
        router.pop();
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const Key('ordo-open-hours')));
        expect(
          container
              .read(hoursLiturgicalSelectionProvider)
              .selected
              ?.ordo
              ?.officeKind,
          'sunday',
        );
        expect(container.read(selectedDateProvider), DateTime(year, 11, 2));
      },
    );
  }

  testWidgets('Period notes are collapsed and can be opened', (tester) async {
    await start(tester, location: '/hours/ordo?date=2026-03-05');
    await tapVisible(tester, find.text('Літургічныя заўвагі'));
    final title = find.text('Агульныя ўказанні перыяду');
    await tapVisible(tester, title);
    final tile = find.ancestor(of: title, matching: find.byType(ExpansionTile));
    expect(tester.widget<ExpansionTile>(tile.first).initiallyExpanded, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('colour date picker returns date on $platform', (tester) async {
      DateTime? result;
      final container = ProviderContainer(
        overrides: [
          selectedDateProvider.overrideWith((ref) => date),
          liturgicalContentReadyProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showAmbientDatePicker(
                      context: context,
                      initialDate: date,
                    );
                    if (result != null) {
                      container
                          .read(liturgicalNavigationControllerProvider)
                          .openDate(result!);
                    }
                  },
                  child: const Text('pick'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();
      expect(find.byType(VestmentMarker), findsWidgets);
      await tester.tap(find.byKey(const Key('ordo-day-2026-10-08')));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 10, 8));
      expect(container.read(selectedDateProvider), result);
      expect(find.byType(Dialog), findsNothing);
    });
  }

  for (final scale in [1.0, 1.3, 1.5, 2.0]) {
    testWidgets('day and month fit 320px at text scale $scale', (tester) async {
      final (router, _) = await start(
        tester,
        width: 320,
        scale: scale,
        location: '/hours/hora/2026-10-07/${rosary().dayId}',
      );
      await openOrdo(tester);
      await tapVisible(tester, find.byKey(const Key('ordo-open-month')));
      final cell = tester.getSize(find.byKey(const Key('ordo-day-2026-10-07')));
      expect(cell.width, greaterThanOrEqualTo(44));
      expect(cell.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      router.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    for (final scale in [1.5, 2.0]) {
      testWidgets(
        'shared month: multiple dioceses, 320px, $brightness, scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          DateTime? selected;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                liturgicalContentReadyProvider.overrideWith((ref) async {}),
                dioceseSelectionProvider.overrideWith(_AllDioceses.new),
              ],
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: LiturgicalMonthCalendar(
                      initialDate: DateTime(2026, 8, 26),
                      onSelected: (date) => selected = date,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final cell = find.byKey(const Key('ordo-day-2026-08-26'));
          final marker = tester.widget<VestmentMarker>(
            find.descendant(of: cell, matching: find.byType(VestmentMarker)),
          );
          final engine = OrdoRuntime.engine;
          final expectedColors = <String>{
            for (final diocese in ['vitebsk', 'grodno'])
              ...engine.resolve('2026-08-26', diocese: diocese).legalColors,
          };
          expect(marker.colors, expectedColors.take(3).toList());
          expect(tester.getSize(cell).width, greaterThanOrEqualTo(44));
          await tester.tap(cell);
          await tester.pumpAndSettle();
          expect(selected, DateTime(2026, 8, 26));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
