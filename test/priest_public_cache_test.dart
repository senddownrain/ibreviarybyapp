import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_migration.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'public snapshot removes private records, compacts old frames and keeps user data',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'priest-public-cache-',
      );
      try {
        await HiveService.init(path: temp.path, loadBundle: false);
        await HiveService.prayerCategoriesBox.put('closed', {
          'priestOnly': true,
          'tags': ['closed'],
        });
        await HiveService.prayersBox.put('closed', {
          'title': 'Closed',
          'text': 'PRIVATE-TEXT-SENTINEL',
          'tags': ['closed'],
        });
        await HiveService.prayersBox.put('public', {
          'title': 'Public',
          'text': 'Before',
          'tags': ['public'],
        });
        await HiveService.settingsBox.put('favoriteIds', ['closed', 'public']);
        await HiveService.localPrayersBox.put('local', {'text': 'Personal'});
        var sdkClears = 0;
        Future<void> clearSdk() async {
          sdkClears++;
        }

        await HiveService.sanitizeLegacyFirestoreCache(clearSdk);
        await HiveService.sanitizeLegacyFirestoreCache(clearSdk);
        expect(sdkClears, 1);
        final snapshot = PrayerAccessContent(
          {
            'public': {
              'id': 'public',
              'title': 'Public',
              'text': 'After',
              'tags': ['public'],
            },
          },
          {
            'public': {
              'id': 'public',
              'tags': ['public'],
            },
          },
        );
        await persistPublicPrayerContent(snapshot);
        expect(HiveService.prayersBox.get('closed'), null);
        expect(HiveService.prayersBox.get('public')['text'], 'After');
        expect(HiveService.settingsBox.get('favoriteIds'), [
          'closed',
          'public',
        ]);
        expect(HiveService.localPrayersBox.get('local')['text'], 'Personal');
        await Hive.close();
        for (final file in temp.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.hive'),
        )) {
          expect(
            latin1.decode(file.readAsBytesSync()),
            isNot(contains('PRIVATE-TEXT-SENTINEL')),
          );
        }
        await HiveService.init(path: temp.path, loadBundle: false);
        expect(ContentStore.instance.collection('prayers').get('closed'), null);
        expect(HiveService.settingsBox.get('favoriteIds'), [
          'closed',
          'public',
        ]);
      } finally {
        await Hive.close();
        await temp.delete(recursive: true);
      }
    },
  );
  test('a protected snapshot is rejected before any disk write', () async {
    final temp = await Directory.systemTemp.createTemp(
      'priest-rejected-cache-',
    );
    try {
      await HiveService.init(path: temp.path, loadBundle: false);
      await expectLater(
        persistPublicPrayerContent(
          const PrayerAccessContent({
            'closed': {'priestOnly': true, 'text': 'Private'},
          }, {}),
        ),
        throwsFormatException,
      );
      expect(HiveService.prayersBox.keys, isEmpty);
    } finally {
      await Hive.close();
      await temp.delete(recursive: true);
    }
  });
  test(
    'new public bundle removes migrated IDs with false legacy flags, '
    'even from newer overlays; user data and later public updates survive',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'priest-bundle-upgrade-',
      );
      final manifest =
          jsonDecode(File('assets/content/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      final cleanup = PriestCacheCleanup.fromManifest(manifest);
      final privateId = cleanup.prayers.first,
          categoryId = cleanup.categories.first;
      final newer = DateTime.now().millisecondsSinceEpoch + 86400000;
      try {
        await HiveService.init(path: temp.path, loadBundle: false);
        await HiveService.prayersBox.put(privateId, {
          'text': 'FORMERLY-PUBLIC-PRIVATE-SENTINEL',
          'priestOnly': false,
          'effectivePriestOnly': false,
        }, version: newer);
        await HiveService.prayerCategoriesBox.put(categoryId, {
          'name': 'Old category',
          'priestOnly': false,
        }, version: newer);
        await HiveService.prayersBox.put('new-public', {
          'text': 'PUBLIC-KEEP',
        }, version: newer);
        await HiveService.settingsBox.put('favoriteIds', [
          privateId,
          'new-public',
        ]);
        await HiveService.localPrayersBox.put('mine', {
          'text': 'PERSONAL-KEEP',
        });
        await HiveService.metaBox.put('priestPublicCacheSanitizedV1', true);
        await HiveService.metaBox.put('priestFirestoreCacheSanitizedV1', true);
        await Hive.close();
        await HiveService.init(path: temp.path, loadBundle: true);
        await HiveService.content.ensureLoaded(kContentCollections);
        expect(HiveService.prayersBox.get(privateId), null);
        expect(HiveService.prayerCategoriesBox.get(categoryId), null);
        expect(HiveService.prayersBox.get('new-public')['text'], 'PUBLIC-KEEP');
        expect(HiveService.settingsBox.get('favoriteIds'), [
          privateId,
          'new-public',
        ]);
        expect(
          HiveService.localPrayersBox.get('mine')['text'],
          'PERSONAL-KEEP',
        );
        var clears = 0;
        await HiveService.sanitizeLegacyFirestoreCache(() async {
          clears++;
        });
        await HiveService.sanitizeLegacyFirestoreCache(() async {
          clears++;
        });
        expect(
          clears,
          1,
          reason: 'The former V1 marker must not skip the new migration',
        );
        for (final file in temp.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.hive'),
        )) {
          expect(
            latin1.decode(file.readAsBytesSync()),
            isNot(contains('FORMERLY-PUBLIC-PRIVATE-SENTINEL')),
          );
        }
        // A subsequent authorized PUBLIC server snapshot may reopen this ID.
        // The cleanup is an upgrade, not a permanent local access decision.
        await HiveService.prayersBox.put(privateId, {
          'text': 'REOPENED-PUBLIC',
        }, version: newer);
        await Hive.close();
        await HiveService.init(path: temp.path, loadBundle: true);
        await HiveService.content.ensureLoaded(kContentCollections);
        expect(
          HiveService.prayersBox.get(privateId)['text'],
          'REOPENED-PUBLIC',
        );
      } finally {
        await Hive.close();
        await temp.delete(recursive: true);
      }
    },
  );
  test(
    'legacy cache cannot reintroduce migrated IDs after startup cleanup',
    () async {
      final temp = await Directory.systemTemp.createTemp('priest-old-cache-');
      try {
        await HiveService.init(path: temp.path, loadBundle: true);
        await HiveService.content.ensureLoaded(kContentCollections);
        final cleanup = PriestCacheCleanup.fromManifest(
          HiveService.content.bundleManifest,
        );
        await HiveService.metaBox.delete(kContentModelKey);
        final old = await Hive.openBox('prayers');
        await old.put(cleanup.prayers.first, {
          'text': 'LEGACY-PRIVATE-SENTINEL',
          'priestOnly': false,
          'updatedAt': DateTime.now().millisecondsSinceEpoch + 86400000,
        });
        await ContentMigration(HiveService.metaBox).run();
        expect(HiveService.prayersBox.get(cleanup.prayers.first), null);
        expect(await Hive.boxExists('prayers'), false);
      } finally {
        await Hive.close();
        await temp.delete(recursive: true);
      }
    },
  );
}
