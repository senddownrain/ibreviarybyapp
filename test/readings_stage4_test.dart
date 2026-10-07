import 'dart:async';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

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
    ({required dateStr, required liturgicalKey, required dayId}) async =>
        ReadingsLoadResult(
          readings: readings,
          sundayCycle: 'B',
          weekdayCycle: '2',
        );

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'readings-stage4-test-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

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
    expect(find.text('Чытанне'), findsOneWidget);
    expect(find.textContaining('Тэкст чытання'), findsWidgets);
    expect(find.byKey(const Key('readings-options-action')), findsNothing);
    // Readings stay simple: no Ordo / calendar entry on the Readings root.
    expect(find.byKey(const Key('hours-calendar-action')), findsNothing);
    expect(find.text('Каляндар'), findsNothing);

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

  testWidgets('context header keeps its left edge while readings load', (
    tester,
  ) async {
    final result = Completer<ReadingsLoadResult>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_TestSettingsNotifier.new),
          liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
          readingsLoaderProvider.overrideWithValue(
            ({required dateStr, required liturgicalKey, required dayId}) =>
                result.future,
          ),
        ],
        child: const MaterialApp(home: ReadingsScreen(dateStr: '2026-09-09')),
      ),
    );

    final header = find.byKey(const Key('readings-context-header'));
    final loadingLeft = tester.getTopLeft(header).dx;
    await tester.pump(const Duration(milliseconds: 40));
    result.complete(
      ReadingsLoadResult(
        readings: [
          _reading('short', title: 'Кароткая назва'),
          _reading(
            'long',
            title: 'Значна даўжэйшая назва іншага набору чытанняў',
          ),
        ],
        sundayCycle: 'B',
        weekdayCycle: '2',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('readings-options-action')), findsOneWidget);
    expect(tester.getTopLeft(header).dx, loadingLeft);
  });

  testWidgets('period reading uses the Liturgy of the Hours title', (
    tester,
  ) async {
    const reading = ParsedReading(
      id: 'ordinary-w23-d4-cycle2',
      dayId: 'weekday',
      title: 'Сырая назва набору',
      year: '2',
      periodType: 'ordinary',
      periodWeekNumber: 23,
      dayOfWeek: 4,
      reading1: ParsedSection(text: 'Тэкст чытання'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_TestSettingsNotifier.new),
          liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
          readingsLoaderProvider.overrideWithValue(_loader([reading])),
        ],
        child: const MaterialApp(home: ReadingsScreen(dateStr: '2026-09-09')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('XXIII звычайны тыдзень, серада'), findsOneWidget);
    expect(find.text('Сырая назва набору'), findsNothing);
  });

  testWidgets('celebration titles do not get a lectionary year suffix', (
    tester,
  ) async {
    const memorial = ParsedReading(
      id: 'memoria-doc',
      title: 'Святы Ян, Год A',
      year: '2',
      rank: 'memoria',
      dayOfWeek: 4,
      reading1: ParsedSection(text: 'Тэкст чытання'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_TestSettingsNotifier.new),
          liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
          readingsLoaderProvider.overrideWithValue(_loader([memorial])),
        ],
        child: const MaterialApp(home: ReadingsScreen(dateStr: '2026-09-09')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Святы Ян'), findsOneWidget);
    expect(find.text('Святы Ян, Год A'), findsNothing);
    expect(find.text('Святы Ян, Год II'), findsNothing);
  });

  testWidgets('liturgical route formats its title with a Roman week number', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_TestSettingsNotifier.new),
          liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
          readingsLoaderProvider.overrideWithValue(_loader(const [])),
        ],
        child: const MaterialApp(
          home: ReadingsScreen(liturgicalKey: 'ordinary/23/4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('XXIII звычайны тыдзень, серада'), findsOneWidget);
    expect(find.textContaining('тыд. 23'), findsNothing);
  });

  testWidgets('synthetic fallback keeps alleluia text and lone alt chorus', (
    tester,
  ) async {
    const reading = ParsedReading(
      id: 'synthetic-fallback-fixture',
      title: 'Synthetic fixture',
      reading: ParsedSection(text: 'Асноўнае чытанне.'),
      psalm: ParsedSection(
        verses: ['Першы верш.'],
        altChorus: 'Альтэрнатыўны рэфрэн.',
      ),
      alleluia: ParsedSection(text: 'Верш з поля text.'),
      gospel: ParsedSection(text: 'Евангелле.'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_TestSettingsNotifier.new),
          liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
          readingsLoaderProvider.overrideWithValue(_loader([reading])),
        ],
        child: const MaterialApp(home: ReadingsScreen(dateStr: '2026-09-09')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Верш з поля text.'), findsOneWidget);
    expect(find.text('Альтэрнатыўны рэфрэн.'), findsOneWidget);
  });

  testWidgets('a reading sentence opens an accessible color palette', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const reading = ParsedReading(
      id: 'sentence-highlight-fixture',
      title: 'Вылучэнне сказаў',
      reading: ParsedSection(text: 'Першы сказ. Другі сказ.'),
    );
    Widget app() => ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_TestSettingsNotifier.new),
        liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
        readingsLoaderProvider.overrideWithValue(_loader([reading])),
      ],
      child: const MaterialApp(home: ReadingsScreen(dateStr: '2026-09-09')),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    Finder selectableFinder() => find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.textSpan?.toPlainText() ?? widget.data ?? '').contains(
            'Першы сказ. Другі сказ.',
          ),
    );
    final paragraphFinder = find.descendant(
      of: selectableFinder(),
      matching: find.byType(RichText),
    );
    final paragraph = tester.renderObject<RenderParagraph>(paragraphFinder);
    final firstGlyph = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await tester.tapAt(
      paragraph.localToGlobal(firstGlyph.first.toRect().center),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('readings-highlight-amber')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('readings-highlight-amber'))).width,
      greaterThanOrEqualTo(48),
    );
    expect(find.byKey(const Key('readings-highlight-clear')), findsOneWidget);
    expect(find.byKey(const Key('readings-highlight-cancel')), findsOneWidget);
    final paletteBottom = tester
        .getBottomRight(find.byKey(const Key('readings-highlight-palette')))
        .dy;
    expect(800 - paletteBottom, closeTo(16, 0.01));
  });

  testWidgets('options separate groups and expose only selectable cycles', (
    tester,
  ) async {
    final readings = [
      _reading(
        'a',
        title: 'Нядзельныя чытанні, Год B',
        year: 'A',
        dayId: 'sunday',
        text: 'Тэкст A',
      ),
      _reading(
        'b',
        title: 'Нядзельныя чытанні, Год B',
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

    expect(find.text('Нядзельныя чытанні'), findsOneWidget);
    expect(find.text('Цыкл B'), findsOneWidget);
    expect(find.textContaining('Тэкст B'), findsWidgets);
    await tester.tap(find.byKey(const Key('readings-options-action')));
    await tester.pumpAndSettle();
    expect(find.text('СВЯТКАВАННЕ / НАБОР ЧЫТАННЯЎ'), findsOneWidget);
    expect(find.text('ВЫБАР ЧЫТАННЯЎ'), findsOneWidget);
    expect(find.text('Па календары'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('readings-cycle-A')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('readings-cycle-metadata')), findsOneWidget);
    expect(find.text('Цыкл A · зменены'), findsOneWidget);
    expect(find.text('Цыкл B'), findsNothing);
    expect(find.text('Нядзельныя чытанні'), findsOneWidget);
    expect(find.textContaining('Тэкст A'), findsWidgets);

    await tester.tap(find.byKey(const Key('readings-options-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('readings-cycle-B')));
    await tester.pumpAndSettle();
    expect(find.text('Цыкл B'), findsOneWidget);
    expect(find.text('Цыкл A'), findsNothing);
    expect(find.byKey(const Key('readings-cycle-metadata')), findsOneWidget);
    expect(find.textContaining('Тэкст B'), findsWidgets);

    await tester.tap(find.byKey(const Key('readings-options-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Іншае святкаванне'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('readings-cycle-metadata')), findsOneWidget);
    expect(find.text('Набор чытанняў · зменены'), findsOneWidget);
    expect(find.byKey(const Key('readings-cycle-badge')), findsNothing);

    await tester.tap(find.byKey(const Key('readings-options-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Нядзельныя чытанні, Год B').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Тэкст B'), findsWidgets);
    expect(find.byKey(const Key('readings-cycle-metadata')), findsOneWidget);
  });

  testWidgets('Today moves Readings and Hours to the same date', (
    tester,
  ) async {
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
    expect(
      DateUtils.isSameDay(container.read(selectedDateProvider), DateTime.now()),
      isTrue,
    );
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}
