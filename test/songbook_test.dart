import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/admin_songbook_access_provider.dart';
import 'package:mybrev_flutter/widgets/admin_songbook_guard.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/providers/songs_provider.dart';
import 'package:mybrev_flutter/screens/compendium_screen.dart';
import 'package:mybrev_flutter/screens/prayer_detail_screen.dart';
import 'package:mybrev_flutter/screens/prayerbook_placeholder_screen.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';
import 'package:mybrev_flutter/screens/song_detail_screen.dart';
import 'package:mybrev_flutter/screens/songbook_screen.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/songs/song_chord_control.dart';
import 'package:mybrev_flutter/widgets/songs/song_text.dart';

import 'support/compendium_fixture.dart';

const _massId = 'eMmCtxwyJ75ogmL5rwye';

/// Android tonal and iOS Glass chrome.
final _platforms = TargetPlatformVariant(const {
  TargetPlatform.android,
  TargetPlatform.iOS,
});
final _compendium = readBundledCompendium();

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

/// Long lyric lines with a short chord column, and a chord line too long to
/// ever sit beside the lyrics.
const _longSeed = <Map<String, dynamic>>[
  {
    'id': 's-long',
    'title': 'Доўгі спеў',
    'text':
        'Вельмі доўгі радок спеву, які абавязкова пераносіцца на некалькі '
        'радкоў нават на шырокім экране тэлефона ў альбомнай арыентацыі\n'
        'Кароткі радок',
    'chord': 'C G a F\nd G',
    'tag': <int>[],
    'tags': <String>[],
    'source': '',
  },
  {
    'id': 's-chords',
    'title': 'Доўгія акорды',
    'text': 'Першы радок спеву\nДругі радок спеву',
    'chord': 'C G a F C G a F C G a F C G a F C G a F C G a F C G a F\nE',
    'tag': <int>[],
    'tags': <String>[],
    'source': '',
  },
];

/// A typical song: short chord runs next to ordinary lyric lines.
///
/// The test font is 1 em per glyph, about 1.7× a real monospace face, so
/// these two-chord lines take the room of four-chord lines ("G D G D") on a
/// device.
const _typicalSeed = <Map<String, dynamic>>[
  {
    'id': 's-typ',
    'title': 'Тыповы спеў',
    'text':
        'Аллелюя, Езус смерць перамог\n'
        'Устаў з магілы наш Пан і Бог\n'
        'Радуйся, зямля, спявай, неба\n'
        'Хрыстус уваскрос, аллелюя',
    'chord': 'e a\nG D\na7 F\ne D',
    'tag': <int>[],
    'tags': <String>[],
    'source': '',
  },
];

