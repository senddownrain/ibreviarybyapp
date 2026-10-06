import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/constants/hora_items.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/screens/home_screen.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';

void main() {
  setUpAll(() => initializeDateFormatting('be'));

  group('Hours liturgical adapter', () {
    test('sorted first option becomes primary and empty is explicit', () {
      final options = [_option('first'), _option('second')];
      expect(resolvePrimaryLiturgicalOption(options)?.dayId, 'first');
      expect(resolvePrimaryLiturgicalOption(const []), isNull);
    });

    test(
      'alternatives count excludes primary and manual choice is resolved',
      () {
        final options = [_option('first'), _option('second'), _option('third')];
        final automatic = resolveHoursLiturgicalSelection(options);
        final manual = resolveHoursLiturgicalSelection(
          options,
          selectedDayId: 'third',
        );

        expect(automatic.alternativesCount, 2);
        expect(manual.primary?.dayId, 'first');
        expect(manual.dayId, 'third');
        expect(
          resolveHoursLiturgicalSelection([options.first]).alternativesCount,
          0,
        );
      },
    );

    test('template choice updates effective day without changing option', () {
      final base = _day('saint');
      final template = _day('saint-pastors');
      final option = _option(
        'saint',
        templates: [
          DayTemplate(id: base.id, label: 'Асноўны', day: base),
          DayTemplate(id: template.id, label: 'Пастыры', day: template),
        ],
      );
      final selection = resolveHoursLiturgicalSelection([
        option,
      ], selectedDayId: template.id);

      expect(selection.selected?.key, option.key);
      expect(selection.dayId, template.id);
      expect(selection.effectiveOption?.dayId, template.id);
    });

    test('hour availability keeps production checkFields rule', () {
      final day = _day('day', fields: {'laudesAnt1': '<p>Antiphon</p>'});
      final lauds = kHoraItems.singleWhere((hour) => hour.type == 'laudes');
      final vespers = kHoraItems.singleWhere((hour) => hour.type == 'vespers');

      expect(isHourAvailable(day, lauds), isTrue);
      expect(isHourAvailable(day, vespers), isFalse);
      expect(isHourAvailable(null, lauds), isFalse);
    });

    test('Compline availability uses its separate record source', () {
      final day = _day(
        'day',
        fields: {'_periodType': 'ordinary', '_dayOfWeek': '4'},
      );
      final compline = kHoraItems.singleWhere(
        (hour) => hour.type == 'completorium',
      );

      expect(completoriumRecordIdForDay(day), 'ordinary-d4');
      expect(
        isHourAvailable(day, compline, completoriumAvailable: true),
        isTrue,
      );
      expect(
        isHourAvailable(day, compline, completoriumAvailable: false),
        isFalse,
      );
    });

    test('manual overrides are session-scoped per date', () {
      final notifier = HoursLiturgicalOverrideNotifier();
      addTearDown(notifier.dispose);
      final firstDate = DateTime(2026, 9, 8);
      final secondDate = DateTime(2026, 9, 9);

      notifier.select(firstDate, 'alternative');
      expect(notifier.state['2026-09-08'], 'alternative');
      expect(notifier.state['2026-09-09'], isNull);
      notifier.select(secondDate, 'other-day');
      expect(notifier.state['2026-09-08'], 'alternative');
      expect(notifier.state['2026-09-09'], 'other-day');
    });

    test('Hours and Readings share date and selected celebration', () async {
      final firstDate = DateTime(2026, 9, 8);
      final secondDate = DateTime(2026, 9, 9);
      final options = [_option('primary'), _option('alternative')];
      final container = ProviderContainer(
        overrides: [
          selectedDateProvider.overrideWith((ref) => firstDate),
          dayOptionsProvider.overrideWithValue(options),
          readingsBranchStateProvider.overrideWith(
            (ref) => ReadingsBranchState(date: firstDate),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(liturgicalNavigationSyncProvider);

      container.read(liturgicalNavigationControllerProvider).moveBy(1);
      expect(container.read(selectedDateProvider), secondDate);
      expect(container.read(readingsBranchStateProvider).date, secondDate);
      expect(container.read(homeNavDirectionProvider), 1);

      container.read(liturgicalNavigationControllerProvider).moveBy(-1);
      expect(container.read(selectedDateProvider), firstDate);
      expect(container.read(readingsBranchStateProvider).date, firstDate);
      expect(container.read(homeNavDirectionProvider), -1);

      container
          .read(hoursLiturgicalOverridesProvider.notifier)
          .select(firstDate, 'alternative');
      await container.pump();
      expect(container.read(readingsBranchStateProvider).dayId, 'alternative');

      container.read(readingsBranchStateProvider.notifier).state =
          ReadingsBranchState(date: secondDate, dayId: 'primary');
      await container.pump();
      expect(container.read(selectedDateProvider), secondDate);
      expect(
        container.read(hoursLiturgicalOverridesProvider)['2026-09-09'],
        'primary',
      );
    });
  });

  testWidgets('single option hides alternatives and hour opens correct Ora', (
    tester,
  ) async {
    final date = DateTime(2026, 9, 8);
    final option = _option('primary', fields: {'laudesHymn': '<p>Hymn</p>'});
    final router = _hoursRouter(date: date, options: [option]);
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(router, date, [option]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hours-alternatives-control')), findsNothing);
    expect(find.byKey(const Key('hours-hour-laudes')), findsOneWidget);
    expect(find.byKey(const Key('hours-hour-vespers')), findsNothing);

    await tester.tap(find.byKey(const Key('hours-hour-laudes')));
    await tester.pumpAndSettle();
    expect(find.text('2026-09-08 / primary / laudes'), findsOneWidget);
  });

  testWidgets('local celebration shows its Belarusian diocese name', (
    tester,
  ) async {
    final date = DateTime(2026, 9, 8);
    final option = _option(
      'local',
      fields: {'_place': 'grodno', 'laudesAnt1': 'available'},
    );
    final router = _hoursRouter(date: date, options: [option]);
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(router, date, [option]));
    await tester.pumpAndSettle();

    expect(find.text('Гродзенская дыяцэзія'), findsOneWidget);
    expect(find.text('grodno'), findsNothing);
  });

  testWidgets('alternatives sheet updates the selected celebration in place', (
    tester,
  ) async {
    final date = DateTime(2026, 9, 8);
    final options = [
      _option('primary', fields: {'laudesAnt1': 'available'}),
      _option('alternative', fields: {'vesperAnt1': 'available'}),
    ];
    final container = ProviderContainer(overrides: _overrides(date, options));
    addTearDown(container.dispose);
    final router = _hoursRouter(date: date, options: options);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _routerApp(router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Іншыя літургічныя варыянты · 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hours-alternatives-control')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Celebration alternative').last);
    await tester.pumpAndSettle();

    expect(
      container.read(hoursLiturgicalSelectionProvider).dayId,
      'alternative',
    );
    expect(find.text('Celebration alternative'), findsWidgets);
    expect(find.text('Літургія'), findsWidgets);
  });

  testWidgets('Today moves Hours and Readings to the same date', (
    tester,
  ) async {
    final otherDate = DateTime(2026, 9, 8);
    final readingsDate = DateTime(2026, 8, 31);
    final option = _option('primary', fields: {'laudesAnt1': 'available'});
    final container = ProviderContainer(
      overrides: _overrides(otherDate, [option]),
    );
    addTearDown(container.dispose);
    container.read(readingsBranchStateProvider.notifier).state =
        ReadingsBranchState(date: readingsDate);
    final router = _hoursRouter(date: otherDate, options: [option]);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _routerApp(router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hours-today-action')), findsOneWidget);

    await tester.tap(find.byKey(const Key('hours-today-action')));
    await tester.pump();
    expect(
      DateUtils.isSameDay(container.read(selectedDateProvider), DateTime.now()),
      isTrue,
    );
    expect(
      DateUtils.isSameDay(
        container.read(readingsBranchStateProvider).date,
        DateTime.now(),
      ),
      isTrue,
    );
  });

  testWidgets('Hours layout supports 200 percent text on a narrow surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final date = DateUtils.dateOnly(DateTime.now());
    final option = _option(
      'primary',
      title:
          'Вельмі доўгая назва літургічнага святкавання для праверкі маштабу',
      fields: {
        'vesperAnt1': 'available',
        'feastComment': 'Гэты каментар павінен быць толькі ўнутры гадзіны.',
      },
    );
    final router = _hoursRouter(date: date, options: [option]);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _testApp(router, date, [option]),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(option.title), findsOneWidget);
    expect(
      find.text('Гэты каментар павінен быць толькі ўнутры гадзіны.'),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(const Key('hours-celebration-accent'))).height,
      greaterThan(
        tester.getSize(find.byKey(const Key('hours-celebration-title'))).height,
      ),
    );
  });
}

