import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/providers/songs_provider.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';
import 'package:mybrev_flutter/screens/prayerbook_placeholder_screen.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/screens/song_detail_screen.dart';
import 'package:mybrev_flutter/screens/songbook_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

const _massId = 'eMmCtxwyJ75ogmL5rwye';

const _seed = <Map<String, dynamic>>[
  {
    'id': 's-bog',
    'title': 'Бог наш',
    'text': 'Бог наш вялікі\n\nСвяты Пан',
    'chord': 'C G\n\na',
    'tag': [6],
    'tags': <String>[],
    'source': 'Тэставая крыніца',
  },
  {
    'id': 's-ave',
    'title': 'Аве',
    'text': 'Радасць нябёсаў',
    'chord': '',
    'tag': <int>[],
    'tags': ['Уласны'],
    'source': '',
  },
  {
    'id': 's-kal',
    'title': 'Калядная',
    'text': 'Нарадзіўся Хрыстос',
    'chord': 'D',
    'tag': [7],
    'tags': <String>[],
    'source': '',
  },
];

void main() {
  group('Prayerbook sections', () {
    testWidgets('root shows four section tiles after Favorites', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const Scaffold(body: PrayersScreen())));
      await tester.pump();

      expect(find.text('Раздзелы'), findsOneWidget);
      expect(find.byKey(const Key('prayerbook-sections-grid')), findsOneWidget);
      final keys = [
        'holy-mass-destination',
        'songbook-destination',
        'catechism-destination',
        'sacraments-destination',
      ];
      for (final key in keys) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      final mass = tester.getRect(find.byKey(Key(keys[0])));
      final songs = tester.getRect(find.byKey(Key(keys[1])));
      final catechism = tester.getRect(find.byKey(Key(keys[2])));
      final sacraments = tester.getRect(find.byKey(Key(keys[3])));
      expect(mass.top, songs.top, reason: '2 × 2 grid rows');
      expect(mass.height, songs.height, reason: 'row tiles share a height');
      expect(catechism.top, greaterThan(mass.bottom));
      expect(catechism.top, sacraments.top);
      expect(mass.left, lessThan(songs.left));

      final favoritesY = tester.getTopLeft(find.text('Абраныя')).dy;
      final categoriesY = tester.getTopLeft(find.text('Катэгорыі')).dy;
      final allY = tester.getTopLeft(find.text('Усе малітвы')).dy;
      expect(favoritesY, lessThan(mass.top));
      expect(sacraments.bottom, lessThan(categoriesY));
      expect(categoriesY, lessThan(allY));
    });

    testWidgets('section tiles open Mass, Songbook and placeholders', (
      tester,
    ) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('holy-mass-destination')));
      await tester.pumpAndSettle();
      expect(
        _location(router),
        '/prayers/prayer/$_massId',
        reason: 'Mass tile keeps the existing Mass Order prayer action',
      );
      expect(find.text('Парадак святой Імшы'), findsWidgets);
      router.pop();
      await tester.pumpAndSettle();

      for (final (key, path, title) in [
        ('catechism-destination', '/prayers/catechism', 'Катэхізіс'),
        ('sacraments-destination', '/prayers/sacraments', 'Сакрамэнты'),
      ]) {
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(_location(router), path);
        expect(
          find.byKey(const Key('prayerbook-placeholder-title')),
          findsOneWidget,
        );
        expect(find.text(title), findsWidgets);
        expect(find.text('Раздзел у распрацоўцы'), findsOneWidget);
        await tester.tap(find.byTooltip('Назад'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('prayerbook-title')), findsOneWidget);
      }

      await tester.tap(find.byKey(const Key('songbook-destination')));
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/songs');
      expect(find.byKey(const Key('songbook-title')), findsOneWidget);
    });

    testWidgets('missing Mass keeps the sync hint on the tile', (tester) async {
      await tester.pumpWidget(
        _app(const Scaffold(body: PrayersScreen()), prayers: const []),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('holy-mass-destination')));
      await tester.pump();
      expect(find.text('Тэкст пакуль недаступны'), findsOneWidget);
    });

    testWidgets('tiles do not overflow at 200 percent system text', (
      tester,
    ) async {
      for (final width in [320.0, 390.0, 800.0]) {
        tester.view.physicalSize = Size(width, 2400);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(width, 2400),
              textScaler: const TextScaler.linear(2),
            ),
            child: _app(const Scaffold(body: PrayersScreen())),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'width $width');
        expect(
          find.byKey(const Key('prayerbook-sections-list')),
          findsOneWidget,
        );
        expect(find.text('Сакрамэнты'), findsOneWidget);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('Songbook list', () {
    testWidgets('lists songs with tags, favorites first then alphabetical', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router));
      await tester.pumpAndSettle();

      expect(find.text('Спеваў: 3'), findsOneWidget);
      expect(_rowOrder(tester), ['s-ave', 's-bog', 's-kal']);
      expect(find.byKey(const ValueKey('song-tags-s-bog')), findsOneWidget);
      expect(find.text('Марыйныя'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('song-favorite-s-kal')));
      await tester.pump();
      expect(_rowOrder(tester), ['s-kal', 's-ave', 's-bog']);
    });

    testWidgets('search covers title, lyrics and tag names', (tester) async {
      final router = _router(initialLocation: '/prayers/songs');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('song-search-field'));

      await tester.enterText(field, 'хрыстос');
      await tester.pump();
      expect(_rowOrder(tester), ['s-kal']);
      await tester.enterText(field, 'марыйныя');
      await tester.pump();
      expect(_rowOrder(tester), ['s-bog']);
      await tester.enterText(field, 'Аве');
      await tester.pump();
      expect(_rowOrder(tester), ['s-ave']);
      await tester.enterText(field, 'нічога');
      await tester.pump();
      expect(find.byKey(const Key('songbook-empty')), findsOneWidget);
      expect(find.text('Спевы не знойдзены'), findsOneWidget);
    });

    testWidgets('filter sheet combines tags and favorites only', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('song-filter-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('song-tag-filter-Марыйныя')));
      await tester.tap(find.byKey(const ValueKey('song-tag-filter-Калядныя')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('song-filter-done')));
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['s-bog', 's-kal']);

      await tester.tap(find.byKey(const Key('song-filter-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-favorites-only')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('song-filter-done')));
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), isEmpty);
      expect(
        find.text('Няма абраных спеваў для гэтых фільтраў'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('songbook-active-favorites')),
        findsOneWidget,
      );
    });

    testWidgets('compact list hides tags and keeps favorite action', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router));
      await tester.pumpAndSettle();
      final normalHeight = tester
          .getSize(find.byKey(const ValueKey('song-row-s-bog')))
          .height;

      await tester.tap(find.byKey(const Key('songbook-settings-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-compact-list-switch')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('song-tags-s-bog')), findsNothing);
      expect(find.byKey(const ValueKey('song-favorite-s-bog')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('song-row-s-bog'))).height,
        lessThan(normalHeight),
      );
    });

    testWidgets('seed failure without synced songs shows an error state', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router, seedFails: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('songbook-error')), findsOneWidget);
      expect(find.text('Паўтарыць'), findsOneWidget);
    });

    testWidgets('opening the list requests a songbook refresh', (tester) async {
      var refreshes = 0;
      final router = _router(initialLocation: '/prayers/songs');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _app(null, router: router, onRefresh: () => refreshes++),
      );
      await tester.pumpAndSettle();
      expect(refreshes, 1);
    });
  });

  group('Song detail', () {
    testWidgets('detail uses the reader, shares favorites and returns', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('song-search-field')), 'бог');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('song-row-s-bog')));
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/songs/s-bog');
      expect(find.byType(ReaderScaffold), findsOneWidget);
      expect(find.byType(ReaderContextHeader), findsOneWidget);
      expect(find.byType(ReaderContentSurface), findsOneWidget);
      expect(find.text('СПЕЎНІК'), findsOneWidget);
      expect(find.text('Бог наш'), findsOneWidget);
      expect(find.text('Марыйныя'), findsOneWidget);
      expect(find.text('Бог наш вялікі'), findsOneWidget);
      expect(find.byKey(const Key('song-source')), findsOneWidget);
      expect(
        find.textContaining('Тэставая крыніца', findRichText: true),
        findsOneWidget,
      );
      expect(find.byKey(const Key('text-scale-open')), findsOneWidget);
      expect(find.byKey(const Key('song-transpose-control')), findsNothing);
      expect(
        find.text('C G'),
        findsNothing,
        reason: 'chords hidden by default',
      );

      await tester.tap(find.byKey(const Key('song-detail-favorite')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('reader-chrome-back')));
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/songs');
      final field = tester.widget<TextField>(
        find.byKey(const Key('song-search-field')),
      );
      expect(field.controller!.text, 'бог', reason: 'query is restored');
      expect(_rowOrder(tester), ['s-bog']);
      final heart = tester.widget<IconButton>(
        find.byKey(const ValueKey('song-favorite-s-bog')),
      );
      expect(heart.tooltip, 'Выдаліць з абраных');
    });

    testWidgets('transpose changes displayed chords only and resets', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs/s-bog');
      addTearDown(router.dispose);
      late ProviderContainer container;
      await tester.pumpWidget(
        _app(
          null,
          router: router,
          prefs: const SongPreferences(showChords: true),
          onContainer: (value) => container = value,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('song-transpose-control')), findsOneWidget);
      expect(find.text('C G'), findsOneWidget);
      expect(find.byKey(const Key('song-text-above')), findsOneWidget);

      await tester.tap(find.byKey(const Key('song-transpose-up')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('song-transpose-up')));
      await tester.pump();
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('D A'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      final song = container.read(songByIdProvider('s-bog')).requireValue!;
      expect(song.chord, 'C G\n\na', reason: 'stored chords are unchanged');

      await tester.tap(find.byKey(const Key('song-transpose-reset')));
      await tester.pump();
      expect(find.text('0'), findsOneWidget);
      expect(find.text('C G'), findsOneWidget);

      for (var i = 0; i < 14; i++) {
        await tester.tap(find.byKey(const Key('song-transpose-down')));
        await tester.pump();
      }
      expect(find.text('-12'), findsOneWidget);
      expect(find.text('C G'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('song-transpose-down')))
            .onPressed,
        isNull,
      );

      router.go('/prayers/songs/s-kal');
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget, reason: 'new song resets');
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('left chord layout falls back above on narrow large text', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs/s-bog');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _app(
          null,
          router: router,
          prefs: const SongPreferences(
            showChords: true,
            chordLayout: SongChordLayout.left,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('song-text-left')), findsOneWidget);

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: _app(
            null,
            router: router,
            prefs: const SongPreferences(
              showChords: true,
              chordLayout: SongChordLayout.left,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('song-text-above')), findsOneWidget);
    });

    testWidgets('unknown song shows a not found state', (tester) async {
      final router = _router(initialLocation: '/prayers/songs/missing');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router));
      await tester.pumpAndSettle();
      expect(find.text('Спеў не знойдзены'), findsOneWidget);
    });
  });

  group('Song preferences persistence', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('songbook-prefs-');
      await HiveService.init(path: directory.path);
    });
    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test('favorites, chords, layout and compact list survive restart', () {
      final first = ProviderContainer();
      final notifier = first.read(songPreferencesProvider.notifier);
      expect(first.read(songPreferencesProvider).showChords, isFalse);
      expect(
        first.read(songPreferencesProvider).chordLayout,
        SongChordLayout.above,
      );
      notifier
        ..toggleFavorite('a')
        ..toggleFavorite('b')
        ..toggleFavorite('a')
        ..setShowChords(true)
        ..setChordLayout(SongChordLayout.left)
        ..setCompactList(true);
      first.dispose();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      final prefs = second.read(songPreferencesProvider);
      expect(prefs.favoriteSongIds, ['b']);
      expect(prefs.showChords, isTrue);
      expect(prefs.chordLayout, SongChordLayout.left);
      expect(prefs.compactList, isTrue);
      expect(HiveService.settingsBox.get('favoriteSongIds'), '["b"]');
    });

    test('song favorites are independent from prayer favorites', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(songPreferencesProvider.notifier).toggleFavorite('song');
      container.read(settingsProvider.notifier).toggleFavorite('prayer');
      expect(container.read(settingsProvider).favoriteIds, ['prayer']);
      expect(container.read(songPreferencesProvider).favoriteSongIds, ['song']);
      // Let the unawaited settings writes finish before the box closes.
      await pumpEventQueue();
      expect(HiveService.settingsBox.get('favoriteIds'), '["prayer"]');
      expect(HiveService.settingsBox.get('favoriteSongIds'), '["song"]');
    });

    test('legacy right layout is read as left', () async {
      await HiveService.settingsBox.put('songChordLayout', 'right');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(songPreferencesProvider).chordLayout,
        SongChordLayout.left,
      );
    });
  });
}

