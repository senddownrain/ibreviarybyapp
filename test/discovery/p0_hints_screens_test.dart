import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/discovery/discovery.dart';
import 'package:mybrev_flutter/discovery/p0_facts.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/discovery/ui/discovery_visit.dart';
import 'package:mybrev_flutter/discovery/ui/inline_hint_presenter.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart' as production;
import 'package:mybrev_flutter/services/hive_service.dart';

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

class _Minsk extends DioceseSelectionNotifier {
  @override
  DioceseSelection build() => const DioceseSelection(
    selected: ['minsk-mohilev'],
    primary: 'minsk-mohilev',
  );
}

const _variantsId = 'readings.day_variants';
const _yearId = 'readings.other_year';
const _dateId = 'calendar.date_navigation';
const _ordoId = 'ordo.calendar_variants';

Finder _card(String id) => find.byKey(Key('discovery-card-$id'));
Finder get _anyCard =>
    find.byWidgetPredicate((w) => w.key.toString().contains('discovery-card-'));

void main() {
  late Directory directory;
  late MemoryDiscoveryStorage storage;

  setUpAll(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('discovery-p0-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  setUp(() => storage = MemoryDiscoveryStorage());

  /// The production router and screens on the real bundled data, with the
  /// real presenter and an in-memory discovery profile.
  Future<ProviderContainer> start(
    WidgetTester tester, {
    required String location,
    required DateTime selected,
    MemoryDiscoveryStorage? profile,
    bool minskOnly = true,
    Duration settleDelay = const Duration(milliseconds: 100),
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        selectedDateProvider.overrideWith((ref) => selected),
        if (minskOnly) dioceseSelectionProvider.overrideWith(_Minsk.new),
        liturgicalContentReadyProvider.overrideWith((ref) async {}),
        contentUpdatesProvider.overrideWith(_Idle.new),
        settingsProvider.overrideWith(_Settings.new),
        ...discoveryAppOverrides(),
        discoveryStorageProvider.overrideWithValue(profile ?? storage),
        discoverySettleDelayProvider.overrideWithValue(settleDelay),
      ],
    );
    final router = GoRouter(
      initialLocation: location,
      navigatorKey: production.rootNavigatorKey,
      routes: production.router.configuration.routes,
    );
    addTearDown(router.dispose);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(platform: TargetPlatform.android),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Lets the settle delay pass and the card be laid out.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  group('Readings', () {
    testWidgets('CD-0 2026-11-09: no variants -> no hint', (tester) async {
      await start(
        tester,
        location: '/readings?date=2026-11-09',
        selected: DateTime(2026, 11, 9),
      );
      await settle(tester);
      expect(find.byKey(const Key('readings-alternatives-control')), findsOne);
      expect(_anyCard, findsNothing);
    });

    testWidgets('CD-A 2026-12-04: one day_variants hint; Паказаць opens the '
        'sheet, keeps it open, changes nothing', (tester) async {
      final container = await start(
        tester,
        location: '/readings?date=2026-12-04',
        selected: DateTime(2026, 12, 4),
      );
      await settle(tester);
      expect(_card(_variantsId), findsOneWidget);
      expect(_anyCard, findsOneWidget);
      expect(
        find.text('На гэтую дату ёсць іншыя варыянты літургічнага дня'),
        findsOneWidget,
      );
      final primary = container.read(dioceseSelectionProvider).primary;

      await tester.tap(find.byKey(const Key('discovery-hint-show')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('readings-options-sheet')), findsOneWidget);
      expect(_anyCard, findsNothing);
      // The sheet stays open until the person acts.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('readings-options-sheet')), findsOneWidget);
      expect(find.textContaining('Дамаскіна'), findsWidgets);

      // Close with Back: date and diocese are untouched.
      await tester.tap(find.byKey(const Key('readings-options-done')));
      await tester.pumpAndSettle();
      expect(container.read(selectedDateProvider), DateTime(2026, 12, 4));
      expect(container.read(dioceseSelectionProvider).primary, primary);

      final coordinator = await container.read(
        discoveryCoordinatorProvider.future,
      );
      expect(
        coordinator.repository.state.record(_variantsId).completed,
        isTrue,
      );
      expect(coordinator.repository.state.record(_variantsId).seenCount, 1);
    });

    testWidgets('CD-C 2026-11-08: other_year says «паглядзець», is not a '
        'replacement', (tester) async {
      await start(
        tester,
        location: '/readings?date=2026-11-08',
        selected: DateTime(2026, 11, 8),
      );
      await settle(tester);
      expect(_card(_yearId), findsOneWidget);
      expect(_card(_variantsId), findsNothing);
      expect(find.textContaining('паглядзець'), findsOneWidget);
      await tester.tap(find.byKey(const Key('discovery-hint-show')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('readings-cycle-B')), findsOneWidget);
      // Viewing another year is labelled as a preview in the sheet itself.
      await tester.tap(find.byKey(const Key('readings-cycle-B')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Прагляд іншага года'), findsOneWidget);
    });

    testWidgets('CD-B1 2026-12-03: allowed_alternatives stays DEFERRED', (
      tester,
    ) async {
      await start(
        tester,
        location: '/readings?date=2026-12-03',
        selected: DateTime(2026, 12, 3),
      );
      await settle(tester);
      expect(_anyCard, findsNothing);
    });

    testWidgets('«Не паказваць» survives a restart; «Пазней» does not '
        'dismiss for good', (tester) async {
      await start(
        tester,
        location: '/readings?date=2026-12-04',
        selected: DateTime(2026, 12, 4),
      );
      await settle(tester);
      expect(find.byKey(const Key('discovery-hint-later')), findsOneWidget);
      await tester.tap(find.byKey(const Key('discovery-hint-never')));
      await tester.pumpAndSettle();
      expect(_anyCard, findsNothing);
      // The button only hides the card; the control itself still works.
      expect(find.byKey(const Key('readings-alternatives-control')), findsOne);

      // "Restart": a new container over the same stored profile.
      final persisted = MemoryDiscoveryStorage()..value = storage.value;
      await tester.pumpWidget(const SizedBox());
      await start(
        tester,
        location: '/readings?date=2026-12-04',
        selected: DateTime(2026, 12, 4),
        profile: persisted,
      );
      await settle(tester);
      expect(_anyCard, findsNothing);
    });

    testWidgets('scrolling the text shows no hint and hides nothing else', (
      tester,
    ) async {
      await start(
        tester,
        location: '/readings?date=2026-12-04',
        selected: DateTime(2026, 12, 4),
        settleDelay: const Duration(seconds: 2),
      );
      final scrollable = find.byType(CustomScrollView).first;
      // Keep scrolling through the whole settle delay.
      for (var i = 0; i < 5; i++) {
        await tester.drag(scrollable, const Offset(0, -120));
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(_anyCard, findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      // Scrolled away from the top: the anchor is not reachable.
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        greaterThan(24),
      );
      expect(_anyCard, findsNothing);
    });

    testWidgets('date_navigation: three day arrows, once', (tester) async {
      // 11-10..11-12 are ordinary weekdays (cycles I/II): the person has
      // already met «other year», so only the date hint is left to show.
      final learned = MemoryDiscoveryStorage()
        ..value = DiscoveryState.empty.completedHint(_yearId).encode();
      await start(
        tester,
        location: '/readings?date=2026-11-09',
        selected: DateTime(2026, 11, 9),
        profile: learned,
      );
      await settle(tester);
      expect(_anyCard, findsNothing);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('readings-next-day')));
        await tester.pumpAndSettle();
      }
      await settle(tester);
      expect(_card(_dateId), findsOneWidget);
      expect(_card('readings.other_date'), findsNothing);
    });

    testWidgets('hints off globally: nothing, but the controls work', (
      tester,
    ) async {
      final off = MemoryDiscoveryStorage()
        ..value = '{"schema":1,"hintsEnabled":false}';
      await start(
        tester,
        location: '/readings?date=2026-12-04',
        selected: DateTime(2026, 12, 4),
        profile: off,
      );
      await settle(tester);
      expect(_anyCard, findsNothing);
      await tester.tap(find.byKey(const Key('readings-alternatives-control')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('readings-options-sheet')), findsOneWidget);
    });
  });

  group('calendar sheet', () {
    testWidgets('more_periods only from the third opening, inside the sheet, '
        'with no action of its own', (tester) async {
      await start(
        tester,
        location: '/readings?date=2026-11-09',
        selected: DateTime(2026, 11, 9),
      );
      await settle(tester);
      for (var open = 1; open <= 3; open++) {
        await tester.tap(find.byKey(const Key('readings-date-action')));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        final card = _card('calendar.more_periods');
        if (open < 3) {
          expect(card, findsNothing, reason: 'opening $open');
        } else {
          expect(card, findsOneWidget);
          expect(find.byKey(const Key('discovery-hint-show')), findsNothing);
          expect(find.byKey(const Key('discovery-hint-ack')), findsOneWidget);
          expect(find.byKey(const Key('discovery-hint-later')), findsNothing);
          expect(
            find.text('Можна шукаць па літургічных перыядах і святкаваннях'),
            findsOneWidget,
          );
        }
        await tester.tap(find.byKey(const Key('readings-options-done')));
        await tester.pumpAndSettle();
      }
    });
  });

  group('Ordo', () {
    testWidgets('CD-A 2026-12-04: dioceses differ -> hint, Паказаць only opens '
        'the diocese sheet', (tester) async {
      final container = await start(
        tester,
        location: '/hours/ordo?date=2026-12-04',
        selected: DateTime(2026, 12, 4),
      );
      await settle(tester);
      expect(_card(_ordoId), findsOneWidget);
      await tester.tap(find.byKey(const Key('discovery-hint-show')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ordo-diocese-grodno')), findsOneWidget);
      expect(container.read(dioceseSelectionProvider).primary, 'minsk-mohilev');
      expect(container.read(dioceseSelectionProvider).selected, [
        'minsk-mohilev',
      ]);
    });

    testWidgets('CD-0 2026-11-09: dioceses agree -> no hint', (tester) async {
      await start(
        tester,
        location: '/hours/ordo?date=2026-11-09',
        selected: DateTime(2026, 11, 9),
      );
      await settle(tester);
      expect(_anyCard, findsNothing);
    });
  });

  group('P0 rules', () {
    test('diocese difference comes from the Ordo resolver (Stage 1 dates)', () {
      expect(
        dioceseOptionsDiffer(DateTime(2026, 12, 4), OrdoRuntime.engine),
        isTrue,
      );
      expect(
        dioceseOptionsDiffer(DateTime(2026, 11, 9), OrdoRuntime.engine),
        isFalse,
      );
    });

    test(
      'copy: Belarusian text from the Stage 1 table, no forbidden words',
      () {
        final catalog = HintCatalog.standard();
        final p0 = catalog.all.where((h) => h.priority == HintPriority.p0);
        expect(p0.map((h) => h.id), [
          'readings.day_variants',
          'readings.allowed_alternatives',
          'readings.other_year',
          'ordo.calendar_variants',
          'calendar.date_navigation',
          'calendar.more_periods',
        ]);
        const forbidden = [
          'замяніць',
          'разрэшана',
          'іншыя Імшы',
          'пошук па ўсім',
        ];
        for (final hint in p0) {
          for (final word in forbidden) {
            expect(hint.copyBe, isNot(contains(word)), reason: hint.id);
          }
        }
        expect(
          catalog.byId(_yearId)!.copyBe,
          'Тут можна паглядзець чытанні іншых літургічных гадоў',
        );
        expect(catalog.byId('calendar.more_periods')!.actionLabelBe, isNull);
      },
    );

    test('allowed_alternatives is DEFERRED and other_date is not P0', () {
      final catalog = HintCatalog.standard();
      expect(
        catalog.byId('readings.allowed_alternatives')!.status,
        HintStatus.deferred,
      );
      expect(catalog.byId('readings.other_date')!.priority, HintPriority.p1);
    });
  });

  test('InlineHintPresenter refuses a hint without a mounted slot', () async {
    final presenter = InlineHintPresenter();
    final hint = HintCatalog.standard().byId(_variantsId)!;
    expect(await presenter.present(hint), isFalse);
    expect(presenter.shown, isNull);
  });
}
