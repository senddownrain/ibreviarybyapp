import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';
import 'package:mybrev_flutter/discovery/hints/p1_hints.dart';
import 'package:mybrev_flutter/discovery/hints/p2_hints.dart';
import 'package:mybrev_flutter/discovery/p2_navigation.dart';
import 'package:mybrev_flutter/discovery/ui/coachmark.dart';
import 'package:mybrev_flutter/discovery/ui/p1_hint_hosts.dart';
import 'package:mybrev_flutter/discovery/ui/p2_hint_hosts.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/models/song.dart';
import 'package:mybrev_flutter/router/discovery_navigation.dart';
import 'package:mybrev_flutter/providers/bible_data_provider.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/songs_provider.dart';

import 'support.dart';
import '../support/compendium_fixture.dart';

const _hint = Key('discovery-hint');

DiscoveryContext _prayersRoot({
  Map<String, Object?> facts = const {},
  Set<String> anchors = const {
    'discover.songbook.link',
    'discover.compendium.link',
    'discover.bible.tab',
  },
  DiscoveryUiState ui = DiscoveryUiState.calm,
  int visit = 1,
}) => DiscoveryContext(
  screenId: 'prayers',
  visitId: visit,
  status: DiscoveryDataStatus.ready,
  anchors: anchors,
  ui: ui,
  facts: {
    kFactNavSwitches: 3,
    kFactSongbookLoaded: true,
    kFactSongbookVisits: 0,
    kFactCompendiumAvailable: true,
    kFactCompendiumVisits: 0,
    kFactBibleAvailable: true,
    kFactBibleVisits: 0,
    ...facts,
  },
);

String _decide(DiscoveryContext context, {DiscoveryState? state}) =>
    const HintPolicy()
        .decide(
          catalog: p2Hints,
          context: context,
          state: state ?? DiscoveryState.empty,
          now: t0,
        )
        .label;

