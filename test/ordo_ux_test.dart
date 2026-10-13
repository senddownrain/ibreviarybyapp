import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/screens/ordo_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/widgets/hours_options_sheet.dart';
import 'package:mybrev_flutter/widgets/ordo/liturgical_month_calendar.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_sheet.dart';
import 'package:mybrev_flutter/widgets/ordo/vestment_marker.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/ordo/reading_references.dart';

class _Dioceses extends DioceseSelectionNotifier {
  @override
  DioceseSelection build() => const DioceseSelection(
    selected: ['grodno', 'vitebsk'],
    primary: 'vitebsk',
  );
}

/// The «Літургія гадзінаў» section of the Ordo day is collapsed by design:
/// open it before looking at the Office variants.
Future<void> expandOfficeSection(WidgetTester tester) async {
  final tile = find.ancestor(
    of: find.text('Літургія гадзінаў'),
    matching: find.byType(ExpansionTile),
  );
  if (tile.evaluate().isEmpty) return;
  await tester.ensureVisible(tile.first);
  await tester.pump();
  await tester.tap(
    find.descendant(of: tile.first, matching: find.byType(ListTile)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late Directory directory;
  final font = Platform.environment['ORDO_UX_FONT'];
  setUpAll(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('ordo-ux-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
    if (font != null) {
      await (FontLoader('UxSans')..addFont(
            File(
              font,
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/phosphor_flutter/PhosphorRegular')..addFont(
            rootBundle.load('packages/phosphor_flutter/lib/fonts/Phosphor.ttf'),
          ))
          .load();
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<ProviderContainer> frame(
    WidgetTester tester,
    DateTime date,
    Widget child, {
    double width = 360,
    double scale = 1,
    Brightness brightness = Brightness.light,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        selectedDateProvider.overrideWith((ref) => date),
        liturgicalContentReadyProvider.overrideWith((ref) async {}),
        ordoNotesReadyProvider.overrideWith((ref) async {}),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            brightness: brightness,
            fontFamily: font == null ? null : 'UxSans',
          ),
          builder: (context, child) => RepaintBoundary(
            key: const Key('ux-capture'),
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (font == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('ux-capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = Directory('build/ordo_ux')..createSync(recursive: true);
      File(
        '${output.path}/$name.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'calendar sheet keeps radio geometry, real colours and nested Office $brightness $scale',
        (tester) async {
          final container = await frame(
            tester,
            DateTime(2026, 10, 6),
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    showDragHandle: true,
                    builder: (_) => const LiturgicalCalendarSheet(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
            width: scale == 2 ? 320 : 360,
            brightness: brightness,
            scale: scale,
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          final first = container
              .read(hoursLiturgicalSelectionProvider)
              .sortedOptions
              .first;
          final row = find.byKey(ValueKey('hours-celebration-${first.key}'));
          expect(
            tester.widget<RadioListTile<String>>(row).contentPadding,
            EdgeInsets.zero,
          );
          final radioX = tester
              .getTopLeft(
                find.descendant(of: row, matching: find.byType(Radio<String>)),
              )
              .dx;
          final titleX = tester
              .getTopLeft(
                find.descendant(of: row, matching: find.text(first.title)),
              )
              .dx;
          await capture(tester, 'calendar-6-${brightness.name}-$scale');
          await tester.ensureVisible(
            find.byKey(const Key('ordo-day-2026-10-07')),
          );
          await tester.tap(find.byKey(const Key('ordo-day-2026-10-07')));
          await tester.pumpAndSettle();
          final rosary = container
              .read(hoursLiturgicalSelectionProvider)
              .selected!;
          final single = find.byKey(
            ValueKey('hours-celebration-${rosary.key}'),
          );
          expect(
            tester
                .getTopLeft(
                  find.descendant(
                    of: single,
                    matching: find.byType(Radio<String>),
                  ),
                )
                .dx,
            radioX,
          );
          expect(
            tester
                .getTopLeft(
                  find.descendant(
                    of: single,
                    matching: find.text(rosary.title),
                  ),
                )
                .dx,
            titleX,
          );
          expect(
            tester
                .widget<VestmentMarker>(
                  find.descendant(
                    of: single,
                    matching: find.byType(VestmentMarker),
                  ),
                )
                .colors,
            ['albus'],
          );
          expect(find.byType(LiturgicalCalendarSheet), findsOneWidget);
          await tester.ensureVisible(single);
          await tester.pumpAndSettle();
          await capture(tester, 'calendar-7-${brightness.name}-$scale');
          final template = find.byKey(
            ValueKey('hours-template-${rosary.templates.last.id}'),
          );
          await tester.ensureVisible(template);
          await tester.tap(template);
          await tester.pumpAndSettle();
          expect(
            container.read(hoursLiturgicalSelectionProvider).dayId,
            rosary.templates.last.id,
          );
          expect(find.byType(LiturgicalCalendarSheet), findsOneWidget);
          await capture(tester, 'calendar-7-common-${brightness.name}-$scale');
          await tester.ensureVisible(
            find.byKey(const Key('ordo-day-2026-10-09')),
          );
          await tester.tap(find.byKey(const Key('ordo-day-2026-10-09')));
          await tester.pumpAndSettle();
          final options = container
              .read(hoursLiturgicalSelectionProvider)
              .sortedOptions;
          for (final option in options.where((o) => o.ordo != null)) {
            final marker = tester.widget<VestmentMarker>(
              find.descendant(
                of: find.byKey(ValueKey('hours-celebration-${option.key}')),
                matching: find.byType(VestmentMarker),
              ),
            );
            expect(
              marker.colors,
              <String>{
                option.ordo!.color,
                ...option.ordo!.colorAlternatives,
              }.toList(),
            );
          }
          await tester.ensureVisible(
            find.byKey(ValueKey('hours-celebration-${options.first.key}')),
          );
          await tester.pumpAndSettle();
          await capture(tester, 'calendar-9-${brightness.name}-$scale');
          expect(find.text('Пошук паводле перыяду або свята'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'month/year jump browses independently, supports keyboard and calendar bounds',
    (tester) async {
      final date = DateTime(2026, 10, 7);
      DateTime? picked;
      final semantics = tester.ensureSemantics();
      await frame(
        tester,
        date,
        Scaffold(
          body: SingleChildScrollView(
            child: LiturgicalMonthCalendar(
              initialDate: date,
              onSelected: (d) => picked = d,
            ),
          ),
        ),
      );
      Future<void> jump(int year, int month) async {
        await tester.tap(find.byKey(const Key('ordo-jump-month')));
        await tester.pumpAndSettle();
        final yearField = find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<int> &&
              w.decoration.labelText == 'Год',
        );
        tester.widget<DropdownButtonFormField<int>>(yearField).onChanged!(year);
        await tester.pumpAndSettle();
        final monthField = find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<int> &&
              w.decoration.labelText == 'Месяц',
        );
        tester.widget<DropdownButtonFormField<int>>(monthField).onChanged!(
          month,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ordo-jump-apply')));
        await tester.pumpAndSettle();
        expect(picked, isNull);
      }

      await jump(2031, 11);
      expect(find.byKey(const Key('ordo-day-2031-11-02')), findsOneWidget);
      await jump(kCalendarFirstDate.year, kCalendarFirstDate.month);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('ordo-previous-month')))
            .onPressed,
        isNull,
      );
      await jump(kCalendarLastDate.year, kCalendarLastDate.month);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('ordo-next-month')))
            .onPressed,
        isNull,
      );
      await jump(2026, 10);
      await tester.tap(find.byKey(const Key('ordo-jump-month')));
      await tester.pumpAndSettle();
      await capture(tester, 'month-year-jump');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(picked, isNull);
      await tester.tap(find.byKey(const Key('ordo-day-2026-10-09')));
      await tester.pumpAndSettle();
      expect(picked, DateTime(2026, 10, 9));
      expect(
        tester
            .getSemantics(find.byKey(const Key('ordo-day-2026-10-07')))
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  for (final year in [2025, 2031]) {
    testWidgets(
      'All Souls $year displays three Mass sets and Sunday Office once',
      (tester) async {
        final date = DateTime(year, 11, 2);
        await frame(tester, date, OrdoScreen(initialDate: date));
        await expandOfficeSection(tester);
        expect(find.byKey(const Key('ordo-office-split')), findsOneWidget);
        for (final id in ['first', 'second', 'third']) {
          expect(find.byKey(ValueKey('ordo-mass-set-$id')), findsOneWidget);
        }
        await capture(tester, 'all-souls-$year-header');
        await tester.ensureVisible(
          find.byKey(const ValueKey('ordo-mass-set-first')),
        );
        await tester.pumpAndSettle();
        await capture(tester, 'all-souls-$year-readings');
        await tester.ensureVisible(find.byKey(const Key('ordo-office-split')));
        await tester.pumpAndSettle();
        await capture(tester, 'all-souls-$year-office');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'month/year dialog stays usable at 320px, text x2, $brightness',
      (tester) async {
        await frame(
          tester,
          DateTime(2026, 10, 7),
          Scaffold(
            body: SingleChildScrollView(
              child: LiturgicalMonthCalendar(
                initialDate: DateTime(2026, 10, 7),
                onSelected: (_) {},
              ),
            ),
          ),
          width: 320,
          scale: 2,
          brightness: brightness,
        );
        await tester.tap(find.byKey(const Key('ordo-jump-month')));
        await tester.pumpAndSettle();
        await capture(tester, 'month-year-jump-${brightness.name}-2.0');
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is DropdownButtonFormField<int> &&
                w.decoration.labelText == 'Месяц',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ordo-jump-apply')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('ordo-day-2026-10-07')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'selected alternative and competing memorials keep one heading and collapsed details',
    (tester) async {
      for (final date in [
        DateTime(2026, 10, 6),
        DateTime(2026, 10, 9),
        DateTime(2026, 6, 13),
      ]) {
        final option = LiturgicalContentService()
            .contentForDate(date)
            .options
            .where((o) => o.ordo?.role == 'alternative')
            .first;
        await frame(
          tester,
          date,
          OrdoScreen(initialDate: date, dayId: option.templates.last.id),
        );
        expect(find.text(option.title), findsWidgets);
        if (date.month == 6 && date.day == 13) {
          final refs = readingReferencesForDay(
            LiturgicalContentService().contentForDate(date).ordo,
            ReadingReferenceIndex.current(),
          ).singleWhere((r) => r.optionId == 'sv-anthony-padua');
          expect(refs.reference, isNotNull);
          expect(find.text('Чытанні: ${refs.reference}'), findsOneWidget);
          expect(
            find.text('Поўны тэкст гэтых чытанняў пакуль недаступны'),
            findsOneWidget,
          );
        }
        expect(find.text('Абрана'), findsOneWidget);
        final directions = find.ancestor(
          of: find.text('Асаблівыя ўказанні'),
          matching: find.byType(ExpansionTile),
        );
        final notes = find.ancestor(
          of: find.text('Літургічныя заўвагі'),
          matching: find.byType(ExpansionTile),
        );
        expect(
          tester.widget<ExpansionTile>(directions).initiallyExpanded,
          isFalse,
        );
        expect(tester.widget<ExpansionTile>(notes).initiallyExpanded, isFalse);
        await capture(tester, 'selected-${date.month}-${date.day}-header');
        await tester.ensureVisible(find.byKey(const Key('ordo-open-hours')));
        await tester.pumpAndSettle();
        await capture(tester, 'selected-${date.month}-${date.day}-office');
        await tester.scrollUntilVisible(
          find.text('Асаблівыя ўказанні'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Асаблівыя ўказанні')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Асаблівыя ўказанні'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Камплета:'), findsOneWidget);
        await capture(tester, 'selected-${date.month}-${date.day}-directions');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'diocesan differences remain visible and identical readings appear once',
    (tester) async {
      final date = DateTime(2026, 8, 26);
      await frame(
        tester,
        date,
        OrdoScreen(initialDate: date),
        overrides: [dioceseSelectionProvider.overrideWith(_Dioceses.new)],
      );
      expect(
        find.textContaining('Выбраныя дыяцэзіі адрозніваюцца'),
        findsOneWidget,
      );
      await capture(tester, 'dioceses-header');
      await tester.ensureVisible(
        find.textContaining('Выбраныя дыяцэзіі адрозніваюцца'),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'dioceses-celebrations');
      await tester.pumpWidget(const SizedBox());
      await frame(
        tester,
        DateTime(2026, 10, 9),
        OrdoScreen(initialDate: DateTime(2026, 10, 9)),
      );
      final groups = find.byKey(const Key('ordo-reading-references'));
      final citations = <String>[];
      for (final text in tester.widgetList<Text>(
        find.descendant(of: groups, matching: find.byType(Text)),
      )) {
        if (text.textSpan is TextSpan) {
          final span = text.textSpan! as TextSpan;
          citations.add((span.children!.last as TextSpan).text!);
        }
      }
      expect(citations, isNotEmpty);
      expect(citations.toSet().length, citations.length);
      expect(tester.takeException(), isNull);
    },
  );

  for (final day in [7, 9]) {
    for (final width in [360.0, 430.0]) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 1.5]) {
          testWidgets('selector Oct $day, $width, $brightness, scale $scale', (
            tester,
          ) async {
            final date = DateTime(2026, 10, day);
            final container = await frame(
              tester,
              date,
              Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) =>
                          HoursOptionsSheet(date: date, color: Colors.green),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
              width: width,
              scale: scale,
              brightness: brightness,
            );
            await tester.tap(find.text('open'));
            await tester.pumpAndSettle();
            final options = container
                .read(hoursLiturgicalSelectionProvider)
                .sortedOptions;
            final sheet = find.byType(HoursOptionsSheet);
            if (day == 7) {
              expect(
                find.byKey(const Key('hours-single-celebration')),
                findsNothing,
              );
              expect(
                find.byKey(ValueKey('hours-celebration-${options.first.key}')),
                findsOneWidget,
              );
              expect(
                find.descendant(of: sheet, matching: find.text('З дня')),
                findsOneWidget,
              );
              final marian = find.text('Пра Найсвяцейшую Панну Марыю');
              expect(marian, findsOneWidget);
              if (scale == 1) expect(marian.hitTestable(), findsOneWidget);
            } else {
              expect(find.text('СВЯТКАВАННЕ'), findsOneWidget);
              expect(
                options.where((o) => o.ordo?.role == 'alternative').length,
                greaterThanOrEqualTo(2),
              );
              for (final option in options.where(
                (o) => o.ordo?.role == 'alternative',
              )) {
                final row = find.byKey(
                  ValueKey('hours-celebration-${option.key}'),
                );
                await tester.ensureVisible(row);
                await tester.tap(row);
                await tester.pumpAndSettle();
                expect(
                  container
                      .read(hoursLiturgicalSelectionProvider)
                      .selected
                      ?.optionId,
                  option.optionId,
                );
                expect(find.text(option.title), findsWidgets);
                if (option.templates.length > 1) {
                  final variants = find.byKey(
                    ValueKey('hours-variants-${option.key}'),
                  );
                  expect(variants, findsOneWidget);
                  expect(
                    tester.getTopLeft(variants).dy,
                    greaterThan(tester.getTopLeft(row).dy),
                  );
                  final template = option.templates.last;
                  final choice = find.byKey(
                    ValueKey('hours-template-${template.id}'),
                  );
                  await tester.ensureVisible(choice);
                  await tester.tap(choice);
                  await tester.pumpAndSettle();
                  expect(
                    container.read(hoursLiturgicalSelectionProvider).dayId,
                    template.id,
                  );
                }
              }
              expect(find.text('ІНШЫЯ АФІЦЫІ'), findsOneWidget);
              final dead = options.singleWhere(
                (o) => o.optionId == 'office-for-dead',
              );
              final row = find.byKey(ValueKey('hours-celebration-${dead.key}'));
              await tester.ensureVisible(row);
              await tester.tap(row);
              await tester.pumpAndSettle();
              expect(
                container
                    .read(hoursLiturgicalSelectionProvider)
                    .selected
                    ?.optionId,
                dead.optionId,
              );
              // Return to the final memorial for the visual review.
              final memorial = options.lastWhere(
                (o) => o.ordo?.role == 'alternative',
              );
              final memorialRow = find.byKey(
                ValueKey('hours-celebration-${memorial.key}'),
              );
              await tester.ensureVisible(memorialRow);
              await tester.tap(memorialRow);
              await tester.pumpAndSettle();
            }
            expect(
              tester
                  .getSize(
                    find.widgetWithText(FilledButton, 'Літургія гадзінаў'),
                  )
                  .height,
              greaterThanOrEqualTo(48),
            );
            expect(
              find
                  .widgetWithText(FilledButton, 'Літургія гадзінаў')
                  .hitTestable(),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            if (width == 360) {
              await capture(tester, 'selector-$day-${brightness.name}-$scale');
            }
            final applied = container
                .read(hoursLiturgicalSelectionProvider)
                .dayId;
            await tester.tap(
              find.widgetWithText(FilledButton, 'Літургія гадзінаў'),
            );
            await tester.pumpAndSettle();
            expect(find.byType(HoursOptionsSheet), findsNothing);
            expect(
              container.read(hoursLiturgicalSelectionProvider).dayId,
              applied,
            );
          });
        }
      }
    }
  }

  testWidgets('selector keeps distinct diocesan rows of the same celebration', (
    tester,
  ) async {
    final date = DateTime(2026, 10, 7);
    final base = LiturgicalContentService().contentForDate(date).options.first;
    final options = [
      base.copyWith(
        key: '${base.key}@grodno',
        contextDiocese: 'grodno',
        dioceses: ['grodno'],
        badges: ['Гродна'],
      ),
      base.copyWith(
        key: '${base.key}@pinsk',
        contextDiocese: 'pinsk',
        dioceses: ['pinsk'],
        badges: ['Пінск'],
      ),
    ];
    final container = await frame(
      tester,
      date,
      Scaffold(
        body: HoursOptionsSheet(date: date, color: Colors.blue),
      ),
      overrides: [dayOptionsProvider.overrideWithValue(options)],
    );
    expect(find.textContaining('Гродна'), findsOneWidget);
    expect(find.textContaining('Пінск'), findsOneWidget);
    final row = find.byKey(ValueKey('hours-celebration-${options.last.key}'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(
      container.read(hoursLiturgicalSelectionProvider).selected?.key,
      options.last.key,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ORDO October 7 keeps memorial data and both Office variants', (
    tester,
  ) async {
    final date = DateTime(2026, 10, 7);
    await frame(tester, date, OrdoScreen(initialDate: date));
    expect(
      find.byKey(const Key('ordo-row-our-lady-rosary-primary')),
      findsOneWidget,
    );
    await expandOfficeSection(tester);
    expect(find.textContaining('• З дня'), findsOneWidget);
    expect(find.text('• Пра Найсвяцейшую Панну Марыю'), findsOneWidget);
    expect(
      find.textContaining('Год II · III тыдзень Псалтыра'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Белы'), findsWidgets);
    expect(find.text('Літургія гадзінаў'), findsWidgets);
    expect(find.text('Чытанні'), findsWidgets);
    await capture(tester, 'day-7-light');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'month lists all days, crosses year and respects calendar bounds',
    (tester) async {
      final date = DateTime(2026, 12, 31);
      await frame(tester, date, OrdoMonthScreen(initialDate: date));
      expect(find.byKey(const Key('ordo-day-2026-12-01')), findsOneWidget);
      expect(find.byKey(const Key('ordo-day-2026-12-31')), findsOneWidget);
      await tester.tap(find.byKey(const Key('ordo-next-month')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ordo-day-2027-01-01')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ordo-day-2027-01-31')), findsOneWidget);
      await tester.tap(find.byKey(const Key('ordo-previous-month')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ordo-day-2026-12-31')).hitTestable(),
        findsOneWidget,
      );
      for (final boundary in [kCalendarFirstDate, kCalendarLastDate]) {
        await tester.pumpWidget(const SizedBox());
        await frame(tester, boundary, OrdoMonthScreen(initialDate: boundary));
        final arrow = boundary == kCalendarFirstDate
            ? 'ordo-previous-month'
            : 'ordo-next-month';
        expect(
          tester.widget<IconButton>(find.byKey(Key(arrow))).onPressed,
          isNull,
        );
      }
      await tester.pumpWidget(const SizedBox());
      await frame(
        tester,
        DateTime(2028, 2, 29),
        OrdoMonthScreen(initialDate: DateTime(2028, 2, 29)),
      );
      expect(find.byKey(const Key('ordo-day-2028-02-29')), findsOneWidget);
      expect(find.byKey(const Key('ordo-day-2028-03-01')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('day and month utility layout $brightness $scale', (
        tester,
      ) async {
        final date = DateTime(2026, 10, 9);
        await frame(
          tester,
          date,
          OrdoScreen(initialDate: date),
          scale: scale,
          brightness: brightness,
        );
        expect(find.byKey(const Key('ordo-open-month')), findsOneWidget);
        expect(find.byKey(const Key('ordo-open-readings')), findsOneWidget);
        expect(find.byKey(const Key('ordo-open-hours')), findsOneWidget);
        expect(find.byType(RadioListTile<String>), findsNothing);
        expect(find.text('Літургія гадзінаў'), findsWidgets);
        expect(find.text('Чытанні'), findsWidgets);
        await capture(tester, 'day-${brightness.name}-$scale');
        await tester.pumpWidget(const SizedBox());
        await frame(
          tester,
          date,
          OrdoMonthScreen(initialDate: date),
          scale: scale,
          brightness: brightness,
        );
        expect(find.byType(LiturgicalMonthCalendar), findsNothing);
        final selected = find.byKey(const Key('ordo-day-2026-10-09'));
        expect(selected.hitTestable(), findsOneWidget);
        expect(
          find.descendant(
            of: selected,
            matching: find.textContaining('Дыянісія'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: selected,
            matching: find.textContaining('Леанардзі'),
          ),
          findsOneWidget,
        );
        await capture(tester, 'month-${brightness.name}-$scale');
        await tester.tap(find.byKey(const Key('ordo-next-month')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('ordo-day-2026-11-01')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('ordo-previous-month')));
        await tester.pumpAndSettle();
        expect(selected.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
