// Readings screen with structured Mass reading sets (real bundled
// documents): the compact set selector, the set kept in the session state
// and asked by the route, ordered sections, the Passion by roles, rubrics,
// the sequence and reference-only sets. No golden files.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/models/mass_reading_sets.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/readings_screen.dart';
import 'package:mybrev_flutter/widgets/reader/mass_set_selector.dart';

final Map<String, Map<String, dynamic>> _docs = decodeContentCollection(
  File('$kContentAssetDir/readings.json.gz').readAsBytesSync(),
).docs;

ParsedReading doc(String id) => ParsedReading.fromMap(id, _docs[id]!);

ReadingsLoadResult _result(List<String> ids, {String sundayCycle = 'A'}) =>
    ReadingsLoadResult(
      readings: [for (final id in ids) doc(id)],
      sundayCycle: sundayCycle,
      weekdayCycle: '2',
    );

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

Widget _screen(
  ReadingsLoadResult result, {
  String dateStr = '2026-08-15',
  String? requestedSetId,
  String? requestedCycle,
  ProviderContainer? container,
  Key? key,
}) {
  final screen = MaterialApp(
    home: ReadingsScreen(
      key: key,
      dateStr: dateStr,
      requestedSetId: requestedSetId,
      requestedCycle: requestedCycle,
    ),
  );
  if (container != null) {
    return UncontrolledProviderScope(container: container, child: screen);
  }
  return ProviderScope(overrides: _overrides(result), child: screen);
}

List<Override> _overrides(ReadingsLoadResult result) => [
  liturgicalContentReadyProvider.overrideWith((ref) async {}),
  dayOptionsProvider.overrideWithValue(const []),
  settingsProvider.overrideWith(_TestSettingsNotifier.new),
  liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
  readingsLocalLoaderProvider.overrideWithValue(
    ({required dateStr, required liturgicalKey, required dayId}) => result,
  ),
  readingsLoaderProvider.overrideWithValue(
    ({required dateStr, required liturgicalKey, required dayId}) async =>
        result,
  ),
];

Finder _text(String text) => find.textContaining(text, findRichText: true);

ChoiceChip _chip(WidgetTester tester, String setId) =>
    tester.widget<ChoiceChip>(find.byKey(ValueKey('readings-mass-set-$setId')));

Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 400, scrollable: find.byType(Scrollable).first);

