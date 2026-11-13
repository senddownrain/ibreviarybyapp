import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/ordo/day_union.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_day_presentation_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/widgets/liturgical_date_navigation_row.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_disclosure.dart';
import 'package:mybrev_flutter/widgets/liturgical_selector_components.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/widgets/selection_option_card.dart';
import 'package:mybrev_flutter/router/router.dart' as production;
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/screens/liturgical_picker_screen.dart';
import 'package:mybrev_flutter/widgets/ordo/liturgical_month_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_visual.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_sheet.dart';
import 'package:mybrev_flutter/widgets/liturgical_day_header.dart';
import 'package:mybrev_flutter/screens/ordo_screen.dart';
import 'package:mybrev_flutter/widgets/hours_options_sheet.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';

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

class _FourDioceses extends DioceseSelectionNotifier {
  @override
  DioceseSelection build() => const DioceseSelection(
    primary: 'minsk-mohilev',
    selected: ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk'],
  );
}

class _VitebskDiocese extends DioceseSelectionNotifier {
  @override
  DioceseSelection build() => const DioceseSelection(
    primary: 'vitebsk',
    selected: ['vitebsk'],
  );
}

/// The «Today» buttons exist only when the shown date is not the real today
/// (the wall clock), so a fixed preview date must never be today.
DateTime _notToday(DateTime date) {
  final now = DateTime.now();
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  return isToday ? date.add(const Duration(days: 1)) : date;
}

