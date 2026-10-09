import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import 'package:mybrev_flutter/models/mass_ritual.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/screens/bible_chapter_screen.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/screens/readings_screen.dart';
import 'package:mybrev_flutter/theme/app_theme.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/system_insets.dart';
import 'package:mybrev_flutter/widgets/app_navigation_dock.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

enum _NavigationMode { threeButton, gesture }

extension on _NavigationMode {
  double get systemInset => this == _NavigationMode.threeButton ? 48 : 24;
  String get label =>
      this == _NavigationMode.threeButton ? '3-button' : 'gesture';
}

class _Viewport {
  const _Viewport(this.width, this.height);

  final double width;
  final double height;

  String get label => '${width.toInt()}x${height.toInt()}';
}

const _viewports = [_Viewport(390, 840), _Viewport(320, 720)];
const _modes = [_NavigationMode.threeButton, _NavigationMode.gesture];

const _prayers = [
  Prayer(
    id: 'morning',
    title: 'Ранішняя малітва',
    body: '<p>Добры Божа</p>',
    tags: ['ранішнія'],
  ),
  Prayer(
    id: 'evening',
    title: 'Вячэрняя малітва',
    body: '<p>Дзякуй Табе</p>',
    tags: ['вечар'],
  ),
  Prayer(
    id: 'night',
    title: 'Малітва перад сном',
    body: '<p>Будзь са мною</p>',
    tags: ['вечар'],
  ),
];

const _categories = [
  PrayerMenuCategory(
    id: 'morning-category',
    name: 'Ранішнія',
    tags: ['ранішнія'],
    isGlobal: true,
  ),
  PrayerMenuCategory(
    id: 'evening-category',
    name: 'Вячэрнія',
    tags: ['вечар'],
    isGlobal: true,
  ),
];

const _reading = ParsedReading(
  id: 'layout-lab-reading',
  title: 'XXVI звычайная нядзеля, Год B',
  year: 'B',
  dayId: 'sunday',
  reading1: ParsedSection(
    bible: 'Ліч 11, 25–29',
    text:
        'Пан сышоў у воблаку і гаварыў з Майсеем. Першы сказ для вылучэння. '
        'Няхай увесь народ Пана будзе прарокамі. Другі сказ працягвае чытанне. '
        'Дух Пана спачывае на тых, каго Ён паклікаў.',
  ),
  psalm: ParsedSection(
    chorus: 'Наказы Пана радуюць сэрца.',
    verses: [
      'Закон Пана дасканалы, ажыўляе душу.',
      'Сведчанне Пана вернае, вучыць простых мудрасці.',
      'Слуга Твой захоўвае іх уважліва.',
    ],
  ),
  gospel: ParsedSection(
    bible: 'Мк 9, 38–43',
    text:
        'Хто не супраць нас, той за нас. Хто напоіць вас кубкам вады, '
        'не страціць узнагароды сваёй.',
  ),
);

