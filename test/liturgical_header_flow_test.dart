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
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_day_presentation_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart' as production;
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/screens/liturgical_picker_screen.dart';
import 'package:mybrev_flutter/widgets/ordo/liturgical_month_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_visual.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_sheet.dart';
import 'package:mybrev_flutter/widgets/liturgical_day_header.dart';
import 'package:mybrev_flutter/screens/ordo_screen.dart';

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

  ProviderContainer containerFor(DateTime date) => ProviderContainer(
    overrides: [
      selectedDateProvider.overrideWith((ref) => date),
      liturgicalContentReadyProvider.overrideWith((ref) async {}),
      contentUpdatesProvider.overrideWith(_Idle.new),
      settingsProvider.overrideWith(_Settings.new),
    ],
  );

  Future<(GoRouter, ProviderContainer)> start(
    WidgetTester tester, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = containerFor(DateTime(2026, 10, 7));
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
      final output = Directory('audit-evidence/liturgical-header');
      await output.create(recursive: true);
      await File(
        '${output.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pump();
  }

  test('real weekday and Marian memorial share canonical presentation', () {
    final container = containerFor(DateTime(2026, 10, 6));
    addTearDown(container.dispose);
    var p = container.read(liturgicalDayPresentationProvider);
    expect(p.title, 'XXVII звычайны тыдзень');
    expect(p.metadata, 'Аўторак · будні дзень');
    container.read(liturgicalNavigationControllerProvider).moveBy(1);
    p = container.read(liturgicalDayPresentationProvider);
    expect(p.title, contains('Ружанцовай'));
    expect(p.metadata, 'Серада · успамін');
    expect(p.accent, LiturgicalAccents.marian);
    expect(p.variantCount, greaterThan(1));
    container
        .read(liturgicalNavigationControllerProvider)
        .openDate(DateTime(2026, 10, 11));
    expect(
      container.read(liturgicalDayPresentationProvider).metadata,
      'Нядзеля',
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
      expect(find.text('Сёння'), findsNothing);
      await snapshot(tester, 'readings-marian');
      await tester.tap(find.byKey(const Key('readings-date-action')));
      await tester.pumpAndSettle();
      expect(find.byType(LiturgicalCalendarSheet), findsOneWidget);
      await snapshot(tester, 'calendar');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calendar date, Today and advanced picker use one entry', (
    tester,
  ) async {
    final (_, container) = await start(tester);
    await tester.tap(find.byKey(const Key('hours-previous-day')));
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), DateTime(2026, 10, 6));
    await snapshot(tester, 'hours-weekday');
    await tester.tap(find.byKey(const Key('hours-date-action')));
    await tester.pumpAndSettle();
    expect(find.byType(LiturgicalMonthCalendar), findsOneWidget);
    await tester.tap(find.byKey(const Key('ordo-day-2026-10-07')));
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), DateTime(2026, 10, 7));
    expect(find.byType(LiturgicalCalendarSheet), findsOneWidget);
    expect(find.textContaining('Ружанцовай'), findsWidgets);
    await tester.ensureVisible(
      find.byKey(const Key('liturgical-calendar-today')),
    );
    await tester.tap(find.byKey(const Key('liturgical-calendar-today')));
    await tester.pumpAndSettle();
    expect(
      DateUtils.isSameDay(container.read(selectedDateProvider), DateTime.now()),
      isTrue,
    );
    await tester.ensureVisible(
      find.byKey(const Key('liturgical-calendar-picker')),
    );
    await tester.tap(find.byKey(const Key('liturgical-calendar-picker')));
    await tester.pumpAndSettle();
    expect(find.byType(LiturgicalPickerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.byType(LiturgicalCalendarSheet), findsOneWidget);
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
    await tester.ensureVisible(
      find.byKey(const Key('liturgical-calendar-picker')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('liturgical-calendar-picker')));
    await tester.pumpAndSettle();
    expect(find.byType(LiturgicalPickerScreen), findsOneWidget);
    expect(
      tester
          .widget<LiturgicalPickerScreen>(find.byType(LiturgicalPickerScreen))
          .mode,
      'readings',
    );
  });
}
