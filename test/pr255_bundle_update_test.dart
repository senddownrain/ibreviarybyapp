// Real bundle and old released-bundle hashes; fake remote only, never Firebase.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/content/content_updater.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

import 'content_offline_test.dart' show FakeRemote, bundled;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const names = ['days', 'liturgicalTemplates', 'liturgicalProperTexts'];
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pr255-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
    await ContentStore.instance.idle();
  });
  tearDown(() async {
    await ContentStore.instance.idle();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('new bundle is current against its exact future publication', () async {
    final remote = FakeRemote({for (final n in names) n: bundled(n)});
    expect(
      (await ContentUpdater(remote: remote).check()).kind,
      ContentCheckKind.current,
    );
    expect(remote.manifestReads, isEmpty);
    expect(remote.fetched, isEmpty);
  });

  test(
    'real old hashes require app release; no documents downloaded',
    () async {
      final old =
          jsonDecode(
                File(
                  'test/fixtures/pr255_previous_hashes.json',
                ).readAsStringSync(),
              )
              as Map;
      final remote = FakeRemote({
        for (final n in names) n: bundled(n),
      }, contentVersion: 1794815100000);
      for (final n in names) {
        final collection = ContentStore.instance.collection(n);
        await collection.debugReplaceBaseline(
          bundled(n),
          (old[n] as Map).cast<String, String>(),
          1794092262000,
        );
      }
      final before = ContentStore.instance.collection('days').digest();
      final check = await ContentUpdater(remote: remote).check();
      expect(check.kind, ContentCheckKind.appReleaseRequired);
      expect(check.reason, AppReleaseReason.rebuild);
      expect(check.plan, isNull);
      expect(remote.fetched, isEmpty);
      expect(ContentStore.instance.collection('days').digest(), before);
      expect(ContentStore.instance.collection('days').overlayLength, 0);
    },
  );

  test(
    'apply refuses a manually supplied mass rebuild before network',
    () async {
      final remote = FakeRemote({});
      final plan = ContentUpdatePlan(
        contentVersion: 1794815100000,
        collections: [
          CollectionUpdate(
            collection: 'days',
            download: ['example'],
            remove: [],
            hashes: {},
            bytes: 1,
            changed: 734,
            existing: 736,
          ),
        ],
      );
      await expectLater(
        ContentUpdater(remote: remote).apply(plan),
        throwsA(isA<ContentUpdateRejected>()),
      );
      expect(remote.fetched, isEmpty);
      expect(ContentStore.instance.collection('days').overlayLength, 0);
    },
  );

  test(
    'app upgrade drops old overlay and survives offline Hive restart',
    () async {
      final collection = ContentStore.instance.collection('days');
      final docs = bundled('days');
      final id = 'advent-21-12';
      await collection.put(id, {
        ...docs[id]!,
        'vesperR': 'old cached text',
      }, version: 1794092262000);
      await collection.debugReplaceBaseline(docs, {
        for (final e in docs.entries) e.key: documentHash(e.value),
      }, 1794815100000);
      expect(collection.get(id), docs[id]);
      expect(collection.overlayLength, 0);
      await ContentStore.instance.idle();
      await Hive.close();
      await HiveService.init(path: directory.path, loadBundle: true);
      await ContentStore.instance.ensureLoaded(kContentCollections);
      await ContentStore.instance.idle();
      expect(ContentStore.instance.collection('days').get(id), docs[id]);
    },
  );
}
