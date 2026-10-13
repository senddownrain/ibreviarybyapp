// Delivery chain of the `readings` collection on the REAL published manifest
// (readings v7, digest 93314983ba9c1bd5; production snapshot of 2026-10-13
// after the web migration of 324 documents).
//
// The shipped bundle is now built from that export: bundle == manifest. The
// scenarios of the former situation stay, run against an app that still
// ships the OLD (2026-10-07) bundle:
//
//   BUNDLE_STALE   the shipped bundle differs from the published manifest
//   OVERLAY_STALE  an overlay document older than the bundle/manifest
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
  final manifest = (delivery['manifest'] as Map)['readings'] as Map;
  final old = delivery['old'] as Map<String, dynamic>;
  // What the OLD bundle lacks / has in another version.
  final changed = (old['changed'] as List).cast<String>()..sort();

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
  Map<String, Map<String, dynamic>>? oldBaseDocs;
  Map<String, String>? oldBaseHashes;

  Future<void> installOldBundle() async {
    final oldDocs = (old['documents'] as Map).cast<String, dynamic>();
    final oldHashes = (old['hashes'] as Map).cast<String, String>();
    final docs = <String, Map<String, dynamic>>{
      for (final key in readings().keys)
        key: oldDocs[key] != null
            ? Map<String, dynamic>.from(oldDocs[key] as Map)
            : Map<String, dynamic>.from(readings().get(key) as Map),
    };
    final hashes = <String, String>{
      for (final entry in readings().effectiveHashes().entries)
        if (entry.value != null) entry.key: entry.value!,
      ...oldHashes,
    };
    oldBaseDocs = docs;
    oldBaseHashes = hashes;
    await readings().debugReplaceBaseline(
      docs,
      hashes,
      old['contentVersion'] as int,
    );
  }

  /// The process of the OLD app restarts: the same storage, the old bundle
  /// as its baseline (the recovery runs before the baseline is read).
  Future<void> restartOldApp() async {
    await Hive.close();
    await HiveService.init(path: directory.path, loadBundle: false);
    await readings().debugReplaceBaseline(
      oldBaseDocs!,
      oldBaseHashes!,
      old['contentVersion'] as int,
    );
  }

  group('what ships', () {
    test('the bundle is internally consistent', () {
      final bundled =
          (ContentStore.instance.bundleManifest!['collections']
                  as Map)['readings']
              as Map;
      expect(readings().length, bundled['count']);
      expect(readings().digest(), bundled['digest']);
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

    test('the bundle equals the published manifest: no stale document, '
        'every web-rewritten document is in it', () {
      final hashes = (manifest['hashes'] as Map).cast<String, String>();
      final local = readings().effectiveHashes();
      expect(local, hashes);
      expect(readings().digest(), manifest['digest']);
      expect(manifest['digest'], '93314983ba9c1bd5');
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
    });

    test('the corrected Gospel citation is the bundle data (Мц 22)', () {
      final doc = readings().get('ordinary-w28-d1--A') as Map;
      expect((doc['gospel'] as Map)['bible'], 'Мц 22, 1–10');
    });

    test('the Ordo collections are bundle-only: the manifest names none of '
        'them, so a phone never gets them as a patch', () {
      final published =
          (((delivery['manifest'] as Map)['current'] as Map)['collections']
              as Map);
      for (final name in kOrdoCalendarCollections) {
        expect(published.containsKey(name), isFalse, reason: name);
      }
      expect(published.containsKey('liturgicalProperTexts'), isFalse);
      expect(published.containsKey('liturgicalOrdoNotes'), isFalse);
    });
  });

  group('an app with the current bundle', () {
    test('the version check says current and downloads nothing', () async {
      final remote = ProductionReadingsRemote();
      await ContentStore.instance.ensureLoaded(const ['readings']);
      final check = await ContentUpdater(remote: remote).check();
      expect(check.kind, ContentCheckKind.current);
      expect(remote.fetched, isEmpty);
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
      expect(stale, changed);
      expect(stale, hasLength(363));
      expect(readings().digest(), isNot(manifest['digest']));
    });

    test(
      'the check offers a small patch of exactly the stale documents',
      () async {
        final remote = ProductionReadingsRemote();
        final check = await ContentUpdater(remote: remote).check();
        expect(check.kind, ContentCheckKind.patch);
        final update = check.plan!.collections.single;
        expect(update.collection, 'readings');
        expect(update.download, changed);
        expect(update.remove, isEmpty);
        expect(check.plan!.isRebuildSized, isFalse);
        // 363 of 822 documents = 44.2 %: below the client's rebuild guard
        // (more than 50 % of the collection).
        expect(update.download.length / 822, lessThan(0.5));
        expect(remote.fetched, isEmpty, reason: 'a check downloads no text');
      },
    );

    test('applying it makes the effective digest the published one, '
        'atomically, and a second check is current', () async {
      final remote = ProductionReadingsRemote();
      final before = readings().digest();
      final check = await applyPublishedReadings(remote: remote);
      expect(check.kind, ContentCheckKind.patch);
      expect(readings().digest(), manifest['digest']);
      expect(readings().digest(), isNot(before));
      expect(readings().overlayLength, changed.length);
      expect(remote.fetched.toSet(), changed.toSet());
      final again = await ContentUpdater(remote: remote).check();
      expect(again.kind, ContentCheckKind.current);
    });

    test('a corrupted download changes nothing', () async {
      final remote = ProductionReadingsRemote(corrupt: {changed.first});
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
      final remote = ProductionReadingsRemote(failFetch: true);
      final updater = ContentUpdater(remote: remote);
      final check = await updater.check();
      await expectLater(
        updater.apply(check.plan!),
        throwsA(isA<SocketException>()),
      );
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
        final remote = ProductionReadingsRemote();
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
      await applyPublishedReadings();
      expect(readings().overlayLength, changed.length);
      // The next app release ships production as its bundle.
      final docs = <String, Map<String, dynamic>>{
        for (final key in readings().keys)
          key: Map<String, dynamic>.from(readings().get(key) as Map),
      };
      final hashes = (manifest['hashes'] as Map).cast<String, String>();
      await readings().debugReplaceBaseline(
        docs,
        hashes,
        ((delivery['manifest'] as Map)['current'] as Map)['contentVersion']
                as int? ??
            0,
      );
      expect(readings().overlayLength, 0);
      expect(readings().digest(), manifest['digest']);
    });

    test('a document newer than the new bundle survives', () async {
      await applyPublishedReadings();
      final id = changed.first;
      final keep = Map<String, dynamic>.from(readings().get(id) as Map);
      await readings().debugReplaceBaseline(
        {
          for (final key in readings().keys)
            key: key == id
                ? {...keep, 'title': 'older bundle text'}
                : Map<String, dynamic>.from(readings().get(key) as Map),
        },
        {
          for (final entry in readings().effectiveHashes().entries)
            if (entry.value != null && entry.key != id) entry.key: entry.value!,
          id: 'oldhash',
        },
        1,
      );
      expect(readings().overlayEntry(id), isNotNull);
    });
  });
}
