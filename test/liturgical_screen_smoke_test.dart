import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/screens/ora_screen.dart';
import 'package:mybrev_flutter/screens/readings_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/widgets/app_overflow_menu.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/psalm_choir_html.dart';

double _fontSize = 16;
PsalmodyMode _mode = PsalmodyMode.leftBreak;

class _SmokeSettings extends SettingsNotifier {
  @override
  SettingsState build() =>
      SettingsState(fontSize: _fontSize, psalmodyMode: _mode);

  // This UI fixture does not open SettingsNotifier's private Hive box. Keep
  // slider changes in memory; persistence has its own real-I/O tests.
  @override
  void setFontSize(double size) {
    state = state.copyWith(fontSize: normalizeReaderFontSize(size));
  }

  @override
  Future<void> setPsalmodyMode(PsalmodyMode value) async {
    state = state.copyWith(psalmodyMode: value);
  }
}

void main() {
  late Directory directory;
  final date = DateTime(2028, 8, 1);
  setUpAll(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('liturgy-smoke-');
    await HiveService.init(path: directory.path);
    // Widget tests normally render text in Ahem (solid blocks). Load the
    // packaged real fonts only for screenshot review; production is untouched.
    if (Platform.environment['LITURGY_SMOKE_IMAGES'] == '1') {
      GoogleFonts.config.allowRuntimeFetching = false;
      for (final (family, asset) in [
        ('VisualPreview', 'assets/google_fonts/Literata-Regular.ttf'),
        (
          GoogleFonts.literata().fontFamily!,
          'assets/google_fonts/Literata-Regular.ttf',
        ),
        (
          GoogleFonts.cormorantGaramond(
            fontWeight: FontWeight.w700,
          ).fontFamily!,
          'assets/google_fonts/CormorantGaramond-Bold.ttf',
        ),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
        (
          'packages/phosphor_flutter/PhosphorRegular',
          'packages/phosphor_flutter/lib/fonts/Phosphor.ttf',
        ),
      ]) {
        await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      }
    }
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/office_assembly_parity.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final apostle = Map<String, dynamic>.from(
      (fixture['templates'] as Map<String, dynamic>)['apostles'] as Map,
    );
    final sunday = Map<String, dynamic>.from(
      (fixture['templates'] as Map<String, dynamic>)['sunday-week-1'] as Map,
    );
    apostle.remove('_schema');
    apostle.remove('_kind');
    const psalmSample =
        '<p style="text-align:center"><span style="color:red">'
        'Псальм 63 (62), 2–9</span></p>'
        '<p><em>Той з Богам, хто адкідае ўчынкі цемры</em></p>'
        '<p>Божа, Ты Бог мой *<br>Цябе шукаю.</p>';
    for (var i = 1; i <= 3; i++) {
      apostle['laudesPs$i'] = psalmSample;
      apostle['laudesAnt$i'] =
          '<p><span style="color:red">$i ант.</span> Хвала Пану.</p>';
      apostle['sext1Ant$i'] =
          '<p><span style="color:red">$i ант.</span> Хвала Пану.'
          '<br><span style="color:red"></span></p>';
      apostle['sext1Ps$i'] = psalmSample;
    }
    apostle['laudesHymn'] = '<p>Спяваем хвалу Пану.</p>';
    for (final field in [
      'officeOfReadingsHymn',
      'sext1Hymn',
      'sext2Hymn',
      'sext3Hymn',
      'vesperHymn',
    ]) {
      apostle[field] = apostle['laudesHymn'];
    }
    for (final field in [
      'officeOfReadingsPr',
      'laudesPr',
      'vesperPr',
      'sext1Pr',
      'sext2Pr',
      'sext3Pr',
    ]) {
      apostle[field] = '<p style="margin-bottom:40px">Молімся Пану.</p>';
    }
    apostle['laudesInter'] =
        '<p>Узнясём малітвы:</p><p><em>Выслухай нас.</em></p>'
        '<p>За Касцёл.</p><p>— Выслухай нас.</p>';
    apostle['vesperInter'] =
        '<p>Узнясём малітвы:<br><em>Выслухай нас.</em><br>'
        'За Касцёл.<br>— Выслухай нас.</p>';
    final ordinary = Map<String, dynamic>.from(fixture['currentDay'] as Map);
    ordinary['laudesHymn'] = '<p>Спяваем хвалу Пану.</p>';
    for (var i = 1; i <= 3; i++) {
      ordinary['laudesPs$i'] = psalmSample;
    }
    await HiveService.daysBox.put('ordinary-smoke', {
      ...ordinary,
      'id': 'ordinary-smoke',
      '_periodType': 'ordinary',
      '_periodWeekNumber': '17',
      '_dayOfWeek': '3',
    });
    await HiveService.daysBox.put('smoke', {
      ...apostle,
      'id': 'smoke',
      '_periodType': 'ordinary',
      '_periodWeekNumber': '17',
      '_dayOfWeek': '3',
      '_rank': 'festum',
    });
    await HiveService.daysBox.put('sunday-smoke', {
      ...ordinary,
      ...sunday,
      'id': 'sunday-smoke',
      '_periodType': 'ordinary',
      '_periodWeekNumber': '1',
      '_dayOfWeek': '7',
      '_rank': 'dominica',
    });
    final structured = Map<String, dynamic>.from(apostle);
    for (var i = 1; i <= 3; i++) {
      structured['laudesPs$i'] =
          '<p class="ora-ant"><span style="color:red">$i ант.</span> Хвала Пану.</p>'
          '<div class="ora-psalm">$psalmSample</div>'
          '<p class="ora-ant"><span style="color:red">$i ант.</span> Хвала Пану.</p>';
    }
    await HiveService.daysBox.put('structured-smoke', {
      ...structured,
      'id': 'structured-smoke',
      '_periodType': 'ordinary',
      '_periodWeekNumber': '17',
      '_dayOfWeek': '3',
    });
    final singleAnt = Map<String, dynamic>.from(apostle);
    singleAnt['laudesAnt2'] = '';
    singleAnt['laudesAnt3'] = '';
    await HiveService.daysBox.put('single-ant-smoke', {
      ...singleAnt,
      'id': 'single-ant-smoke',
      '_periodType': 'ordinary',
      '_periodWeekNumber': '17',
      '_dayOfWeek': '3',
    });
    final plainAnt = Map<String, dynamic>.from(apostle);
    for (var i = 1; i <= 3; i++) {
      plainAnt['laudesAnt$i'] = 'Ант. Хвала Пану $i.';
    }
    await HiveService.daysBox.put('plain-ant-smoke', {
      ...plainAnt,
      'id': 'plain-ant-smoke',
      '_periodType': 'ordinary',
      '_periodWeekNumber': '17',
      '_dayOfWeek': '3',
    });
    // 08.11.2026, XXXII Sunday: the shipped Benedictus antiphon had
    // malformed <span"> openings. Keep the exact broken shape in this fixture.
    await HiveService.daysBox.put('sunday-32-broken-antiphon', {
      ...apostle,
      'id': 'sunday-32-broken-antiphon',
      '_periodType': 'ordinary',
      '_periodWeekNumber': '32',
      '_dayOfWeek': '7',
      '_rank': 'dominica',
      'laudesAntBen':
          '<p><span style="color: red;">Ант. да песні Захарыі</span></p>'
          '<p><span style="color: red;">Год А:</span>'
          '<span"> Сярод ночы ўзняўся крык: </span>'
          '<span style="color: red;">*</span>'
          '<span"> Вось жаніх! Выходзьце яму насустрач.</span></p>'
          '<p><span style="color: red;">Год В:</span>'
          '<span"> Сапраўды кажу вам.</span></p>'
          '<p><span style="color: red;">Год С:</span>'
          '<span"> Майсей засведчыў.</span></p>',
    });
    await HiveService.invitatoriumsBox.put('one', {
      'title': 'Заклік',
      'invitatoriumPs1': '<p>Прыйдзіце, уславім Пана *</p>',
    });
    for (var day = 1; day <= 7; day++) {
      await HiveService.completoriumsBox.put('ordinary-d$day', {
        'compHymn': '<p>Спяваем хвалу Пану.</p>',
        'compAnt1': '<p>Ант. Пан мой.</p>',
        'compPs1': '<p><em>Псальм 4</em></p><p>Пачуй мяне, Божа *</p>',
        'compR': '<p>Кароткае чытанне 1 П 5, 8</p><p>Будзьце цвярозымі.</p>',
        'compResp':
            '<p>Кароткі рэспансорый<br>К. У рукі Твае * '
            'Н. Аддаю дух мой.</p>',
        'compAntS': '<p>Ант. Збаў нас, Пане.</p>',
        'compPr': '<p>Молімся Пану.</p>',
        'compAntM': '<p>Вітай, Каралева.</p>',
      });
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('08.11.2026 Benedictus Year A antiphon is sung twice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _fontSize = 16;
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_SmokeSettings.new)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: const Key('smoke-capture'),
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'VisualPreview'),
            home: OraScreen(
              dayId: 'sunday-32-broken-antiphon',
              oraType: 'laudes',
              date: DateTime(2026, 11, 8),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sungText = find.byWidgetPredicate(
      (widget) =>
          widget is Html &&
          (widget.data ?? '').contains('Сярод ночы ўзняўся крык') &&
          (widget.data ?? '').contains('Выходзьце яму насустрач'),
    );
    expect(sungText, findsNWidgets(2));
    await _captureVisibleAntiphon(
      tester,
      '2026-11-08-benedictus-year-a-opening',
      sungText.first,
    );
    await _captureVisibleAntiphon(
      tester,
      '2026-11-08-benedictus-year-a-repeat',
      sungText.last,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final hour in ['laudes', 'vespers', 'lectionis', 'completorium']) {
    for (final mode in PsalmodyMode.values) {
      testWidgets(
        '$hour renders ${mode.name} and keeps it when changing modes',
        (tester) async {
          _fontSize = 16;
          _mode = mode;
          final container = ProviderContainer(
            overrides: [settingsProvider.overrideWith(_SmokeSettings.new)],
          );
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: OraScreen(dayId: 'smoke', oraType: hour, date: date),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(PsalmChoirHtml), findsWidgets);
          void verify(PsalmodyMode expected) {
            for (final element in find.byType(PsalmChoirHtml).evaluate()) {
              expect(PsalmodyScope.maybeOf(element)!.mode, expected);
              final html = tester.widget<Html>(
                find.descendant(
                  of: find.byWidget(element.widget),
                  matching: find.byType(Html),
                ),
              );
              final strophes = parseFragment(
                html.data!,
              ).querySelectorAll('.psalm-strophe');
              expect(strophes, isNotEmpty);
              for (final strophe in strophes) {
                if (expected == PsalmodyMode.alternatingStanzas) {
                  expect(strophe.querySelector('br, .psalm-line'), isNull);
                } else {
                  expect(strophe.querySelector('.psalm-line'), isNotNull);
                }
              }
            }
          }

          verify(mode);
          final before = tester.state(find.byType(OraScreen));
          for (final next in PsalmodyMode.values) {
            await container
                .read(settingsProvider.notifier)
                .setPsalmodyMode(next);
            await tester.pumpAndSettle();
            verify(next);
            expect(tester.state(find.byType(OraScreen)), same(before));
            expect(
              tester.widget<OraScreen>(find.byType(OraScreen)).oraType,
              hour,
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          container.dispose();
          _mode = PsalmodyMode.leftBreak;
        },
      );
    }
  }

  testWidgets(
    'Office navigation preserves date and option and resets choir selection',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      _fontSize = 24;
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith(_SmokeSettings.new)],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation:
            '/hours/ora/2028-08-01/smoke/laudes?option=chosen-variant',
        routes: [
          GoRoute(
            path: '/hours/ora/:date/:dayId/:type',
            builder: (context, state) => OraScreen(
              key: ValueKey(state.uri),
              date: DateTime.parse(state.pathParameters['date']!),
              dayId: state.pathParameters['dayId']!,
              oraType: state.pathParameters['type']!,
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
      final psalms = find.byType(PsalmChoirHtml);
      expect(psalms, findsNWidgets(4)); // Three psalms and Benedictus.
      Html firstPsalm() => tester.widget<Html>(
        find.descendant(of: psalms.first, matching: find.byType(Html)),
      );
      firstPsalm().onLinkTap!('psalm-choir:1', {}, null);
      await tester.pump();
      for (final psalm in psalms.evaluate()) {
        final html = tester.widget<Html>(
          find.descendant(
            of: find.byWidget(psalm.widget),
            matching: find.byType(Html),
          ),
        );
        expect(html.data, contains('psalm-choir-muted'));
      }
      final settings = container.read(settingsProvider.notifier);
      await settings.setPsalmodyMode(PsalmodyMode.leftBreakIndent);
      await tester.pumpAndSettle();
      expect(firstPsalm().data, contains('psalm-continuation'));
      expect(firstPsalm().data, contains('psalm-choir-muted'));
      final reader = tester.widget<ReaderScaffold>(find.byType(ReaderScaffold));
      final scroll = reader.scrollController!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final next = find.byKey(const Key('ora-next-hour'));
      final up = find.byKey(const Key('reader-scroll-to-top'));
      expect(tester.getRect(next).overlaps(tester.getRect(up)), isFalse);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/hours/ora/2028-08-01/smoke/terz',
      );
      expect(
        router.routeInformationProvider.value.uri.queryParameters['option'],
        'chosen-variant',
      );
      expect(
        tester
            .widget<ReaderScaffold>(find.byType(ReaderScaffold))
            .scrollController!
            .offset,
        0,
      );
      for (final psalm in find.byType(PsalmChoirHtml).evaluate()) {
        final html = tester.widget<Html>(
          find.descendant(
            of: find.byWidget(psalm.widget),
            matching: find.byType(Html),
          ),
        );
        expect(html.data, isNot(contains('psalm-choir-muted')));
      }
      final currentReader = tester.widget<ReaderScaffold>(
        find.byType(ReaderScaffold),
      );
      currentReader.scrollController!.jumpTo(
        currentReader.scrollController!.position.maxScrollExtent,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hour-switcher-pill')));
      await tester.pumpAndSettle();
      expect(find.text('Літургія гадзінаў'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Камплета'),
        180,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(find.text('Камплета'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Камплета'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/hours/ora/2028-08-01/smoke/completorium',
      );
      expect(
        router.routeInformationProvider.value.uri.queryParameters['option'],
        'chosen-variant',
      );
      expect(find.byKey(const Key('ora-next-hour')), findsNothing);
      final canticle = tester.widget<Html>(
        find.descendant(
          of: find.byType(PsalmChoirHtml).last,
          matching: find.byType(Html),
        ),
      );
      expect(
        parseFragment(canticle.data!).querySelectorAll('.psalm-continuation'),
        isNotEmpty,
      );
      canticle.onLinkTap!('psalm-choir:1', {}, null);
      await tester.pump();
      router.go(
        '/hours/ora/2028-08-02/ordinary-smoke/laudes?option=other-variant',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ReaderScaffold>(find.byType(ReaderScaffold))
            .scrollController!
            .offset,
        0,
      );
      for (final psalm in find.byType(PsalmChoirHtml).evaluate()) {
        final html = tester.widget<Html>(
          find.descendant(
            of: find.byWidget(psalm.widget),
            matching: find.byType(Html),
          ),
        );
        expect(html.data, isNot(contains('psalm-choir-muted')));
      }

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Ora day color reaches context without recoloring Reader or Aa', (
    tester,
  ) async {
    final contexts = <Color>[];
    final schemes = <ColorScheme>[];
    for (final dayId in ['ordinary-smoke', 'smoke']) {
      final day = LiturgicalDay.fromMap(
        Map<String, dynamic>.from(HiveService.daysBox.get(dayId) as Map),
      );
      contexts.add(liturgicalColorForDay(day));
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(dayId),
          overrides: [settingsProvider.overrideWith(_SmokeSettings.new)],
          child: MaterialApp(
            key: ValueKey('app-$dayId'),
            theme: ThemeData(colorScheme: AppPalette.scheme(Brightness.light)),
            home: OraScreen(dayId: dayId, oraType: 'laudes', date: date),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reader = tester.widget<ReaderScaffold>(find.byType(ReaderScaffold));
      expect(reader.seasonColor, contexts.last);
      expect(find.byKey(const Key('app-overflow-open')), findsOneWidget);
      schemes.add(
        Theme.of(tester.element(find.byType(AppOverflowMenu))).colorScheme,
      );
      expect(tester.takeException(), isNull);
    }
    expect(contexts[0], isNot(contexts[1]));
    expect(schemes[0].primary, schemes[1].primary);
    expect(schemes[0].primaryContainer, schemes[1].primaryContainer);
  });

  final cases = <(String, String, Brightness, double, Size)>[
    ('ordinary-smoke', 'laudes', Brightness.light, 16, const Size(900, 1600)),
    ('sunday-smoke', 'laudes', Brightness.light, 16, const Size(390, 844)),
    ('smoke', 'laudes', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'laudes', Brightness.dark, 24, const Size(900, 1600)),
    ('smoke', 'vespers', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'lectionis', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'morning', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'terz', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'sext', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'non', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'completorium', Brightness.light, 16, const Size(900, 1600)),
    ('smoke', 'completorium', Brightness.dark, 24, const Size(900, 1600)),
    // Phone widths exercise wrapping in both the chrome and long document.
    ('smoke', 'laudes', Brightness.light, 16, const Size(360, 800)),
    ('smoke', 'lectionis', Brightness.light, 16, const Size(360, 800)),
    ('smoke', 'terz', Brightness.light, 16, const Size(360, 800)),
    ('smoke', 'completorium', Brightness.light, 16, const Size(360, 800)),
    ('smoke', 'laudes', Brightness.light, 16, const Size(390, 844)),
    ('smoke', 'lectionis', Brightness.light, 16, const Size(390, 844)),
    ('smoke', 'sext', Brightness.light, 16, const Size(390, 844)),
    ('smoke', 'completorium', Brightness.dark, 24, const Size(390, 844)),
    ('smoke', 'morning', Brightness.light, 16, const Size(360, 800)),
    ('smoke', 'morning', Brightness.dark, 24, const Size(390, 844)),
    ('smoke', 'non', Brightness.light, 16, const Size(390, 844)),
    ('structured-smoke', 'laudes', Brightness.light, 16, const Size(390, 844)),
    ('single-ant-smoke', 'laudes', Brightness.light, 16, const Size(390, 844)),
    ('plain-ant-smoke', 'laudes', Brightness.light, 16, const Size(390, 844)),
  ];
  for (final (dayId, hour, brightness, size, viewport) in cases) {
    testWidgets('$dayId $hour ${brightness.name} $size '
        '${viewport.width}x${viewport.height} builds document', (tester) async {
      _fontSize = size;
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('smoke-capture'),
          child: ProviderScope(
            overrides: [settingsProvider.overrideWith(_SmokeSettings.new)],
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: ReaderChromeModeScope(
                controller: ReaderChromeModeController(ReaderChromeMode.full),
                child: OraScreen(dayId: dayId, oraType: hour, date: date),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader-content-surface')), findsOneWidget);
      expect(find.byKey(const Key('ora-source-footer')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final headings = tester
          .widgetList<LiturgicalSectionHeading>(
            find.byType(LiturgicalSectionHeading),
          )
          .toList();
      if (dayId == 'smoke') {
        const expectedBoundaries = {
          'laudes': 4,
          'vespers': 4,
          'terz': 2,
          'sext': 2,
          'non': 2,
          'lectionis': 3,
          'completorium': 5,
          'morning': 7,
        };
        expect(
          find.byType(LiturgicalSectionDivider),
          findsNWidgets(expectedBoundaries[hour]!),
        );
        expect(
          find.byType(LiturgicalHeadingReferenceRow),
          hour == 'lectionis' ? findsNothing : findsOneWidget,
        );
        expect(find.byType(LiturgicalResponsoryBlock), findsWidgets);
      }
      if (const {
        'structured-smoke',
        'single-ant-smoke',
        'plain-ant-smoke',
      }.contains(dayId)) {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.height == LiturgicalSpacing.psalmBlockToNext,
          ),
          findsAtLeastNWidgets(2),
        );
      }
      if (dayId == 'structured-smoke') {
        expect(find.byType(PsalmChoirHtml), findsAtLeastNWidgets(3));
      }
      if (hour == 'lectionis' || hour == 'morning') {
        // The divider owns the first transition; the second reading owns its
        // gap because no divider separates the two readings.
        expect(
          headings
              .singleWhere((heading) => heading.title == 'Першае чытанне')
              .startsSection,
          isFalse,
        );
        expect(
          headings
              .singleWhere((heading) => heading.title == 'Другое чытанне')
              .startsSection,
          isTrue,
        );
      }
      if (const {'laudes', 'vespers', 'morning'}.contains(hour)) {
        expect(
          headings
              .singleWhere((heading) => heading.title == 'Просьбы')
              .startsSection,
          isFalse,
        );
      }
      if (const {
        'laudes',
        'vespers',
        'morning',
        'completorium',
      }.contains(hour)) {
        expect(
          headings
              .singleWhere((heading) => heading.title == 'Малітва')
              .startsSection,
          isFalse,
        );
      }
      if (hour == 'lectionis' || hour == 'morning') {
        // A feast includes Te Deum. It shares HYMN_BODY in both compositions.
        final teDeum = tester
            .widgetList<Html>(find.byType(Html))
            .singleWhere(
              (html) => html.data?.contains('Цябе, Бога, праслаўляем') ?? false,
            );
        expect(teDeum.style['body']?.lineHeight?.size, ReaderTheme.hymnHeight);
        expect(
          teDeum.style['p']?.margin?.bottom?.value,
          LiturgicalSpacing.hymnStropheAfter,
        );
      }
      await _captureIfRequested(
        tester,
        '$dayId-$hour-${brightness.name}-$size-${viewport.width}x${viewport.height}',
      );
      final captureName =
          '$dayId-$hour-${brightness.name}-$size-${viewport.width}x${viewport.height}';
      final psalms = find.byType(PsalmChoirHtml);
      if (psalms.evaluate().length > 1) {
        await _captureSectionIfRequested(
          tester,
          '$captureName-psalm-blocks',
          psalms.at(1),
        );
      }
      await _captureSectionIfRequested(
        tester,
        '$captureName-short-reading',
        find.byType(LiturgicalHeadingReferenceRow),
      );
      await _captureSectionIfRequested(
        tester,
        '$captureName-second-reading',
        find.text('ДРУГОЕ ЧЫТАННЕ'),
      );
      await _captureSectionIfRequested(
        tester,
        '$captureName-intercessions',
        find.text('Просьбы'),
      );
      await _captureSectionIfRequested(
        tester,
        '$captureName-prayer',
        find.text('МАЛІТВА'),
      );
      if (hour == 'morning' && psalms.evaluate().length > 4) {
        await _captureSectionIfRequested(
          tester,
          '$captureName-laudes-transition',
          find.text('Псалмодыя').last,
        );
        await _captureSectionIfRequested(
          tester,
          '$captureName-laudes-psalmody',
          psalms.at(4),
        );
      }
      if (const {
        'laudes',
        'vespers',
        'morning',
        'completorium',
      }.contains(hour)) {
        final canticle = find.text('Песня з Евангелля');
        if (canticle.evaluate().isNotEmpty) {
          await tester.ensureVisible(canticle.first);
          await tester.pumpAndSettle();
          await _captureIfRequested(
            tester,
            '$dayId-$hour-${brightness.name}-$size-${viewport.width}x${viewport.height}-canticle',
          );
        }
      }
      if (hour == 'completorium') {
        final marian = find.text(
          'Антыфоны на заканчэнне да Найсвяцейшай Панны Марыі',
        );
        if (marian.evaluate().isNotEmpty) {
          await tester.ensureVisible(marian.first);
          await tester.pumpAndSettle();
          await _captureIfRequested(
            tester,
            '$dayId-$hour-${brightness.name}-$size-${viewport.width}x${viewport.height}-marian',
          );
        }
      }
    });
  }

  testWidgets('Laudes, Sext and structured psalms have equal geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _fontSize = 16;

    Future<List<double>> gaps(String dayId, String hour) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey('$dayId-$hour'),
          overrides: [settingsProvider.overrideWith(_SmokeSettings.new)],
          child: ReaderTypographyScope(
            useSystemFonts: true,
            child: MaterialApp(
              home: OraScreen(dayId: dayId, oraType: hour, date: date),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final opening = find.byKey(const Key('liturgical-psalm-opening'));
      final metadata0 = find.byKey(const Key('liturgical-psalm-metadata-0'));
      final metadata1 = find.byKey(const Key('liturgical-psalm-metadata-1'));
      final body = find.byKey(const Key('liturgical-psalm-body'));
      final repeat = find.byKey(const Key('liturgical-psalm-repeat'));
      expect(opening, findsAtLeastNWidgets(2));
      expect(metadata0, findsAtLeastNWidgets(2));
      expect(metadata1, findsAtLeastNWidgets(2));
      expect(repeat, findsAtLeastNWidgets(2));
      return [
        tester.getRect(metadata0.first).top -
            tester.getRect(opening.first).bottom,
        tester.getRect(body.first).top - tester.getRect(metadata1.first).bottom,
        tester.getRect(opening.at(1)).top - tester.getRect(repeat.first).bottom,
      ];
    }

    final laudes = await gaps('smoke', 'laudes');
    final sext = await gaps('smoke', 'terz');
    final structured = await gaps('structured-smoke', 'laudes');
    for (var i = 0; i < laudes.length; i++) {
      expect(sext[i], closeTo(laudes[i], .5));
      expect(structured[i], closeTo(laudes[i], .5));
    }
  });

  testWidgets('hymn, prayer and intercession roles keep one geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _fontSize = 16;

    Future<Map<String, List<double>>> measure(String hour) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey('roles-$hour'),
          overrides: [settingsProvider.overrideWith(_SmokeSettings.new)],
          child: ReaderTypographyScope(
            useSystemFonts: true,
            child: MaterialApp(
              home: OraScreen(dayId: 'smoke', oraType: hour, date: date),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final result = <String, List<double>>{};
      for (final role in ['hymn', 'prayer', 'intercession']) {
        final title = role == 'hymn'
            ? find.byWidgetPredicate(
                (widget) =>
                    widget is LiturgicalSectionHeading &&
                    widget.title == 'Гімн',
              )
            : find.byKey(Key('liturgical-$role-title'));
        final body = role == 'hymn'
            ? find.byWidgetPredicate(
                (widget) =>
                    widget is Html &&
                    (widget.data ?? '').contains('Спяваем хвалу Пану.'),
              )
            : find.byKey(Key('liturgical-$role-body'));
        if (title.evaluate().isEmpty || body.evaluate().isEmpty) continue;
        final titleText = find
            .descendant(of: title.first, matching: find.byType(Text))
            .first;
        result[role] = [
          tester.getRect(body.first).top - tester.getRect(titleText).bottom,
        ];
      }
      return result;
    }

    final laudes = await measure('laudes');
    for (final hour in [
      'lectionis',
      'terz',
      'sext',
      'non',
      'vespers',
      'completorium',
      'morning',
    ]) {
      final actual = await measure(hour);
      for (final role in ['hymn', 'prayer', 'intercession']) {
        if (!actual.containsKey(role)) continue;
        expect(
          actual[role]!.single,
          closeTo(laudes[role]!.single, .5),
          reason: '$role in $hour',
        );
      }
    }
  });

  for (final width in [360.0, 390.0]) {
    testWidgets('Gospel canticle metadata stays centered at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      _fontSize = 16;
      for (final hour in ['laudes', 'vespers', 'completorium', 'morning']) {
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('canticle-$hour-$width'),
            overrides: [settingsProvider.overrideWith(_SmokeSettings.new)],
            child: ReaderTypographyScope(
              useSystemFonts: true,
              child: MaterialApp(
                home: OraScreen(dayId: 'smoke', oraType: hour, date: date),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final service = find.byWidgetPredicate(
          (widget) =>
              widget is Html &&
              (widget.data ?? '').contains('Песня з Евангелля'),
        );
        final caption = find.byWidgetPredicate(
          (widget) =>
              widget is Html && (widget.data ?? '').contains('Песня Захарыі') ||
              widget is Html && (widget.data ?? '').contains('Песня Марыі') ||
              widget is Html && (widget.data ?? '').contains('Песня Сімяона'),
        );
        expect(service, findsOneWidget, reason: hour);
        expect(caption, findsOneWidget, reason: hour);
        for (final target in [service, caption]) {
          final html = tester.widget<Html>(target);
          expect(html.style['p']?.textAlign, TextAlign.center);
          expect(tester.getSize(target).width, closeTo(width - 44, .5));
        }
        final bodies = tester.widgetList<PsalmChoirHtml>(
          find.byType(PsalmChoirHtml),
        );
        expect(bodies.last.style['body']?.textAlign, TextAlign.left);
      }
    });
  }

  testWidgets('single antiphon has one opening and one repeat', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_SmokeSettings.new)],
        child: ReaderTypographyScope(
          useSystemFonts: true,
          child: MaterialApp(
            home: OraScreen(
              dayId: 'single-ant-smoke',
              oraType: 'laudes',
              date: date,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The second pair belongs to Benedictus; Psalmody contributes one pair.
    expect(find.byKey(const Key('liturgical-psalm-opening')), findsNWidgets(2));
    expect(find.byKey(const Key('liturgical-psalm-repeat')), findsNWidgets(2));
    expect(
      find.byKey(const Key('liturgical-psalm-body')),
      findsAtLeastNWidgets(3),
    );
  });

  for (final (brightness, size, viewport) in [
    (Brightness.light, 16.0, const Size(900, 1600)),
    (Brightness.dark, 24.0, const Size(900, 1600)),
    (Brightness.light, 16.0, const Size(360, 800)),
    (Brightness.dark, 24.0, const Size(390, 844)),
  ]) {
    testWidgets('readings ${brightness.name} $size '
        '${viewport.width}x${viewport.height} builds document', (tester) async {
      _fontSize = size;
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reading = ParsedReading(
        id: 'smoke-reading',
        title: 'Свята',
        reading1: const ParsedSection(
          bible: 'Флп 4, 10–23',
          comment: 'Даведаліся пра дадзеную мне ласку',
          title: 'Чытанне Паслання святога апостала Паўла.',
          text: 'Браты, я вельмі ўзрадаваўся ў Пану.',
        ),
        psalm: const ParsedSection(
          title: 'Рэспансарыйны псальм',
          chorus: 'Пан пачуў мяне.',
          verses: ['2. Я цвёрда спадзяваўся * і Ён пачуў мяне.'],
        ),
        alleluia: const ParsedSection(
          bible: 'Рым 8, 15',
          verse: 'Пане, навучы нас маліцца.',
        ),
        gospel: const ParsedSection(
          bible: 'Лк 1, 68–79',
          title: '+ Чытанне святога Евангелля паводле Лукі.',
          text: 'Благаслаўлёны Пан, Бог Ізраэля.',
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('smoke-capture'),
          child: ProviderScope(
            overrides: [
              settingsProvider.overrideWith(_SmokeSettings.new),
              liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
              readingsLoaderProvider.overrideWithValue(
                ({
                  required dateStr,
                  required liturgicalKey,
                  required dayId,
                }) async => ReadingsLoadResult(
                  readings: [reading],
                  sundayCycle: 'B',
                  weekdayCycle: '2',
                ),
              ),
              readingsLocalLoaderProvider.overrideWithValue(
                ({required dateStr, required liturgicalKey, required dayId}) =>
                    ReadingsLoadResult(
                      readings: [reading],
                      sundayCycle: 'B',
                      weekdayCycle: '2',
                    ),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(brightness: brightness),
              home: const ReadingsScreen(dateStr: '2028-08-01'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('readings-document-end')), findsOneWidget);
      expect(find.textContaining('Крыніца: Catholic.by'), findsNothing);
      expect(find.byKey(const Key('reader-content-surface')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final responseColor = ReaderTheme.of(
        tester.element(find.byKey(const Key('reader-content-surface'))),
      ).rubricSoft;
      final responses = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == responseColor,
      );
      expect(responses, findsNWidgets(4));
      for (final response in tester.widgetList<Container>(responses)) {
        final decoration = response.decoration! as BoxDecoration;
        expect(decoration.boxShadow, isNull);
        expect(decoration.border, isNull);
        expect(decoration.borderRadius, BorderRadius.circular(6));
      }
      await _captureIfRequested(
        tester,
        'readings-${brightness.name}-$size-${viewport.width}x${viewport.height}',
      );
      await _captureSectionIfRequested(
        tester,
        'readings-refrain-${brightness.name}-$size-${viewport.width}',
        find.byKey(const Key('psalm-refrain-opening')),
      );
      await _captureSectionIfRequested(
        tester,
        'readings-acclamation-${brightness.name}-$size-${viewport.width}',
        find.text('Пане, навучы нас маліцца.', findRichText: true),
      );

      if (Platform.environment['READER_UI_ACCEPTANCE_IMAGES'] == '1' &&
          brightness == Brightness.light &&
          viewport.width == 360) {
        final scroll = tester
            .widget<ReaderScaffold>(find.byType(ReaderScaffold))
            .scrollController!;
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        await _captureIfRequested(tester, 'reader-acceptance-03-readings-end');
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
      }

      // Exercise the actual Aa slider and settings rebuild at every supported
      // step, including the minimum where absolute metadata floors regress.
      await tester.tap(find.byKey(const Key('app-overflow-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Шрыфт'));
      await tester.pumpAndSettle();
      for (var step = 7; step <= 18; step++) {
        final requestedSize = kDefaultReaderFontSize * step / 10;
        tester
            .widget<Slider>(find.byKey(const Key('text-scale-slider')))
            .onChanged!(requestedSize);
        await tester.pumpAndSettle();
        final reader = ReaderTheme.of(
          tester.element(find.byKey(const Key('reader-content-surface'))),
        );
        for (final reference in ['Флп 4, 10–23', 'Рым 8, 15', 'Лк 1, 68–79']) {
          final style = tester.widget<Text>(find.text(reference)).style!;
          expect(
            style.fontSize,
            closeTo(reader.metadata(requestedSize).fontSize!, .001),
          );
          expect(style.fontSize, lessThan(requestedSize));
        }
        final comment = tester
            .widget<Text>(find.text('Даведаліся пра дадзеную мне ласку'))
            .style!;
        expect(
          comment.fontSize,
          closeTo(reader.psalmSubtitle(requestedSize).fontSize!, .001),
        );
        expect(comment.fontStyle, FontStyle.italic);
        for (final formula in [
          'Чытанне Паслання святога апостала Паўла.',
          '+ Чытанне святога Евангелля паводле Лукі.',
        ]) {
          final introduction = tester.widget<Text>(find.text(formula)).style!;
          expect(
            introduction.fontSize,
            closeTo(requestedSize * 1.04, .001),
          );
          expect(introduction.fontWeight, FontWeight.w700);
        }
        final bodyFinder = find.text(
          'Браты, я вельмі ўзрадаваўся ў Пану.',
          findRichText: true,
        );
        final body = tester.widget<RichText>(bodyFinder);
        final sizes = _renderedFontSizes(
          body.text,
          DefaultTextStyle.of(tester.element(bodyFinder)).style,
        );
        expect(sizes, isNotEmpty);
        expect(sizes, everyElement(closeTo(requestedSize, .001)));
        expect(tester.takeException(), isNull);
      }
    });
  }
}

// HTML and sentence highlighting both inherit styles through nested spans.
List<double?> _renderedFontSizes(InlineSpan span, TextStyle inherited) {
  if (span is! TextSpan) return const [];
  final style = inherited.merge(span.style);
  return [
    if ((span.text ?? '').trim().isNotEmpty) style.fontSize,
    for (final child in span.children ?? <InlineSpan>[])
      ..._renderedFontSizes(child, style),
  ];
}

Future<void> _captureVisibleAntiphon(
  WidgetTester tester,
  String name,
  Finder target,
) async {
  if (Platform.environment['LITURGY_SMOKE_IMAGES'] != '1') return;
  await Scrollable.ensureVisible(
    tester.element(target.first),
    alignment: 0.25,
    duration: Duration.zero,
  );
  await tester.pumpAndSettle();
  final rect = tester.getRect(target.first);
  final screenHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  expect(rect.top, greaterThanOrEqualTo(0), reason: '$name should be onscreen');
  expect(
    rect.bottom,
    lessThanOrEqualTo(screenHeight),
    reason: '$name should be onscreen',
  );
  await _captureIfRequested(tester, name);
}

Future<void> _captureIfRequested(WidgetTester tester, String name) async {
  if (Platform.environment['LITURGY_SMOKE_IMAGES'] != '1') return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('smoke-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/liturgy_smoke')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _captureSectionIfRequested(
  WidgetTester tester,
  String name,
  Finder target,
) async {
  if (Platform.environment['LITURGY_SMOKE_IMAGES'] != '1' ||
      target.evaluate().isEmpty) {
    return;
  }
  await Scrollable.ensureVisible(
    tester.element(target.first),
    alignment: 0.22,
    duration: Duration.zero,
  );
  await tester.pumpAndSettle();
  await _captureIfRequested(tester, name);
}
