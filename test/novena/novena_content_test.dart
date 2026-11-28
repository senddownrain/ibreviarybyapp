import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/content/content_updater.dart';
import 'package:mybrev_flutter/novena/novena_definition.dart';
import 'package:mybrev_flutter/novena/novena_providers.dart';
import 'package:mybrev_flutter/novena/novena_store.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

import 'support.dart';

/// A publication that names only `novenaDefinitions`.
class _Remote implements ContentRemote {
  _Remote(this.docs);
  final Map<String, Map<String, dynamic>> docs;
  Map<String, String> get hashes => {
    for (final MapEntry(:key, :value) in docs.entries) key: documentHash(value),
  };

  @override
  Future<Map<String, dynamic>?> fetchCurrent() async => {
    'schemaVersion': kContentSchemaVersion,
    'contentVersion': DateTime(2030).millisecondsSinceEpoch,
    'collections': {
      kNovenaCollection: {'digest': contentDigest(hashes), 'version': 1},
    },
  };

  @override
  Future<Map<String, dynamic>?> fetchCollectionManifest(String name) async => {
    'digest': contentDigest(hashes),
    'hashes': hashes,
  };

  @override
  Future<Map<String, Map<String, dynamic>>> fetchDocuments(
    String name,
    List<String> ids,
  ) async => {for (final id in ids) id: docs[id]!};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundle ships the published novenas; a later publication patches '
      'them and the calendar suggests on the start date', () async {
    final directory = await Directory.systemTemp.createTemp('novena-content-');
    addTearDown(() async {
      await ContentStore.instance.idle();
      await Hive.close();
      await directory.delete(recursive: true);
    });
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.idle();
    final collection = ContentStore.instance.collection(kNovenaCollection);
    expect(collection.isLoaded, isTrue);
    expect(collection.length, 55);

    // What ships is published and assembles from the shipped public prayers.
    final prayers = bundledPrayers();
    for (final doc in bundledDocs(kNovenaCollection).values) {
      final definition = NovenaDefinition.tryParse(doc)!;
      expect(definition.isPublished, isTrue, reason: definition.title);
      expect(
        definition.resolveAll(prayers),
        isNotNull,
        reason: definition.title,
      );
    }

    final docs = bundledDocs(kNovenaCollection);
    final first = docs.keys.first;
    final remote = _Remote({
      ...docs,
      first: {...docs[first]!, 'contentVersion': 2},
    });
    final updater = ContentUpdater(remote: remote);
    final check = await updater.check();
    expect(check.kind, ContentCheckKind.patch);
    await updater.apply(check.plan!);
    expect(collection.length, 55);
    expect((collection.get(first) as Map)['contentVersion'], 2);

    var now = DateTime(2027, 5, 7);
    final container = ProviderContainer(
      overrides: [
        novenaBoxProvider.overrideWithValue(MemoryNovenaBox()),
        novenaClockProvider.overrideWithValue(() => now),
        novenaPublicPrayersProvider.overrideWithValue(bundledPrayers()),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(novenaDefinitionsProvider), hasLength(55));
    final subscription = container.listen(novenaSuggestionsProvider, (_, _) {});
    for (var i = 0; i < 100 && subscription.read().length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    // 7 May 2027: Pentecost minus nine days from the app's own calendar, and
    // the fixed date of St Andrew Bobola (16 May).
    expect(
      {for (final item in subscription.read()) item.definition.novenaId},
      {'Iiufha8NyLABTw92rA5S', 'cn_c3f7320a05c0e7c7'},
    );
    now = DateTime(2027, 5, 8);
    container.read(novenaTodayProvider.notifier).refresh();
    expect(subscription.read(), isEmpty);
  });
}
