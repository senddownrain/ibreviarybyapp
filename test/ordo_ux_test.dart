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
                findsOneWidget,
              );
              expect(
                find.byKey(const Key('hours-celebration-our-lady-rosary')),
                findsNothing,
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
                expect(find.text(option.title), findsOneWidget);
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
                  .getSize(find.widgetWithText(FilledButton, 'Літургія'))
                  .height,
              greaterThanOrEqualTo(48),
            );
            expect(
              find.widgetWithText(FilledButton, 'Літургія').hitTestable(),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            if (width == 360) {
              await capture(tester, 'selector-$day-${brightness.name}-$scale');
            }
            final applied = container
                .read(hoursLiturgicalSelectionProvider)
                .dayId;
            await tester.tap(find.widgetWithText(FilledButton, 'Літургія'));
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
    expect(find.text('• З дня'), findsOneWidget);
    expect(find.text('• Пра Найсвяцейшую Панну Марыю'), findsOneWidget);
    expect(find.text('Псалтыр III · Год II'), findsOneWidget);
    expect(find.textContaining('Успамін · Белы'), findsOneWidget);
    expect(find.byType(TextButton), findsNWidgets(2));
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
        expect(find.text('Адкрыць чытанні'), findsOneWidget);
        expect(find.text('Адкрыць Літургію гадзін'), findsOneWidget);
        expect(find.byType(RadioListTile<String>), findsNothing);
        expect(find.byType(TextButton), findsNWidgets(2));
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
