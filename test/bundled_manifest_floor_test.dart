import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/content/content_updater.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

class _OldManifest implements ContentRemote {
  _OldManifest(this.entries);
  final Map<String, dynamic> entries;
  int manifests = 0, downloads = 0;
  @override
  Future<Map<String, dynamic>?> fetchCurrent() async => {
    'schemaVersion': 1,
    'contentVersion': 1794938108754,
    'collections': entries,
  };
  @override
  Future<Map<String, dynamic>?> fetchCollectionManifest(String c) async {
    manifests++;
    throw StateError('Stale index must be ignored');
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchDocuments(
    String c,
    List<String> ids,
  ) async {
    downloads++;
    throw StateError('Never download stale content');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'older published indexes cannot roll back newer bundled source/category snapshots',
    () async {
      final dir = await Directory.systemTemp.createTemp('bundle-floor-');
      try {
        await HiveService.init(path: dir.path, loadBundle: true);
        final store = ContentStore.instance;
        await store.ensureLoaded(kContentCollections);
        await store.idle();
        final entries = <String, dynamic>{};
        for (final n in ['readings', 'prayers', 'prayerCategories', 'songs']) {
          final e = (store.bundleManifest!['collections'] as Map)[n] as Map;
          final floor = (e['minimumRemoteVersion'] as num).toInt();
          expect(floor, greaterThan(0));
          entries[n] = {'digest': 'old index', 'version': floor - 1};
        }
        final before = {
          for (final n in entries.keys) n: store.collection(n).digest(),
        };
        await HiveService.settingsBox.put('favoriteIds', '["mine"]');
        await HiveService.localPrayersBox.put('mine', {'title': 'Мая'});
        final remote = _OldManifest(entries);
        expect(
          (await ContentUpdater(remote: remote).check()).kind,
          ContentCheckKind.current,
        );
        expect(remote.manifests, 0);
        expect(remote.downloads, 0);
        expect({
          for (final n in entries.keys) n: store.collection(n).digest(),
        }, before);
        expect(HiveService.settingsBox.get('favoriteIds'), '["mine"]');
        expect(HiveService.localPrayersBox.get('mine'), isNotNull);
      } finally {
        await ContentStore.instance.idle();
        await Hive.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
