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
import 'package:mybrev_flutter/ordo/runtime.dart';

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
    expect(find.bySemanticsLabel('Белы'), findsOneWidget);
    expect(
      find.textContaining('Колер літургічнага адзення', findRichText: true),
      findsNothing,
    );
    expect(find.text('Св. Анёлаў Ахоўнікаў'), findsOneWidget);
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

  testWidgets('books are collapsed; All Souls on Sunday names the '
      'Office of the Sunday', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pump(tester, app(DateTime(2025, 11, 2)));
    final books = find.byKey(const Key('ordo-book-Лекцыянарый-Том III'));
    expect(books.hitTestable(), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Літургічныя кнігі'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Літургічныя кнігі')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Літургічныя кнігі'));
    await tester.pumpAndSettle();
    expect(books, findsOneWidget);
    expect(
      find.descendant(of: books, matching: find.text('Том III')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('ordo-book-Літургія гадзінаў-Том III')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Літургія гадзінаў').first,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Літургія гадзінаў').first),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Літургія гадзінаў').first);
    await tester.pumpAndSettle();
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
      find.descendant(
        of: find.byKey(const Key('ordo-office-split')),
        matching: find.text(
          OrdoRuntime.engine.resolve('2025-11-02').sources.office.title,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Sunday suppressed celebrations stay inside collapsed notes', (
    tester,
  ) async {
    await pump(tester, app(DateTime(2026, 10, 11)));
    expect(find.text('Іншыя святкаванні дня'), findsNothing);
    expect(find.textContaining('Не адзначаюцца').hitTestable(), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Літургічныя заўвагі'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Літургічныя заўвагі')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Літургічныя заўвагі'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Не адзначаюцца'), findsOneWidget);
  });

  testWidgets('13.06.2026: weekday primary and two optional memorials', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pump(tester, app(DateTime(2026, 6, 13)));
    expect(
      find.byKey(
        const Key('ordo-row-immaculate-heart-alternative'),
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
      find.text('Можна выбраць замест', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('each celebration displays its own legal colour', (tester) async {
    // 06.10.2026: the weekday (green) and St Bruno (white).
    await pump(tester, app(DateTime(2026, 10, 6)));
    final markers = tester
        .widgetList<VestmentMarker>(find.byType(VestmentMarker))
        .map((m) => m.colors);
    expect(find.bySemanticsLabel('Зялёны'), findsWidgets);
    expect(markers, contains(equals(['albus'])));
    expect(
      find.text('Неабавязковы ўспамін', skipOffstage: false),
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