void main() {
  group('catalog', () {
    test('four P2 IDs, active, with the audited copy', () {
      expect(p2Hints.map((h) => h.id), [
        'discover.prayers',
        'discover.songbook',
        'discover.catechism',
        'discover.bible',
      ]);
      expect(p2Hints.every((h) => h.priority == HintPriority.p2), isTrue);
      expect(p2Hints.every((h) => h.status == HintStatus.active), isTrue);
      final catechism = p2Hints.firstWhere((h) => h.id == 'discover.catechism');
      expect(catechism.copyBe, contains('Кампендыі Катэхізіса'));
      final prayers = p2Hints.firstWhere((h) => h.id == 'discover.prayers');
      expect(prayers.copyBe, contains('«Малітоўнік»'));
    });

    test('no copy advertises priest-only or unfinished content', () {
      for (final hint in p2Hints) {
        expect(hint.copyBe.toLowerCase(), isNot(contains('свяшч')));
        expect(hint.copyBe, isNot(contains('Сакрамэнты')));
        expect(hint.copyBe, isNot(contains('Хутка')));
      }
    });

    test('IDs stay unique next to P0/P1 in the standard catalog', () {
      expect(HintCatalog.standard().byId('discover.bible'), isNotNull);
      expect(p1Hints.map((h) => h.id), isNot(contains('discover.bible')));
    });
  });

  group('eligibility', () {
    test('songbook wins first when everything is ready', () {
      expect(_decide(_prayersRoot()), 'discover.songbook');
    });

    test('no loaded songs: the songbook hint is skipped, not broken', () {
      expect(
        _decide(_prayersRoot(facts: {kFactSongbookLoaded: false})),
        'discover.catechism',
      );
    });

    test('missing data everywhere is a soft no-op', () {
      expect(
        _decide(
          _prayersRoot(
            facts: {
              kFactSongbookLoaded: false,
              kFactCompendiumAvailable: false,
              kFactBibleAvailable: false,
            },
          ),
        ),
        'none',
      );
      expect(
        _decide(DiscoveryContext.loading(screenId: 'prayers', visitId: 1)),
        'none',
      );
      expect(
        _decide(DiscoveryContext.error(screenId: 'prayers', visitId: 1)),
        'none',
      );
    });

    test('a missing fact (unknown source) stays silent', () {
      final context = DiscoveryContext(
        screenId: 'prayers',
        visitId: 1,
        status: DiscoveryDataStatus.ready,
        anchors: const {'discover.songbook.link'},
        facts: const {kFactSongbookLoaded: true, kFactNavSwitches: 3},
      );
      expect(_decide(context), 'none');
    });

    test('anchor not fully visible: no hint', () {
      expect(_decide(_prayersRoot(anchors: const {})), 'none');
      expect(
        _decide(_prayersRoot(anchors: const {'discover.bible.tab'})),
        'discover.bible',
      );
    });

    test('a known section is never offered', () {
      expect(
        _decide(
          _prayersRoot(
            facts: {
              kFactSongbookVisits: 1,
              kFactCompendiumVisits: 2,
              kFactBibleVisits: 1,
            },
          ),
        ),
        'none',
      );
    });

    test('too little navigation (fresh after onboarding): silent', () {
      expect(_decide(_prayersRoot(facts: {kFactNavSwitches: 0})), 'none');
      expect(_decide(_prayersRoot(facts: {kFactNavSwitches: 1})), 'none');
      expect(
        _decide(_prayersRoot(facts: {kFactNavSwitches: 2})),
        isNot('none'),
      );
    });

    test('never over scrolling, reading, a sheet or the keyboard', () {
      for (final ui in const [
        DiscoveryUiState(scrolling: true),
        DiscoveryUiState(activeReading: true),
        DiscoveryUiState(modalOpen: true),
        DiscoveryUiState(keyboardVisible: true),
        DiscoveryUiState(transitioning: true),
      ]) {
        expect(_decide(_prayersRoot(ui: ui)), 'none');
      }
    });

    test('prayers tab hint only on the Liturgy list', () {
      final liturgy = DiscoveryContext(
        screenId: 'hours_root',
        visitId: 1,
        status: DiscoveryDataStatus.ready,
        anchors: const {'discover.prayers.tab'},
        facts: const {
          kFactNavSwitches: 2,
          kFactPrayersAvailable: true,
          kFactPrayersVisits: 0,
        },
      );
      expect(_decide(liturgy), 'discover.prayers');
      expect(_decide(_prayersRoot(anchors: {'discover.prayers.tab'})), 'none');
    });
  });

  group('quota and persistence', () {
    test('only one P2 hint per visit and a 24 h gap between two', () {
      final policy = const HintPolicy();
      var state = DiscoveryState.empty.shown(
        'discover.songbook',
        version: 1,
        now: t0,
        automatic: true,
      );
      final later = t0.add(const Duration(hours: 2));
      final decision = policy.decide(
        catalog: p2Hints,
        context: _prayersRoot(),
        state: state,
        now: later,
        sessionIndex: 2,
      );
      expect(decision.label, 'none');
      expect(
        decision.reasons['discover.catechism'],
        SuppressionReason.cooldown,
      );
      final nextDay = policy.decide(
        catalog: p2Hints,
        context: _prayersRoot(),
        state: state,
        now: t0.add(const Duration(hours: 25)),
        sessionIndex: 2,
      );
      // An ignored hint may come back once, never a third time.
      expect(nextDay.label, 'discover.songbook');
      state = state.shown(
        'discover.songbook',
        version: 1,
        now: t0.add(const Duration(hours: 25)),
        automatic: true,
      );
      final third = policy.decide(
        catalog: p2Hints,
        context: _prayersRoot(),
        state: state,
        now: t0.add(const Duration(days: 3)),
        sessionIndex: 2,
      );
      expect(third.reasons['discover.songbook'], SuppressionReason.maxShows);
      expect(third.label, 'discover.catechism');
    });

    test('«Не паказваць» survives a restart; the visit counter too', () {
      var state = DiscoveryState.empty
          .dismissedHint('discover.songbook')
          .visited(kVisitBible)
          .visited(kVisitBible);
      state = DiscoveryState.decode(state.encode());
      expect(state.record('discover.songbook').dismissed, isTrue);
      expect(state.visitCount(kVisitBible), 2);
      expect(_decide(_prayersRoot(), state: state), 'discover.catechism');
    });

    test('broken visit counters decode to zero without a crash', () {
      final state = DiscoveryState.decode(
        '{"schema":1,"visits":{"a":"x","b":-3,"c":2,"d":null},"records":{}}',
      );
      expect(state.visitCount('a'), 0);
      expect(state.visitCount('b'), 0);
      expect(state.visitCount('c'), 2);
      expect(DiscoveryState.decode('{"schema":1,"visits":5}').visits, isEmpty);
    });

    test('an old payload without visits still loads', () {
      final state = DiscoveryState.decode(
        '{"schema":1,"hintsEnabled":false,"records":{}}',
      );
      expect(state.hintsEnabled, isFalse);
      expect(state.visits, isEmpty);
    });

    test('test-profile reset clears the counters with the history', () {
      final state = DiscoveryState.empty.visited(kVisitSongs).historyReset();
      expect(state.visitCount(kVisitSongs), 0);
    });

    test('P1 beats P2 for the same visit', () {
      final p1 = HintDefinition(
        id: 'app.search',
        version: 1,
        priority: HintPriority.p1,
        screenId: 'prayers',
        anchorId: 'app.search.button',
        copyBe: 'x',
        requirements: [FactRequirement.isTrue(kFactSearchReady)],
      );
      final decision = const HintPolicy().decide(
        catalog: [...p2Hints, p1],
        context: _prayersRoot(
          anchors: const {'app.search.button', 'discover.songbook.link'},
          facts: {kFactSearchReady: true},
        ),
        state: DiscoveryState.empty,
        now: t0,
      );
      expect(decision.label, 'app.search');
      expect(
        decision.reasons['discover.songbook'],
        SuppressionReason.lowerPriority,
      );
    });
  });

  group('routing', () {
    test('the app installs the real route opener', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('discoveryRouteOpenerProvider'));
      expect(main, contains('openDiscoveryRoute'));
    });

    test('routes are the audited ones', () {
      expect(kSongbookRoute, '/prayers/songs');
      expect(kCompendiumRoute, '/prayers/compendium');
      expect(kBibleRoute, '/bible');
      expect(kPrayersRoute, '/prayers');
    });
  });

  group('prayers screen host', () {
    Widget app(
      MemoryDiscoveryStorage storage, {
      int switches = 3,
      AsyncValue<List<Song>> songs = const AsyncData([
        Song(id: 's1', title: 'Песня'),
      ]),
      bool compendium = true,
      bool bible = true,
      List<Prayer> prayers = const [Prayer(id: 'p1', title: 'Ойча наш')],
    }) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => PrayersHintHost(
              child: Scaffold(
                body: ListView(
                  children: [
                    const ListTile(title: Text('Малітоўнік')),
                    ListTile(
                      key: const Key('songbook-destination'),
                      title: const Text('Спеўнік'),
                      onTap: () => context.push('/prayers/songs'),
                    ),
                    ListTile(
                      key: const Key('catechism-destination'),
                      title: const Text('Катэхізіс'),
                      onTap: () => context.push('/prayers/compendium'),
                    ),
                  ],
                ),
                bottomNavigationBar: const SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          key: Key('app-destination-Біблія'),
                          child: Text('Біблія'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/prayers/songs',
            builder: (_, _) => const Scaffold(body: Text('SONGS SCREEN')),
          ),
          GoRoute(
            path: '/prayers/compendium',
            builder: (_, _) => const Scaffold(body: Text('COMPENDIUM SCREEN')),
          ),
          GoRoute(
            path: '/bible',
            builder: (_, _) => const Scaffold(body: Text('BIBLE SCREEN')),
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          discoveryStorageProvider.overrideWithValue(storage),
          discoveryRouteOpenerProvider.overrideWithValue(openDiscoveryRoute),
          hintPresenterProvider.overrideWith(
            (ref) => ref.watch(coachmarkPresenterProvider),
          ),
          navigationSwitchCountProvider.overrideWith(
            () => _FixedSwitches(switches),
          ),
          prayerCatalogProvider.overrideWithValue(prayers),
          songsProvider.overrideWithValue(songs),
          compendiumDatasetProvider.overrideWith(
            (ref) async => readBundledCompendium(),
          ),
          bibleDataProvider.overrideWith(
            (ref) async => bible ? null : throw StateError('no bible'),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    Future<void> wait(WidgetTester tester, [int seconds = 5]) async {
      for (var i = 0; i < seconds * 2; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    testWidgets('songbook hint → «Паказаць» opens the list → Back', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      await tester.pumpWidget(app(storage));
      await wait(tester);
      expect(find.byKey(_hint), findsOneWidget);
      expect(find.text('Шукаеце спеў? Зазірніце ў «Спеўнік»'), findsOneWidget);
      // One suggestion, not a carousel.
      expect(find.byKey(const Key('discovery-hint-card')), findsOneWidget);
      await tester.tap(find.byKey(const Key('discovery-hint-show')));
      await tester.pumpAndSettle();
      expect(find.text('SONGS SCREEN'), findsOneWidget);
      expect(find.byKey(_hint), findsNothing);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('SONGS SCREEN'), findsNothing);
      expect(find.text('Спеўнік'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a second P2 hint waits for the 24 h gap', (tester) async {
      final storage = MemoryDiscoveryStorage();
      await tester.pumpWidget(app(storage));
      await wait(tester);
      await tester.tap(find.byKey(const Key('discovery-hint-never')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        app(
          storage,
          songs: const AsyncData([Song(id: 's1', title: 'Песня')]),
        ),
      );
      // The 24 h gap blocks a second hint in the same minute.
      await wait(tester, 6);
      expect(find.byKey(_hint), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('hidden hint does not return after a restart', (tester) async {
      final storage = MemoryDiscoveryStorage();
      await tester.pumpWidget(app(storage));
      await wait(tester);
      await tester.tap(find.byKey(const Key('discovery-hint-never')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      final state = DiscoveryState.decode(storage.value);
      expect(state.record('discover.songbook').dismissed, isTrue);
      await tester.pumpWidget(app(storage));
      await wait(tester, 6);
      expect(find.text('Шукаеце спеў? Зазірніце ў «Спеўнік»'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no songs: no songbook hint, no dead button', (tester) async {
      await tester.pumpWidget(
        app(
          MemoryDiscoveryStorage(),
          songs: const AsyncData(<Song>[]),
          compendium: false,
        ),
      );
      await wait(tester);
      expect(find.text('Шукаеце спеў? Зазірніце ў «Спеўнік»'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('songs still loading or failed: silent', (tester) async {
      for (final songs in <AsyncValue<List<Song>>>[
        const AsyncLoading(),
        AsyncError(StateError('offline'), StackTrace.empty),
      ]) {
        await tester.pumpWidget(app(MemoryDiscoveryStorage(), songs: songs));
        await wait(tester);
        expect(find.text('Шукаеце спеў? Зазірніце ў «Спеўнік»'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('little navigation so far: nothing appears', (tester) async {
      await tester.pumpWidget(app(MemoryDiscoveryStorage(), switches: 1));
      await wait(tester, 6);
      expect(find.byKey(_hint), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('known section: songbook already visited, Compendium next', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage()
        ..value = DiscoveryState.empty.visited(kVisitSongs).encode();
      await tester.pumpWidget(app(storage));
      await wait(tester);
      expect(
        find.text('Адказы на пытанні веры можна шукаць у Кампендыі Катэхізіса'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('discovery-hint-show')));
      await tester.pumpAndSettle();
      expect(find.text('COMPENDIUM SCREEN'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Bible hint switches to the Bible', (tester) async {
      final storage = MemoryDiscoveryStorage()
        ..value = DiscoveryState.empty
            .visited(kVisitSongs)
            .visited(kVisitCompendium)
            .encode();
      await tester.pumpWidget(app(storage));
      await wait(tester);
      expect(
        find.text('Поўныя кнігі Святога Пісання — у раздзеле «Біблія»'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('discovery-hint-show')));
      await tester.pumpAndSettle();
      expect(find.text('BIBLE SCREEN'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('empty prayer catalog does not break the screen', (
      tester,
    ) async {
      await tester.pumpWidget(app(MemoryDiscoveryStorage(), prayers: const []));
      await wait(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('visit counters', () {
    testWidgets('opening a destination counts once and survives restart', (
      tester,
    ) async {
      final storage = MemoryDiscoveryStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [discoveryStorageProvider.overrideWithValue(storage)],
          child: const MaterialApp(
            home: DiscoveryVisitMark(visitKey: kVisitSongs, child: Text('x')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(DiscoveryState.decode(storage.value).visitCount(kVisitSongs), 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('without the hint box nothing is counted and nothing throws', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DiscoveryVisitMark(visitKey: kVisitSongs, child: Text('x')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    test('only the Prayer book and Bible branches are counted', () {
      expect(branchVisitKey(AppBranch.prayerbook), kVisitPrayerbook);
      expect(branchVisitKey(AppBranch.bible), kVisitBible);
      expect(branchVisitKey(AppBranch.hours), isNull);
      expect(branchVisitKey(AppBranch.readings), isNull);
    });
  });

  group('Liturgy list host', () {
    testWidgets('«Малітоўнік» tab hint opens the Prayer book', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => LiturgyRootHintHost(
              child: Scaffold(
                body: const Text('ORDO'),
                bottomNavigationBar: const SizedBox(
                  height: 60,
                  child: Center(
                    key: Key('app-destination-Малітоўнік'),
                    child: Text('Малітоўнік'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/prayers',
            builder: (_, _) => const Scaffold(body: Text('PRAYERBOOK')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryStorageProvider.overrideWithValue(
              MemoryDiscoveryStorage(),
            ),
            discoveryRouteOpenerProvider.overrideWithValue(openDiscoveryRoute),
            hintPresenterProvider.overrideWith(
              (ref) => ref.watch(coachmarkPresenterProvider),
            ),
            navigationSwitchCountProvider.overrideWith(() => _FixedSwitches(2)),
            prayerCatalogProvider.overrideWithValue(const [
              Prayer(id: 'p1', title: 'Ойча наш'),
            ]),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(
        find.text(
          'У раздзеле «Малітоўнік» ёсць малітвы і набажэнствы на розныя патрэбы',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('discovery-hint-show')));
      await tester.pumpAndSettle();
      expect(find.text('PRAYERBOOK'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

class _FixedSwitches extends NavigationSwitchCount {
  _FixedSwitches(this.value);

  final int value;

  @override
  int build() => value;
}
