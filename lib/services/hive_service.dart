import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_migration.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/services/priest_access_policy.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';

const kTemplatesBoxName = 'liturgicalTemplates';

/// Local storage.
///
/// * Canonical content (Liturgy of the Hours, readings, prayers, songs, …)
///   ships with the app and is read through [ContentStore]; Hive keeps only
///   documents updated after the app was built (`content_<collection>`).
/// * Hive boxes of the reader's own data: `settings` (preferences,
///   highlights, favourites), `localPrayers`, `meta` (update bookkeeping).
class HiveService {
  static const _metaBox = 'meta';
  static const _localPrayersBoxName = 'localPrayers';
  static const _settingsBoxName = 'settings';

  static late Box _meta;
  static late Box _localPrayers;
  static Box? _settings;

  static ContentStore get content => ContentStore.instance;

  /// The liturgical collections are decoded and readable.
  static bool get isCacheReady =>
      Hive.isBoxOpen(_metaBox) && content.areLoaded(kLiturgicalCollections);

  static ContentCollection get prayersBox => content.collection('prayers');
  static ContentCollection get daysBox => content.collection('days');
  static ContentCollection get readingsBox => content.collection('readings');
  static ContentCollection get invitatoriumsBox =>
      content.collection('invitatoriums');
  static ContentCollection get completoriumsBox =>
      content.collection('completoriums');
  static ContentCollection get templatesBox =>
      content.collection(kTemplatesBoxName);
  static ContentCollection get prayerCategoriesBox =>
      content.collection('prayerCategories');
  static ContentCollection get songsBox => content.collection('songs');

  static Box get metaBox => _meta;
  static Box get localPrayersBox => _localPrayers;
  static bool get isSettingsReady =>
      (_settings?.isOpen ?? false) || Hive.isBoxOpen(_settingsBoxName);
  static Box get settingsBox => _settings ?? Hive.box(_settingsBoxName);

  /// `liturgicalTemplates` by id (a handful of documents).
  static Map<String, Map<String, dynamic>> templates() => {
    for (final key in templatesBox.keys)
      if (templatesBox.get(key) case final Map raw)
        key: Map<String, dynamic>.from(raw),
  };

  /// Writes one entry of a plain Hive box (the Compendium copy).
  static Future<void> putCached(String box, dynamic key, Object data) =>
      Hive.box(box).put(key, data);

  static Future<void> removeCached(String box, dynamic key) =>
      Hive.box(box).delete(key);

  /// Opens storage. [loadBundle] false (tests): the content starts empty
  /// and is seeded through the collections' `put`.
  static Future<void> init({
    String? path,
    AssetBundle? bundle,
    bool? loadBundle,
  }) async {
    if (path == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(path);
    }
    _meta = await Hive.openBox(_metaBox);
    _localPrayers = await Hive.openBox(_localPrayersBoxName);
    _settings = await Hive.openBox(_settingsBoxName);
    // main awaits init before constructing ProviderScope. Complete the one-key
    // migration here, where write/flush failures propagate to the initializer;
    // synchronous settings reads must never start unobserved disk writes.
    final settings = _settings!;
    final psalmodyMode = resolvePsalmodyMode(
      storedMode: settings.get('psalmodyMode'),
      legacyLayout: settings.get('psalmVerseLayout'),
      legacyBreakMode: settings.get('psalmMarkerBreakMode'),
    );
    if (settings.get('psalmodyMode') != psalmodyMode.name) {
      await settings.put('psalmodyMode', psalmodyMode.name);
      await settings.flush();
    }
    final withBundle = loadBundle ?? path == null;
    await content.open(bundle: bundle, loadBundle: withBundle);
    if (withBundle) {
      // Remove protected texts that a former public sync may have left behind.
      // User prayers, settings and favourite IDs are never touched.
      await content.ensureLoaded(['prayers', 'prayerCategories']);
      final cleanup = PriestCacheCleanup.fromManifest(content.bundleManifest);
      final sanitizedKey = 'priestPublicCacheSanitized${cleanup.digest}';
      final migrationNeeded = _meta.get(sanitizedKey) != true;
      final policy = PriestAccessPolicy({
        for (final id in prayerCategoriesBox.keys)
          id: {
            ...Map<String, dynamic>.from(prayerCategoriesBox.get(id) as Map),
            if (migrationNeeded && cleanup.categories.contains(id))
              'priestOnly': true,
          },
      });
      final restricted = {
        for (final id in prayersBox.keys)
          if (policy.prayerRestricted(prayersBox.get(id) as Map, id: id) ||
              (migrationNeeded && cleanup.prayers.contains(id)))
            id: null,
      };
      final restrictedCategories = {
        for (final id in prayerCategoriesBox.keys)
          if (policy.categoryRestricted(id)) id: null,
      };
      if (restricted.isNotEmpty) {
        await prayersBox.applyUpdate(
          restricted,
          {},
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      if (restrictedCategories.isNotEmpty) {
        await prayerCategoriesBox.applyUpdate(
          restrictedCategories,
          {},
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      // Also discard old, already-deleted frames on the first upgrade to this
      // access model; Hive's visible keys alone cannot find those frames.
      if (restricted.isNotEmpty ||
          restrictedCategories.isNotEmpty ||
          migrationNeeded) {
        await prayersBox.compactOverlay();
        await prayerCategoriesBox.compactOverlay();
        if (Hive.isBoxOpen(ContentStore.stagingBoxName)) {
          await Hive.box(ContentStore.stagingBoxName).compact();
        }
        await _meta.put(sanitizedKey, true);
      }
    }
    if (withBundle) content.preloadAll();
    if (!withBundle) {
      // Tests start on the current model.
      await _meta.put(kContentModelKey, kContentModel);
    }
  }

  /// The former download cache is read once and removed — after the first
  /// frame and after the liturgical texts are decoded, so it never delays
  /// the first screen (a full old database is large).
  static Future<void> migrateFormerCache() async {
    await WidgetsBinding.instance.endOfFrame;
    await content.ensureLoaded(kLiturgicalCollections);
    await ContentMigration(_meta).run();
  }

  /// Former Firestore prayer reads also populated the SDK's disk cache.
  /// Canonical offline content lives in ContentStore; this duplicate cache
  /// can be cleared once without removing user data or the public corpus.
  static Future<void> sanitizeLegacyFirestoreCache(
    Future<void> Function() clearPersistence,
  ) async {
    final cleanup = PriestCacheCleanup.fromManifest(content.bundleManifest);
    final key = 'priestFirestoreCacheSanitized${cleanup.digest}';
    if (_meta.get(key) == true) return;
    await clearPersistence();
    await _meta.put(key, true);
  }

  static bool? getMetaFlag(String key) => _meta.get(key) as bool?;

  static Future<void> setMetaFlag(String key, bool value) async {
    await _meta.put(key, value);
  }

  static DateTime? getMetaTime(String key) =>
      DateTime.tryParse(_meta.get(key)?.toString() ?? '');

  static Future<void> setMetaTime(String key, DateTime time) =>
      _meta.put(key, time.toIso8601String());
}
