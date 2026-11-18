// Delivery against the captured production index and the reviewed next index
// from November 2026. The historical baseline is the 2026-10-07 app bundle.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/content/content_updater.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';

import 'support/lectionary_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final delivery = lectionaryDeliveryFixture();
  final captured = delivery['manifest'] as Map;
  final planned = delivery['planned'] as Map;
  final manifest = planned['readings'] as Map;
  final old = delivery['old'] as Map<String, dynamic>;
  final historicalCollection = old['collection'] as Map<String, dynamic>;
  final added = (old['added'] as List).cast<String>();
  final removed = (old['removed'] as List).cast<String>();
  final download = [...added, ...(old['changed'] as List).cast<String>()]
    ..sort();
  late Map<String, Map<String, dynamic>> bundledDocs;
  late Map<String, String> bundledHashes;
  late int bundledVersion;

  Future<void> open() async {
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  }

  setUp(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('lectionary-delivery-');
    await open();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  ContentCollection readings() => ContentStore.instance.collection('readings');

  /// An installed app that still ships the 2026-10-07 bundle: the current
  /// baseline with the old text of the documents that changed since.
  late Map<String, Map<String, dynamic>> oldBaseDocs;
  late Map<String, String> oldBaseHashes;

  Future<void> restoreOldBaseline() async {
    ContentStore.instance.bundleManifest = {
      'contentVersion': old['contentVersion'],
      'collections': {'readings': historicalCollection},
    };
    await readings().debugReplaceBaseline(
      oldBaseDocs,
      oldBaseHashes,
      historicalCollection['contentVersion'] as int,
    );
  }

  Future<void> installOldBundle() async {
    final oldDocs = (old['documents'] as Map).cast<String, dynamic>();
    final oldHashes = (old['hashes'] as Map).cast<String, String>();
    final store = ContentStore.instance;
    bundledVersion =
        (store.bundleManifest!['collections']
                as Map)['readings']['contentVersion']
            as int;
    bundledDocs = {
      for (final id in readings().keys)
        id: Map<String, dynamic>.from(readings().get(id) as Map),
    };
    bundledHashes = readings().effectiveHashes().cast<String, String>();
    final docs = <String, Map<String, dynamic>>{
      for (final entry in bundledDocs.entries)
        if (!added.contains(entry.key)) entry.key: entry.value,
      for (final entry in oldDocs.entries)
        entry.key: Map<String, dynamic>.from(entry.value as Map),
    };
    final hashes = <String, String>{
      for (final entry in bundledHashes.entries)
        if (!added.contains(entry.key)) entry.key: entry.value,
      ...oldHashes,
    };
    oldBaseDocs = docs;
    oldBaseHashes = hashes;
    await restoreOldBaseline();
  }

  /// The process of the OLD app restarts: the same storage, the old bundle
  /// as its baseline (the recovery runs before the baseline is read).
  Future<void> restartOldApp() async {
    await Hive.close();
    await HiveService.init(path: directory.path, loadBundle: false);
    await restoreOldBaseline();
  }

  group('what ships', () {
    test('the bundle is internally consistent', () {
      final bundled =
          (ContentStore.instance.bundleManifest!['collections']
                  as Map)['readings']
              as Map;
      expect(readings().length, bundled['count']);
      expect(readings().digest(), bundled['digest']);
      expect({
        for (final id in readings().keys)
          id: documentHash(
            Map<String, dynamic>.from(readings().get(id) as Map),
          ),
      }, readings().effectiveHashes());
      expect(
        (delivery['bundle'] as Map)['hashErrors'],
        isEmpty,
        reason: 'every bundled document hashes to its own hash',
      );
      expect(
        (delivery['bundle'] as Map)['recomputedDigest'],
        bundled['digest'],
      );
    });

    test(
      'the bundle matches the verified production snapshot and reviewed index: '
      'every web-rewritten document is in it',
      () {
        final hashes = (manifest['hashes'] as Map).cast<String, String>();
        final local = readings().effectiveHashes();
        expect(local, hashes);
        expect(readings().digest(), manifest['digest']);
        expect(manifest['digest'], (delivery['production'] as Map)['digest']);
        expect(manifest['version'], 8);
        expect(delivery['removed'], isEmpty);
        expect(delivery['added'], isEmpty);
        expect(delivery['changed'], isEmpty);
        final rewritten = (delivery['rewritten'] as List)
            .cast<Map<String, dynamic>>();
        expect(rewritten, hasLength(324));
        for (final item in rewritten) {
          expect(local[item['id']], item['afterHash'], reason: '${item['id']}');
        }
        expect(
          readings().overlayLength,
          0,
          reason: 'the bundle itself, no overlay',
        );
      },
    );

    test('the corrected Gospel citation is the bundle data (Мц 22)', () {
      final doc = readings().get('ordinary-w28-d1--A') as Map;
      expect((doc['gospel'] as Map)['bible'], 'Мц 22, 1–10');
    });

    test('the captured index publishes proper texts and omits the remaining '
        'Ordo collections', () {
      final published = (captured['current'] as Map)['collections'] as Map;
      for (final name in kOrdoCalendarCollections) {
        expect(published.containsKey(name), isFalse, reason: name);
      }
      expect(published.containsKey('liturgicalProperTexts'), isTrue);
      expect(published.containsKey('liturgicalOrdoNotes'), isFalse);
    });
  });

  group('an app with the current bundle', () {
    test('the reviewed v8 index matches and downloads nothing', () async {
      final remote = ProductionReadingsRemote(usePlannedIndex: true);
      await ContentStore.instance.ensureLoaded(const ['readings']);
      final check = await ContentUpdater(remote: remote).check();
      expect(check.kind, ContentCheckKind.current);
      expect(remote.indexReads, 0);
      expect(remote.fetched, isEmpty);
    });

    test('the captured v7 index cannot roll back the current bundle', () async {
      final capturedReadings = captured['readings'] as Map;
      final bundled =
          (ContentStore.instance.bundleManifest!['collections']
                  as Map)['readings']
              as Map;
      expect(capturedReadings['digest'], isNot(readings().digest()));
      expect(capturedReadings['version'], 7);
      expect(bundled['minimumRemoteVersion'], manifest['version']);
      final remote = ProductionReadingsRemote();
      final check = await ContentUpdater(remote: remote).check();
      expect(check.kind, ContentCheckKind.current);
      expect(remote.indexReads, 0);
      expect(remote.fetched, isEmpty);
      expect(readings().digest(), manifest['digest']);
    });
  });

  group('what an installed phone with the OLD bundle receives', () {
    setUp(installOldBundle);

    test('the old bundle is behind by exactly the documented distance '
        '(BUNDLE_STALE)', () {
      final hashes = (manifest['hashes'] as Map).cast<String, String>();
      final local = readings().effectiveHashes();
      final stale = [
        for (final entry in hashes.entries)
          if (local[entry.key] != entry.value) entry.key,
      ]..sort();
      expect(readings().digest(), historicalCollection['digest']);
      expect(readings().length, historicalCollection['count']);
      expect(stale, download);
      expect(stale, hasLength(366));
    });

    test('the captured v7 index still updates the October bundle', () async {
      final remote = ProductionReadingsRemote();
      final updater = ContentUpdater(remote: remote);
      final check = await updater.check();
      expect(check.kind, ContentCheckKind.patch);
      expect(check.plan!.documents, 363);
      await updater.apply(check.plan!);
      final published = captured['readings'] as Map;
      expect(readings().digest(), published['digest']);
      expect(remote.fetched, check.plan!.collections.single.download);
      expect((await updater.check()).kind, ContentCheckKind.current);
    });

    test(
      'the reviewed v8 index offers a small patch of exactly the stale documents',
      () async {
        final remote = ProductionReadingsRemote(usePlannedIndex: true);
        final check = await ContentUpdater(remote: remote).check();
        expect(check.kind, ContentCheckKind.patch);
        final update = check.plan!.collections.single;
        expect(update.collection, 'readings');
        expect(update.download, download);
        expect(update.remove, removed);
        expect(check.plan!.isRebuildSized, isFalse);
        final sizes = (manifest['sizes'] as Map).cast<String, int>();
        expect(
          update.bytes,
          download.fold<int>(0, (sum, id) => sum + sizes[id]!),
        );
        expect(
          update.download.length / update.existing,
          lessThan(kPatchMaxChangedShare),
        );
        expect(remote.fetched, isEmpty, reason: 'a check downloads no text');
      },
    );

    test('applying it makes the effective digest the published one, '
        'atomically, and a second check is current', () async {
      final remote = ProductionReadingsRemote(usePlannedIndex: true);
      final before = readings().digest();
      final check = await applyPublishedReadings(remote: remote);
      expect(check.kind, ContentCheckKind.patch);
      expect(readings().digest(), manifest['digest']);
      expect(readings().digest(), isNot(before));
      expect(readings().overlayLength, download.length);
      expect(remote.fetched, download);
      final again = await ContentUpdater(remote: remote).check();
      expect(again.kind, ContentCheckKind.current);
    });

    test('a corrupted download changes nothing', () async {
      final remote = ProductionReadingsRemote(
        usePlannedIndex: true,
        corrupt: {download.first},
      );
      final before = readings().digest();
      final updater = ContentUpdater(remote: remote);
      final check = await updater.check();
      await expectLater(
        updater.apply(check.plan!),
        throwsA(isA<ContentUpdateRejected>()),
      );
      expect(readings().digest(), before);
      expect(readings().overlayLength, 0);
    });

    test('offline in the middle of an update: the bundle keeps serving, '
        'nothing is half-installed', () async {
      final remote = ProductionReadingsRemote(
        usePlannedIndex: true,
        failFetch: true,
      );
      final updater = ContentUpdater(remote: remote);
      final before = readings().digest();
      final check = await updater.check();
      await expectLater(
        updater.apply(check.plan!),
        throwsA(isA<SocketException>()),
      );
      expect(remote.fetched, download.take(download.length ~/ 2));
      expect(readings().digest(), before);
      expect(readings().overlayLength, 0);
      final loaded = loadReadingsForDate(
        service: ParsedReadingsService(),
        calendar: CalendarService(),
        date: DateTime(2026, 10, 12),
        dayId: null,
        diocese: 'minsk-mohilev',
      );
      expect(loaded, isNotNull);
      expect(loaded!.readings, isNotEmpty);
    });

    for (final phase in ContentCommitPhase.values) {
      test('interrupted after ${phase.name}: after a restart the phone has '
          'the bundle or the whole published set, never a mix', () async {
        final remote = ProductionReadingsRemote(usePlannedIndex: true);
        final updater = ContentUpdater(remote: remote);
        await ContentStore.instance.ensureLoaded(const ['readings']);
        final plan = (await updater.check()).plan!;
        // Stage the same generation the updater would, then stop.
        final staged = <String, Map<String, Map<String, dynamic>?>>{};
        final docs = await remote.fetchDocuments(
          'readings',
          plan.collections.single.download,
        );
        staged['readings'] = readings().planUpdate(
          {for (final id in plan.collections.single.download) id: docs[id]},
          plan.collections.single.hashes,
          plan.contentVersion,
        );
        final bundleDigest = readings().digest();
        await ContentStore.instance.commit(
          staged,
          plan.contentVersion,
          stopAfter: phase,
        );
        // The process dies here: a new run opens the same storage.
        await restartOldApp();
        final digest = readings().digest();
        final complete = digest == manifest['digest'];
        if (phase == ContentCommitPhase.staged) {
          expect(digest, bundleDigest, reason: 'not READY: dropped');
        } else {
          expect(complete, isTrue, reason: 'READY: replayed at start');
        }
        // Never a mix: the digest is one of the two published states.
        expect({bundleDigest, manifest['digest']}.contains(digest), isTrue);
      });
    }
  });

  group('overlay against a newer bundle', () {
    setUp(installOldBundle);
    test('OVERLAY_STALE: an app update whose bundle already has the '
        'published documents drops the overlay (the bundle wins)', () async {
      await applyPublishedReadings(
        remote: ProductionReadingsRemote(usePlannedIndex: true),
      );
      expect(readings().overlayLength, download.length);
      await readings().debugReplaceBaseline(
        bundledDocs,
        bundledHashes,
        bundledVersion,
      );
      expect(readings().overlayLength, 0);
      expect(readings().digest(), manifest['digest']);
    });

    test('a document newer than the new bundle survives', () async {
      await applyPublishedReadings(
        remote: ProductionReadingsRemote(usePlannedIndex: true),
      );
      final id = download.first;
      final keep = readings().get(id);
      await readings().debugReplaceBaseline(
        {...bundledDocs, id: oldBaseDocs[id]!},
        {...bundledHashes, id: oldBaseHashes[id]!},
        historicalCollection['contentVersion'] as int,
      );
      expect(readings().overlayEntry(id), isNotNull);
      expect(readings().get(id), keep);
    });
  });
}