String _location(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  final last = config.matches.last;
  return last is ImperativeRouteMatch ? last.matches.uri.path : config.uri.path;
}

List<String> _rowOrder(WidgetTester tester) {
  final rows = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('song-row-'),
  );
  final entries = [
    for (final element in rows.evaluate())
      (
        (element.widget.key! as ValueKey<String>).value.substring(9),
        tester.getTopLeft(find.byWidget(element.widget)).dy,
      ),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final entry in entries) entry.$1];
}

GoRouter _router({String initialLocation = '/prayers'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/prayers',
      builder: (context, state) => const Scaffold(body: PrayersScreen()),
      routes: [
        GoRoute(
          path: 'prayer/:id',
          builder: (context, state) =>
              PrayerDetailScreen(prayerId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: 'songs',
          builder: (context, state) => const SongbookScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  SongDetailScreen(songId: state.pathParameters['id']!),
            ),
          ],
        ),
        GoRoute(
          path: 'catechism',
          builder: (context, state) => const CatechismPlaceholderScreen(),
        ),
        GoRoute(
          path: 'sacraments',
          builder: (context, state) => const SacramentsPlaceholderScreen(),
        ),
      ],
    ),
  ],
);

Widget _app(
  Widget? child, {
  GoRouter? router,
  List<Prayer> prayers = const [
    Prayer(
      id: _massId,
      title: 'Парадак святой Імшы',
      body: '<h2>Уступ</h2><p>Імя Айца</p>',
    ),
  ],
  SongPreferences prefs = const SongPreferences(),
  bool seedFails = false,
  VoidCallback? onRefresh,
  void Function(ProviderContainer)? onContainer,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(_TestSettingsNotifier.new),
      liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
      allPrayersProvider.overrideWithValue(prayers),
      localPrayersProvider.overrideWith(_TestLocalPrayersNotifier.new),
      prayerMenuCategoriesProvider.overrideWithValue(const []),
      globalPrayerCategoriesProvider.overrideWith(
        (ref) => Stream.value(const []),
      ),
      songSeedProvider.overrideWith(
        (ref) async => seedFails ? throw StateError('asset') : _seed,
      ),
      cachedSongDocsProvider.overrideWithValue(const []),
      songPreferencesProvider.overrideWith(() => _TestSongPrefs(prefs)),
      songbookRefreshProvider.overrideWithValue(onRefresh ?? () {}),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        if (onContainer != null) {
          onContainer(ProviderScope.containerOf(context));
        }
        return router == null
            ? MaterialApp(home: child)
            : MaterialApp.router(routerConfig: router);
      },
    ),
  );
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

class _TestLocalPrayersNotifier extends LocalPrayersNotifier {
  @override
  List<Prayer> build() => const [];
}

/// In-memory preferences; persistence is covered with a real Hive box above.
class _TestSongPrefs extends SongPreferencesNotifier {
  _TestSongPrefs(this.initial);
  final SongPreferences initial;

  @override
  SongPreferences build() => initial;

  @override
  void toggleFavorite(String id) {
    final values = [...state.favoriteSongIds];
    if (!values.remove(id)) values.add(id);
    state = state.copyWith(favoriteSongIds: values);
  }

  @override
  void setCompactList(bool value) => state = state.copyWith(compactList: value);

  @override
  void setShowChords(bool value) => state = state.copyWith(showChords: value);

  @override
  void setChordLayout(SongChordLayout layout) =>
      state = state.copyWith(chordLayout: layout);
}