void main() {
  late Directory directory;
  final capture = GlobalKey();
  final previewFont = Platform.environment['HEADER_PREVIEW_FONT'];
  setUpAll(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('liturgical-header-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
    if (previewFont != null) {
      await (FontLoader('HeaderSans')..addFont(
            File(previewFont).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
      for (final font in <String, String>{
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        'packages/phosphor_flutter/PhosphorRegular':
            'packages/phosphor_flutter/lib/fonts/Phosphor.ttf',
        'packages/phosphor_flutter/PhosphorBold':
            'packages/phosphor_flutter/lib/fonts/Phosphor-Bold.ttf',
        'packages/phosphor_flutter/PhosphorLight':
            'packages/phosphor_flutter/lib/fonts/Phosphor-Light.ttf',
        'packages/phosphor_flutter/PhosphorFill':
            'packages/phosphor_flutter/lib/fonts/Phosphor-Fill.ttf',
        GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700).fontFamily!:
            'assets/google_fonts/CormorantGaramond-Bold.ttf',
        GoogleFonts.literata().fontFamily!:
            'assets/google_fonts/Literata-Regular.ttf',
      }.entries) {
        await (FontLoader(
          font.key,
        )..addFont(rootBundle.load(font.value))).load();
      }
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  ProviderContainer containerFor(
    DateTime date, [
    List<Override> overrides = const [],
  ]) => ProviderContainer(
    overrides: [
      selectedDateProvider.overrideWith((ref) => date),
      liturgicalContentReadyProvider.overrideWith((ref) async {}),
      contentUpdatesProvider.overrideWith(_Idle.new),
      settingsProvider.overrideWith(_Settings.new),
      ...overrides,
    ],
  );

  Future<(GoRouter, ProviderContainer)> start(
    WidgetTester tester, {
    double scale = 1,
    double width = 390,
    Brightness brightness = Brightness.light,
    DateTime? date,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = containerFor(date ?? DateTime(2026, 10, 7), overrides);
    final router = GoRouter(
      initialLocation: '/hours',
      navigatorKey: production.rootNavigatorKey,
      routes: production.router.configuration.routes,
    );
    addTearDown(container.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(
            platform: TargetPlatform.android,
            colorScheme: AppPalette.scheme(brightness),
            fontFamily: previewFont == null ? null : 'HeaderSans',
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: capture, child: child!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (router, container);
  }

  Future<void> snapshot(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('HEADER_PREVIEWS')) return;
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = Directory(
        Platform.environment['SELECTOR_EVIDENCE_DIR'] ??
            'build/refinement-header',
      );
      await output.create(recursive: true);
      await File(
        '${output.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pump();
  }

  testWidgets(
    'approved 12 November Vitebsk Hours and Readings headers',
    (tester) async {
      final (router, container) = await start(
        tester,
        date: DateTime(2026, 11, 12),
        overrides: [
          dioceseSelectionProvider.overrideWith(_VitebskDiocese.new),
        ],
      );
      final presentation = container.read(liturgicalDayPresentationProvider);
      expect(presentation.title, contains('Язафата'));
      expect(presentation.place, contains('Віцебская дыяцэзія'));
      expect(presentation.rank, isNotEmpty);
      expect(find.text('Віцебская дыяцэзія'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LiturgicalDayHeader),
          matching: find.byType(Chip),
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(find.text('Віцебская дыяцэзія')).dy,
        lessThan(
          tester.getTopLeft(
            find.byKey(const Key('hours-celebration-title')),
          ).dy,
        ),
      );
      final hoursMetadata = tester.widget<Text>(
        find.byKey(const Key('hours-day-metadata')),
      );
      expect(
        hoursMetadata.textSpan!.toPlainText(),
        startsWith(presentation.rank),
      );
      expect(
        hoursMetadata.textSpan!.toPlainText(),
        isNot(contains('тыдзень Псалтыра')),
      );
      await snapshot(tester, 'approved-vitebsk-hours-12-nov-2026');

      router.go('/readings');
      await tester.pumpAndSettle();
      expect(find.text('Віцебская дыяцэзія'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LiturgicalDayHeader),
          matching: find.byType(Chip),
        ),
        findsNothing,
      );
      final readingsMetadata = tester.widget<Text>(
        find.byKey(const Key('readings-day-metadata')),
      );
      expect(
        readingsMetadata.textSpan!.toPlainText(),
        startsWith(presentation.rank),
      );
      expect(
        readingsMetadata.textSpan!.toPlainText(),
        contains('Год II'),
      );
      expect(
        readingsMetadata.textSpan!.toPlainText(),
        isNot(contains('тыдзень Псалтыра')),
      );
      await snapshot(tester, 'approved-vitebsk-readings-12-nov-2026');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '12 November alternatives show each diocese once while preserving ranks',
    (tester) async {
      final (router, container) = await start(
        tester,
        date: DateTime(2026, 11, 12),
        overrides: [
          dioceseSelectionProvider.overrideWith(_FourDioceses.new),
        ],
      );
      await tester.tap(find.byKey(const Key('hours-alternatives-control')));
      await tester.pumpAndSettle();

      final options = container
          .read(hoursLiturgicalSelectionProvider)
          .sortedOptions
          .where((option) => !option.disabled && option.day != null)
          .toList();
      final localOptions = options.where(
        (option) => option.badges.contains('Мінск') ||
            option.badges.contains('Віцебск'),
      ).toList();
      expect(localOptions.any((o) => o.badges.contains('Мінск')), isTrue);
      expect(localOptions.any((o) => o.badges.contains('Віцебск')), isTrue);
      for (final option in localOptions) {
        final choice = tester.widget<LiturgicalCelebrationChoice>(
          find.byKey(ValueKey('hours-celebration-${option.key}')),
        );
        final subtitle = choice.subtitle ?? '';
        final pieces = subtitle.split(' · ');
        for (final badge in option.badges) {
          expect(pieces, isNot(contains(badge)),
              reason: 'Duplicate diocese badge in ${option.title}');
          final full = switch (badge) {
            'Мінск' => 'Мінска-Магілёўская архідыяцэзія',
            'Віцебск' => 'Віцебская дыяцэзія',
            'Гродна' => 'Гродзенская дыяцэзія',
            'Пінск' => 'Пінская дыяцэзія',
            _ => badge,
          };
          expect(subtitle, contains(full));
          expect(full.allMatches(subtitle).length, 1,
              reason: 'Repeated full diocese in ${option.title}');
        }
        if (option.ordo case final ordo?) {
          final rank = kRankLabels[ordo.rank] ??
              ordoOfficeKindLabel(ordo.officeKind);
          if (rank.isNotEmpty) expect(subtitle, startsWith(rank));
        }
      }
      expect(tester.takeException(), isNull);
      router.pop();
    },
  );

  testWidgets('date control visual preview: light Readings', (
    tester,
  ) async {
    final (router, _) = await start(
      tester,
      width: 390,
      brightness: Brightness.light,
      date: _notToday(DateTime(2026, 11, 13)),
    );
    router.go('/readings');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('readings-today')), findsOneWidget);
    // Date has no elevated floating-card shadow; alternatives have a
    // discoverable but still neutral tap surface.
    final dateBox = tester.widget<DecoratedBox>(
      find.byKey(const Key('readings-date-control')),
    );
    final dateDecoration = dateBox.decoration as BoxDecoration;
    expect(dateDecoration.boxShadow, isNull);
    expect(dateDecoration.color!.a, lessThan(0.04));
    final alternatives = tester.widget<TextButton>(
      find.byKey(const Key('readings-alternatives-control')),
    );
    final alternativesFill = alternatives.style?.backgroundColor?.resolve({});
    expect(alternativesFill, isNotNull);
    expect(alternativesFill!.a, lessThan(0.025));
    expect(alternatives.style?.minimumSize?.resolve({})?.height, 48);
    expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
    await snapshot(tester, 'polished-date-control-readings-light-2026-11-13');
    expect(tester.takeException(), isNull);
  });

  testWidgets('date control visual preview: dark Hours and Readings', (
    tester,
  ) async {
    // Screenshot evidence from the actual Flutter widgets, not a mockup.
    final (router, container) = await start(
      tester,
      width: 390,
      brightness: Brightness.dark,
      date: _notToday(DateTime(2026, 11, 21)),
    );
    expect(find.byKey(const Key('hours-today')), findsOneWidget);
    await snapshot(tester, 'polished-date-control-hours-dark-2026-11-21');
    router.go('/readings');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('readings-today')), findsOneWidget);
    await snapshot(tester, 'polished-date-control-readings-dark-2026-11-21');

    container
        .read(liturgicalNavigationControllerProvider)
        .openDate(DateTime.now());
    router.go('/hours');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hours-today')), findsNothing);
    await snapshot(tester, 'polished-date-control-hours-dark-today');
  });

  test('real weekday and Marian memorial share canonical presentation', () {
    final container = containerFor(DateTime(2026, 10, 6));
    addTearDown(container.dispose);
    var p = container.read(liturgicalDayPresentationProvider);
    expect(p.title, 'XXVII звычайны тыдзень');
    expect(p.metadata, 'Аўторак · III тыдзень Псалтыра');
    container.read(liturgicalNavigationControllerProvider).moveBy(1);
    p = container.read(liturgicalDayPresentationProvider);
    expect(p.title, contains('Ружанцовай'));
    expect(p.metadata, 'Серада · III тыдзень Псалтыра');
    expect(p.accent, LiturgicalAccents.marian);
    expect(p.variantCount, greaterThan(1));
    container
        .read(liturgicalNavigationControllerProvider)
        .openDate(DateTime(2026, 10, 11));
    expect(
      container.read(liturgicalDayPresentationProvider).metadata,
      'Нядзеля · IV тыдзень Псалтыра',
    );
  });

  test('manual Office survives date round trip and calendar bounds', () async {
    final date = DateTime(2026, 10, 7);
    final container = containerFor(date);
    addTearDown(container.dispose);
    container.read(liturgicalNavigationSyncProvider);
    final controller = container.read(liturgicalNavigationControllerProvider);
    final selected = container.read(hoursLiturgicalSelectionProvider).selected!;
    final alternative = selected.templates.last.id;
    controller.selectDay(date, alternative, diocese: selected.contextDiocese);
    controller.moveBy(1);
    controller.moveBy(-1);
    await container.pump();
    expect(container.read(hoursLiturgicalSelectionProvider).dayId, alternative);
    expect(container.read(readingsBranchStateProvider).dayId, alternative);
    controller.openDate(kCalendarFirstDate);
    controller.moveBy(-1);
    expect(container.read(selectedDateProvider), kCalendarFirstDate);
    controller.openDate(kCalendarLastDate);
    controller.moveBy(1);
    expect(container.read(selectedDateProvider), kCalendarLastDate);
  });

  testWidgets(
    'both headers retain title and blue accent after Office selection',
    (tester) async {
      final (router, container) = await start(tester);
      final original = container.read(liturgicalDayPresentationProvider);
      await snapshot(tester, 'hours-marian');
      await tester.tap(find.byKey(const Key('hours-alternatives-control')));
      await tester.pumpAndSettle();
      final selection = container.read(hoursLiturgicalSelectionProvider);
      final alternative = selection.selected!.templates.last.id;
      await tester.tap(find.byKey(ValueKey('hours-template-$alternative')));
      await tester.pumpAndSettle();
      await snapshot(tester, 'calendar-variants');
      await tester.tap(find.text('Гатова'));
      await tester.pumpAndSettle();
      router.go('/readings');
      await tester.pumpAndSettle();
      final header = tester.widget<LiturgicalDayHeader>(
        find.byType(LiturgicalDayHeader),
      );
      expect(header.presentation.title, original.title);
      expect(header.presentation.accent, LiturgicalAccents.marian);
      expect(
        container.read(hoursLiturgicalSelectionProvider).dayId,
        alternative,
      );
      expect(find.byKey(const Key('readings-today')), findsOneWidget);
      expect(find.text('Сёння'), findsNothing);
      await snapshot(tester, 'readings-marian');
      await tester.tap(find.byKey(const Key('readings-date-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('readings-options-sheet')), findsOneWidget);
      await snapshot(tester, 'calendar');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Hours date expands the same chooser; Today and deep search remain available',
    (tester) async {
      final (router, container) = await start(tester);
      await tester.tap(find.byKey(const Key('hours-previous-day')));
      await tester.pumpAndSettle();
      expect(container.read(selectedDateProvider), DateTime(2026, 10, 6));
      await tester.tap(find.byKey(const Key('hours-date-action')));
      await tester.pumpAndSettle();
      expect(find.byType(LiturgicalMonthCalendar), findsOneWidget);
      await tester.tap(find.byKey(const Key('ordo-day-2026-10-07')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('compact-liturgical-calendar')),
        findsNothing,
      );
      expect(find.byType(OrdoScreen), findsNothing);
      expect(find.byType(LiturgicalCalendarSheet), findsOneWidget);
      expect(container.read(selectedDateProvider), DateTime(2026, 10, 7));
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hours-today')));
      await tester.pumpAndSettle();
      expect(
        DateUtils.isSameDay(
          container.read(selectedDateProvider),
          DateTime.now(),
        ),
        isTrue,
      );
      await tester.tap(find.byKey(const Key('hours-date-action')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('liturgical-calendar-picker')),
      );
      await tester.tap(find.byKey(const Key('liturgical-calendar-picker')));
      await tester.pumpAndSettle();
      expect(find.byType(LiturgicalPickerScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Readings chooser stays reactive across celebrations, years and dates',
    (tester) async {
      String? singleDayId;
      final (router, container) = await start(
        tester,
        overrides: [
          readingsLocalLoaderProvider.overrideWithValue(
            ({required dateStr, required liturgicalKey, required dayId}) =>
                null,
          ),
          readingsLoaderProvider.overrideWithValue(
            ({
              required dateStr,
              required liturgicalKey,
              required dayId,
            }) async => ReadingsLoadResult(
              sundayCycle: 'A',
              weekdayCycle: '2',
              readings: [
                if (dayId != null && dayId == singleDayId)
                  const ParsedReading(
                    id: 'single',
                    title: 'Уласныя чытанні',
                    reading1: ParsedSection(text: 'Адзіны ўласны тэкст.'),
                  )
                else ...[
                  const ParsedReading(
                    id: 'year1',
                    dayId: 'weekday',
                    title: 'Чытанні дня',
                    year: '1',
                    reading1: ParsedSection(text: 'Тэкст першага года.'),
                  ),
                  const ParsedReading(
                    id: 'year2',
                    dayId: 'weekday',
                    title: 'Чытанні дня',
                    year: '2',
                    reading1: ParsedSection(text: 'Тэкст другога года.'),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
      container
          .read(liturgicalNavigationControllerProvider)
          .openDate(DateTime(2026, 10, 9));
      await tester.pumpAndSettle();
      final options = container
          .read(hoursLiturgicalSelectionProvider)
          .sortedOptions;
      final memorial = options.firstWhere((o) => o.title.contains('Дыянісія'));
      singleDayId = memorial.dayId;
      final weekday = options.firstWhere((o) => o.ordo?.kind == 'temporal');
      router.go('/readings');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('readings-alternatives-control')));
      await tester.pumpAndSettle();
      Future<void> choose(String key) async {
        final finder = find.byKey(ValueKey(key));
        await tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('readings-options-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('readings-options-sheet')), findsOneWidget);
      }

      await choose('readings-celebration-${memorial.key}');
      expect(
        container.read(hoursLiturgicalSelectionProvider).selected?.key,
        memorial.key,
      );
      expect(find.byKey(const ValueKey('readings-cycle-1')), findsNothing);
      expect(
        find.byKey(ValueKey('readings-celebration-${weekday.key}')),
        findsOneWidget,
      );
      await choose('readings-celebration-${weekday.key}');
      await choose('readings-cycle-1');
      expect(
        tester
            .widget<SelectionOptionCard>(
              find.byKey(const ValueKey('readings-cycle-1')),
            )
            .selected,
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('readings-options-done')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('readings-options-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('readings-options-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('readings-options-sheet')), findsNothing);
      expect(find.textContaining('Тэкст першага года.'), findsWidgets);
      await tester.tap(find.byKey(const Key('readings-alternatives-control')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectionOptionCard>(
              find.byKey(const ValueKey('readings-cycle-1')),
            )
            .selected,
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('readings-calendar-disclosure')),
        -300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('readings-options-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('readings-calendar-disclosure')));
      await tester.pumpAndSettle();
      await choose('ordo-day-2026-10-10');
      expect(container.read(selectedDateProvider), DateTime(2026, 10, 10));
      expect(
        find.byKey(ValueKey('readings-celebration-${memorial.key}')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shell calendar shortcut opens the liturgical day', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.byKey(const Key('hours-calendar-action')));
    await tester.pumpAndSettle();
    expect(find.byType(OrdoScreen), findsOneWidget);
    expect(find.byType(LiturgicalCalendarSheet), findsNothing);
    await tester.tap(find.byKey(const Key('ordo-date-action')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('compact-liturgical-calendar')),
      findsOneWidget,
    );
    expect(find.byType(LiturgicalMonthCalendar), findsOneWidget);
    expect(find.byKey(const Key('liturgical-calendar-today')), findsOneWidget);
  });

  testWidgets('headers and variants allow 200 percent text', (tester) async {
    final (router, _) = await start(tester, scale: 2);
    tester.view.physicalSize = const Size(320, 844);
    await tester.pumpAndSettle();
    await snapshot(tester, 'hours-large-text');
    await tester.ensureVisible(
      find.byKey(const Key('hours-alternatives-control')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hours-alternatives-control')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Гатова'));
    await tester.pumpAndSettle();
    router.go('/readings');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Readings calendar survives date change and opens its Picker', (
    tester,
  ) async {
    final (router, container) = await start(tester);
    router.go('/readings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('readings-date-action')));
    await tester.pumpAndSettle();
    expect(find.byType(LiturgicalMonthCalendar), findsOneWidget);
    await tester.tap(find.byKey(const Key('ordo-day-2026-10-06')));
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), DateTime(2026, 10, 6));
    expect(find.byType(OrdoScreen), findsNothing);
    expect(find.byKey(const Key('readings-options-sheet')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('readings-calendar-picker')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('readings-options-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('readings-calendar-picker')));
    await tester.pumpAndSettle();
    expect(find.byType(LiturgicalPickerScreen), findsOneWidget);
    expect(
      tester
          .widget<LiturgicalPickerScreen>(find.byType(LiturgicalPickerScreen))
          .mode,
      'readings',
    );
  });
  testWidgets(
    '14 October Office header keeps weekday, celebration and applicable psalter',
    (tester) async {
      final (router, container) = await start(tester);
      final date = DateTime(2026, 10, 14);
      final navigation = container.read(liturgicalNavigationControllerProvider);
      navigation.openDate(date);
      await tester.pumpAndSettle();
      final option = container
          .read(hoursLiturgicalSelectionProvider)
          .sortedOptions
          .firstWhere((o) => o.title.contains('Калікста'));
      navigation.selectDay(date, option.dayId!, diocese: option.contextDiocese);
      await tester.pumpAndSettle();
      router.push(
        oraRouteForContext(
          date: date,
          dayId: option.dayId!,
          oraType: 'invitatorium',
          diocese: option.contextDiocese,
        ),
      );
      await tester.pumpAndSettle();
      final header = tester.widget<ReaderContextHeader>(
        find.byType(ReaderContextHeader),
      );
      expect(header.eyebrow, 'Серада, 14 кастрычніка 2026');
      expect(header.subtitle, contains('Калікста'));
      expect(header.title, 'Заклік');
      expect(header.metadata, 'Звычайны перыяд · IV тыдзень Псалтыра');
      await snapshot(tester, 'hour-14-october');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Readings variants keep calendar celebrations separate from sets and Office templates',
    (tester) async {
      final (router, container) = await start(tester);
      container
          .read(liturgicalNavigationControllerProvider)
          .openDate(DateTime(2026, 10, 9));
      router.go('/readings');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('readings-alternatives-control')));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('readings-options-sheet'));
      expect(sheet, findsOneWidget);
      expect(find.byType(HoursOptionsSheet), findsNothing);
      expect(find.text('Варыянт літургіі гадзінаў'), findsNothing);
      expect(
        find.descendant(of: sheet, matching: find.textContaining('Ев.')),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.textContaining('Пс ')),
        findsNothing,
      );
      await snapshot(tester, 'readings-variants-9-october');
      expect(tester.takeException(), isNull);
    },
  );

  test('festal own texts do not advertise the seasonal psalter', () {
    final container = containerFor(DateTime(2026, 12, 25));
    addTearDown(container.dispose);
    final day = container.read(hoursLiturgicalSelectionProvider).day!;
    expect(liturgicalDayPsalterLabel(day, DateTime(2026, 12, 25)), isEmpty);
  });
  for (final width in [320.0, 360.0, 390.0, 430.0, 800.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('real selectors at $width px and text $scale', (
        tester,
      ) async {
        final (router, container) = await start(
          tester,
          width: width,
          scale: scale,
          date: DateTime(2026, 10, 13),
        );
        Future<void> tap(Key key) async {
          final target = find.byKey(key);
          if (target.hitTestable().evaluate().isEmpty) {
            await Scrollable.ensureVisible(
              tester.element(target),
              alignment: .5,
            );
          }
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        await tap(const Key('hours-alternatives-control'));
        expect(
          tester
              .widget<LiturgicalCalendarDisclosure>(
                find.byType(LiturgicalCalendarDisclosure),
              )
              .expanded,
          isFalse,
        );
        await snapshot(tester, 'widget-hours-collapsed-$width-$scale');
        await tap(const Key('liturgical-calendar-toggle'));
        expect(find.byKey(const Key('ordo-day-2026-10-13')), findsOneWidget);
        final calendar = find.byType(LiturgicalMonthCalendar);
        expect(
          find.descendant(
            of: calendar,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is SingleChildScrollView &&
                  w.scrollDirection == Axis.horizontal,
            ),
          ),
          findsNothing,
        );
        await snapshot(tester, 'widget-hours-expanded-$width-$scale');
        final original = container.read(hoursLiturgicalSelectionProvider).dayId;
        await tap(const Key('ordo-jump-month'));
        expect(find.byKey(const Key('ordo-month-10')), findsOneWidget);
        expect(find.byKey(const Key('ordo-day-2026-10-13')), findsNothing);
        await snapshot(tester, 'widget-month-picker-$width-$scale');
        await tap(const Key('ordo-pick-year'));
        await snapshot(tester, 'widget-year-picker-$width-$scale');
        await tap(const Key('ordo-year-2026'));
        await tap(const Key('ordo-month-12'));
        expect(container.read(selectedDateProvider), DateTime(2026, 10, 13));
        expect(
          container.read(hoursLiturgicalSelectionProvider).dayId,
          original,
        );
        await tap(const Key('ordo-next-month'));
        expect(find.byKey(const Key('ordo-day-2027-01-01')), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        router.go('/readings');
        await tester.pumpAndSettle();
        await tap(const Key('readings-alternatives-control'));
        final first = find.byKey(const ValueKey('readings-cycle-1'));
        final second = find.byKey(const ValueKey('readings-cycle-2'));
        expect(first, findsOneWidget);
        expect(second, findsOneWidget);
        await tester.ensureVisible(first);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
        expect(
          tester.getSize(first).width,
          closeTo(tester.getSize(second).width, .01),
        );
        await snapshot(tester, 'widget-readings-two-cycles-$width-$scale');
        await tap(const ValueKey('readings-cycle-1'));
        expect(
          container.read(hoursLiturgicalSelectionProvider).dayId,
          original,
        );
        await tap(const Key('readings-cycle-automatic'));
        expect(tester.widget<SelectionOptionCard>(second).selected, isTrue);
        expect(
          find.byKey(const Key('readings-options-done')).hitTestable(),
          findsOneWidget,
        );
        expect(find.byType(LiturgicalSelectorSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('real Sunday cycles, All Souls Mass sets and Office sources', (
    tester,
  ) async {
    final (router, container) = await start(
      tester,
      date: DateTime(2026, 10, 11),
    );
    router.go('/readings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('readings-alternatives-control')));
    await tester.pumpAndSettle();
    for (final cycle in ['A', 'B', 'C']) {
      expect(find.byKey(ValueKey('readings-cycle-$cycle')), findsOneWidget);
    }
    await tester.ensureVisible(find.byKey(const ValueKey('readings-cycle-A')));
    await tester.pumpAndSettle();
    await snapshot(tester, 'widget-readings-three-cycles');
    router.pop();
    await tester.pumpAndSettle();
    container
        .read(liturgicalNavigationControllerProvider)
        .openDate(DateTime(2025, 11, 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('readings-alternatives-control')));
    await tester.pumpAndSettle();
    for (final set in ['first', 'second', 'third']) {
      expect(find.byKey(ValueKey('readings-mass-set-$set')), findsOneWidget);
    }
    await tester.ensureVisible(
      find.byKey(const ValueKey('readings-mass-set-third')),
    );
    await tester.pumpAndSettle();
    await snapshot(tester, 'widget-readings-multiple-mass-sets');
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 360.0, 390.0, 430.0, 800.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          'Ordo four dioceses and date-only calendar $brightness $width $scale',
          (tester) async {
            final (router, container) = await start(
              tester,
              width: width,
              scale: scale,
              brightness: brightness,
              date: DateTime(2026, 10, 9),
              overrides: [
                dioceseSelectionProvider.overrideWith(_FourDioceses.new),
              ],
            );
            final settings = container.read(dioceseSelectionProvider);
            router.go('/hours/ordo?date=2026-10-09');
            await tester.pumpAndSettle();
            expect(find.text('Пятніца'), findsNothing);
            final dioceses = find.byKey(const Key('ordo-dioceses'));
            final today = find.byKey(const Key('ordo-today'));
            expect(
              tester.getRect(dioceses).right,
              lessThanOrEqualTo(tester.getRect(today).left),
            );
            expect(
              find.textContaining('Мінск · Гродна · Пінск · Віцебск'),
              findsOneWidget,
            );
            await snapshot(
              tester,
              'widget-ordo-four-dioceses-${brightness.name}-$width-$scale',
            );
            final dateAction = find.byKey(const Key('ordo-date-action'));
            await tester.ensureVisible(dateAction);
            await tester.pumpAndSettle();
            await tester.tap(dateAction);
            await tester.pumpAndSettle();
            expect(find.byType(HoursOptionsSheet), findsNothing);
            expect(find.byType(LiturgicalCalendarDisclosure), findsNothing);
            expect(find.text('СВЯТКАВАННЕ'), findsNothing);
            await snapshot(
              tester,
              'widget-ordo-date-only-${brightness.name}-$width-$scale',
            );
            await tester.ensureVisible(
              find.byKey(const Key('ordo-day-2026-10-10')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('ordo-day-2026-10-10')));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('compact-liturgical-calendar')),
              findsOneWidget,
            );
            expect(
              container.read(selectedDateProvider),
              DateTime(2026, 10, 10),
            );
            expect(container.read(dioceseSelectionProvider), same(settings));
            await tester.tap(find.text('Гатова'));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<LiturgicalDateNavigationRow>(
                    find.byType(LiturgicalDateNavigationRow),
                  )
                  .date,
              DateTime(2026, 10, 10),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'required real dates expose their permitted celebration and Office data',
    (tester) async {
      final (router, container) = await start(tester);
      final navigation = container.read(liturgicalNavigationControllerProvider);
      for (final date in [
        DateTime(2026, 10, 6),
        DateTime(2026, 10, 7),
        DateTime(2026, 10, 9),
        DateTime(2026, 10, 13),
        DateTime(2026, 10, 14),
        DateTime(2026, 12, 27),
        DateTime(2025, 11, 2),
        DateTime(2031, 11, 2),
        DateTime(2028, 2, 29),
        kCalendarFirstDate,
        kCalendarLastDate,
      ]) {
        navigation.openDate(date);
        await tester.pumpAndSettle();
        final selection = container.read(hoursLiturgicalSelectionProvider);
        expect(selection.selected, isNotNull, reason: '$date');
        expect(selection.template, isNotNull, reason: '$date');
        expect(selection.day, isNotNull, reason: '$date');
        final alternatives = find.byKey(
          const Key('hours-alternatives-control'),
        );
        final entry = alternatives.evaluate().isNotEmpty
            ? alternatives
            : find.byKey(const Key('hours-date-action'));
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('hours-celebration-${selection.selected!.key}')),
          findsOneWidget,
        );
        if (selection.selected!.templates.length > 1) {
          expect(
            find.byKey(ValueKey('hours-variants-${selection.selected!.key}')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull, reason: '$date');
        await snapshot(
          tester,
          'widget-fixture-${date.toIso8601String().substring(0, 10)}',
        );
        router.pop();
        await tester.pumpAndSettle();
      }
    },
  );
}