void main() {
  group('Song filter state', () {
    test('search and tags alone determine activity and badge count', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(songsFilterProvider.notifier);
      expect(container.read(songsFilterProvider).isActive, isFalse);
      notifier.setSearch('  Бог  ');
      expect(container.read(songsFilterProvider).isActive, isTrue);
      expect(container.read(songsFilterProvider).filterCount, 0);
      notifier.toggleTag('Марыйныя');
      notifier.toggleTag('Калядныя');
      expect(container.read(songsFilterProvider).filterCount, 2);
      notifier.clearFilters();
      final cleared = container.read(songsFilterProvider);
      expect(cleared.selectedTags, isEmpty);
      expect(cleared.searchQuery, '  Бог  ');
      expect(cleared.isActive, isTrue);
      notifier.setSearch('  ');
      expect(container.read(songsFilterProvider).isActive, isFalse);
    });
  });

  group('Admin-only songbook', () {
    test('role validation defaults to deny for unknown users', () {
      expect(isAdminRecord('ordinary', null), isFalse);
      expect(isAdminRecord('ordinary', {'role': 'other'}), isFalse);
      expect(isAdminRecord('ordinary', {}), isTrue);
      expect(isAdminRecord('ordinary', {'role': 'admin'}), isTrue);
      expect(isAdminRecord('ordinary', {'role': 'superadmin'}), isTrue);
    });

    testWidgets('guests do not see the tile or the songbook via a deep link', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: PrayersScreen()), admin: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('songbook-destination')), findsNothing);

      final router = _router(initialLocation: '/prayers/songs/s-bog');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router, admin: false));
      await tester.pumpAndSettle();
      expect(find.text('Раздзел недаступны'), findsOneWidget);
      expect(find.byKey(const Key('songbook-title')), findsNothing);
    });
  });

  group('Prayerbook sections', () {
    testWidgets('root shows three section tiles after Favorites', (
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
      expect(find.text('Пілігрымковы'), findsOneWidget);
      final keys = [
        'holy-mass-destination',
        'songbook-destination',
        'catechism-destination',
      ];
      for (final key in keys) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      final mass = tester.getRect(find.byKey(Key(keys[0])));
      final songs = tester.getRect(find.byKey(Key(keys[1])));
      final catechism = tester.getRect(find.byKey(Key(keys[2])));
      expect(mass.top, songs.top, reason: '2 × 2 grid rows');
      expect(mass.height, songs.height, reason: 'row tiles share a height');
      expect(catechism.top, greaterThan(mass.bottom));
      expect(find.byKey(const Key('sacraments-destination')), findsNothing);
      expect(find.text('Сакрамэнты'), findsNothing);
      expect(mass.left, lessThan(songs.left));

      final favoritesY = tester.getTopLeft(find.text('Абраныя')).dy;
      final categoriesY = tester.getTopLeft(find.text('Катэгорыі')).dy;
      final allY = tester.getTopLeft(find.text('Усе малітвы')).dy;
      expect(favoritesY, lessThan(mass.top));
      expect(catechism.bottom, lessThan(categoriesY));
      expect(categoriesY, lessThan(allY));
    });

    testWidgets('section tiles open Mass, Songbook and Compendium', (
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

      await tester.tap(find.byKey(const Key('catechism-destination')));
      await tester.pumpAndSettle();
      expect(
        _location(router),
        '/prayers/compendium',
        reason: 'the Катэхізіс tile opens the Compendium',
      );
      expect(find.byKey(const Key('compendium-title')), findsOneWidget);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('songbook-destination')));
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/songs');
      expect(find.byKey(const Key('songbook-title')), findsOneWidget);
      expect(find.byKey(const Key('songbook-subtitle')), findsOneWidget);
    });

    testWidgets('legacy Sacraments deep link stays valid without a root tile', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/sacraments');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router));
      await tester.pumpAndSettle();

      expect(_location(router), '/prayers/sacraments');
      expect(find.byKey(const Key('prayerbook-placeholder-title')), findsOneWidget);
      expect(find.text('Сакрамэнты'), findsOneWidget);
      expect(find.text('Раздзел у распрацоўцы'), findsOneWidget);
    });

    testWidgets('missing Mass says so on the tile', (tester) async {
      await tester.pumpWidget(
        _app(const Scaffold(body: PrayersScreen()), prayers: const []),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('holy-mass-destination')));
      await tester.pump();
      expect(find.text('Тэкст Імшы недаступны'), findsOneWidget);
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
        expect(find.text('Сакрамэнты'), findsNothing);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('Songbook list', () {
    testWidgets('lists songs, favorites first then alphabetical', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router));
      await tester.pumpAndSettle();

      expect(find.text('Спеваў: 3'), findsOneWidget);
      expect(_rowOrder(tester), ['s-ave', 's-bog', 's-kal']);

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

    testWidgets('filter sheet supports tags, removal and reset', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('song-favorite-s-kal')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('song-filter-action')));
      await tester.pumpAndSettle();
      expect(find.text('Толькі абраныя'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('song-tag-filter-Марыйныя')));
      await tester.tap(find.byKey(const ValueKey('song-tag-filter-Калядныя')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('song-filter-done')));
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['s-kal', 's-bog']);
      expect(
        find.byKey(const ValueKey('songbook-active-tag-Марыйныя')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('songbook-active-tag-Калядныя')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('songbook-active-tag-Марыйныя')),
          matching: find.byTooltip('Delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['s-kal']);
      expect(
        find.byKey(const ValueKey('songbook-active-tag-Марыйныя')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('song-filter-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ачысціць'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('song-filter-done')));
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['s-kal', 's-ave', 's-bog']);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('song-favorite-s-kal')),
            )
            .tooltip,
        'Выдаліць з абраных',
      );
      expect(
        find.byKey(const ValueKey('songbook-active-tag-Калядныя')),
        findsNothing,
      );
    });

    testWidgets('tag chips fit a 320 dp phone at 200 percent text', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      const size = Size(320, 640);
      tester.view.physicalSize = size;
      const longTag = 'ВельміДоўгіТэгБезПрабелаўДляМаленькагаЭкрана';
      final router = _router(initialLocation: '/prayers/songs');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(2),
          ),
          child: _app(
            null,
            router: router,
            seed: [
              ..._seed,
              {
                'id': 'long',
                'title': 'Доўгі',
                'text': 'Тэкст',
                'tags': [longTag],
              },
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-filter-action')));
      await tester.pumpAndSettle();
      expect(find.text('Толькі абраныя'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('song-tag-filter-$longTag')),
      );
      await tester.tap(find.byKey(const ValueKey('song-tag-filter-$longTag')));
      await tester.ensureVisible(
        find.byKey(const ValueKey('song-tag-filter-Уласны')),
      );
      await tester.tap(find.byKey(const ValueKey('song-tag-filter-Уласны')));
      await tester.tap(find.byKey(const Key('song-filter-done')));
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['s-ave', 'long']);
      final longChip = tester.getRect(
        find.byKey(const ValueKey('songbook-active-tag-$longTag')),
      );
      final otherChip = tester.getRect(
        find.byKey(const ValueKey('songbook-active-tag-Уласны')),
      );
      expect(longChip.right, lessThanOrEqualTo(size.width));
      expect(otherChip.top, greaterThanOrEqualTo(longChip.bottom));
      expect(tester.takeException(), isNull);
    }, variant: _platforms);

    testWidgets('list is always compact and has no songbook settings', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('songbook-settings-action')), findsNothing);
      expect(find.byTooltip('Налады спеўніка'), findsNothing);
      expect(find.byKey(const Key('song-compact-list-switch')), findsNothing);
      for (final id in ['s-ave', 's-bog', 's-kal']) {
        expect(find.byKey(ValueKey('song-tags-$id')), findsNothing);
        expect(find.byKey(ValueKey('song-favorite-$id')), findsOneWidget);
        final height = tester
            .getSize(find.byKey(ValueKey('song-row-$id')))
            .height;
        expect(height, inInclusiveRange(48, 52), reason: 'compact row $id');
      }
      expect(find.text('Марыйныя'), findsNothing, reason: 'no tags in rows');

      // Tags stay searchable and filterable without being shown in rows.
      await tester.enterText(
        find.byKey(const Key('song-search-field')),
        'марыйныя',
      );
      await tester.pump();
      expect(_rowOrder(tester), ['s-bog']);
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
      expect(find.text('СПЕЎНІК ПІЛІГРЫМКОВЫ'), findsOneWidget);
      expect(find.text('Бог наш'), findsOneWidget);
      expect(find.text('Марыйныя'), findsOneWidget);
      expect(find.text('Бог наш вялікі'), findsOneWidget);
      expect(find.byKey(const Key('song-source')), findsOneWidget);
      final source = tester.widget<Text>(find.byKey(const Key('song-source')));
      final reader = ReaderTheme.of(
        tester.element(find.byKey(const Key('song-source'))),
      );
      expect(source.style?.color, reader.muted);
      expect(source.style?.height, ReaderTheme.metadataHeight);
      expect(
        find.textContaining('Тэставая крыніца', findRichText: true),
        findsOneWidget,
      );
      expect(find.byKey(const Key('app-overflow-open')), findsOneWidget);
      expect(
        find.byKey(const Key('reader-chrome-overflow')),
        findsOneWidget,
        reason: 'one unified reader menu',
      );
      expect(find.byKey(const Key('song-chord-control')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ReaderContextHeader),
          matching: find.byKey(const Key('song-chord-control')),
        ),
        findsOneWidget,
        reason: 'chord control lives in the reader header, before the text',
      );
      expect(
        tester.getRect(find.byKey(const Key('song-chord-control'))).bottom,
        lessThan(tester.getTopLeft(find.text('Бог наш вялікі')).dy),
      );
      expect(
        find.text('C G'),
        findsNothing,
        reason: 'chords hidden by default',
      );
      expect(_iconButton(tester, 'song-transpose-up').onPressed, isNull);
      expect(_iconButton(tester, 'song-chord-layout-toggle').onPressed, isNull);

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

      expect(find.byKey(const Key('song-chord-control')), findsOneWidget);
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
      expect(_iconButton(tester, 'song-transpose-down').onPressed, isNull);

      await tester.tap(find.byKey(const Key('song-transpose-reset')));
      await tester.pump();
      for (var i = 0; i < 14; i++) {
        await tester.tap(find.byKey(const Key('song-transpose-up')));
        await tester.pump();
      }
      expect(find.text('+12'), findsOneWidget);
      expect(find.text('C G'), findsOneWidget, reason: '+12 is an octave');
      expect(_iconButton(tester, 'song-transpose-up').onPressed, isNull);

      router.go('/prayers/songs/s-kal');
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget, reason: 'new song resets');
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('song without chords shows no chord control', (tester) async {
      final router = _router(initialLocation: '/prayers/songs/s-ave');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _app(
          null,
          router: router,
          prefs: const SongPreferences(
            showChords: true,
            chordLayout: SongChordLayout.right,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Радасць нябёсаў'), findsOneWidget);
      expect(find.byKey(const Key('song-chord-control')), findsNothing);
      expect(find.byKey(const Key('song-transpose-up')), findsNothing);
      expect(find.byKey(const Key('song-chords-toggle')), findsNothing);
    });

    testWidgets('chord toggle shows and hides chords and persists choice', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs/s-bog');
      addTearDown(router.dispose);
      late ProviderContainer container;
      await tester.pumpWidget(
        _app(null, router: router, onContainer: (value) => container = value),
      );
      await tester.pumpAndSettle();
      expect(find.text('C G'), findsNothing);

      await tester.tap(find.byKey(const Key('song-chords-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('C G'), findsOneWidget);
      expect(container.read(songPreferencesProvider).showChords, isTrue);
      expect(_iconButton(tester, 'song-chords-toggle').isSelected, isTrue);
      expect(_iconButton(tester, 'song-transpose-up').onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('song-chords-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('C G'), findsNothing);
      expect(container.read(songPreferencesProvider).showChords, isFalse);
    });

    testWidgets('layout toggle switches between above and right', (
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
      expect(find.byKey(const Key('song-text-above')), findsOneWidget);
      final lyricAbove = tester.getRect(find.text('Бог наш вялікі'));
      final chordAbove = tester.getRect(find.text('C G'));
      expect(chordAbove.bottom, lessThanOrEqualTo(lyricAbove.top + 0.5));

      await tester.tap(find.byKey(const Key('song-chord-layout-toggle')));
      await tester.pumpAndSettle();
      expect(
        container.read(songPreferencesProvider).chordLayout,
        SongChordLayout.right,
      );
      expect(find.byKey(const Key('song-text-right')), findsOneWidget);
      final lyric = tester.getRect(find.text('Бог наш вялікі'));
      final chord = tester.getRect(find.text('C G'));
      expect(chord.left, greaterThan(lyric.left), reason: 'chords on right');
      expect(chord.top, lessThan(lyric.bottom), reason: 'same row');
      expect(chord.bottom, greaterThan(lyric.top), reason: 'same row');
      final surface = tester.getRect(
        find.byKey(const Key('reader-content-surface')),
      );
      expect(
        chord.width,
        lessThan(surface.width * SongText.rightLayoutMaxChordShare),
        reason: 'the chord column stays secondary',
      );

      await tester.tap(find.byKey(const Key('song-chord-layout-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('song-text-above')), findsOneWidget);
      expect(
        container.read(songPreferencesProvider).chordLayout,
        SongChordLayout.above,
      );
    });

    testWidgets('right falls back above on narrow width and keeps preference', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs/s-bog');
      addTearDown(router.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      late ProviderContainer container;
      const prefs = SongPreferences(
        showChords: true,
        chordLayout: SongChordLayout.right,
      );

      Future<void> pumpAt(double width, double scale) async {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: TextScaler.linear(scale),
            ),
            child: _app(
              null,
              router: router,
              prefs: prefs,
              onContainer: (value) => container = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$width @ $scale');
      }

      await pumpAt(800, 1);
      expect(find.byKey(const Key('song-text-right')), findsOneWidget);

      await pumpAt(360, 2);
      expect(find.byKey(const Key('song-text-above')), findsOneWidget);
      expect(find.text('C G'), findsOneWidget);
      expect(
        container.read(songPreferencesProvider).chordLayout,
        SongChordLayout.right,
        reason: 'runtime fallback does not change the preference',
      );
      // The control keeps showing the preference and quietly marks the
      // temporary fallback: a dot, the tooltip and the semantics value.
      expect(
        _iconButton(tester, 'song-chord-layout-toggle').tooltip,
        'Акорды справа: не хапае шырыні, паказаны над радкамі',
      );
      expect(_opacity(tester, 'song-chord-layout-fallback'), 1);
      expect(
        tester
            .getSemantics(find.byKey(const Key('song-chord-layout-semantics')))
            .value,
        'Справа ад тэксту. Цяпер над радкамі: не хапае шырыні',
      );
      final narrow = tester.getRect(
        find.byKey(const Key('song-chord-layout-toggle')),
      );

      await pumpAt(800, 1);
      expect(find.byKey(const Key('song-text-right')), findsOneWidget);
      expect(
        _iconButton(tester, 'song-chord-layout-toggle').tooltip,
        'Акорды справа ад тэксту',
      );
      expect(_opacity(tester, 'song-chord-layout-fallback'), 0);
      expect(
        tester
            .getSemantics(find.byKey(const Key('song-chord-layout-semantics')))
            .value,
        'Справа ад тэксту',
      );
      expect(
        tester.getSize(find.byKey(const Key('song-chord-layout-toggle'))),
        narrow.size,
        reason: 'the hint does not change the control',
      );
    });

    testWidgets('chord control semantics name the state and the actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final router = _router(initialLocation: '/prayers/songs/s-bog');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _app(
          null,
          router: router,
          prefs: const SongPreferences(showChords: true),
        ),
      );
      await tester.pumpAndSettle();

      final layout = find.byKey(const Key('song-chord-layout-semantics'));
      final value = find.byKey(const Key('song-transpose-semantics'));
      expect(tester.getSemantics(layout).label, 'Размяшчэнне акордаў');
      expect(tester.getSemantics(layout).value, 'Над радкамі');
      expect(
        tester.getSemantics(layout).hint,
        'Паставіць акорды справа, калі хапае шырыні',
      );
      expect(_opacity(tester, 'song-chord-layout-fallback'), 0);
      expect(
        _iconButton(tester, 'song-chords-toggle').tooltip,
        'Схаваць акорды',
      );
      expect(tester.getSemantics(value).label, 'Арыгінальная танальнасць');
      expect(tester.getSemantics(value).hint, isEmpty);
      expect(_opacity(tester, 'song-transpose-reset-hint'), 0);

      await tester.tap(find.byKey(const Key('song-chord-layout-toggle')));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(layout).value, 'Справа ад тэксту');
      expect(tester.getSemantics(layout).hint, 'Паставіць акорды над радкамі');

      await tester.tap(find.byKey(const Key('song-transpose-up')));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(value).label, 'Танальнасць +1 паўтон');
      expect(
        tester.getSemantics(value).hint,
        'Вярнуць арыгінальную танальнасць',
      );
      expect(
        _opacity(tester, 'song-transpose-reset-hint'),
        1,
        reason: 'a shifted value shows that it can be reset',
      );
      expect(
        find.byTooltip('Націсніце, каб вярнуць арыгінальную танальнасць'),
        findsOneWidget,
      );
      for (final tooltip in ['Панізіць на паўтон', 'Павысіць на паўтон']) {
        expect(find.byTooltip(tooltip), findsOneWidget);
      }

      // The reset is reachable through the semantics action as well.
      tester.semantics.tap(find.semantics.byLabel('Танальнасць +1 паўтон'));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);
      expect(_opacity(tester, 'song-transpose-reset-hint'), 0);
      handle.dispose();
    });

    testWidgets('chord control keeps 48 dp targets on a 320 dp phone', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      const size = Size(320, 640);
      tester.view.physicalSize = size;
      for (final scale in [1.0, 1.3, 2.0]) {
        final router = _router(initialLocation: '/prayers/songs/s-bog');
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: _app(
              null,
              router: router,
              prefs: const SongPreferences(showChords: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 12; i++) {
          await tester.tap(find.byKey(const Key('song-transpose-down')));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'scale $scale');
        expect(find.text('-12'), findsOneWidget);
        for (final key in [
          'song-chords-toggle',
          'song-chord-layout-toggle',
          'song-transpose-down',
          'song-transpose-up',
        ]) {
          final target = tester.getSize(find.byKey(Key(key)));
          expect(target.width, greaterThanOrEqualTo(48), reason: key);
          expect(target.height, greaterThanOrEqualTo(48), reason: key);
        }
        final value = tester.getRect(
          find.byKey(const Key('song-transpose-value-box')),
        );
        expect(value.height, greaterThanOrEqualTo(48));
        expect(value.width, greaterThanOrEqualTo(48));
        final label = tester.getRect(
          find.byKey(const Key('song-transpose-value')),
        );
        expect(label.left, greaterThanOrEqualTo(value.left));
        expect(label.right, lessThanOrEqualTo(value.right));
        final control = tester.getRect(
          find.byKey(const Key('song-chord-control')),
        );
        expect(control.left, greaterThanOrEqualTo(0));
        expect(control.right, lessThanOrEqualTo(size.width - 22 + 0.01));
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      }
    }, variant: _platforms);

    testWidgets('chord control scales down instead of overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: SongChordControl(
                  showChords: true,
                  layout: SongChordLayout.right,
                  layoutFallback: true,
                  transpose: -12,
                  onShowChordsChanged: (_) {},
                  onLayoutChanged: (_) {},
                  onTransposeChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(const Key('song-chord-control'))).width,
        lessThanOrEqualTo(200.01),
      );
    });

    testWidgets(
      'long lyrics wrap beside the chords in landscape and on tablets',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        const prefs = SongPreferences(
          showChords: true,
          chordLayout: SongChordLayout.right,
        );
        for (final size in const [Size(844, 390), Size(1024, 768)]) {
          final router = _router(initialLocation: '/prayers/songs/s-long');
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(size: size),
              child: _app(null, router: router, prefs: prefs, seed: _longSeed),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$size');
          expect(find.byKey(const Key('song-text-right')), findsOneWidget);

          final surface = tester.getRect(
            find.byKey(const Key('reader-content-surface')),
          );
          final lyric = tester.getRect(find.textContaining('Вельмі доўгі'));
          final short = tester.getRect(find.text('Кароткі радок'));
          final chord = tester.getRect(find.text('C G a F'));
          final second = tester.getRect(find.text('d G'));
          expect(
            lyric.height,
            greaterThan(short.height * 1.5),
            reason: 'the long line wraps instead of scrolling sideways',
          );
          expect(lyric.right, lessThan(chord.left), reason: 'no overlap');
          expect(chord.right, lessThanOrEqualTo(surface.right));
          expect(chord.left, second.left, reason: 'one chord column');
          expect(
            lyric.width,
            greaterThan(chord.width * 2),
            reason: 'lyrics stay primary',
          );
          expect(
            chord.top,
            lessThan(lyric.top + short.height),
            reason: 'chords sit on the first line of a wrapped lyric',
          );
          expect(second.top, greaterThan(lyric.bottom - 1));
          await tester.pumpWidget(const SizedBox());
          router.dispose();
        }
      },
      variant: _platforms,
    );

    testWidgets('long lyrics wrap without overflow on a 320 dp phone', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final layout in SongChordLayout.values) {
        const size = Size(320, 640);
        final router = _router(initialLocation: '/prayers/songs/s-long');
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: size),
            child: _app(
              null,
              router: router,
              prefs: SongPreferences(showChords: true, chordLayout: layout),
              seed: _longSeed,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$layout');
        final side = find
            .byKey(const Key('song-text-right'))
            .evaluate()
            .isNotEmpty;
        final lyric = tester.getRect(find.textContaining('Вельмі доўгі'));
        final chord = tester.getRect(find.text('C G a F'));
        expect(lyric.left, greaterThanOrEqualTo(22));
        expect(lyric.right, lessThanOrEqualTo(size.width - 22));
        expect(chord.right, lessThanOrEqualTo(size.width - 22));
        if (side) {
          expect(layout, SongChordLayout.right);
          expect(lyric.right, lessThan(chord.left));
          expect(
            lyric.width,
            greaterThanOrEqualTo(16 * SongText.rightLayoutMinLyricsEm),
            reason: 'the lyric column keeps its minimum',
          );
        } else {
          expect(chord.bottom, lessThanOrEqualTo(lyric.top + 0.5));
        }
        expect(
          _opacity(tester, 'song-chord-layout-fallback'),
          layout == SongChordLayout.right && !side ? 1 : 0,
          reason: 'a fallback is never silent',
        );
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      }
    });

    testWidgets(
      'right renders beside the lyrics on 360-430 dp phones in every key',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        for (final size in const [
          Size(360, 760),
          Size(393, 852),
          Size(430, 932),
        ]) {
          final router = _router(initialLocation: '/prayers/songs/s-typ');
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(size: size),
              child: _app(
                null,
                router: router,
                prefs: const SongPreferences(
                  showChords: true,
                  chordLayout: SongChordLayout.right,
                ),
                seed: _typicalSeed,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final lyricFinder = find.text('Аллелюя, Езус смерць перамог');
          Rect chordColumn() => tester.getRect(
            find
                .ancestor(
                  of: find.byWidgetPredicate(
                    (widget) =>
                        widget is Text &&
                        widget.maxLines == 1 &&
                        widget.softWrap == false &&
                        widget.key == null,
                  ),
                  matching: find.byType(SizedBox),
                )
                .first,
          );
          void expectRight(String reason) {
            expect(tester.takeException(), isNull, reason: reason);
            expect(
              find.byKey(const Key('song-text-right')),
              findsOneWidget,
              reason: reason,
            );
            expect(
              _opacity(tester, 'song-chord-layout-fallback'),
              0,
              reason: reason,
            );
          }

          expectRight('$size original key');
          final lyric = tester.getRect(lyricFinder);
          final column = chordColumn();
          final chord = tester.getRect(find.text('e a'));
          expect(chord.left, greaterThan(lyric.right - 0.5), reason: '$size');
          expect(chord.top, lessThan(lyric.bottom));
          expect(chord.bottom, greaterThan(lyric.top));
          expect(chord.right, lessThanOrEqualTo(size.width - 22));
          expect(
            lyric.width,
            greaterThanOrEqualTo(16 * SongText.rightLayoutMinLyricsEm),
          );

          Future<void> step(String key, int times) async {
            for (var i = 0; i < times; i++) {
              await tester.tap(find.byKey(Key(key)));
              await tester.pump();
              final value = tester
                  .widget<Text>(find.byKey(const Key('song-transpose-value')))
                  .data;
              expectRight('$size at $value');
              expect(
                chordColumn(),
                column,
                reason: 'chord column is stable at $value',
              );
              expect(
                tester.getRect(lyricFinder),
                lyric,
                reason: 'lyrics do not re-wrap at $value',
              );
            }
          }

          await step('song-transpose-down', 12);
          expect(find.text('-12'), findsOneWidget);
          await step('song-transpose-up', 24);
          expect(find.text('+12'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          router.dispose();
        }
      },
      variant: _platforms,
    );

    testWidgets('layout button uses distinct above and right glyphs', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs/s-bog');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _app(
          null,
          router: router,
          prefs: const SongPreferences(showChords: true),
        ),
      );
      await tester.pumpAndSettle();
      final above = find.byKey(const Key('song-chord-layout-glyph-above'));
      final right = find.byKey(const Key('song-chord-layout-glyph-right'));
      expect(above, findsOneWidget);
      expect(right, findsNothing);
      final size = tester.getSize(above);
      await tester.tap(find.byKey(const Key('song-chord-layout-toggle')));
      await tester.pumpAndSettle();
      expect(above, findsNothing);
      expect(tester.getSize(right), size);
    });

    testWidgets(
      'long chord lines never take the lyric column or overflow',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        late ProviderContainer container;
        for (final (size, scale) in const [
          (Size(320, 640), 1.0),
          (Size(390, 844), 2.0),
          (Size(844, 390), 1.0),
          (Size(1024, 768), 1.0),
        ]) {
          final router = _router(initialLocation: '/prayers/songs/s-chords');
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: _app(
                null,
                router: router,
                prefs: const SongPreferences(
                  showChords: true,
                  chordLayout: SongChordLayout.right,
                ),
                seed: _longSeed,
                onContainer: (value) => container = value,
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (var i = 0; i < 2; i++) {
            await tester.tap(find.byKey(const Key('song-transpose-up')));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull, reason: '$size @ $scale');
          expect(
            find.byKey(const Key('song-text-above')),
            findsOneWidget,
            reason: 'a chord line wider than 45% is shown above: $size',
          );
          expect(
            _opacity(tester, 'song-chord-layout-fallback'),
            1,
            reason: 'the fallback is signalled on the control',
          );
          expect(
            container.read(songPreferencesProvider).chordLayout,
            SongChordLayout.right,
          );
          final surface = tester.getRect(
            find.byKey(const Key('reader-content-surface')),
          );
          final chord = tester.getRect(find.textContaining('D A b G D A b G'));
          final lyric = tester.getRect(find.text('Першы радок спеву'));
          expect(chord.left, greaterThanOrEqualTo(surface.left));
          expect(chord.right, lessThanOrEqualTo(surface.right));
          expect(chord.bottom, lessThanOrEqualTo(lyric.top + 0.5));
          expect(lyric.right, lessThanOrEqualTo(surface.right));
          await tester.pumpWidget(const SizedBox());
          router.dispose();
        }
      },
      variant: _platforms,
    );

    test('right layout rule uses real constraints', () {
      const scaler = TextScaler.noScaling;
      SongChordLayout resolve(
        double width,
        double chords, {
        double font = 16,
      }) => SongText.resolveLayout(
        preferred: SongChordLayout.right,
        width: width,
        fontSize: font,
        textScaler: scaler,
        chordColumnWidth: chords,
      );
      expect(resolve(700, 60), SongChordLayout.right);
      expect(resolve(346, 60), SongChordLayout.right);
      expect(resolve(276, 60), SongChordLayout.right, reason: '12.5 em');
      expect(resolve(230, 60), SongChordLayout.above, reason: 'lyrics narrow');
      expect(resolve(700, 330), SongChordLayout.above, reason: 'long chords');
      expect(
        SongText.resolveLayout(
          preferred: SongChordLayout.right,
          width: 400,
          fontSize: 18,
          textScaler: const TextScaler.linear(2),
          chordColumnWidth: 60,
        ),
        SongChordLayout.above,
        reason: 'large text',
      );
      expect(
        SongText.resolveLayout(
          preferred: SongChordLayout.above,
          width: 2000,
          fontSize: 18,
          textScaler: scaler,
          chordColumnWidth: 10,
        ),
        SongChordLayout.above,
      );
    });

    testWidgets('chord control geometry is stable across states', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/songs/s-bog');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(null, router: router));
      await tester.pumpAndSettle();

      Map<String, Rect> geometry() => {
        for (final key in [
          'song-chord-control',
          'song-chords-toggle',
          'song-chord-layout-toggle',
          'song-transpose-down',
          'song-transpose-value-box',
          'song-transpose-up',
        ])
          key: tester.getRect(find.byKey(Key(key))),
      };
      final hidden = geometry();
      for (final rect in [
        hidden['song-chords-toggle']!,
        hidden['song-transpose-up']!,
        hidden['song-transpose-down']!,
      ]) {
        expect(rect.width, greaterThanOrEqualTo(48), reason: 'hit target');
        expect(rect.height, greaterThanOrEqualTo(48), reason: 'hit target');
      }

      Future<void> tapKey(String key, [int times = 1]) async {
        for (var i = 0; i < times; i++) {
          await tester.tap(find.byKey(Key(key)));
          await tester.pumpAndSettle();
        }
      }

      await tapKey('song-chords-toggle');
      expect(geometry(), hidden, reason: 'show chords');
      await tapKey('song-transpose-up', 12);
      expect(find.text('+12'), findsOneWidget);
      expect(geometry(), hidden, reason: '+12');
      await tapKey('song-transpose-reset');
      expect(find.text('0'), findsOneWidget);
      expect(geometry(), hidden, reason: 'reset');
      await tapKey('song-transpose-down', 12);
      expect(find.text('-12'), findsOneWidget);
      expect(geometry(), hidden, reason: '-12');
      await tapKey('song-chord-layout-toggle');
      expect(geometry(), hidden, reason: 'layout right');
      await tapKey('song-chords-toggle');
      expect(geometry(), hidden, reason: 'hide chords');
    }, variant: _platforms);

    testWidgets(
      'detail with chords does not overflow at 200 percent text',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        for (final layout in SongChordLayout.values) {
          for (final size in const [
            Size(320, 640),
            Size(390, 844),
            Size(844, 390),
          ]) {
            final router = _router(initialLocation: '/prayers/songs/s-bog');
            tester.view.physicalSize = size;
            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(2),
                ),
                child: _app(
                  null,
                  router: router,
                  prefs: SongPreferences(showChords: true, chordLayout: layout),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('song-transpose-down')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$layout $size');
            expect(find.text('-1'), findsOneWidget);
            final control = tester.getRect(
              find.byKey(const Key('song-chord-control')),
            );
            expect(control.right, lessThanOrEqualTo(size.width));
            expect(
              find.byKey(
                Key(
                  layout == SongChordLayout.right && size.width > 800
                      ? 'song-text-right'
                      : 'song-text-above',
                ),
              ),
              findsOneWidget,
              reason: 'landscape keeps right, portrait falls back: $size',
            );
            await tester.pumpWidget(const SizedBox());
            router.dispose();
          }
        }
      },
      variant: _platforms,
    );

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

    test('favorites, chords and layout survive restart', () {
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
        ..setChordLayout(SongChordLayout.right);
      first.dispose();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      final prefs = second.read(songPreferencesProvider);
      expect(prefs.favoriteSongIds, ['b']);
      expect(prefs.showChords, isTrue);
      expect(prefs.chordLayout, SongChordLayout.right);
      expect(HiveService.settingsBox.get('favoriteSongIds'), '["b"]');
      expect(HiveService.settingsBox.get('songChordLayout'), 'right');
      expect(HiveService.settingsBox.get('songShowChords'), isTrue);

      second.read(songPreferencesProvider.notifier)
        ..setChordLayout(SongChordLayout.above)
        ..setShowChords(false);
      final third = ProviderContainer();
      addTearDown(third.dispose);
      expect(
        third.read(songPreferencesProvider).chordLayout,
        SongChordLayout.above,
      );
      expect(third.read(songPreferencesProvider).showChords, isFalse);
    });

    test('song favorites are independent from prayer favorites', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(songPreferencesProvider.notifier).toggleFavorite('song');
      await container.read(settingsProvider.notifier).toggleFavorite('prayer');
      expect(container.read(settingsProvider).favoriteIds, ['prayer']);
      expect(container.read(songPreferencesProvider).favoriteSongIds, ['song']);
      await HiveService.settingsBox.flush();
      expect(HiveService.settingsBox.get('favoriteIds'), '["prayer"]');
      expect(HiveService.settingsBox.get('favoriteSongIds'), '["song"]');
    });

    test('stored left layout migrates to right', () async {
      await HiveService.settingsBox.put('songChordLayout', 'left');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(songPreferencesProvider).chordLayout,
        SongChordLayout.right,
      );
      expect(HiveService.settingsBox.get('songChordLayout'), 'right');
    });

    test('stored right and unknown layouts are read safely', () async {
      await HiveService.settingsBox.put('songChordLayout', 'right');
      final right = ProviderContainer();
      expect(
        right.read(songPreferencesProvider).chordLayout,
        SongChordLayout.right,
      );
      right.dispose();

      await HiveService.settingsBox.put('songChordLayout', 42);
      final unknown = ProviderContainer();
      addTearDown(unknown.dispose);
      expect(
        unknown.read(songPreferencesProvider).chordLayout,
        SongChordLayout.above,
      );
      expect(SongChordLayout.values, [
        SongChordLayout.above,
        SongChordLayout.right,
      ]);
    });

    test('migration is idempotent and writes nothing once applied', () async {
      final box = HiveService.settingsBox;
      await box.put('songChordLayout', 'left');
      await box.put('songCompactList', false);
      await box.put('favoriteSongIds', '["a"]');
      final writes = <Object?>[];
      final subscription = box.watch().listen((event) => writes.add(event.key));
      addTearDown(subscription.cancel);

      final first = ProviderContainer();
      expect(
        first.read(songPreferencesProvider).chordLayout,
        SongChordLayout.right,
      );
      first.dispose();
      await box.flush();
      await Future<void>.delayed(Duration.zero);
      expect(writes, unorderedEquals(['songChordLayout', 'songCompactList']));
      writes.clear();

      for (var i = 0; i < 2; i++) {
        final next = ProviderContainer();
        final prefs = next.read(songPreferencesProvider);
        expect(prefs.chordLayout, SongChordLayout.right);
        expect(prefs.favoriteSongIds, ['a'], reason: 'favorites are kept');
        next.dispose();
      }
      await box.flush();
      await Future<void>.delayed(Duration.zero);
      expect(writes, isEmpty, reason: 'nothing left to migrate');
      expect(box.get('songChordLayout'), 'right');
      expect(box.containsKey('songCompactList'), isFalse);
    });

    test('old compact list setting is ignored and removed', () async {
      await HiveService.settingsBox.put('songCompactList', true);
      await HiveService.settingsBox.put('songShowChords', true);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final prefs = container.read(songPreferencesProvider);
      expect(prefs.showChords, isTrue);
      expect(prefs.chordLayout, SongChordLayout.above);
      expect(HiveService.settingsBox.containsKey('songCompactList'), isFalse);
    });
  });
}

