// «Offline by installation»: the bundled content, the update overlay, the
// version check, the move from the former download cache, and the
// Settings section. No network in any of these tests.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_migration.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/content/content_updater.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/content_updates_provider.dart';
import 'package:mybrev_flutter/services/compendium_repository.dart';
import 'package:mybrev_flutter/services/days_index.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/widgets/data_settings_section.dart';

/// Version manifest and documents of a pretend Firestore.
class FakeRemote implements ContentRemote {
  FakeRemote(this.collections, {this.contentVersion = 0});

  /// collection → id → document (null = no document).
  final Map<String, Map<String, Map<String, dynamic>>> collections;
  final int contentVersion;

  /// Corrupts a document after the manifest was published.
  final Map<String, Map<String, dynamic>> served = {};

  int currentReads = 0;
  final List<String> manifestReads = [];
  final List<String> fetched = [];

  Map<String, String> _hashes(String name) => {
    for (final entry in collections[name]!.entries)
      entry.key: documentHash(entry.value),
  };

  @override
  Future<Map<String, dynamic>?> fetchCurrent() async {
    currentReads++;
    return {
      'schemaVersion': kContentSchemaVersion,
      'contentVersion': contentVersion,
      'collections': {
        for (final name in collections.keys)
          name: {'digest': contentDigest(_hashes(name))},
      },
    };
  }