ReadingsLoader get _readingsLoader =>
    ({required dateStr, required liturgicalKey, required dayId}) async =>
        const ReadingsLoadResult(
          readings: [_reading],
          sundayCycle: 'B',
          weekdayCycle: '2',
        );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bottom geometry', () {
    test('system and gesture insets use max, not sum', () {
      expect(systemBottomObstruction(visualInset: 48, gestureInset: 0), 48);
      expect(systemBottomObstruction(visualInset: 24, gestureInset: 24), 24);
      expect(systemBottomObstruction(visualInset: 24, gestureInset: 32), 32);
    });

    test('overlay reserve subtracts existing reader or dock space', () {
      double reserve(double consumed) => floatingOverlayContentReserve(
        overlayHeight: 65.6,
        overlayBottom: 64,
        readerBottomPadding: consumed,
        contentGap: 24,
      );
      expect(reserve(90), closeTo(63.6, 0.01)); // no dock, 48 system + 42
      expect(reserve(126), closeTo(27.6, 0.01)); // Full dock
      expect(reserve(0), closeTo(153.6, 0.01)); // Hidden dock
      expect(reserve(200), 0); // already fully consumed
    });

    testWidgets('root inset ignores descendant dock padding', (tester) async {
      _configureView(
        tester,
        const _Viewport(390, 840),
        _NavigationMode.gesture,
      );
      double? measured;
      await tester.pumpWidget(
        _themedApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(bottom: 102)),
              child: Builder(
                builder: (nested) {
                  measured = systemBottomInset(nested);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(measured, 24);
    });

    testWidgets('iOS keeps its existing local safe inset', (tester) async {
      _configureView(
        tester,
        const _Viewport(390, 840),
        _NavigationMode.gesture,
      );
      double? measured;
      await tester.pumpWidget(
        _themedApp(
          home: Theme(
            data: ThemeData(platform: TargetPlatform.iOS),
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(padding: const EdgeInsets.only(bottom: 30)),
                child: Builder(
                  builder: (nested) {
                    measured = systemBottomInset(nested);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(measured, 30);
    });
  });

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final hiveDirectory = await Directory.systemTemp.createTemp(
      'android-layout-lab-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox('settings');
    BibleRepository.setData('bel', {
      'books': [
        {
          'id': 'lab',
          'name': 'Кніга Layout Lab',
          'order': 1,
          'chapters': [
            [
              for (var verse = 1; verse <= 36; verse++)
                {
                  'num': verse,
                  'text':
                      'Дэтэрмінаваны тэкст верша $verse для праверкі геаметрыі чытача.',
                },
            ],
          ],
        },
      ],
    });
  });

  // Keep Hive open until the isolate exits. Bible's debounced scroll save can
  // otherwise race teardown on Windows (the production Bible tests do the same).

  group('window geometry is distinct from the app dock reserve', () {
    for (final viewport in _viewports) {
      for (final mode in _modes) {
        testWidgets('Prayerbook ${viewport.label} ${mode.label}', (
          tester,
        ) async {
          _configureView(tester, viewport, mode);
          await tester.pumpWidget(
            _prayerApp(
              _shellBody(
                body: const PrayersScreen(),
                dockMode: ReaderChromeMode.full,
              ),
            ),
          );
          await tester.pump();
          await _jumpToEnd(tester);
          await tester.pump();

          final last = tester.getRect(
            find.byKey(const Key('my-prayers-destination')),
          );
          final dock = tester.getRect(find.byKey(const Key('app-dock-full')));
          final bodyMedia = MediaQuery.of(
            tester.element(find.byKey(const Key('my-prayers-destination'))),
          );
          final view = View.of(
            tester.element(find.byKey(const Key('my-prayers-destination'))),
          );
          final directViewInset =
              view.viewPadding.bottom / view.devicePixelRatio;
          final gap = dock.top - last.bottom;

          expect(directViewInset, mode.systemInset);
          expect(bodyMedia.viewPadding.bottom, 0);
          expect(bodyMedia.padding.bottom, 78 + mode.systemInset);
          // 24dp list breathing room plus the dock container's 6dp top inset.
          expect(gap, closeTo(30, 0.01));
          expect(_maxScrollExtent(tester), greaterThan(0));
          debugPrint(
            'LAYOUT_LAB prayerbook ${viewport.label} ${mode.label}: '
            'system=$directViewInset, localViewPadding=${bodyMedia.viewPadding.bottom}, '
            'localPadding=${bodyMedia.padding.bottom}, dockTop=${dock.top}, '
            'lastBottom=${last.bottom}, gap=$gap, '
            'scroll=${_maxScrollExtent(tester)} CORRECT',
          );
        });
      }
    }
  });

  group('Prayer search', () {
    for (final mode in _modes) {
      testWidgets('${mode.label} closed and open keyboard', (tester) async {
        const viewport = _Viewport(390, 840);
        _configureView(tester, viewport, mode);
        await tester.pumpWidget(
          _prayerApp(const PrayerCatalogScreen(searchInitially: false)),
        );
        await tester.pumpAndSettle();

        final closed = tester.getRect(
          find.byKey(const Key('prayer-search-dock')),
        );
        final closedGap = viewport.height - mode.systemInset - closed.bottom;
        expect(closedGap, closeTo(12, 0.01));

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        final open = tester.getRect(
          find.byKey(const Key('prayer-search-dock')),
        );
        final imeTop = viewport.height - 300;
        final openGap = imeTop - open.bottom;
        expect(openGap, closeTo(12, 0.01));
        expect(open.bottom, lessThan(imeTop));
        expect(find.byKey(const Key('prayer-search-field')), findsOneWidget);

        debugPrint(
          'LAYOUT_LAB prayer-search ${mode.label}: '
          'closedGap=$closedGap ${closedGap > 20 ? 'TOO LOOSE' : 'CORRECT'}, '
          'imeGap=$openGap CORRECT',
        );

        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pump();
      });
    }
  });

  testWidgets('iOS search keeps its safe gap across keyboard and themes', (
    tester,
  ) async {
    const viewport = _Viewport(390, 844);
    for (final brightness in [Brightness.light, Brightness.dark]) {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844)
        ..padding = const FakeViewPadding(bottom: 34)
        ..viewPadding = const FakeViewPadding(bottom: 34)
        ..viewInsets = FakeViewPadding.zero;
      await tester.pumpWidget(
        _prayerApp(
          const PrayerCatalogScreen(searchInitially: false),
          brightness: brightness,
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.pumpAndSettle();
      Rect search() =>
          tester.getRect(find.byKey(const Key('prayer-search-dock')));
      expect(viewport.height - 34 - search().bottom, closeTo(12, 0.01));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(viewport.height - 300 - search().bottom, closeTo(12, 0.01));
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      expect(viewport.height - 34 - search().bottom, closeTo(12, 0.01));
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  group('selection palettes', () {
    for (final mode in _modes) {
      testWidgets('Readings ${mode.label}', (tester) async {
        const viewport = _Viewport(390, 840);
        _configureView(tester, viewport, mode);
        await tester.pumpWidget(_readingsApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await _selectReadingSentence(tester);
        await _jumpToEnd(tester);
        await tester.pump();

        final palette = tester.getRect(
          find.byKey(const Key('readings-highlight-palette')),
        );
        // Attribution is the final content, after the reading document.
        final document = tester.getRect(
          find.byKey(const Key('readings-source-footer')),
        );
        final safeTop = viewport.height - mode.systemInset;
        final safeGap = safeTop - palette.bottom;
        final tail = palette.top - document.bottom;
        final reserve = tester.widget<Padding>(
          find.byKey(const Key('readings-selection-content-reserve')),
        );
        final reserveBottom = (reserve.padding as EdgeInsets).bottom;

        expect(safeGap, closeTo(16, 0.01));
        expect(reserveBottom, lessThan(72));
        expect(tail, closeTo(24, 0.01));
        debugPrint(
          'LAYOUT_LAB readings ${mode.label}: safeGap=$safeGap, '
          'selectionReserve=$reserveBottom, tail=$tail, '
          'scroll=${_maxScrollExtent(tester)} CORRECT',
        );
      });

      testWidgets('Bible ${mode.label}', (tester) async {
        const viewport = _Viewport(390, 840);
        _configureView(tester, viewport, mode);
        final app = _bibleApp();
        addTearDown(app.router.dispose);
        await tester.pumpWidget(app.widget);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byKey(const Key('bible-verse-1')));
        await tester.pumpAndSettle();
        await _jumpToEnd(tester);
        await tester.pump();

        final palette = tester.getRect(
          find.byKey(const Key('bible-highlight-palette')),
        );
        final last = tester.getRect(
          find.byKey(const Key('bible-chapter-navigation')),
        );
        final safeTop = viewport.height - mode.systemInset;
        final safeGap = safeTop - palette.bottom;
        final tail = palette.top - last.bottom;
        final reserve = tester.widget<Padding>(
          find.byKey(const Key('bible-selection-content-reserve')),
        );
        final reserveBottom = (reserve.padding as EdgeInsets).bottom;

        expect(safeGap, closeTo(16, 0.01));
        expect(reserveBottom, lessThan(72));
        expect(tail, closeTo(24, 0.01));
        debugPrint(
          'LAYOUT_LAB bible ${mode.label}: safeGap=$safeGap, '
          'selectionReserve=$reserveBottom, tail=$tail, '
          'scroll=${_maxScrollExtent(tester)} CORRECT',
        );
      });
    }
  });

  group('320x720 narrow matrix', () {
    for (final mode in _modes) {
      testWidgets('${mode.label} search and palettes remain usable', (
        tester,
      ) async {
        const viewport = _Viewport(320, 720);
        _configureView(tester, viewport, mode);

        await tester.pumpWidget(
          _prayerApp(const PrayerCatalogScreen(searchInitially: false)),
        );
        await tester.pumpAndSettle();
        final search = tester.getRect(
          find.byKey(const Key('prayer-search-dock')),
        );
        expect(
          viewport.height - mode.systemInset - search.bottom,
          closeTo(12, 0.01),
        );
        expect(search.left, greaterThanOrEqualTo(0));
        expect(search.right, lessThanOrEqualTo(viewport.width));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        await tester.pumpWidget(_readingsApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await _selectReadingSentence(tester);
        final readingsPalette = tester.getRect(
          find.byKey(const Key('readings-highlight-palette')),
        );
        expect(readingsPalette.left, greaterThanOrEqualTo(0));
        expect(readingsPalette.right, lessThanOrEqualTo(viewport.width));
        expect(
          viewport.height - mode.systemInset - readingsPalette.bottom,
          closeTo(16, 0.01),
        );
        await _jumpToEnd(tester);
        await tester.pump();
        final readingDocument = tester.getRect(
          find.byKey(const Key('readings-source-footer')),
        );
        expect(readingsPalette.top - readingDocument.bottom, closeTo(24, 0.01));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        final bible = _bibleApp();
        await tester.pumpWidget(bible.widget);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byKey(const Key('bible-verse-1')));
        await tester.pumpAndSettle();
        final biblePalette = tester.getRect(
          find.byKey(const Key('bible-highlight-palette')),
        );
        expect(biblePalette.left, greaterThanOrEqualTo(0));
        expect(biblePalette.right, lessThanOrEqualTo(viewport.width));
        expect(
          viewport.height - mode.systemInset - biblePalette.bottom,
          closeTo(16, 0.01),
        );
        await _jumpToEnd(tester);
        await tester.pump();
        final chapterNavigation = tester.getRect(
          find.byKey(const Key('bible-chapter-navigation')),
        );
        expect(biblePalette.top - chapterNavigation.bottom, closeTo(24, 0.01));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        bible.router.dispose();
      });
    }
  });

  group('Holy Mass section bar', () {
    // The previous anchor (local MediaQuery padding + 14) put the bar inside
    // the system navigation area whenever the shell had consumed the inset.
    const gap = 14.0;
    const contentGap = 24.0;

    Future<({Rect bar, Rect contentEnd, double localPadding})> measure(
      WidgetTester tester, {
      required bool shellConsumesInset,
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      await tester.pumpWidget(
        _massApp(shellConsumesInset: shellConsumesInset, platform: platform),
      );
      await tester.pumpAndSettle();
      // The section with the longest name: a two-line title on narrow phones.
      await tester.tap(find.byKey(const Key('mass-section-selector')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('mass-section-eucharistic-liturgy')),
      );
      await tester.pumpAndSettle();
      await _jumpToEnd(tester);
      await tester.pumpAndSettle();
      final barFinder = find.byKey(const Key('mass-navigator-bar'));
      expect(tester.takeException(), isNull);
      return (
        bar: tester.getRect(barFinder),
        contentEnd: tester.getRect(
          find.byKey(const Key('mass-content-reserve')),
        ),
        localPadding: MediaQuery.paddingOf(tester.element(barFinder)).bottom,
      );
    }

    void expectClear(
      ({Rect bar, Rect contentEnd, double localPadding}) m,
      _Viewport viewport,
      double systemInset,
    ) {
      final safeBottom = viewport.height - systemInset;
      // Entirely above the system navigation area, at the shared gap.
      expect(m.bar.bottom, closeTo(safeBottom - gap, 0.01));
      expect(m.bar.bottom, lessThanOrEqualTo(safeBottom));
      expect(m.bar.top, greaterThan(0));
      expect(m.bar.height, greaterThanOrEqualTo(48));
      expect(m.bar.left, greaterThanOrEqualTo(0));
      expect(m.bar.right, lessThanOrEqualTo(viewport.width));
      // The end of the document scrolls clear of the bar.
      expect(m.bar.top - m.contentEnd.top, closeTo(contentGap, 0.01));
    }

    for (final viewport in _viewports) {
      for (final mode in _modes) {
        testWidgets('Android ${mode.label} ${viewport.label}', (tester) async {
          _configureView(tester, viewport, mode);
          final m = await measure(tester, shellConsumesInset: false);
          expect(m.localPadding, mode.systemInset);
          expectClear(m, viewport, mode.systemInset);
          debugPrint(
            'LAYOUT_LAB mass ${viewport.label} ${mode.label}: '
            'barTop=${m.bar.top}, barBottom=${m.bar.bottom}, '
            'contentEnd=${m.contentEnd.top} CORRECT',
          );
        });

        testWidgets(
          'Android ${mode.label} ${viewport.label}, shell consumed the inset',
          (tester) async {
            _configureView(tester, viewport, mode);
            final m = await measure(tester, shellConsumesInset: true);
            // The dock-less shell leaves no local bottom padding at all.
            expect(m.localPadding, 0);
            expectClear(m, viewport, mode.systemInset);
          },
        );
      }
    }

    testWidgets('Android without a bottom inset', (tester) async {
      const viewport = _Viewport(390, 840);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = Size(viewport.width, viewport.height);
      addTearDown(tester.view.reset);
      for (final consumed in [false, true]) {
        final m = await measure(tester, shellConsumesInset: consumed);
        expectClear(m, viewport, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('iOS stays 14pt above the home indicator', (tester) async {
      const viewport = _Viewport(390, 844);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = Size(viewport.width, viewport.height)
        ..padding = const FakeViewPadding(bottom: 34)
        ..viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      for (final consumed in [false, true]) {
        final m = await measure(
          tester,
          shellConsumesInset: consumed,
          platform: TargetPlatform.iOS,
        );
        expectClear(m, viewport, 34);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  testWidgets('Full Compact Hidden use their actual dock reserve', (
    tester,
  ) async {
    const viewport = _Viewport(390, 840);
    for (final mode in ReaderChromeMode.values) {
      _configureView(tester, viewport, _NavigationMode.gesture);
      await tester.pumpWidget(_readerDockApp(mode));
      await tester.pumpAndSettle();
      await _jumpToEnd(tester);
      await tester.pump();

      final marker = tester.getRect(find.byKey(const Key('reader-last-item')));
      final media = MediaQuery.of(
        tester.element(find.byKey(const Key('reader-last-item'))),
      );
      final expectedPadding = switch (mode) {
        ReaderChromeMode.full => 102.0,
        ReaderChromeMode.compact => 96.0,
        ReaderChromeMode.hidden => 0.0,
      };
      expect(media.padding.bottom, expectedPadding);
      expect(marker.bottom, lessThanOrEqualTo(viewport.height));
      debugPrint(
        'LAYOUT_LAB reader ${mode.name}: contentPadding=${media.padding.bottom}, '
        'lastBottom=${marker.bottom}, scroll=${_maxScrollExtent(tester)} '
        '${mode == ReaderChromeMode.hidden ? 'CORRECT no dock reserve' : 'CORRECT'}',
      );
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('dock ${brightness.name} backing keeps its reserve', (
      tester,
    ) async {
      _configureView(
        tester,
        const _Viewport(390, 840),
        _NavigationMode.gesture,
      );
      await tester.pumpWidget(
        _themedApp(
          brightness: brightness,
          home: _shellBody(
            body: const ColoredBox(
              color: Colors.transparent,
              child: SizedBox.expand(),
            ),
            dockMode: ReaderChromeMode.full,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dock = find.byKey(const Key('app-dock-android'));
      expect(tester.getSize(dock).height, 102);
      final decoration =
          tester.widget<Container>(dock).decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors.first.a, 0);
      expect(gradient.colors.last.a, greaterThan(0));
    });
  }

  testWidgets('cycle metadata light', (tester) async {
    _configureView(tester, const _Viewport(390, 840), _NavigationMode.gesture);
    await tester.pumpWidget(_readingsApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('readings-cycle-metadata')), findsNothing);
    expect(find.textContaining(' · Год B'), findsOneWidget);
  });

  testWidgets('cycle metadata dark', (tester) async {
    _configureView(tester, const _Viewport(390, 840), _NavigationMode.gesture);
    await tester.pumpWidget(_readingsApp(brightness: Brightness.dark));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('readings-cycle-metadata')), findsNothing);
    expect(find.textContaining(' · Год B'), findsOneWidget);
  });
}

void _configureView(
  WidgetTester tester,
  _Viewport viewport,
  _NavigationMode mode,
) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(viewport.width, viewport.height)
    ..padding = FakeViewPadding(bottom: mode.systemInset)
    ..viewPadding = FakeViewPadding(bottom: mode.systemInset)
    ..systemGestureInsets = FakeViewPadding(
      bottom: mode == _NavigationMode.gesture ? mode.systemInset : 0,
    )
    ..viewInsets = FakeViewPadding.zero;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio()
      ..resetPadding()
      ..resetViewPadding()
      ..resetSystemGestureInsets()
      ..resetViewInsets();
  });
}

Widget _themedApp({
  required Widget home,
  Brightness brightness = Brightness.light,
  TargetPlatform platform = TargetPlatform.android,
}) {
  final scheme = AppPalette.scheme(brightness);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    themeMode: brightness == Brightness.light
        ? ThemeMode.light
        : ThemeMode.dark,
    theme: ThemeData(
      useMaterial3: true,
      platform: platform,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      platform: platform,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    ),
    builder: (context, child) =>
        ReaderTypographyScope(useSystemFonts: true, child: child!),
    home: home,
  );
}

Widget _prayerApp(
  Widget home, {
  Brightness brightness = Brightness.light,
  TargetPlatform platform = TargetPlatform.android,
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith(_LabSettingsNotifier.new),
    liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
    allPrayersProvider.overrideWithValue(_prayers),
    prayersContentProvider.overrideWith((ref) async {}),
    localPrayersProvider.overrideWith(_LabLocalPrayersNotifier.new),
    prayerMenuCategoriesProvider.overrideWithValue(_categories),
    globalPrayerCategoriesProvider.overrideWith(
      (ref) => Stream.value(_categories),
    ),
  ],
  child: _themedApp(home: home, brightness: brightness, platform: platform),
);

String _massBody(String label) =>
    List.generate(12, (i) => '$label $i.').join('\n\n');

final _massPrayer = Prayer(
  id: kMassRitual.primaryPrayerId,
  title: 'Парадак святой Імшы',
  textFormat: 'mybrev-markdown',
  body: [
    for (final major in kMassRitual.majorSections)
      '### ${major.title}\n\n${_massBody(major.title)}',
  ].join('\n\n'),
);

/// The Mass reader either directly under the window (local padding equals the
/// system inset) or inside the shell with its dock hidden, which consumes the
/// inset before the reader builds.
Widget _massApp({
  required bool shellConsumesInset,
  TargetPlatform platform = TargetPlatform.android,
}) {
  final reader = PrayerDetailScreen(prayerId: kMassRitual.primaryPrayerId);
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(_LabSettingsNotifier.new),
      liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
      allPrayersProvider.overrideWithValue([_massPrayer]),
      prayersContentProvider.overrideWith((ref) async {}),
      localPrayersProvider.overrideWith(_LabLocalPrayersNotifier.new),
    ],
    child: _themedApp(
      platform: platform,
      home: shellConsumesInset
          ? _shellBody(body: reader, dockMode: ReaderChromeMode.hidden)
          : reader,
    ),
  );
}

Widget _readingsApp({Brightness brightness = Brightness.light}) =>
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_LabSettingsNotifier.new),
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
        liturgicalSeasonColorProvider.overrideWithValue(Colors.green),
        readingsLoaderProvider.overrideWithValue(_readingsLoader),
      ],
      child: _themedApp(
        brightness: brightness,
        home: const ReadingsScreen(dateStr: '2026-09-27'),
      ),
    );

({Widget widget, GoRouter router}) _bibleApp() {
  final book = BibleRepository.getBooks('bel').first;
  final router = GoRouter(
    initialLocation: '/bible?version=bel&book=${book.id}&chapter=1',
    routes: [
      GoRoute(
        path: '/bible',
        builder: (context, state) => BibleChapterScreen(
          versionId: state.uri.queryParameters['version'] ?? 'bel',
          bookId: state.uri.queryParameters['book'] ?? book.id,
          chapter:
              int.tryParse(state.uri.queryParameters['chapter'] ?? '') ?? 1,
        ),
      ),
    ],
  );
  final scheme = AppPalette.scheme(Brightness.light);
  return (
    router: router,
    widget: ProviderScope(
      overrides: [settingsProvider.overrideWith(_LabSettingsNotifier.new)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: ThemeData(
          useMaterial3: true,
          platform: TargetPlatform.android,
          colorScheme: scheme,
          scaffoldBackgroundColor: scheme.surfaceContainerLowest,
        ),
        builder: (context, child) =>
            ReaderTypographyScope(useSystemFonts: true, child: child!),
      ),
    ),
  );
}

Widget _shellBody({required Widget body, required ReaderChromeMode dockMode}) =>
    Scaffold(
      key: const Key('layout-lab-shell'),
      extendBody: true,
      body: body,
      bottomNavigationBar: AppNavigationDock(
        activeBranch: AppBranch.prayerbook,
        mode: dockMode,
        seasonColor: Colors.indigo,
        onSelect: (_) {},
        onExpand: () {},
      ),
    );

Widget _readerDockApp(ReaderChromeMode mode) => _themedApp(
  home: _shellBody(
    dockMode: mode,
    body: ReaderScaffold(
      chromeMode: mode,
      enableDoubleTapFullscreen: false,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < 30; index++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Доўгі тэкст чытача, радок ${index + 1}.'),
            ),
          const Text('Апошні значны радок', key: Key('reader-last-item')),
        ],
      ),
    ),
  ),
);

Future<void> _selectReadingSentence(WidgetTester tester) async {
  final selectable = find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        (widget.textSpan?.toPlainText() ?? widget.data ?? '').contains(
          'Першы сказ для вылучэння',
        ),
  );
  final paragraphFinder = find.descendant(
    of: selectable,
    matching: find.byType(RichText),
  );
  final paragraph = tester.renderObject<RenderParagraph>(paragraphFinder.first);
  final glyphs = paragraph.getBoxesForSelection(
    const TextSelection(baseOffset: 0, extentOffset: 5),
  );
  await tester.tapAt(paragraph.localToGlobal(glyphs.first.toRect().center));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byKey(const Key('readings-highlight-cancel')), findsOneWidget);
}

/// Lazy lists refine their estimated extent once the end is laid out, so a
/// single jump can land short (or past) the real end; repeat until stable.
Future<void> _jumpToEnd(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 5; i++) {
    final position = tester.state<ScrollableState>(scrollable).position;
    if (position.pixels == position.maxScrollExtent && i > 0) break;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
  }
}

double _maxScrollExtent(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .maxScrollExtent;

class _LabSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

class _LabLocalPrayersNotifier extends LocalPrayersNotifier {
  @override
  List<Prayer> build() => const [];
}
