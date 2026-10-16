import 'dart:io';

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
import 'package:mybrev_flutter/screens/hora_picker_screen.dart';
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
    expect(
      common.day.field('officeOfReadingsHymn'),
      commonData['officeOfReadingsHymn'],
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
    bool allDioceses = false,
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
        if (allDioceses)
          dioceseSelectionProvider.overrideWith(_AllDioceses.new),
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
    addTearDown(router.dispose);
    addTearDown(container.dispose);
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
    expect(find.byType(HoraPickerScreen), findsNothing);
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
    final (router, _) = await start(tester);
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
    router.pop();
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
  });

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
      expect(find.text('Па перыядзе'), findsOneWidget);
      expect(find.text('Па свяце'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  for (final mode in ['hours', 'readings']) {
    testWidgets(
      'catalog Nicholas 2026 blocked / 2027 real $mode route and back',
      (tester) async {
        final (router, container) = await start(
          tester,
          location: '/$mode/picker',
          allDioceses: true,
        );
        await tapVisible(tester, find.text('Па свяце'));
        await tester.enterText(
          find.byKey(const Key('picker-feast-search')),
          'Мікалая',
        );
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.byKey(const Key('picker-entry-sv-nicholas')),
        );
        await tapVisible(tester, find.byKey(const Key('catalog-calendar')));
        await tapVisible(tester, find.byKey(const Key('picker-year')));
        await tapVisible(tester, find.byKey(const Key('picker-year-2026')));
        await tapVisible(
          tester,
          find.byKey(const Key('catalog-open-occurrence')),
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('catalog-open-occurrence')),
              )
              .onPressed,
          isNull,
        );
        await tapVisible(tester, find.byKey(const Key('picker-year-next')));
        expect(find.text('2027'), findsWidgets);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('catalog-open-occurrence')),
              )
              .onPressed,
          isNotNull,
        );
        await tapVisible(
          tester,
          find.byKey(const Key('catalog-open-occurrence')),
        );
        if (mode == 'hours') {
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(container.read(selectedDateProvider), DateTime(2027, 12, 6));
          expect(
            container.read(hoursLiturgicalSelectionProvider).selected!.optionId,
            'sv-nicholas',
          );
        } else {
          expect(find.byType(ReadingsScreen), findsOneWidget);
          final query = GoRouterState.of(
            tester.element(find.byType(ReadingsScreen)),
          ).uri.queryParameters;
          expect(query['option'], 'sv-nicholas');
          expect(query['date'], '2027-12-06');
          expect(query['diocese'], 'vitebsk');
        }
        expect(container.read(dioceseSelectionProvider).primary, 'vitebsk');
        router.pop();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('picker-entry-sv-nicholas')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

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
      await tapVisible(tester, find.byKey(const Key('hora-open-ordo')));
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