  @override
  Future<Map<String, dynamic>?> fetchCollectionManifest(String name) async {
    manifestReads.add(name);
    final hashes = _hashes(name);
    return {
      'digest': contentDigest(hashes),
      'hashes': hashes,
      'sizes': {for (final id in hashes.keys) id: 1000},
    };
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchDocuments(
    String name,
    List<String> ids,
  ) async {
    fetched.addAll(ids.map((id) => '$name/$id'));
    return {
      for (final id in ids)
        id: ?(served['$name/$id'] ?? collections[name]![id]),
    };
  }
}

/// A copy of the bundled collection [name], as Firestore would serve it.
Map<String, Map<String, dynamic>> bundled(String name) {
  final collection = ContentStore.instance.collection(name);
  return {
    for (final key in collection.keys)
      key: Map<String, dynamic>.from(collection.get(key) as Map),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  Future<void> openWithBundle() async {
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('content-');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  group('distribution', () {
    test(
      'every collection ships with the app and matches its manifest',
      () async {
        await openWithBundle();
        final manifest = ContentStore.instance.bundleManifest!;
        for (final name in kContentCollections) {
          final collection = ContentStore.instance.collection(name);
          final described = (manifest['collections'] as Map)[name] as Map;
          expect(collection.length, described['count'], reason: name);
          expect(collection.digest(), described['digest'], reason: name);
        }
      },
    );

    test('a fresh install opens the Hours and the Readings offline, '
        'far outside the former ±7-day window', () async {
      await openWithBundle();
      final calendar = CalendarService();
      for (final date in [
        DateTime(2026, 10, 7),
        DateTime(2027, 3, 14), // IV Sunday of Lent, months away
        DateTime(2031, 12, 25), // Christmas, years away
        DateTime(2026, 2, 19), // Thursday after Ash Wednesday (week-less)
      ]) {
        final options = LiturgicalContentService().getContentForDate(
          date,
          calendar.getYearOptionsCached(date.year),
          calendar.getYearOptionsCached(date.year + 1),
          calendar.getDynamicDatesCached(date.year),
        );
        expect(
          options.where((o) => o.day != null),
          isNotEmpty,
          reason: '$date',
        );
        final day = LiturgicalContentService().resolveDayLocal(
          date,
          options.firstWhere((o) => o.dayId != null).dayId!,
          calendar.getYearOptionsCached(date.year),
          calendar.getYearOptionsCached(date.year + 1),
          calendar.getDynamicDatesCached(date.year),
        );
        expect(day, isNotNull, reason: '$date');
        final readings = ParsedReadingsService().cachedForDate(
          date,
          calendar.getYearOptionsCached(date.year),
          calendar.getYearOptionsCached(date.year + 1),
          calendar.getDynamicDatesCached(date.year),
          includeAlternatives: true,
        );
        expect(readings, isNotEmpty, reason: '$date');
      }
      expect(HiveService.invitatoriumsBox, isNotEmpty);
      expect(HiveService.completoriumsBox, isNotEmpty);
      expect(HiveService.prayersBox, isNotEmpty);
    });

    test('Hive holds no copy of the bundled corpus', () async {
      await openWithBundle();
      for (final name in kContentCollections) {
        expect(ContentStore.instance.collection(name).overlayLength, 0);
      }
    });
  });

  group('versions', () {
    test('same digest: one small request, nothing downloaded', () async {
      await openWithBundle();
      final remote = FakeRemote({
        for (final name in kContentCollections) name: bundled(name),
      });
      final plan = await ContentUpdater(remote: remote).check();
      expect(plan, isNull);
      expect(remote.currentReads, 1);
      expect(remote.manifestReads, isEmpty);
      expect(remote.fetched, isEmpty);
    });

    test('one changed document: only that document is downloaded', () async {
      await openWithBundle();
      final days = bundled('days');
      final id = days.keys.firstWhere((key) => days[key]!['_date'] == '28.09');
      days[id] = {...days[id]!, 'laudesPr': 'Выпраўленая малітва'};
      final remote = FakeRemote({
        for (final name in kContentCollections)
          name: name == 'days' ? days : bundled(name),
      }, contentVersion: DateTime(2030).millisecondsSinceEpoch);
      final updater = ContentUpdater(remote: remote);
      final plan = (await updater.check())!;
      expect(remote.manifestReads, ['days']);
      expect(plan.documents, 1);
      await updater.apply(plan);
      expect(remote.fetched, ['days/$id']);
      expect(
        (HiveService.daysBox.get(id) as Map)['laudesPr'],
        'Выпраўленая малітва',
      );
      expect(DaysIndex.idsByDate(['28.09']), contains(id));
      expect(HiveService.daysBox.overlayLength, 1);
      // The device now has what the manifest has.
      expect(await updater.check(), isNull);
    });

    test('a removed document disappears; a new one appears', () async {
      await openWithBundle();
      final prayers = bundled('prayers');
      final removed = prayers.keys.first;
      prayers.remove(removed);
      prayers['new-prayer'] = {
        'id': 'new-prayer',
        'title': 'Новая',
        'text': 'Тэкст',
      };
      final remote = FakeRemote({
        for (final name in kContentCollections)
          name: name == 'prayers' ? prayers : bundled(name),
      }, contentVersion: DateTime(2030).millisecondsSinceEpoch);
      final updater = ContentUpdater(remote: remote);
      await updater.apply((await updater.check())!);
      expect(HiveService.prayersBox.get(removed), isNull);
      expect(HiveService.prayersBox.keys, isNot(contains(removed)));
      expect(HiveService.prayersBox.get('new-prayer'), isNotNull);
    });

    test('a document that does not match the manifest is rejected; '
        'nothing changes', () async {
      await openWithBundle();
      final days = bundled('days');
      final ids = days.keys.take(2).toList();
      for (final id in ids) {
        days[id] = {...days[id]!, 'note': 'new'};
      }
      final remote = FakeRemote({
        for (final name in kContentCollections)
          name: name == 'days' ? days : bundled(name),
      });
      remote.served['days/${ids.last}'] = {
        ...days[ids.last]!,
        'note': 'broken',
      };
      final updater = ContentUpdater(remote: remote);
      final plan = (await updater.check())!;
      final before = HiveService.daysBox.digest();
      await expectLater(
        updater.apply(plan),
        throwsA(isA<ContentUpdateRejected>()),
      );
      expect(HiveService.daysBox.digest(), before);
      expect(HiveService.daysBox.overlayLength, 0);
      expect((HiveService.daysBox.get(ids.first) as Map)['note'], isNull);
    });

    test('a missing document rejects the update', () async {
      await openWithBundle();
      final songs = bundled('songs');
      final id = songs.keys.first;
      songs[id] = {...songs[id]!, 'title': 'Новая назва'};
      final remote = _MissingRemote({
        for (final name in kContentCollections)
          name: name == 'songs' ? songs : bundled(name),
      });
      final updater = ContentUpdater(remote: remote);
      await expectLater(
        updater.apply((await updater.check())!),
        throwsA(isA<ContentUpdateRejected>()),
      );
      expect(HiveService.songsBox.overlayLength, 0);
    });

    test('a newer local update survives a restart', () async {
      await openWithBundle();
      final id = HiveService.daysBox.keys.first;
      final doc = {...(HiveService.daysBox.get(id) as Map), 'x-fix': 'yes'};
      await HiveService.daysBox.applyUpdate(
        {id: Map<String, dynamic>.from(doc)},
        {id: documentHash(doc)},
        DateTime(2099).millisecondsSinceEpoch,
      );
      await Hive.close();
      await openWithBundle();
      expect((HiveService.daysBox.get(id) as Map)['x-fix'], 'yes');
    });

    test(
      'an app update with a newer bundle supersedes an older local update',
      () async {
        await openWithBundle();
        final id = HiveService.daysBox.keys.first;
        final doc = {...(HiveService.daysBox.get(id) as Map), 'x-fix': 'old'};
        // Downloaded before the bundle of this app version was built.
        await HiveService.daysBox.applyUpdate(
          {id: Map<String, dynamic>.from(doc)},
          {id: documentHash(doc)},
          HiveService.daysBox.baselineVersion - 1000,
        );
        await Hive.close();
        await openWithBundle();
        expect((HiveService.daysBox.get(id) as Map)['x-fix'], isNull);
        expect(HiveService.daysBox.overlayLength, 0);
      },
    );
  });

  group('former download cache', () {
    Future<void> seedLegacy() async {
      Hive.init(directory.path);
      final days = await Hive.openBox('days');
      final meta = await Hive.openBox('meta');
      final settings = await Hive.openBox('settings');
      final local = await Hive.openBox('localPrayers');
      await meta.put('ready_days_2026-10-6', true);
      await meta.put('lastSync_days', '2026-09-01T00:00:00.000');
      await settings.put('fontSize', 21);
      await local.put('mine', {'title': 'Мая малітва'});
      await Hive.openBox('readingsIndex');
      await Hive.openBox('bible_bel').then((box) => box.put('gen', {'x': 1}));
      return days.put('legacy-only', {'id': 'legacy-only', 'updatedAt': 1});
    }

    test('newer documents are kept, older ones dropped, the cache removed, '
        'user data untouched — and running again changes nothing', () async {
      await seedLegacy();
      final days = Hive.box('days');
      await Hive.close();
      await openWithBundle();
      final store = ContentStore.instance;
      final bundledId = store.collection('days').keys.first;
      final bundledDoc = Map<String, dynamic>.from(
        store.collection('days').get(bundledId) as Map,
      );
      // Re-open the former box with a newer edit of a bundled document and
      // an older copy of another one.
      final legacy = await Hive.openBox('days');
      final otherId = store.collection('days').keys.elementAt(1);
      await legacy.putAll({
        bundledId: {
          ...bundledDoc,
          'laudesPr': 'newer',
          'updatedAt': DateTime(2099).millisecondsSinceEpoch,
        },
        otherId: {
          ...(store.collection('days').get(otherId) as Map),
          'laudesPr': 'older',
          'updatedAt': 1,
        },
      });
      expect(days.isOpen, isFalse);
      final migration = ContentMigration(HiveService.metaBox);
      await migration.run();
      expect(migration.carried, 1);
      expect((HiveService.daysBox.get(bundledId) as Map)['laudesPr'], 'newer');
      expect(
        (HiveService.daysBox.get(otherId) as Map)['laudesPr'],
        isNot('older'),
      );
      expect(HiveService.daysBox.get('legacy-only'), isNull);
      for (final name in ['days', 'readingsIndex', 'bible_bel']) {
        expect(await Hive.boxExists(name), isFalse, reason: name);
      }
      expect(HiveService.metaBox.get('ready_days_2026-10-6'), isNull);
      expect(HiveService.metaBox.get('lastSync_days'), isNull);
      expect(HiveService.settingsBox.get('fontSize'), 21);
      expect(HiveService.localPrayersBox.get('mine'), isNotNull);
      expect(migration.isDone, isTrue);
      final again = ContentMigration(HiveService.metaBox);
      await again.run();
      expect(again.carried, 0);
      expect((HiveService.daysBox.get(bundledId) as Map)['laudesPr'], 'newer');
    });
  });

  group('update policy', () {
    ProviderContainer container(FakeRemote remote) {
      final container = ProviderContainer(
        overrides: [
          contentUpdaterProvider.overrideWithValue(
            ContentUpdater(remote: remote),
          ),
          isOfflineProvider.overrideWithValue(false),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          compendiumSyncProvider.overrideWithValue(
            CompendiumSync(
              remote: _NoCompendium(),
              bundledVersion: () async => 0,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    FakeRemote changed(String name, Map<String, Map<String, dynamic>> docs) =>
        FakeRemote({
          for (final item in kContentCollections)
            item: item == name ? docs : bundled(item),
        }, contentVersion: DateTime(2030).millisecondsSinceEpoch);

    test('100 new prayers: only those are downloaded, by themselves', () async {
      await openWithBundle();
      final prayers = bundled('prayers');
      for (var i = 0; i < 100; i++) {
        prayers['new-$i'] = {
          'id': 'new-$i',
          'title': 'Малітва $i',
          'text': 'Тэкст $i',
        };
      }
      final remote = changed('prayers', prayers);
      final c = container(remote);
      await c.read(contentUpdatesProvider.notifier).check();
      final state = c.read(contentUpdatesProvider);
      expect(state.phase, ContentUpdatePhase.idle);
      expect(state.lastUpdate, isNotNull);
      expect(state.awaitsAppRelease, isFalse);
      expect(remote.manifestReads, ['prayers']);
      expect(remote.fetched, hasLength(100));
      expect(
        remote.fetched.every((id) => id.startsWith('prayers/new-')),
        isTrue,
      );
      expect(HiveService.prayersBox.get('new-99'), isNotNull);
    });

    test('a rebuild-sized diff is left to the next app release', () async {
      await openWithBundle();
      final days = bundled('days');
      for (final id in days.keys.take(500)) {
        days[id] = {...days[id]!, 'note': 'rebuilt'};
      }
      final remote = changed('days', days);
      final c = container(remote);
      await c.read(contentUpdatesProvider.notifier).check();
      final state = c.read(contentUpdatesProvider);
      expect(state.awaitsAppRelease, isTrue);
      expect(state.failed, isFalse);
      expect(remote.fetched, isEmpty);
      expect(HiveService.daysBox.overlayLength, 0);
    });

    test('a newer schema is never installed as a patch', () async {
      await openWithBundle();
      final days = bundled('days');
      days[days.keys.first] = {...days[days.keys.first]!, 'note': 'v2'};
      final remote = _SchemaRemote(changed('days', days));
      final plan = await ContentUpdater(remote: remote).check();
      expect(plan, isNull);
      expect(remote.manifestReads, isEmpty);
      expect(remote.fetched, isEmpty);
    });

    test('the daily check runs once a day', () async {
      await openWithBundle();
      final remote = FakeRemote({
        for (final name in kContentCollections) name: bundled(name),
      });
      final c = container(remote);
      final notifier = c.read(contentUpdatesProvider.notifier);
      await notifier.checkIfDue();
      await notifier.checkIfDue();
      expect(remote.currentReads, 1);
      await notifier.check();
      expect(remote.currentReads, 2);
    });
  });

  group('settings', () {
    // Real file IO stays outside the fake-async widget zone.
    setUp(() => HiveService.init(path: directory.path));

    Future<void> pump(
      WidgetTester tester,
      ContentUpdateState state, {
      bool offline = false,
    }) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentUpdatesProvider.overrideWith(() => _FixedUpdates(state)),
          isOfflineProvider.overrideWithValue(offline),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DataSettingsSection()),
          ),
        ),
      ),
    );

    testWidgets('only the reader\'s questions: offline, current, check', (
      tester,
    ) async {
      await pump(tester, ContentUpdateState(lastCheck: DateTime.now()));
      expect(find.text('Даныя і афлайн'), findsOneWidget);
      expect(find.text('Тэксты даступныя без сеткі'), findsOneWidget);
      expect(find.text('Актуальныя'), findsOneWidget);
      expect(find.textContaining('Праверана сёння'), findsOneWidget);
      expect(find.text('Праверыць абнаўленні'), findsOneWidget);
      // The former sync controls are gone.
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(DropdownButtonFormField), findsNothing);
      for (final gone in [
        'Wi-Fi',
        'Загрузіць усю базу',
        'кэш',
        'дакумент',
        'Сінхранізацыя',
        'Перыяд',
        'дзён',
        'МБ',
        'мабільн',
        'Тэксты ад',
      ]) {
        expect(find.textContaining(gone), findsNothing, reason: gone);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a failed check is calm', (tester) async {
      await pump(tester, const ContentUpdateState(failed: true));
      expect(find.text('Не ўдалося праверыць абнаўленні'), findsOneWidget);
      expect(find.text('Тэксты на прыладзе даступныя'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a rebuild waits for the app; nothing about Wi-Fi or sizes', (
      tester,
    ) async {
      await pump(
        tester,
        ContentUpdateState(lastCheck: DateTime.now(), awaitsAppRelease: true),
      );
      expect(
        find.text('Новыя тэксты прыйдуць з абнаўленнем праграмы'),
        findsOneWidget,
      );
      for (final gone in [
        'Wi',
        'МБ',
        'мабільн',
        'Загрузіць',
        'Пачакаць',
        'Тэксты ад',
      ]) {
        expect(find.textContaining(gone), findsNothing, reason: gone);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('offline: the texts work, the check waits', (tester) async {
      await pump(tester, const ContentUpdateState(), offline: true);
      expect(
        find.text('Няма сеткі. Усе тэксты працуюць і так.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('data-check-updates')),
      );
      expect(button.onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('activation', () {
    Map<String, dynamic> edited(String name, String id, String note) => {
      ...Map<String, dynamic>.from(
        ContentStore.instance.collection(name).get(id) as Map,
      ),
      'note': note,
    };

    /// One update touching three related collections.
    Future<Map<String, String>> commitRelated({
      ContentCommitPhase? crashAfter,
    }) async {
      final store = ContentStore.instance;
      final ids = {
        for (final name in ['days', 'readings', 'liturgicalTemplates'])
          name: store.collection(name).keys.first,
      };
      ContentStore.crashAfter = crashAfter;
      addTearDown(() => ContentStore.crashAfter = null);
      await store.commit({
        for (final MapEntry(key: name, value: id) in ids.entries)
          name: store
              .collection(name)
              .planUpdate(
                {id: edited(name, id, 'v101')},
                {id: documentHash(edited(name, id, 'v101'))},
                DateTime(2030).millisecondsSinceEpoch,
              ),
      }, DateTime(2030).millisecondsSinceEpoch);
      ContentStore.crashAfter = null;
      return ids;
    }

    String? noteOf(String name, String id) =>
        (ContentStore.instance.collection(name).get(id) as Map)['note']
            as String?;

    Future<void> restart() async {
      await Hive.close();
      await openWithBundle();
    }

    test('a completed update is new in every collection', () async {
      await openWithBundle();
      final ids = await commitRelated();
      for (final MapEntry(key: name, value: id) in ids.entries) {
        expect(noteOf(name, id), 'v101', reason: name);
      }
      expect(Hive.box(ContentStore.stagingBoxName), isEmpty);
    });

    test(
      'crash while staging: old content, before and after a restart',
      () async {
        await openWithBundle();
        final ids = await commitRelated(crashAfter: ContentCommitPhase.staged);
        for (final MapEntry(key: name, value: id) in ids.entries) {
          expect(noteOf(name, id), isNull, reason: name);
        }
        await restart();
        for (final MapEntry(key: name, value: id) in ids.entries) {
          expect(noteOf(name, id), isNull, reason: name);
        }
        expect(Hive.box(ContentStore.stagingBoxName), isEmpty);
      },
    );

    test('crash after READY: old until restart, then new everywhere', () async {
      await openWithBundle();
      final ids = await commitRelated(crashAfter: ContentCommitPhase.ready);
      for (final MapEntry(key: name, value: id) in ids.entries) {
        expect(noteOf(name, id), isNull, reason: name);
      }
      await restart();
      for (final MapEntry(key: name, value: id) in ids.entries) {
        expect(noteOf(name, id), 'v101', reason: name);
      }
    });

    test('crash while writing overlays: readers never see a mix; '
        'the restart finishes it', () async {
      await openWithBundle();
      final ids = await commitRelated(crashAfter: ContentCommitPhase.written);
      // Overlays are on disk, the views were not switched: still old.
      for (final MapEntry(key: name, value: id) in ids.entries) {
        expect(noteOf(name, id), isNull, reason: name);
      }
      await restart();
      for (final MapEntry(key: name, value: id) in ids.entries) {
        expect(noteOf(name, id), 'v101', reason: name);
      }
      expect(Hive.box(ContentStore.stagingBoxName), isEmpty);
    });
  });

  group('corrections and app releases', () {
    Map<String, dynamic> withText(String id, String text) => {
      ...Map<String, dynamic>.from(HiveService.daysBox.baselineDocument(id)!),
      'laudesPr': text,
    };

    Future<void> publish(int version, Map<String, Map<String, dynamic>> docs) {
      final remote = FakeRemote({
        for (final name in kContentCollections)
          name: name == 'days' ? {...bundled('days'), ...docs} : bundled(name),
      }, contentVersion: version);
      final updater = ContentUpdater(remote: remote);
      return updater.check().then((plan) => updater.apply(plan!));
    }

    test(
      'v101 wrong text, v102 back to the bundled text: no overlay left',
      () async {
        await openWithBundle();
        final id = HiveService.daysBox.keys.first;
        final original = Map<String, dynamic>.from(
          HiveService.daysBox.baselineDocument(id)!,
        );
        await publish(101, {id: withText(id, 'памылковы тэкст')});
        expect(
          (HiveService.daysBox.get(id) as Map)['laudesPr'],
          'памылковы тэкст',
        );
        await publish(102, {id: original});
        expect(
          (HiveService.daysBox.get(id) as Map)['laudesPr'],
          original['laudesPr'],
        );
        expect(HiveService.daysBox.overlayLength, 0);
      },
    );

    test('v102 corrects v101 with a third text', () async {
      await openWithBundle();
      final id = HiveService.daysBox.keys.first;
      await publish(101, {id: withText(id, 'памылковы тэкст')});
      await publish(102, {id: withText(id, 'выпраўлены тэкст')});
      expect(
        (HiveService.daysBox.get(id) as Map)['laudesPr'],
        'выпраўлены тэкст',
      );
      expect(HiveService.daysBox.overlayEntry(id)!['v'], 102);
      expect(
        await ContentUpdater(
          remote: FakeRemote({
            for (final name in kContentCollections)
              name: name == 'days' ? {...bundled('days')} : bundled(name),
          }),
        ).check(),
        isNull,
        reason: 'the device has exactly what is published',
      );
    });

    test('a new app bundle absorbs the patches it contains', () async {
      await openWithBundle();
      final days = HiveService.daysBox;
      final ids = days.keys.take(3).toList();
      await publish(101, {ids[0]: withText(ids[0], 'v101')});
      await publish(102, {ids[1]: withText(ids[1], 'v102')});
      await publish(103, {ids[2]: withText(ids[2], 'v103')});
      expect(days.overlayLength, 3);
      // New release: built after v102 (contains v101 and v102), not v103.
      final docs = <String, Map<String, dynamic>>{
        for (final key in days.keys)
          key: Map<String, dynamic>.from(days.baselineDocument(key)!),
        ids[0]: withText(ids[0], 'v101'),
        ids[1]: withText(ids[1], 'v102'),
      };
      await days.debugReplaceBaseline(docs, {
        for (final e in docs.entries) e.key: documentHash(e.value),
      }, 102);
      expect(
        days.overlayLength,
        1,
        reason: 'only v103 is newer than the bundle',
      );
      expect((days.get(ids[0]) as Map)['laudesPr'], 'v101');
      expect((days.get(ids[1]) as Map)['laudesPr'], 'v102');
      expect((days.get(ids[2]) as Map)['laudesPr'], 'v103');
    });
  });

  group('former download cache at full size', () {
    test('an almost complete old database: newer kept, the rest freed, '
        'user data intact', () async {
      await openWithBundle();
      final store = ContentStore.instance;
      // The former boxes, as a user who downloaded «the whole database».
      final legacy = <String, int>{};
      for (final name in ['days', 'readings', 'prayers', 'songs']) {
        final box = await Hive.openBox(name);
        final collection = store.collection(name);
        await box.putAll({
          for (final key in collection.keys)
            key: Map<String, dynamic>.from(collection.get(key) as Map),
        });
        legacy[name] = box.length;
      }
      final newer = HiveService.daysBox.keys.elementAt(5);
      await Hive.box('days').put(newer, {
        ...Map<String, dynamic>.from(HiveService.daysBox.get(newer) as Map),
        'laudesPr': 'newer than the bundle',
        'updatedAt': DateTime(2099).millisecondsSinceEpoch,
      });
      await HiveService.settingsBox.putAll({
        'fontSize': 22,
        'favoriteIds': '["p1"]',
        'highlights:r1': {'s1': 'yellow'},
      });
      await HiveService.localPrayersBox.put('mine', {'title': 'Мая'});
      final bytesBefore = Directory(directory.path)
          .listSync()
          .whereType<File>()
          .fold<int>(0, (total, file) => total + file.lengthSync());
      final watch = Stopwatch()..start();
      final migration = ContentMigration(HiveService.metaBox);
      await migration.run();
      watch.stop();
      final bytesAfter = Directory(directory.path)
          .listSync()
          .whereType<File>()
          .fold<int>(0, (total, file) => total + file.lengthSync());
      // ignore: avoid_print
      print(
        'MIGRATION ${legacy.values.reduce((a, b) => a + b)} documents, '
        '${(bytesBefore / 1048576).toStringAsFixed(1)} MB → '
        '${(bytesAfter / 1048576).toStringAsFixed(1)} MB in ${watch.elapsedMilliseconds} ms',
      );
      expect(migration.carried, 1);
      expect(
        (HiveService.daysBox.get(newer) as Map)['laudesPr'],
        'newer than the bundle',
      );
      for (final name in legacy.keys) {
        expect(await Hive.boxExists(name), isFalse, reason: name);
      }
      expect(bytesAfter, lessThan(bytesBefore ~/ 10));
      expect(HiveService.settingsBox.get('fontSize'), 22);
      expect(HiveService.settingsBox.get('favoriteIds'), '["p1"]');
      expect(HiveService.settingsBox.get('highlights:r1'), isNotNull);
      expect(HiveService.localPrayersBox.get('mine'), isNotNull);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

class _MissingRemote extends FakeRemote {
  _MissingRemote(super.collections);
  @override
  Future<Map<String, Map<String, dynamic>>> fetchDocuments(
    String name,
    List<String> ids,
  ) async => {};
}

/// Published for a newer app: schemaVersion above the supported one.
class _SchemaRemote extends FakeRemote {
  _SchemaRemote(FakeRemote inner)
    : super(inner.collections, contentVersion: inner.contentVersion);
  @override
  Future<Map<String, dynamic>?> fetchCurrent() async => {
    ...(await super.fetchCurrent())!,
    'schemaVersion': kContentSchemaVersion + 1,
  };
}

class _NoCompendium implements CompendiumRemote {
  @override
  Future<Map<String, dynamic>?> fetchMeta() async => null;
  @override
  Future<List<Map<String, dynamic>>> fetchUnits() async => const [];
}

class _FixedUpdates extends ContentUpdatesNotifier {
  _FixedUpdates(this._state);
  final ContentUpdateState _state;
  @override
  ContentUpdateState build() => _state;
}