IconButton _iconButton(WidgetTester tester, String key) =>
    tester.widget<IconButton>(find.byKey(Key(key)));

double _opacity(WidgetTester tester, String key) =>
    tester.widget<AnimatedOpacity>(find.byKey(Key(key))).opacity;

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
          builder: (context, state) => const AdminSongbookGuard(child: SongbookScreen()),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  AdminSongbookGuard(child: SongDetailScreen(songId: state.pathParameters['id']!)),
            ),
          ],
        ),
        GoRoute(
          path: 'compendium',
          builder: (context, state) => const CompendiumScreen(),
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
  bool admin = true,
  List<Map<String, dynamic>> seed = _seed,
  void Function(ProviderContainer)? onContainer,
}) {
  return ProviderScope(
    overrides: [
      adminSongbookAccessProvider.overrideWith((ref) => Stream.value(admin)),
      settingsProvider.overrideWith(_TestSettingsNotifier.new),
      liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
      allPrayersProvider.overrideWithValue(prayers),
      prayersContentProvider.overrideWith((ref) async {}),
      localPrayersProvider.overrideWith(_TestLocalPrayersNotifier.new),
      prayerMenuCategoriesProvider.overrideWithValue(const []),
      globalPrayerCategoriesProvider.overrideWith(
        (ref) => Stream.value(const []),
      ),
      songSeedProvider.overrideWith(
        (ref) async => seedFails ? throw StateError('asset') : seed,
      ),
      songPreferencesProvider.overrideWith(() => _TestSongPrefs(prefs)),
      ...compendiumOverrides(_compendium),
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
  void setShowChords(bool value) => state = state.copyWith(showChords: value);

  @override
  void setChordLayout(SongChordLayout layout) =>
      state = state.copyWith(chordLayout: layout);
}
