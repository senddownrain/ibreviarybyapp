import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_migration.dart';
import 'package:mybrev_flutter/content/content_store.dart';

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
    final withBundle = loadBundle ?? path == null;
    await content.open(bundle: bundle, loadBundle: withBundle);
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

  static bool? getMetaFlag(String key) => _meta.get(key) as bool?;

  static Future<void> setMetaFlag(String key, bool value) async {
    await _meta.put(key, value);
  }

  static DateTime? getMetaTime(String key) =>
      DateTime.tryParse(_meta.get(key)?.toString() ?? '');

  static Future<void> setMetaTime(String key, DateTime time) =>
      _meta.put(key, time.toIso8601String());
}
