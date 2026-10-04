import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mybrev_flutter/navigation/bible_navigation.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/screens/bible_chapter_screen.dart';
import 'package:mybrev_flutter/screens/bible_search_screen.dart';
import 'package:mybrev_flutter/services/bible_seed_loader.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Map<String, dynamic> belSeed;
  late Map<String, dynamic> ruSeed;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    hiveDirectory = await Directory.systemTemp.createTemp('bible-stage6-');
    Hive.init(hiveDirectory.path);
    await Hive.openBox('settings');
    await Hive.box('settings').clear();
    belSeed = await BibleSeedLoader.load(lang: 'bel');
    ruSeed = await BibleSeedLoader.load(lang: 'ru');
    BibleRepository.setData('bel', belSeed);
    BibleRepository.setData('ru', ruSeed);
  });

  // Hive stays open for the lifetime of the test isolate. Closing it while the
  // final widget tree is being disposed can race the reader's debounced scroll
  // save on Windows.

  group('Bible location and navigation', () {
    test('first run uses a sensible first-book default', () {
      final first = BibleRepository.getBooks('bel').first;
      final location = BibleNavigation.resolve(versionId: 'bel');
      expect(location?.bookId, first.id);
      expect(location?.chapter, 1);
    });

    test('root restores last location and clamps a corrupt chapter', () {
      final book = BibleRepository.getBooks('bel').first;
      final location = BibleNavigation.resolve(
        versionId: 'bel',
        saved: {'bookId': book.id, 'chapter': 99999},
      );
      expect(location?.bookId, book.id);
      expect(location?.chapter, book.chapterCount);
    });

    test('translation switch preserves the canonical book and chapter', () {
      final sourceBook = BibleRepository.getBooks('bel').firstWhere(
        (book) => BibleRepository.getParallelBook('bel', book.id, 'ru') != null,
      );
      final target = BibleNavigation.switchTranslation(
        current: BibleLocation(
          versionId: 'bel',
          bookId: sourceBook.id,
          chapter: sourceBook.chapterCount.clamp(1, 2),
        ),
        targetVersionId: 'ru',
      );
      expect(target?.versionId, 'ru');
      expect(target?.bookId, isNotEmpty);
      expect(target?.chapter, greaterThanOrEqualTo(1));
    });

    test('translation fallback uses the saved target location', () {
      final unsupported = BibleRepository.getBooks('ru').firstWhere(
        (book) => BibleRepository.getParallelBook('ru', book.id, 'bel') == null,
      );
      final fallback = BibleRepository.getBooks('bel').last;
      final target = BibleNavigation.switchTranslation(
        current: BibleLocation(
          versionId: 'ru',
          bookId: unsupported.id,
          chapter: 1,
        ),
        targetVersionId: 'bel',
        targetSaved: {'bookId': fallback.id, 'chapter': 2},
      );
      expect(target?.bookId, fallback.id);
      expect(target?.chapter, 2.clamp(1, fallback.chapterCount));
    });

    test('previous and next cross book boundaries', () {
      final books = BibleRepository.getBooks('bel');
      final first = books.first;
      final second = books[1];
      final next = BibleNavigation.relative(
        BibleLocation(
          versionId: 'bel',
          bookId: first.id,
          chapter: first.chapterCount,
        ),
        1,
      );
      expect((next?.bookId, next?.chapter), (second.id, 1));
      final previous = BibleNavigation.relative(next!, -1);
      expect(
        (previous?.bookId, previous?.chapter),
        (first.id, first.chapterCount),
      );
    });

    test('first and last chapter boundaries disable navigation', () {
      final books = BibleRepository.getBooks('bel');
      expect(
        BibleNavigation.relative(
          BibleLocation(versionId: 'bel', bookId: books.first.id, chapter: 1),
          -1,
        ),
        isNull,
      );
      expect(
        BibleNavigation.relative(
          BibleLocation(
            versionId: 'bel',
            bookId: books.last.id,
            chapter: books.last.chapterCount,
          ),
          1,
        ),
        isNull,
      );
    });

    test('canonical and search-result routes preserve a verse target', () {
      const location = BibleLocation(
        versionId: 'bel',
        bookId: 'gn',
        chapter: 3,
        verse: 7,
      );
      expect(BibleNavigation.route(location), contains('/bible?'));
      expect(
        BibleNavigation.route(location, searchResult: true),
        contains('/bible/search/result?'),
      );
      expect(BibleNavigation.route(location), contains('verse=7'));
    });

    test('missing and corrupt local data produce an empty graceful state', () {
      BibleRepository.setData('bel', {'books': 'corrupt'});
      expect(BibleRepository.getBooks('bel'), isEmpty);
      expect(BibleNavigation.resolve(versionId: 'bel'), isNull);
      expect(BibleRepository.getBooks('unknown'), isEmpty);
      BibleRepository.setData('bel', belSeed);
    });
  });

  group('Bible reader interactions', () {
    testWidgets(
      'reader is neutral and exposes translation, picker, search, Aa',
      (tester) async {
        await _pumpBible(tester);
        expect(find.byKey(const Key('reader-content-surface')), findsOneWidget);
        expect(find.text('БЕЛ'), findsOneWidget);
        expect(find.text('РУС'), findsOneWidget);
        expect(
          find.byKey(const Key('bible-book-chapter-picker')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('bible-search-open')), findsOneWidget);
        expect(find.byKey(const Key('text-scale-open')), findsOneWidget);
      },
    );

    testWidgets('BEL and RUS switch keeps the reading location', (
      tester,
    ) async {
      final app = await _pumpBible(tester);
      await tester.tap(find.text('РУС'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final query =
          app.router.routeInformationProvider.value.uri.queryParameters;
      expect(query['version'], 'ru');
      expect(query['chapter'], '1');
      expect(query['book'], isNotEmpty);
    });

    testWidgets('book/chapter picker changes chapter', (tester) async {
      final app = await _pumpBible(tester);
      final book = BibleRepository.getBooks('bel').first;
      await tester.tap(find.byKey(const Key('reader-context-title-action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Кнігі і раздзелы'), findsOneWidget);
      if (book.chapterCount > 1) {
        final chapter = find.byKey(Key('bible-chapter-${book.id}-2'));
        await tester.tap(chapter);
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          app
              .router
              .routeInformationProvider
              .value
              .uri
              .queryParameters['chapter'],
          '2',
        );
      }

      final secondBook = BibleRepository.getBooks('bel')[1];
      await tester.tap(find.byKey(const Key('reader-context-title-action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(Key('bible-book-${book.id}')));
      await tester.pump();
      await tester.tap(find.byKey(Key('bible-book-${secondBook.id}')));
      await tester.pump();
      await tester.tap(find.byKey(Key('bible-chapter-${secondBook.id}-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        app.router.routeInformationProvider.value.uri.queryParameters['book'],
        secondBook.id,
      );
    });

    testWidgets('inline chapter center opens the existing full-name picker', (
      tester,
    ) async {
      await _pumpBible(tester);
      final book = BibleRepository.getBooks('bel').first;
      expect(find.byKey(const Key('bible-chapter-navigation')), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bible-book-chapter-picker')));
      await tester.pumpAndSettle();
      expect(find.text('Кнігі і раздзелы'), findsOneWidget);
      expect(find.text(book.name), findsWidgets);
    });

    testWidgets(
      'manual downward scroll compacts the Bible dock and a new chapter resets it',
      (tester) async {
        final controller = ReaderChromeModeController(ReaderChromeMode.full);
        addTearDown(controller.dispose);
        final app = await _pumpBible(tester, chromeController: controller);
        expect(controller.value, ReaderChromeMode.full);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
        await tester.pump();
        expect(controller.value, ReaderChromeMode.full);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();
        expect(controller.value, ReaderChromeMode.compact);

        final next = BibleNavigation.relative(app.location, 1)!;
        app.router.go(BibleNavigation.route(next));
        await tester.pumpAndSettle();
        expect(controller.value, ReaderChromeMode.full);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();
        expect(controller.value, ReaderChromeMode.compact);
        // Let the gesture recognizer's short double-tap window expire.
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets('next and previous chapter controls navigate', (tester) async {
      final app = await _pumpBible(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bible-next-chapter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        app
            .router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['chapter'],
        '2',
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bible-previous-chapter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        app
            .router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['chapter'],
        '1',
      );
    });

    testWidgets('verse selection adds, removes, and persists a highlight', (
      tester,
    ) async {
      final app = await _pumpBible(tester);
      await tester.tap(find.byKey(const Key('bible-verse-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('bible-highlight-amber')), findsOneWidget);
      await tester.tap(find.byKey(const Key('bible-highlight-amber')));
      await tester.pump(const Duration(milliseconds: 300));
      final location = app.location;
      expect(
        Hive.box('settings').get(BibleNavigation.highlightKey(location)),
        containsPair('1', 'amber'),
      );
      await tester.tap(find.byKey(const Key('bible-verse-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('bible-highlight-clear')));
      await tester.pump();
      expect(
        Hive.box('settings').get(BibleNavigation.highlightKey(location)),
        isEmpty,
      );
    });

    testWidgets('double tap enters fullscreen without selecting a verse', (
      tester,
    ) async {
      final controller = ReaderChromeModeController(ReaderChromeMode.compact);
      addTearDown(controller.dispose);
      await _pumpBible(tester, chromeController: controller);

      final verse = find.byKey(const Key('bible-verse-1'));
      await tester.tap(verse);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(verse);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reader-chrome-hidden')), findsOneWidget);
      expect(find.byKey(const Key('bible-highlight-cancel')), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('verse palette exposes names, state, and 48dp targets', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpBible(tester);
      await tester.tap(find.byKey(const Key('bible-verse-1')));
      await tester.pumpAndSettle();

      final amber = find.byKey(const Key('bible-highlight-amber'));
      expect(tester.getSize(amber).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(amber).height, greaterThanOrEqualTo(48));
      expect(tester.getSemantics(amber).label, 'Бурштынавы колер');
      expect(
        tester.getSize(find.byKey(const Key('bible-highlight-clear'))).width,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byKey(const Key('bible-highlight-cancel'))).width,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(amber);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bible-verse-1')));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(amber).flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );
      semantics.dispose();
    });

    testWidgets('verse palette uses reported zero system inset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpBible(tester);
      await tester.tap(find.byKey(const Key('bible-verse-1')));
      await tester.pumpAndSettle();

      final paletteBottom = tester
          .getBottomRight(find.byKey(const Key('bible-highlight-palette')))
          .dy;
      expect(800 - paletteBottom, closeTo(16, 0.01));
    });

    testWidgets('system TextScaler increases rendered verse body', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpBible(tester);
      final normal = tester.getSize(
        find.byKey(const Key('bible-verse-body-1')),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pumpBible(tester, textScale: 2);
      final scaled = tester.getSize(
        find.byKey(const Key('bible-verse-body-1')),
      );

      expect(scaled.height, greaterThan(normal.height));
      final richText = tester.widget<RichText>(
        find.byKey(const Key('bible-verse-body-1')),
      );
      expect(richText.textScaler.scale(20), 40);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Aa changes the shared size and exposes reader fonts', (
      tester,
    ) async {
      await _pumpBible(tester);
      await tester.tap(find.byKey(const Key('text-scale-open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Выгляд тэксту'), findsOneWidget);
      await tester.tap(find.byKey(const Key('text-scale-increase')));
      await tester.pump();
      expect(find.text('110%'), findsOneWidget);
      expect(find.text('Шрыфт чытання'), findsOneWidget);
    });

    testWidgets('search result opens the verse and Back restores query state', (
      tester,
    ) async {
      final app = await _pumpBible(tester);
      final verse = BibleRepository.getChapter(
        app.location.versionId,
        app.location.bookId,
        1,
      ).first;
      final word = verse.text
          .split(RegExp(r'\s+'))
          .map(
            (part) => part.replaceAll(RegExp(r'[^\p{L}]', unicode: true), ''),
          )
          .firstWhere((part) => part.length >= 3);
      await tester.tap(find.byKey(const Key('bible-search-open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byKey(const Key('bible-search-field')), word);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('ВЕРШЫ ·'), findsOneWidget);
      await tester.tap(
        find.byKey(Key('bible-search-verse-1-${verse.verse}')).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(Key('bible-verse-${verse.verse}')), findsOneWidget);
      app.router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('bible-search-field')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('bible-search-field')))
            .controller
            ?.text,
        word,
      );
    });

    testWidgets('scroll offset survives recreation and branch-style return', (
      tester,
    ) async {
      await _pumpBible(tester, initialScrollOffset: 120);
      final scroll = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(scroll.controller?.offset, closeTo(120, 0.1));
    });

    testWidgets('Compact and Hidden chrome remain shell-controlled', (
      tester,
    ) async {
      final controller = ReaderChromeModeController(ReaderChromeMode.compact);
      await _pumpBible(tester, chromeController: controller);
      addTearDown(controller.dispose);
      expect(find.byKey(const Key('reader-chrome-restore')), findsNothing);
      controller.value = ReaderChromeMode.hidden;
      await tester.pump();
      expect(find.byKey(const Key('reader-chrome-hidden')), findsOneWidget);
      expect(find.byKey(const Key('reader-chrome-restore')), findsNothing);
    });

    testWidgets('iOS and Android use their native chrome interpretations', (
      tester,
    ) async {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        await _pumpBible(tester, platform: platform);
        expect(
          find.byKey(
            Key(
              platform == TargetPlatform.iOS
                  ? 'adaptive-chrome-glass'
                  : 'adaptive-chrome-ambient',
            ),
          ),
          findsWidgets,
        );
      }
    });

    testWidgets('large text and narrow screens do not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpBible(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });
}

class _TestBibleApp {
  const _TestBibleApp(this.router, this.location);

  final GoRouter router;
  final BibleLocation location;
}

Future<_TestBibleApp> _pumpBible(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.android,
  double textScale = 1,
  ReaderChromeModeController? chromeController,
  double initialScrollOffset = 0,
}) async {
  final book = BibleRepository.getBooks('bel').first;
  final location = BibleLocation(versionId: 'bel', bookId: book.id, chapter: 1);
  Hive.box(
    'settings',
  ).put(BibleNavigation.scrollKey(location), initialScrollOffset);
  late GoRouter router;
  BibleChapterScreen chapter(GoRouterState state) => BibleChapterScreen(
    versionId: state.uri.queryParameters['version'] ?? location.versionId,
    bookId: state.uri.queryParameters['book'] ?? location.bookId,
    chapter: int.tryParse(state.uri.queryParameters['chapter'] ?? '') ?? 1,
  );
  router = GoRouter(
    initialLocation: BibleNavigation.route(location),
    routes: [
      GoRoute(
        path: '/bible',
        builder: (_, state) => chapter(state),
        routes: [
          GoRoute(
            path: 'search',
            builder: (_, state) => BibleSearchScreen(
              versionId: state.uri.queryParameters['version']!,
              bookId: state.uri.queryParameters['book']!,
            ),
            routes: [
              GoRoute(path: 'result', builder: (_, state) => chapter(state)),
            ],
          ),
        ],
      ),
    ],
  );
  Widget child = MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(platform: platform),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  );
  if (chromeController != null) {
    child = ReaderChromeModeScope(controller: chromeController, child: child);
  }
  await tester.pumpWidget(ProviderScope(child: child));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
  return _TestBibleApp(router, location);
}
