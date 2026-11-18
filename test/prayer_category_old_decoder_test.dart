// This test deliberately uses only APIs present in Flutter main 60e8e7f.
// Copy unchanged into that checkout before implementing the new model/policy.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/prayers_screen.dart';

const _fixtureDir = 'test/fixtures/prayer-categories';

class _SyntheticBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(
      '$_fixtureDir/${key.split('/').last}',
    ).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

class _Settings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bytes = File('$_fixtureDir/prayerCategories.json.gz').readAsBytesSync();
  final decoded = decodeContentCollection(bytes);

  test(
    'OLD DECODER x NEW GZIP: schema, string table, hashes and old model',
    () {
      final wire =
          jsonDecode(utf8.decode(GZipDecoder().decodeBytes(bytes))) as Map;
      expect(wire['schemaVersion'], kContentSchemaVersion);
      expect(wire['strings'], isNotEmpty);
      expect(decoded.collection, 'prayerCategories');
      expect(
        decoded.docs.keys,
        containsAll(['root', 'middle', 'leaf', 'legacy', 'folder']),
      );
      for (final entry in decoded.docs.entries) {
        expect(documentHash(entry.value), decoded.hashes[entry.key]);
        final category = PrayerMenuCategory.global(entry.key, entry.value);
        expect(category.id, entry.key);
        expect(category.name, entry.value['name']);
        expect(category.tags, entry.value['tags']);
        expect(category.parentId, entry.value['parentId']);
      }
      expect(decoded.docs['root']!['prayerIds'], [
        'manual',
        'both',
        'shared-private',
      ]);
      expect(decoded.docs['folder']!['tags'], isEmpty);
      expect(decoded.docs['legacy']!.containsKey('prayerIds'), isFalse);
      expect(decoded.docs['codec-probe']!['prayerIds'], [
        'synthetic-opaque-prayer-reference-longer-than-32',
      ]);
    },
  );

  test(
    'OLD ContentStore: bundle, update overlay, close/restart/reload',
    () async {
      final directory = await Directory.systemTemp.createTemp('old-decoder-');
      final store = ContentStore.instance;
      Hive.init(directory.path);
      try {
        await store.open(bundle: _SyntheticBundle());
        await store.ensureLoaded(['prayerCategories', 'prayers']);
        final collection = store.collection('prayerCategories');
        expect(collection.get('root')['prayerIds'], [
          'manual',
          'both',
          'shared-private',
        ]);
        expect(
          store.collection('prayers').keys,
          isNot(contains('shared-private')),
        );
        final updated = <String, dynamic>{
          ...decoded.docs['root']!,
          'prayerIds': ['manual'],
        };
        await store.commit({
          'prayerCategories': collection.planUpdate(
            {'root': updated},
            {'root': documentHash(updated)},
            2000,
          ),
        }, 2000);
        await Hive.close();
        await store.open(bundle: _SyntheticBundle());
        await store.ensureLoaded(['prayerCategories', 'prayers']);
        expect(collection.get('root')['prayerIds'], ['manual']);
        expect(collection.get('root')['name'], 'Fixture root');
        expect(collection.get('leaf')['parentId'], 'middle');
        expect(
          collection.get('codec-probe')['iconId'],
          'synthetic-existing-icon-id',
        );
      } finally {
        await store.idle();
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets('OLD category list UI accepts new documents without crashing', (
    tester,
  ) async {
    final category = PrayerMenuCategory.global('root', decoded.docs['root']!);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_Settings.new),
          prayerMenuCategoriesProvider.overrideWithValue([category]),
          prayerCatalogProvider.overrideWithValue(const [
            Prayer(id: 'tagged', title: 'Synthetic prayer', tags: ['root-tag']),
          ]),
        ],
        child: const MaterialApp(
          home: PrayerCategoryScreen(categoryId: 'root'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fixture root'), findsOneWidget);
    expect(find.text('Synthetic prayer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
