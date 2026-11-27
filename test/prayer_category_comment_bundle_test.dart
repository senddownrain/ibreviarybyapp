import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/content/content_updater.dart';
import 'package:mybrev_flutter/models/prayer_menu_category.dart'
    show isPublishedPrayerCategory;
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';

import 'content_offline_test.dart' show FakeRemote;
import 'prayer_category_contract_test.dart' show fixtureDirectory;
import 'priest_access_test.dart' show MemoryStorage, SparkGateway;

const _newFixture = 'test/fixtures/prayer-category-comments';
const _categories = 'prayerCategories';

class _FixtureBundle extends CachingAssetBundle {
  _FixtureBundle(this.directory);
  final String directory;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    await File('$directory/${key.split('/').last}').readAsBytes(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy bundle still decodes categories without comments', () {
    final bundle = decodeContentCollection(
      File('$fixtureDirectory/$_categories.json.gz').readAsBytesSync(),
    );
    expect(bundle.docs, isNotEmpty);
    for (final entry in bundle.docs.entries) {
      expect(PrayerMenuCategory.global(entry.key, entry.value).comment, isNull);
    }
  });

  test('shipped bundle decodes categories and preserves comments', () async {
    final data = await rootBundle.load(
      '$kContentAssetDir/$_categories.json.gz',
    );
    final bundle = decodeContentCollection(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    expect(bundle.docs, isNotEmpty);
    for (final entry in bundle.docs.entries) {
      expect(documentHash(entry.value), bundle.hashes[entry.key]);
      final category = PrayerMenuCategory.global(entry.key, entry.value);
      final raw = entry.value['comment'];
      if (raw is Map &&
          isPublishedPrayerCategory(entry.value) &&
          isPublishedPrayerCategory(raw) &&
          raw['content'] is String &&
          (raw['content'] as String).trim().isNotEmpty) {
        expect(category.comment?.content, raw['content'], reason: entry.key);
      } else {
        expect(category.comment, isNull, reason: entry.key);
      }
    }
  });

  test(
    'new Web-generated bundle preserves nested fields and excludes restricted ancestry',
    () {
      final bytes = File('$_newFixture/$_categories.json.gz').readAsBytesSync();
      final bundle = decodeContentCollection(bytes);
      expect(bundle.docs, contains('comment-leaf'));
      for (final id in [
        'restricted',
        'restricted-child',
        'canonical-private',
        'canonical-child',
        'unpublished',
        'unpublished-child',
      ]) {
        expect(bundle.docs, isNot(contains(id)));
      }
      for (final entry in bundle.docs.entries) {
        expect(documentHash(entry.value), bundle.hashes[entry.key]);
      }
      final root = PrayerMenuCategory.global('root', bundle.docs['root']!);
      expect(root.comment?.title, 'Тлумачэнне');
      expect(root.comment?.sourceId, 'ojcha-nash-2022');
      expect(root.comment?.content, contains('**тэкст**'));
      expect(root.prayerIds, ['manual', 'both', 'shared-private']);
    },
  );

  test(
    'comment update and bundle replacement persist offline with favorites and settings',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'category-comments-',
      );
      final store = ContentStore.instance;
      final gateway = SparkGateway();
      Hive.init(directory.path);

      Future<void> open(String fixture) async {
        await Hive.openBox('settings');
        await store.open(bundle: _FixtureBundle(fixture));
        await store.ensureLoaded(const ['prayers', _categories]);
      }

      Future<void> verify(String? expectedContent) async {
        final container = ProviderContainer(
          overrides: [
            priestAccessProvider.overrideWith(
              (ref) => PriestAccessController(gateway, MemoryStorage()),
            ),
          ],
        );
        try {
          final categories = await container.read(
            globalPrayerCategoriesProvider.future,
          );
          final root = categories.singleWhere(
            (category) => category.id == 'root',
          );
          expect(root.comment?.content, expectedContent);
          expect(container.read(settingsProvider).favoriteIds, ['manual']);
          expect(container.read(settingsProvider).fontSize, 24);
        } finally {
          container.dispose();
        }
      }

      try {
        await open(fixtureDirectory);
        await Hive.box(
          'settings',
        ).putAll({'favoriteIds': '["manual"]', 'fontSize': 24.0});
        await verify(null);

        final next = decodeContentCollection(
          File('$_newFixture/$_categories.json.gz').readAsBytesSync(),
        );
        final original = next.docs['root']!;
        final originalComment =
            (original['comment'] as Map)['content'] as String;
        final remote = FakeRemote({
          _categories: next.docs,
        }, contentVersion: 2000);
        final updater = ContentUpdater(remote: remote);
        final check = await updater.check();
        await updater.apply(check.plan!);
        expect(
          remote.fetched,
          unorderedEquals([
            '$_categories/root',
            '$_categories/comment-parent',
            '$_categories/comment-leaf',
          ]),
        );

        await Hive.close();
        await open(fixtureDirectory);
        await verify(originalComment);

        await Hive.close();
        await open(_newFixture);
        expect(Hive.box('content_$_categories'), isEmpty);
        await verify(originalComment);

        final updated = {
          ...original,
          'comment': {'content': 'Updated text'},
        };
        final cleared = {...original}..remove('comment');
        expect(documentHash(updated), isNot(documentHash(original)));
        expect(documentHash(cleared), isNot(documentHash(updated)));
        for (final (version, row, expected) in [
          (3000, updated, 'Updated text'),
          (4000, cleared, null),
        ]) {
          final remote = FakeRemote({
            _categories: {...next.docs, 'root': row},
          }, contentVersion: version);
          final updater = ContentUpdater(remote: remote);
          await updater.apply((await updater.check()).plan!);
          expect(remote.fetched, ['$_categories/root']);
          await Hive.close();
          await open(_newFixture);
          await verify(expected);
          expect(store.collection(_categories).get('root'), row);
        }
      } finally {
        await store.idle();
        await gateway.close();
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