List<Override> _overrides(DateTime date, List<DayOption> options) => [
  selectedDateProvider.overrideWith((ref) => date),
  dayOptionsProvider.overrideWithValue(options),
  selectedDateReadyProvider.overrideWith((ref) async {}),
  isOfflineProvider.overrideWithValue(false),
  contentUpdatesProvider.overrideWith(_TestBootstrapNotifier.new),
];

Widget _testApp(GoRouter router, DateTime date, List<DayOption> options) =>
    ProviderScope(
      overrides: _overrides(date, options),
      child: _routerApp(router),
    );

Widget _routerApp(GoRouter router) => MaterialApp.router(
  theme: ThemeData(platform: TargetPlatform.android, useMaterial3: true),
  routerConfig: router,
);

GoRouter _hoursRouter({
  required DateTime date,
  required List<DayOption> options,
}) => GoRouter(
  initialLocation: '/hours',
  routes: [
    GoRoute(
      path: '/hours',
      builder: (_, _) => const Scaffold(body: HomeScreen()),
      routes: [
        GoRoute(
          path: 'ora/:date/:dayId/:type',
          builder: (_, state) => Scaffold(
            body: Text(
              '${state.pathParameters['date']} / '
              '${state.pathParameters['dayId']} / '
              '${state.pathParameters['type']}',
            ),
          ),
        ),
        GoRoute(
          path: 'picker',
          builder: (_, _) => const Scaffold(body: Text('advanced picker')),
        ),
      ],
    ),
  ],
);

class _TestBootstrapNotifier extends ContentUpdatesNotifier {
  @override
  ContentUpdateState build() => const ContentUpdateState();
}

DayOption _option(
  String id, {
  String? title,
  Map<String, dynamic> fields = const {},
  List<DayTemplate>? templates,
}) {
  final day = _day(id, fields: fields);
  return DayOption(
    source: LiturgicalOptionSource.fixed,
    title: title ?? 'Celebration $id',
    subtitle: 'Свята',
    day: day,
    key: 'fixed-$id',
    contextPeriodType: 'ordinary',
    templates: templates ?? [DayTemplate(id: id, label: 'Асноўны', day: day)],
  );
}

LiturgicalDay _day(String id, {Map<String, dynamic> fields = const {}}) =>
    LiturgicalDay.fromMap({
      'id': id,
      '_feastName': 'Celebration $id',
      '_periodType': 'ordinary',
      ...fields,
    });
