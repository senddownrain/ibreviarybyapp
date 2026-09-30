// Data loading: computed calendar, cache-first reads, request dedupe,
// load states and the loading UI language.
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/models/load_state.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/models/sync_plan.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/providers/cache_policy_provider.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/data_activity_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/sync_provider.dart';
import 'package:mybrev_flutter/services/cache_warmup_service.dart';
import 'package:mybrev_flutter/services/data_log.dart';
import 'package:mybrev_flutter/services/days_index.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/services/liturgical_day_service.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';
import 'package:mybrev_flutter/utils/readings_index.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/widgets/data_loading_notice.dart';
import 'package:mybrev_flutter/widgets/data_settings_section.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';

// Firestore is never reached in these tests.
// ignore_for_file: subtype_of_sealed_class

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('data-loading-');
    await HiveService.init(path: directory.path);
    // Size totals are memoized on first use; do it outside widget tests so
    // no disk write is left pending in a fake-async zone.
    for (final target in SyncTarget.values) {
      HiveService.cachedBytes(target.collection);
    }
    await Hive.box('meta').flush();
    CacheWarmupService.startedLoads = 0;
  });
  tearDown(() async {
    DataLog.sink = null;
    await Hive.close();
    await directory.delete(recursive: true);
  });

  final date = DateTime(2026, 9, 28); // Monday, XXVI week of Ordinary Time
  final calendar = CalendarService();
  Future<void> seedDay() async {
    await HiveService.daysBox.putAll({
      'ordinary-w26-d2': {
        'id': 'ordinary-w26-d2',
        '_periodType': 'ordinary',
        '_periodWeekNumber': '26',
        '_dayOfWeek': '2',
        'laudesHymn': 'day hymn',
        'sext1Hymn': 'day sext',
      },
      '28-09-sv-wenceslaus': {
        'id': '28-09-sv-wenceslaus',
        '_date': '28.09',
        '_rank': 'memoria-ad-libitum',
        '_feastName': 'Св. Вацлава, мучаніка',
        'laudesPr': 'own prayer',
      },
      'feast-ascension-doc': {
        'id': 'feast-ascension-doc',
        '_feast': 'feast-ascension',
        '_feastName': 'Унебаўшэсце Пана',
      },
    });
  }

  group('days index', () {
    test('answers date, feast and period lookups without scanning', () async {
      await seedDay();
      expect(DaysIndex.idsByDate(['28.09']), ['28-09-sv-wenceslaus']);
      expect(DaysIndex.idsByFeast(['feast-ascension']), [
        'feast-ascension-doc',
      ]);
      expect(DaysIndex.idByPeriod('ordinary', 26, 2), 'ordinary-w26-d2');
      expect(DaysIndex.idsByDate(['01.01']), isEmpty);
      // Repeated lookups reuse the index.
      final rebuilds = DaysIndex.rebuilds;
      DaysIndex.idsByDate(['28.09']);
      DaysIndex.idByPeriod('ordinary', 26, 2);
      expect(DaysIndex.rebuilds, rebuilds);
    });

    test('a write to the box is visible to the next lookup', () async {
      await seedDay();
      expect(DaysIndex.idsByDate(['29.09']), isEmpty);
      await HiveService.putCached('days', '29-09-archangels', {
        'id': '29-09-archangels',
        '_date': '29.09',
      });
      expect(DaysIndex.idsByDate(['29.09']), ['29-09-archangels']);
      await HiveService.daysBox.delete('29-09-archangels');
      expect(DaysIndex.idsByDate(['29.09']), isEmpty);
    });

    test('day options come from the indexed documents', () async {
      await seedDay();
      final options = LiturgicalContentService().getContentForDate(
        date,
        calendar.getYearOptionsCached(2026),
        calendar.getYearOptionsCached(2027),
        calendar.getDynamicDatesCached(2026),
      );
      expect(options.map((option) => option.dayId), [
        'ordinary-w26-d2',
        '28-09-sv-wenceslaus',
      ]);
    });
  });

  group('cache first', () {
    test(
      'a cached day is resolved synchronously, like the async path',
      () async {
        await seedDay();
        final content = LiturgicalContentService();
        LiturgicalDay? local(String id) => content.resolveDayLocal(
          date,
          id,
          calendar.getYearOptionsCached(2026),
          calendar.getYearOptionsCached(2027),
          calendar.getDynamicDatesCached(2026),
        );
        // Not marked ready: the caller must use the network path.
        expect(local('28-09-sv-wenceslaus'), isNull);
        await HiveService.markDateCached('days', date);
        final day = local('28-09-sv-wenceslaus')!;
        expect(day.data['laudesPr'], 'own prayer');
        expect(
          day.data['laudesHymn'],
          'day hymn',
          reason: 'filled from the day',
        );
        expect(day.data['_calendarDate'], '2026-09-28');

        final context = computeLiturgicalContext(
          date,
          calendar.getYearOptionsCached(2026),
          calendar.getYearOptionsCached(2027),
          calendar.getDynamicDatesCached(2026),
        );
        final remote = await LiturgicalDayService(
          db: _NoFirestore(),
        ).resolveDayForDate(date, '28-09-sv-wenceslaus', context, const []);
        expect(day.toMap(), remote!.toMap());
        expect(local('missing'), isNull);
      },
    );

    test('cached readings are returned without a request', () async {
      final service = ParsedReadingsService(
        db: _NoFirestore(),
        days: _CountingDays(),
      );
      List<ParsedReading>? cached() => service.cachedForDate(
        date,
        calendar.getYearOptionsCached(2026),
        calendar.getYearOptionsCached(2027),
        calendar.getDynamicDatesCached(2026),
        includeAlternatives: true,
      );
      expect(cached(), isNull);
      await HiveService.readingsBox.put('r1', {
        'id': 'r1',
        '_periodType': 'ordinary',
        '_periodWeekNumber': 26,
        '_dayOfWeek': 2,
        'title': 'Панядзелак',
        'gospel': {
          'bible': 'Лк 9, 46-50',
          'text': 'У той час Езус сказаў сваім вучням.',
        },
      });
      expect(cached(), isNull, reason: 'the date is not marked complete yet');
      await HiveService.markDateCached('readings', date);
      expect(cached()!.single.id, 'r1');
    });
  });

  test('readings linked to a day are found through the index', () async {
    await ReadingsIndex.ensureBuilt();
    expect(ReadingsIndex.isBuilt, isTrue);
    await cacheReadingDoc('linked', {
      '_date': '01.08',
      '_dayIds': ['01-08-sv-alphonsus-liguori'],
    });
    expect(ReadingsIndex.lookupByDayId('01-08-sv-alphonsus-liguori'), [
      'linked',
    ]);
    await cacheReadingDoc('linked', {'_date': '01.08'});
    expect(ReadingsIndex.lookupByDayId('01-08-sv-alphonsus-liguori'), isEmpty);
  });

  group('requests', () {
    test('concurrent loads of one date share a single request', () async {
      final days = _CountingDays();
      CacheWarmupService service() => CacheWarmupService(
        calendar: calendar,
        days: days,
        readings: _EmptyReadings(),
      );
      final events = <String>[];
      DataLog.sink = (event, subject) => events.add(event);
      // The selected date, the neighbour prefetch and Vespers of tomorrow
      // may all ask for the same day at once.
      final results = await Future.wait([
        service().warmupDate(date),
        service().warmupDate(date),
        service().warmupDate(date),
      ]);
      expect(results, [true, true, true]);
      expect(days.calls, 1);
      expect(CacheWarmupService.startedLoads, 1);
      expect(events.where((event) => event == 'FETCH START'), hasLength(1));
      expect(CacheWarmupService.isDateReady(date), isTrue);

      // A ready date: no request and no disk write.
      final meta = Hive.box('meta');
      var writes = 0;
      final subscription = meta.watch().listen((_) => writes++);
      expect(await service().warmupDate(date), isTrue);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(days.calls, 1);
      expect(writes, 0);
      expect(events, contains('CACHE HIT'));
    });

    test('the calendar needs no request and no stored document', () async {
      expect(HiveService.yearOptionsBox.isEmpty, isTrue);
      final service = CalendarService();
      expect(await service.ensureYearOptions(2031), isNotNull);
      expect(
        (await service.ensureDynamicDates(2031))['easterSunday'],
        isNotNull,
      );
      expect(SyncTarget.years.automatic, isFalse);
    });
  });

  group('load states', () {
    test('a failure never takes content off the screen', () {
      expect(const LoadState<int>.loading().isFirstLoad, isTrue);
      expect(const LoadState<int>.refreshing(1).isFirstLoad, isFalse);
      expect(const LoadState<int>.refreshing(1).hasData, isTrue);
      final noData = loadStateAfterFailure<int>(null, 'x', offline: true);
      expect(noData.phase, LoadPhase.error);
      expect(
        loadStateAfterFailure<int>(7, 'x', offline: true).phase,
        LoadPhase.offline,
      );
      final partial = loadStateAfterFailure<int>(7, 'x', offline: false);
      expect(partial.phase, LoadPhase.partial);
      expect(partial.data, 7);
      expect(LoadPhase.values, hasLength(7));
    });

    test('activity: only a day without content is a page load', () async {
      final ready = Completer<void>();
      ProviderContainer container(List<Object> options) => ProviderContainer(
        overrides: [
          selectedDateReadyProvider.overrideWith((ref) => ready.future),
          dayOptionsProvider.overrideWithValue(options.cast()),
          syncStatusProvider.overrideWith(_IdleSync.new),
        ],
      );
      final empty = container(const []);
      addTearDown(empty.dispose);
      expect(empty.read(dataActivityProvider), DataActivity.pageLoading);
      final shown = container([
        const DayOption(
          source: LiturgicalOptionSource.period,
          title: 'Дзень',
          key: 'k',
          contextPeriodType: 'ordinary',
        ),
      ]);
      addTearDown(shown.dispose);
      expect(shown.read(dataActivityProvider), DataActivity.refreshing);
      ready.complete();
      await shown.read(selectedDateReadyProvider.future);
      expect(shown.read(dataActivityProvider), DataActivity.idle);
      // Preparing neighbours never turns the page into a loading page.
      shown.read(backgroundPrefetchCountProvider.notifier).state = 1;
      expect(shown.read(dataActivityProvider), DataActivity.backgroundPrefetch);
    });
  });

  group('loading UI', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          syncStatusProvider.overrideWith(_IdleSync.new),
        ],
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );

    testWidgets('first load is calm and says nothing technical', (
      tester,
    ) async {
      await pump(
        tester,
        const DataLoadingNotice(
          label: 'Загружаем чытанні',
          shape: LoadingShape.text,
        ),
      );
      expect(find.text('Загружаем чытанні'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LoadingPlaceholder), findsOneWidget);
      expect(find.textContaining('кэш'), findsNothing);
      expect(find.textContaining('сервер'), findsNothing);
      expect(find.textContaining('КБ'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a refresh keeps its two pixels: no layout shift', (
      tester,
    ) async {
      Future<double> height(bool active) async {
        await pump(
          tester,
          Column(
            children: [
              AppRefreshBar(active: active),
              const SizedBox(key: Key('content'), height: 40),
            ],
          ),
        );
        return tester.getTopLeft(find.byKey(const Key('content'))).dy;
      }

      final idle = await height(false);
      final refreshing = await height(true);
      expect(refreshing, idle);
      expect(tester.getSize(find.byType(AppRefreshBar)).height, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('error and offline states', (tester) async {
      var retried = 0;
      await pump(
        tester,
        Column(
          children: [
            const AppOfflineNotice(),
            AppErrorState(onRetry: () => retried++),
          ],
        ),
      );
      expect(find.text('Працуем з захаванымі данымі'), findsOneWidget);
      expect(find.text('Не ўдалося загрузіць даныя'), findsOneWidget);
      await tester.tap(find.text('Паўтарыць'));
      expect(retried, 1);
    });
  });

  group('settings', () {
    test('status of the data in the reader\'s words', () async {
      final now = DateTime(2026, 9, 28, 12, 34);
      var status = collectDataStatus(now: now);
      expect(status.first.title, 'Літургічны каляндар');
      expect(status.first.readiness, DataReadiness.ready);
      expect(status[1].readiness, DataReadiness.missing);
      await HiveService.markDateCached('days', now);
      status = collectDataStatus(now: now);
      expect(status[1].readiness, DataReadiness.partial);
      expect(status[1].detail, 'сёння гатова, заўтра загрузіцца');
      await HiveService.markDateCached('days', DateTime(2026, 9, 29));
      expect(collectDataStatus(now: now)[1].readiness, DataReadiness.ready);
      expect(
        collectDataStatus(now: now, syncingCollection: 'readings')[2].readiness,
        DataReadiness.loading,
      );
      // Bundled content is available before any download.
      expect(
        status.where((item) => item.title == 'Біблія').single.readiness,
        DataReadiness.ready,
      );
      for (final item in status) {
        expect(item.title, isNot(contains('_')));
        expect(item.detail.toLowerCase(), isNot(contains('firestore')));
        expect(item.detail.toLowerCase(), isNot(contains('hive')));
      }
      expect(formatLastUpdate(now, now: now), 'сёння, 12:34');
      expect(
        formatLastUpdate(DateTime(2026, 9, 27, 8, 5), now: now),
        'учора, 08:05',
      );
      expect(formatLastUpdate(DateTime(2026, 9, 1), now: now), '01.09.2026');
      expect(formatLastUpdate(null), 'яшчэ не абнаўлялася');
    });

    testWidgets('simple switches, update button and details', (tester) async {
      final sync = _RecordingSync();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => Stream.value(true)),
            syncStatusProvider.overrideWith(() => sync),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: DataSettingsSection(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Даныя і загрузка'), findsOneWidget);
      expect(find.text('Аўтаматычнае абнаўленне'), findsOneWidget);
      expect(find.text('Рыхтаваць бліжэйшыя дні'), findsOneWidget);
      expect(find.text('Вялікія абнаўленні толькі па Wi-Fi'), findsOneWidget);
      // The technical controls are one level deeper.
      expect(find.byKey(const Key('sync-liturgy')), findsNothing);
      expect(find.byKey(const Key('data-details')), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DataSettingsSection)),
      );
      // Settings are written to disk: real I/O needs runAsync.
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('data-wifi-only')));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(container.read(cachePolicyProvider).wifiOnlyLarge, isFalse);
      expect(HiveService.settingsBox.get('wifiOnlyLarge'), isFalse);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('data-prefetch-nearby')));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(container.read(cachePolicyProvider).prefetchNearby, isFalse);

      await tester.ensureVisible(find.byKey(const Key('data-update-now')));
      await tester.tap(find.byKey(const Key('data-update-now')));
      await tester.pump();
      final plan = sync.plans.single;
      expect(plan.targets, contains(SyncTarget.days));
      expect(plan.targets.intersection(kLargeSyncTargets), isEmpty);
      expect(plan.dates, hasLength(15));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test(
      'clearing removes downloaded texts and their readiness only',
      () async {
        await seedDay();
        await HiveService.markDateCached('days', date);
        await HiveService.prayersBox.put('p', {'title': 'Малітва'});
        await HiveService.settingsBox.put('fontSize', 20);
        expect(DaysIndex.idsByDate(['28.09']), isNotEmpty);
        await HiveService.clearDownloadedTexts();
        expect(HiveService.daysBox.isEmpty, isTrue);
        expect(HiveService.isDateCached('days', date), isFalse);
        expect(DaysIndex.idsByDate(['28.09']), isEmpty);
        expect(HiveService.prayersBox.length, 1);
        expect(HiveService.settingsBox.get('fontSize'), 20);
      },
    );
  });
}

class _NoFirestore extends Fake implements FirebaseFirestore {}

class _CountingDays extends LiturgicalDayService {
  _CountingDays() : super(db: _NoFirestore());
  int calls = 0;
  @override
  Future<void> prefetchForDate(
    DateTime date, {
    required String periodType,
    required int periodWeek,
    required int dayOfWeek,
    required List<String> feastCodes,
    bool forceRefresh = false,
  }) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _EmptyReadings extends ParsedReadingsService {
  _EmptyReadings() : super(db: _NoFirestore(), days: _CountingDays());
  @override
  Future<List<ParsedReading>> fetchForDate(
    DateTime date,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates, {
    bool forceRefresh = false,
    bool includeAlternatives = false,
    String? dayId,
  }) async => [];
}

class _IdleSync extends SyncStatusNotifier {}

class _RecordingSync extends SyncStatusNotifier {
  final plans = <SyncPlan>[];
  @override
  Future<void> synchronize(SyncPlan plan) async => plans.add(plan);
}
