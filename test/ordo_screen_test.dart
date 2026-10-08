// The mobile Ordo on the bundled content: month with real vestment colours,
// day detail («Колер літургічнага адзення», «Святкаванні дня», notes,
// reading references), no overflow on phones, tablets, light/dark and large
// text.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/screens/ordo_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_visual.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';

class _Dioceses extends DioceseSelectionNotifier {
  _Dioceses(this.value);
  final DioceseSelection value;
  @override
  DioceseSelection build() => value;
}

void main() {
  late Directory directory;
  setUpAll(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('ordo-screen-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Widget app(
    DateTime date, {
    ThemeMode mode = ThemeMode.light,
    double textScale = 1,
    DioceseSelection dioceses = DioceseSelection.initial,
  }) => ProviderScope(
    overrides: [
      liturgicalContentReadyProvider.overrideWith((ref) async {}),
      ordoNotesReadyProvider.overrideWith((ref) async {}),
      dioceseSelectionProvider.overrideWith(() => _Dioceses(dioceses)),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: mode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: OrdoScreen(initialDate: date),
    ),
  );

  Future<void> pump(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('Guardian Angels: vestment colour named, celebrations, notes '
      'and reading references', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pump(tester, app(DateTime(2026, 10, 2)));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('ordo-month-label')), findsNothing);
    expect(find.byType(CalendarDatePicker), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('ordo-vestment-color')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Колер літургічнага адзення', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Белы', findRichText: true), findsWidgets);
    expect(find.text('Святкаванне дня'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('ordo-row-holy-guardian-angels-primary')),
        matching: find.text('Св. Анёлаў Ахоўнікаў'),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('ordo-open-hours')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('ordo-open-hours')), findsOneWidget);
  });

  testWidgets('books volumes above the notes; All Souls on Sunday names the '
      'Office of the Sunday', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pump(tester, app(DateTime(2025, 11, 2)));
    expect(tester.takeException(), isNull);
    final books = find.text('Лекцыянарый т. III · Літургія гадзін т. III');
    await tester.scrollUntilVisible(
      books,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(books, findsOneWidget);
    // Facts line, above the celebrations and the notes.
    expect(
      tester.getTopLeft(books).dy,
      lessThan(
        tester.getTopLeft(find.text('Святкаванне дня', skipOffstage: false)).dy,
      ),
    );
    expect(
      tester.getTopLeft(books).dy,
      lessThan(
        tester
            .getTopLeft(find.text('Асаблівыя ўказанні', skipOffstage: false))
            .dy,
      ),
    );
    // The books note is not repeated among the notes.
    expect(find.text('Лекцыянарый т. III', skipOffstage: false), findsNothing);
    // Mass of All Souls is the primary celebration; the Hours are of the
    // Sunday.
    expect(
      find.byKey(
        const Key('ordo-row-all-faithful-departed-primary'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('ordo-office-split'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('Літургія гадзін — з дня:', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('13.06.2026: two memorial choices, no demotion badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pump(tester, app(DateTime(2026, 6, 13)));
    expect(
      find.byKey(
        const Key('ordo-row-immaculate-heart-primary'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('ordo-row-sv-anthony-padua-alternative'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.text('Абодва ўспаміны неабавязковыя', skipOffstage: false),
      findsNothing,
    );
    expect(
      find.text('ПА ВЫБАРЫ · Успамін', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('a date with several legal colours shows a segmented marker', (
    tester,
  ) async {
    // 06.10.2026: the weekday (green) and St Bruno (white).
    await pump(tester, app(DateTime(2026, 10, 6)));
    final markers = tester
        .widgetList<VestmentMarker>(find.byType(VestmentMarker))
        .where((m) => m.colors.length > 1);
    expect(markers.first.colors, ['viridis', 'albus']);
    expect(
      find.text('ПА ВЫБАРЫ · Неабавязковы ўспамін', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('the selected dioceses that differ are explained, not mixed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      app(
        DateTime(2026, 8, 26),
        dioceses: const DioceseSelection(
          selected: ['grodno', 'vitebsk'],
          primary: 'vitebsk',
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.textContaining('Выбраныя дыяцэзіі адрозніваюцца'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Гродна'), findsWidgets);
    expect(find.text('Віцебск'), findsWidgets);
  });

  for (final width in [320.0, 360.0, 390.0, 430.0, 820.0]) {
    for (final scale in [1.0, 1.4, 2.0]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('no overflow at ${width.toInt()} px, text ×$scale, '
            '${mode.name}', (tester) async {
          tester.view.physicalSize = Size(width * 2, 1600 * 2);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          await pump(
            tester,
            app(DateTime(2026, 11, 2), mode: mode, textScale: scale),
          );
          final scrollable = find.byType(Scrollable).first;
          for (var i = 0; i < 12; i++) {
            await tester.drag(scrollable, const Offset(0, -400));
            await tester.pump();
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  test('one colour vocabulary: no blue vestment, Marian blue is an accent', () {
    expect(kVestmentColors.keys, [
      'albus',
      'ruber',
      'viridis',
      'violaceus',
      'rosaceus',
      'niger',
    ]);
    final marian = liturgicalVisual(color: 'albus', category: 'mary')!;
    expect(marian.label, 'Белы');
    expect(marian.marianAccent, isTrue);
    expect(marian.accent, LiturgicalAccents.marian);
    expect(liturgicalVisual(color: 'blue'), isNull);
    final solemnity = liturgicalVisual(color: 'albus', rank: 'solemnitas')!;
    expect(solemnity.accent, LiturgicalAccents.gold);
  });
}
