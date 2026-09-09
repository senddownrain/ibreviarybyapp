import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/readings_screen.dart';
import 'package:mybrev_flutter/utils/reading_groups.dart';
import 'package:mybrev_flutter/utils/readings_selection.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

ParsedReading _reading(
  String id, {
  required String title,
  String? year,
  String? dayId,
  String text = 'Тэкст чытання',
}) => ParsedReading(
  id: id,
  title: title,
  year: year,
  dayId: dayId,
  reading1: ParsedSection(
    bible: 'Ян 1, 1–5',
    text: List.filled(18, text).join(' '),
  ),
  gospel: ParsedSection(bible: 'Мк 1, 1', text: '$text. Евангелле.'),
);

ReadingsLoader _loader(List<ParsedReading> readings) =>
    ({
      required dateStr,
      required liturgicalKey,
      required dayId,
      required forceRefresh,
    }) async => ReadingsLoadResult(
      readings: readings,
      sundayCycle: 'B',
      weekdayCycle: '2',
    );

void main() {
  group('current production default adapter', () {
    test('keeps first sorted group and calendar cycle fallback', () {
      final readings = [
        _reading('a', title: 'Нядзельныя чытанні', year: 'A', dayId: 'sunday'),
        _reading('b', title: 'Нядзельныя чытанні', year: 'B', dayId: 'sunday'),
        _reading('other', title: 'Іншае святкаванне'),
      ];
      final result = resolveDefaultReadings(
        readings: readings,
        sundayCycle: 'B',
        weekdayCycle: '2',
      );

      expect(result.groups, hasLength(2));
      expect(result.activeGroupKey, result.groups.first.key);
      expect(result.automaticCycle, 'B');
      expect(result.reading?.id, 'b');
    });

    test('linked dayId wins and manual cycle can return to automatic', () {
      final readings = [
        _reading('ordinary', title: 'Звычайны дзень'),
        _reading('linked-a', title: 'Свята', year: 'A', dayId: 'feast'),
        _reading('linked-b', title: 'Свята', year: 'B', dayId: 'feast'),
      ];
      final automatic = resolveDefaultReadings(
        readings: readings,
        sundayCycle: 'B',
        weekdayCycle: '2',
        dayId: 'feast',
      );
      final manual = resolveDefaultReadings(
        readings: readings,
        sundayCycle: 'B',
        weekdayCycle: '2',
        dayId: 'feast',
        manualCycle: 'A',
      );

      expect(automatic.reading?.id, 'linked-b');
      expect(manual.reading?.id, 'linked-a');
      expect(availableCyclesForGroup(manual.documents), ['A', 'B']);
    });

    test('weekday and non-cycle groups expose only real cycles', () {
      final weekdays = [
        _reading('one', title: 'Будні', year: '1'),
        _reading('two', title: 'Будні', year: '2'),
      ];
      expect(availableCyclesForGroup(weekdays), ['1', '2']);
      expect(
        availableCyclesForGroup([_reading('shared', title: 'Свята')]),
        isEmpty,
      );
    });
  });

  testWidgets('root is the shared reader and immediately shows content', (
    tester,
  ) async {
    final controller = ReaderChromeModeController(ReaderChromeMode.full);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_TestSettingsNotifier.new),
          liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
          readingsLoaderProvider.overrideWithValue(
            _loader([_reading('only', title: 'Свята дня')]),
          ),
        ],
        child: MaterialApp(
          home: ReaderChromeModeScope(
            controller: controller,
            child: const ReadingsScreen(dateStr: '2026-09-09'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader-content-surface')), findsOneWidget);
    expect(find.text('ЧЫТАННЕ'), findsOneWidget);
    expect(find.textContaining('Тэкст чытання'), findsWidgets);
    expect(find.byKey(const Key('readings-options-action')), findsNothing);

    ScrollUpdateNotification(
      metrics: FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1200,
        pixels: 220,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      ),
      context: tester.element(find.byType(CustomScrollView)),
      scrollDelta: 20,
      dragDetails: DragUpdateDetails(
        globalPosition: Offset.zero,
        delta: const Offset(0, -20),
      ),
    ).dispatch(tester.element(find.byType(CustomScrollView)));
    await tester.pump();
    expect(controller.value, ReaderChromeMode.compact);
  });

  testWidgets(
    'options separate groups and cycles with manual and auto states',
    (tester) async {
      final readings = [
        _reading(
          'a',
          title: 'Нядзельныя чытанні',
          year: 'A',
          dayId: 'sunday',
          text: 'Тэкст A',
        ),
        _reading(
          'b',
          title: 'Нядзельныя чытанні',
          year: 'B',
          dayId: 'sunday',
          text: 'Тэкст B',
        ),
        _reading('other', title: 'Іншае святкаванне'),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(_TestSettingsNotifier.new),
            liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
            readingsLoaderProvider.overrideWithValue(_loader(readings)),
          ],
          child: const MaterialApp(home: ReadingsScreen(dateStr: '2026-09-09')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Тэкст B'), findsWidgets);
      await tester.tap(find.byKey(const Key('readings-options-action')));
      await tester.pumpAndSettle();
      expect(find.text('СВЯТКАВАННЕ / НАБОР ЧЫТАННЯЎ'), findsOneWidget);
      expect(find.text('ЦЫКЛ'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('readings-cycle-A')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('readings-manual-cycle-marker')),
        findsOneWidget,
      );
      expect(find.textContaining('Тэкст A'), findsWidgets);

      await tester.tap(find.byKey(const Key('readings-options-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('readings-cycle-auto')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('readings-manual-cycle-marker')),
        findsNothing,
      );
      expect(find.textContaining('Тэкст B'), findsWidgets);
    },
  );

  testWidgets('Today changes only Readings branch date', (tester) async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(_TestSettingsNotifier.new),
        liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
        selectedDateProvider.overrideWith((ref) => DateTime(2026, 9, 17)),
        readingsBranchStateProvider.overrideWith(
          (ref) => ReadingsBranchState(date: DateTime(2020, 1, 1)),
        ),
        readingsLoaderProvider.overrideWithValue(
          _loader([_reading('only', title: 'Свята дня')]),
        ),
      ],
    );
    addTearDown(container.dispose);
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/readings?date=2020-01-01',
      routes: [
        GoRoute(
          path: '/readings',
          builder: (_, state) => ReadingsScreen(
            dateStr: state.uri.queryParameters['date'] ?? '2020-01-01',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('readings-today-action')));
    await tester.pumpAndSettle();

    expect(
      DateUtils.isSameDay(
        container.read(readingsBranchStateProvider).date,
        DateTime.now(),
      ),
      isTrue,
    );
    expect(container.read(selectedDateProvider), DateTime(2026, 9, 17));
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}