Future<void> _openOptions(WidgetTester tester) async {
  final action = find.byKey(const Key('readings-alternatives-control'));
  await tester.scrollUntilVisible(
    action,
    -400,
    scrollable: find.byType(Scrollable).first,
  );
  // ensureVisible changes the scroll offset; wait for the new layout before
  // tapping. At 320 px / 200% the old button rect is below the viewport.
  await tester.pumpAndSettle();
  expect(action.hitTestable(), findsOneWidget);
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('readings-options-sheet')), findsOneWidget);
  final selector = find.byKey(const Key('readings-mass-set-selector'));
  await tester.scrollUntilVisible(
    selector,
    250,
    scrollable: find.descendant(
      of: find.byKey(const Key('readings-options-scroll')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    await initializeDateFormatting('be');
    hiveDirectory = await Directory.systemTemp.createTemp('mass-sets-widget-');
    Hive.init(hiveDirectory.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  group('MassSetSelector', () {
    final sets = doc('25-12-naradzhenne-pana').massReadings!.sets;

    testWidgets('labels from the source, selection and callback', (
      tester,
    ) async {
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: MassSetSelector(
                sets: sets,
                selectedId: 'day',
                onSelected: (id) => picked = id,
              ),
            ),
          ),
        ),
      );
      expect(find.text('ЧЫТАННІ ІМШЫ'), findsOneWidget);
      expect(find.text('3 варыянты аднаго святкавання'), findsOneWidget);
      for (final label in [
        'Св. Імша ўначы',
        'Св. Імша на світанні',
        'Св. Імша ўдзень',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(_chip(tester, 'day').selected, isTrue);
      expect(_chip(tester, 'night').selected, isFalse);
      await tester.tap(find.text('Св. Імша на світанні'));
      expect(picked, 'dawn');
      picked = null;
      await tester.tap(find.text('Св. Імша ўдзень'));
      expect(picked, isNull, reason: 'the selected set is not re-selected');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a single set has no selector', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MassSetSelector(
            sets: doc('feast-pentecost').massReadings!.sets,
            selectedId: 'day',
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.byKey(const Key('readings-mass-set-selector')), findsNothing);
    });

    test('Belarusian plural of «варыянт»', () {
      expect(massSetVariantWord(1), 'варыянт');
      expect(massSetVariantWord(2), 'варыянты');
      expect(massSetVariantWord(5), 'варыянтаў');
      expect(massSetVariantWord(12), 'варыянтаў');
      expect(massSetVariantWord(22), 'варыянты');
    });
  });

  group('Readings screen', () {
    final assumption = [
      '15-08-assumption-blessed-virgin-mary',
      'ordinary-w19-d7--2',
    ];

    String gospelOf(String docId, String setId) => doc(docId).massReadings!.sets
        .firstWhere((set) => set.id == setId)
        .sections
        .firstWhere((section) => section.kind == 'gospel')
        .bible!;

    testWidgets('15.08 opens the day Mass; the vigil is one tap away and '
        'stays chosen when the date is opened again', (tester) async {
      final container = ProviderContainer(
        overrides: _overrides(_result(assumption)),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _screen(_result(assumption), container: container, key: UniqueKey()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('readings-mass-set-selector')), findsNothing);
      await _openOptions(tester);
      expect(_chip(tester, 'day').selected, isTrue);
      Navigator.of(
        tester.element(find.byKey(const Key('readings-mass-set-selector'))),
      ).pop();
      await tester.pumpAndSettle();
      final day = gospelOf('15-08-assumption-blessed-virgin-mary', 'day');
      final vigil = gospelOf('15-08-assumption-blessed-virgin-mary', 'vigil');
      await _scrollTo(tester, _text(day));
      expect(_text(day), findsOneWidget);
      expect(_text(vigil), findsNothing);

      await _openOptions(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('readings-mass-set-vigil')),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('readings-mass-set-vigil')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('readings-options-sheet')), findsOneWidget);
      expect(_chip(tester, 'vigil').selected, isTrue);
      await tester.tap(find.byTooltip('Закрыць').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('readings-mass-set-selector')), findsNothing);
      await _scrollTo(tester, _text(vigil));
      expect(_text(vigil), findsOneWidget);
      expect(_text(day), findsNothing);
      expect(
        container.read(readingsMassSetSelectionProvider),
        containsPair(
          '2026-08-15|15-08-assumption-blessed-virgin-mary',
          'vigil',
        ),
      );

      // Another screen of the same date (navigation away and back).
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _screen(_result(assumption), container: container, key: UniqueKey()),
      );
      await tester.pumpAndSettle();
      await _openOptions(tester);
      expect(_chip(tester, 'vigil').selected, isTrue);
      await tester.tap(find.byTooltip('Закрыць').last);
      await tester.pumpAndSettle();

      // Another date does not inherit the choice.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _screen(
          _result(assumption),
          container: container,
          dateStr: '2027-08-15',
          key: UniqueKey(),
        ),
      );
      await tester.pumpAndSettle();
      await _openOptions(tester);
      expect(_chip(tester, 'day').selected, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('three sets fit a 320 px phone at double text size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        _screen(_result(['25-12-naradzhenne-pana']), dateStr: '2026-12-25'),
      );
      await tester.pumpAndSettle();
      await _openOptions(tester);
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('readings-mass-set-day')),
      );
      expect(_chip(tester, 'day').selected, isTrue);
      for (final id in ['night', 'dawn', 'day']) {
        final rect = tester.getRect(
          find.byKey(ValueKey('readings-mass-set-$id')),
        );
        expect(rect.right, lessThanOrEqualTo(320), reason: id);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the route can ask for a set (?set=vigil)', (tester) async {
      await tester.pumpWidget(
        _screen(_result(assumption), requestedSetId: 'vigil'),
      );
      await tester.pumpAndSettle();
      await _openOptions(tester);
      expect(_chip(tester, 'vigil').selected, isTrue);
    });

    testWidgets('24.12 opens the Christmas vigil Mass; the covered legacy '
        'document is not a second choice', (tester) async {
      await tester.pumpWidget(
        _screen(
          _result(['advent-24-12', 'advent-24-12--christmas-vigil']),
          dateStr: '2026-12-24',
        ),
      );
      await tester.pumpAndSettle();
      await _openOptions(tester);
      expect(_chip(tester, 'vigil').selected, isTrue);
      expect(find.text('Ранішняя Св. Імша'), findsOneWidget);
      expect(find.byKey(const Key('readings-options-action')), findsNothing);
    });

    testWidgets('Palm Sunday: rubrics, the Passion by roles, one Gospel', (
      tester,
    ) async {
      final palm = _result([
        'feast-palmsunday',
        'feast-palmsunday--A',
        'feast-palmsunday--B',
        'feast-palmsunday--C',
        'feast-palmsunday--procession',
      ], sundayCycle: 'B');
      await tester.pumpWidget(_screen(palm, dateStr: '2027-03-21'));
      await tester.pumpAndSettle();

      await _openOptions(tester);
      expect(_chip(tester, 'mass').selected, isTrue);
      Navigator.of(
        tester.element(find.byKey(const Key('readings-mass-set-selector'))),
      ).pop();
      await tester.pumpAndSettle();
      expect(find.text('Працэсія з пальмамі'), findsNothing);
      expect(find.textContaining('Год B'), findsWidgets);
      expect(_text('Год B'), findsWidgets);

      final passion = find.byKey(const Key('passion-by-roles'));
      await _scrollTo(tester, passion);
      expect(passion, findsOneWidget);
      expect(_text('Мк 15, 1–39'), findsOneWidget);
      expect(_text('Мц 27, 11–54'), findsNothing);

      // Every role keeps its marker in rubric colour and its own style.
      final spans = <TextSpan>[];
      for (final rich in tester.widgetList<RichText>(
        find.descendant(of: passion, matching: find.byType(RichText)),
      )) {
        rich.text.visitChildren((span) {
          if (span is TextSpan && span.text != null) spans.add(span);
          return true;
        });
      }
      final markers = spans.where(
        (span) => PassionRole.values.any((r) => span.text == '${r.marker} '),
      );
      expect({
        for (final span in markers) span.text,
      }, containsAll(['Ев. ', 'І. ', 'Л. ']));
      expect(
        markers.every((span) => span.style?.fontWeight == FontWeight.w800),
        isTrue,
      );
      final crowd = spans.indexWhere((span) => span.text == 'Л. ');
      expect(spans[crowd + 1].style?.fontStyle, FontStyle.italic);

      // Rubrics of the source in rubric style, before the Passion.
      expect(find.byKey(const ValueKey('reading-rubric')), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a procession set shows only its Gospel of the cycle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(
          _result(['feast-palmsunday'], sundayCycle: 'C'),
          dateStr: '2028-04-09',
          requestedSetId: 'procession',
        ),
      );
      await tester.pumpAndSettle();
      await _openOptions(tester);
      expect(_chip(tester, 'procession').selected, isTrue);
      Navigator.of(
        tester.element(find.byKey(const Key('readings-mass-set-selector'))),
      ).pop();
      await tester.pumpAndSettle();
      await _scrollTo(tester, _text('Лк 19, 28–40'));
      expect(_text('Лк 19, 28–40'), findsOneWidget);
      expect(_text('Мц 21, 1–11'), findsNothing);
      expect(find.byKey(const Key('passion-by-roles')), findsNothing);
    });

    testWidgets('Easter Vigil: ordered sections, no conclusion after the '
        'third reading', (tester) async {
      await tester.pumpWidget(
        _screen(
          _result(['holyweek-w1-d7--vigil', 'holyweek-w1-d7--A-vigil']),
          dateStr: '2026-04-04',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('readings-mass-set-selector')), findsNothing);
      final labels = [
        'Першае чытанне',
        'Другое чытанне',
        'Трэцяе чытанне',
        'Сёмае чытанне',
        'Эпістала',
      ];
      // The whole document is laid out (not lazy): the source order.
      final positions = [
        for (final label in labels) tester.getTopLeft(find.text(label)).dy,
      ];
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThan(positions[i - 1]), reason: labels[i]);
      }
      await _scrollTo(tester, _text('Не гаворыцца: Гэта слова Божае.'));
      expect(_text('Не гаворыцца: Гэта слова Божае.'), findsOneWidget);
      await _scrollTo(tester, _text('Мц 28, 1–10'));
      expect(_text('Мк 16, 1–7'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sequence is rendered as its own section', (tester) async {
      await tester.pumpWidget(
        _screen(_result(['feast-pentecost']), dateStr: '2026-05-24'),
      );
      await tester.pumpAndSettle();
      final sequence = find.byKey(const Key('reading-sequence'));
      await _scrollTo(tester, sequence);
      expect(
        find.descendant(of: sequence, matching: find.text('Секвенцыя')),
        findsOneWidget,
      );
    });

    testWidgets('a reference-only set shows citations and says the text is '
        'not loaded yet', (tester) async {
      await tester.pumpWidget(
        _screen(
          _result(['22-08-our-lady-lahishyn-pinsk']),
          dateStr: '2026-08-22',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reading-reference-only')), findsOneWidget);
      expect(
        find.text('Поўны тэкст чытанняў пакуль не загружаны. Цытаты:'),
        findsOneWidget,
      );
      expect(find.text('Саф 3, 14–18 або Рым 12, 9–16аb'), findsOneWidget);
      expect(find.text('Лк 1, 39–59'), findsOneWidget);
      expect(_text('Гэта слова Божае.'), findsNothing);
      expect(find.text('Тэкст гэтага чытання адсутнічае'), findsNothing);
    });

    testWidgets('a document without sets keeps the flat rendering', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(_result(['ordinary-w19-d7--2']), dateStr: '2026-08-15'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('readings-mass-set-selector')), findsNothing);
      expect(find.byKey(const Key('mass-set-meta')), findsNothing);
      expect(find.text('Чытанне'), findsOneWidget);
    });
  });
}
