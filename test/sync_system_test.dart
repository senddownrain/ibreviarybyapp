// Firestore SDK test doubles intentionally implement its sealed interfaces.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:mybrev_flutter/widgets/cache_sync_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/models/sync_plan.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/providers/data_bootstrap_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/sync_provider.dart';
import 'package:mybrev_flutter/services/cache_warmup_service.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_day_service.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';
import 'package:mybrev_flutter/utils/readings_index.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync-system-');
    await HiveService.init(path: directory.path);
    for (final target in SyncTarget.values) {
      HiveService.cachedBytes(target.collection);
    }
    await Hive.box('meta').flush();
    HiveService.receivedBytes = 0;
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'settings dispatch selected and complete downloads on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final recorder = _RecordingSync();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncStatusProvider.overrideWith(() => recorder)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CacheSyncSettings(),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('sync-selected')));
      await tester.tap(find.byKey(const Key('sync-selected')));
      await tester.pump();
      expect(recorder.plans.single.targets, {...SyncTarget.values});
      expect(recorder.plans.single.period, SyncPeriod.fortnight);
      expect(recorder.plans.single.baseDate, isNotNull);
      await tester.ensureVisible(find.byKey(const Key('sync-entire-database')));
      await tester.tap(find.byKey(const Key('sync-entire-database')));
      await tester.pump();
      expect(recorder.plans.last.period, SyncPeriod.all);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('default date window is today plus seven days each way', () {
    final dates = CacheWarmupService.buildDateOrder(DateTime(2026, 1, 2));
    expect(dates.length, 15);
    expect(dates.first, DateTime(2026, 1, 2));
    expect(dates.toSet().length, 15);
    expect(
      dates.reduce((a, b) => a.isBefore(b) ? a : b),
      DateTime(2025, 12, 26),
    );
    expect(dates.reduce((a, b) => a.isAfter(b) ? a : b), DateTime(2026, 1, 9));
  });

  test('calendar year covers leap day and stops before next year', () {
    final dates = SyncPeriod.year.dates(DateTime(2024, 9, 13));
    expect(dates.length, 366);
    expect(dates.first, DateTime(2024));
    expect(dates.last, DateTime(2024, 12, 31));
    expect(dates, contains(DateTime(2024, 2, 29)));
  });

  test('month period respects calendar month boundaries', () {
    final dates = SyncPeriod.month.dates(DateTime(2024, 1, 31));
    expect(dates.first, DateTime(2024, 1, 31));
    expect(dates.last, DateTime(2024, 2, 28));
    expect(dates.length, 29);
  });

  test(
    'first bootstrap releases today before starting background window',
    () async {
      final today = Completer<void>();
      final background = _RecordingSync();
      final container = ProviderContainer(
        overrides: [
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          selectedDateReadyProvider.overrideWith((ref) => today.future),
          syncStatusProvider.overrideWith(() => background),
        ],
      );
      addTearDown(container.dispose);
      container.read(dataBootstrapProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(dataBootstrapProvider).isRunning, isTrue);
      expect(background.plans, isEmpty);
      today.complete();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(dataBootstrapProvider).initialComplete, isTrue);
      expect(background.plans.single.dates!.length, 15);
      expect(background.plans.single.targets, {...SyncTarget.values});
      expect(background.plans.single.forceRefresh, isFalse);
    },
  );

  test(
    'full coverage marker cannot suppress fetching a missing selected day',
    () async {
      await HiveService.setMetaFlag('fullCache_days', true);
      await HiveService.setMetaFlag('fullCache_readings', true);
      final calendar = _Calendar();
      final days = _Days();
      final service = CacheWarmupService(
        calendar: calendar,
        days: days,
        readings: _Readings(),
      );
      final container = ProviderContainer(
        overrides: [
          calendarServiceProvider.overrideWithValue(calendar),
          selectedDateWarmupServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      await container.read(selectedDateReadyProvider.future);
      expect(days.calls, 1);
      expect(days.forced, isTrue);
    },
  );

  test('failed date does not create completion markers or coverage', () async {
    final date = DateTime(2026, 9, 13);
    final service = CacheWarmupService(
      calendar: _Calendar(),
      days: _Days(fail: true),
      readings: _Readings(),
    );
    await expectLater(service.syncDates([date]), throwsStateError);
    expect(HiveService.isDateCached('days', date), isFalse);
    expect(HiveService.isDateCached('readings', date), isFalse);
    expect(HiveService.getWarmupCoverage(), isNull);
  });

  test('days and readings can be downloaded independently', () async {
    final date = DateTime(2026, 9, 13);
    final days = _Days();
    final readings = _Readings();
    final service = CacheWarmupService(
      calendar: _Calendar(),
      days: days,
      readings: readings,
    );
    await service.syncDates([date], includeReadings: false);
    expect(days.calls, 1);
    expect(days.forced, isTrue);
    expect(readings.calls, 0);
    expect(HiveService.isDateCached('days', date), isTrue);
    expect(HiveService.isDateCached('readings', date), isFalse);
    await service.syncDates([date], includeDays: false);
    expect(days.calls, 1);
    expect(readings.calls, 1);
    expect(HiveService.isDateCached('readings', date), isTrue);
    await service.syncDates([date]);
    expect(days.calls, 1);
    expect(readings.calls, 1);
  });

  test(
    'collection sync uses server pages and removes stale docs after success',
    () async {
      await HiveService.putCached('prayers', 'old', {
        'id': 'old',
        'text': 'offline',
      });
      final db = _Db(
        List.generate(121, (i) => _Doc('p$i', {'text': 'Prayer $i'})),
      );
      final container = ProviderContainer(
        overrides: [syncFirestoreProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await container
          .read(syncStatusProvider.notifier)
          .synchronize(const SyncPlan(targets: {SyncTarget.prayers}));
      expect(db.pageOffsets, [0, 50, 100]);
      expect(db.sources, everyElement(Source.server));
      expect(HiveService.prayersBox.length, 121);
      expect(HiveService.prayersBox.containsKey('old'), isFalse);
      expect(HiveService.getLastSync('prayers'), isNotNull);
      expect(container.read(syncStatusProvider).error, isNull);
      expect(
        container.read(syncStatusProvider).downloadedBytes,
        greaterThan(0),
      );
      expect(
        HiveService.cachedBytes('prayers'),
        HiveService.prayersBox.values.fold<int>(
          0,
          (s, v) => s + HiveService.payloadBytes(v),
        ),
      );
    },
  );

  test(
    'failed second page preserves offline data and first page without success timestamp',
    () async {
      await HiveService.putCached('prayers', 'offline', {'text': 'Saved'});
      final db = _Db(
        List.generate(80, (i) => _Doc('p$i', {'text': 'Prayer'})),
        failAt: 50,
      );
      final container = ProviderContainer(
        overrides: [syncFirestoreProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await container
          .read(syncStatusProvider.notifier)
          .synchronize(const SyncPlan(targets: {SyncTarget.prayers}));
      expect(HiveService.prayersBox.length, 51);
      expect(HiveService.prayersBox.containsKey('offline'), isTrue);
      expect(HiveService.getLastSync('prayers'), isNull);
      expect(container.read(syncStatusProvider).error, isNotNull);
    },
  );

  test('queued manual requests both run', () async {
    final db = _Db([
      _Doc('one', {'text': 'Prayer'}),
    ]);
    final container = ProviderContainer(
      overrides: [syncFirestoreProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final sync = container.read(syncStatusProvider.notifier);
    await Future.wait([
      sync.synchronize(const SyncPlan(targets: {SyncTarget.prayers})),
      sync.synchronize(const SyncPlan(targets: {SyncTarget.prayers})),
    ]);
    expect(db.pageOffsets, [0, 0]);
  });

  test(
    'uncached day requests server and is available locally afterwards',
    () async {
      final db = _Db([
        _Doc('remote-day', {'_title': 'Today'}),
      ]);
      final service = LiturgicalDayService(db: db);
      expect(HiveService.daysBox.isEmpty, isTrue);
      expect(await service.getDayById('remote-day'), isNotNull);
      expect(db.sources, [Source.server]);
      expect(await service.getDayById('remote-day'), isNotNull);
      expect(db.sources.length, 1);
    },
  );

  test(
    'cancelled page download preserves saved pages and offline documents',
    () async {
      await HiveService.putCached('prayers', 'offline', {'text': 'Saved'});
      final db = _Db(List.generate(80, (i) => _Doc('p$i', {'text': 'Prayer'})));
      final container = ProviderContainer(
        overrides: [syncFirestoreProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final sync = container.read(syncStatusProvider.notifier);
      db.onPage = (offset) {
        if (offset == 50) sync.cancel();
      };
      await sync.synchronize(const SyncPlan(targets: {SyncTarget.prayers}));
      expect(HiveService.prayersBox.length, 51);
      expect(HiveService.prayersBox.containsKey('offline'), isTrue);
      expect(HiveService.getLastSync('prayers'), isNull);
      expect(container.read(syncStatusProvider).cancelled, isTrue);
    },
  );

  test('full day collection establishes complete offline coverage', () async {
    final db = _Db([
      _Doc('day', {'_title': 'Day'}),
    ]);
    final container = ProviderContainer(
      overrides: [syncFirestoreProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container
        .read(syncStatusProvider.notifier)
        .synchronize(
          const SyncPlan(targets: {SyncTarget.days}, period: SyncPeriod.all),
        );
    expect(HiveService.isDateCached('days', DateTime(2020)), isTrue);
    expect(HiveService.isDateCached('days', DateTime(2030)), isTrue);
    expect(HiveService.isDateCached('readings', DateTime(2030)), isFalse);
  });

  test(
    'one failed collection does not prevent other selected downloads',
    () async {
      final db = _Db(
        List.generate(80, (i) => _Doc('p$i', {'text': 'Prayer'})),
        failAt: 50,
      );
      final container = ProviderContainer(
        overrides: [syncFirestoreProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await container
          .read(syncStatusProvider.notifier)
          .synchronize(
            const SyncPlan(targets: {SyncTarget.prayers, SyncTarget.bibleBel}),
          );
      expect(db.pageOffsets, [0, 50, 0, 50]);
      expect(HiveService.prayersBox.length, 50);
      expect(HiveService.boxFor('bible_bel').length, 50);
      expect(container.read(syncStatusProvider).error, contains('Малітвы'));
      expect(container.read(syncStatusProvider).error, contains('Біблія'));
    },
  );

  test('concurrent cache writes retain accurate byte totals', () async {
    await Future.wait(
      List.generate(
        20,
        (i) => HiveService.putCached('days', '$i', {'text': 'Дзень $i'}),
      ),
    );
    expect(
      HiveService.cachedBytes('days'),
      HiveService.daysBox.values.fold<int>(
        0,
        (s, v) => s + HiveService.payloadBytes(v),
      ),
    );
  });

  test('updating reading removes its obsolete index keys', () async {
    await cacheReadingDoc('r', {'_date': '01.01', 'text': 'A'});
    await cacheReadingDoc('r', {'_date': '02.01', 'text': 'B'});
    expect(ReadingsIndex.lookupByDate('01.01'), isEmpty);
    expect(ReadingsIndex.lookupByDate('02.01'), ['r']);
  });
}

class _RecordingSync extends SyncStatusNotifier {
  final plans = <SyncPlan>[];
  @override
  Future<void> synchronize(SyncPlan plan) async {
    plans.add(plan);
  }
}

class _Calendar extends CalendarService {
  _Calendar() : super(db: _Db([]));
  @override
  Future<YearOptions?> ensureYearOptions(int year) async => null;
  @override
  Future<DynamicDates> ensureDynamicDates(int year) async => {};
}

class _Days extends LiturgicalDayService {
  _Days({this.fail = false}) : super(db: _Db([]));
  final bool fail;
  int calls = 0;
  bool forced = false;
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
    forced = forceRefresh;
    if (fail) throw StateError('Offline');
  }
}

class _Readings extends ParsedReadingsService {
  _Readings() : super(db: _Db([]), days: _Days());
  int calls = 0;
  @override
  Future<List<ParsedReading>> fetchForDate(
    DateTime date,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates, {
    bool forceRefresh = false,
    bool includeAlternatives = false,
    String? dayId,
  }) async {
    calls++;
    return [];
  }
}

class _Db extends Fake implements FirebaseFirestore {
  _Db(this.documents, {this.failAt});
  final List<_Doc> documents;
  final int? failAt;
  final sources = <Source?>[];
  final pageOffsets = <int>[];
  void Function(int)? onPage;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this);
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db);
  final _Db db;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Ref(db, path!);
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => _Query(db);
}

class _Query extends Fake implements Query<Map<String, dynamic>> {
  _Query(this.db, {this.offset = 0, this.pageSize = 50});
  final _Db db;
  final int offset;
  final int pageSize;
  @override
  Query<Map<String, dynamic>> limit(int limit) =>
      _Query(db, offset: offset, pageSize: limit);
  @override
  Query<Map<String, dynamic>> startAfterDocument(
    DocumentSnapshot<Object?> documentSnapshot,
  ) => _Query(
    db,
    offset: db.documents.indexOf(documentSnapshot as _Doc) + 1,
    pageSize: pageSize,
  );
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    db.sources.add(options?.source);
    db.pageOffsets.add(offset);
    db.onPage?.call(offset);
    if (db.failAt == offset) throw StateError('Disconnected');
    return _Snapshot(db.documents.skip(offset).take(pageSize).toList());
  }
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);
  @override
  final List<_Doc> docs;
}

class _Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
  @override
  bool get exists => true;
}

class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.db, this.id);
  final _Db db;
  @override
  final String id;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    db.sources.add(options?.source);
    return db.documents.firstWhere((doc) => doc.id == id);
  }
}
