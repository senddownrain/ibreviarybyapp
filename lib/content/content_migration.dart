import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';

/// Content model of the device: 1 = former download cache (`days`,
/// `readings`, … boxes filled from Firestore), 2 = bundle + update overlay.
const kContentModelKey = 'contentModel';
const kContentModel = 2;

/// Former cache boxes holding canonical content.
const kLegacyContentBoxes = [
  'days',
  'readings',
  'liturgicalTemplates',
  'invitatoriums',
  'completoriums',
  'prayers',
  'prayerCategories',
  'songs',
];

/// Former boxes with nothing worth keeping (an index, a computed calendar,
/// Bible copies).
const kLegacyDerivedBoxes = [
  'readingsIndex',
  'yearOptions',
  // Former downloaded Bible copies: the bundled Bible is canonical.
  'bible_bel',
  'bible_ru',
];

/// Bookkeeping of the former cache in the `meta` box.
bool isLegacyCacheMetaKey(Object? key) {
  if (key is! String) return false;
  return key.startsWith('ready_') ||
      key.startsWith('fullCache_') ||
      key.startsWith('bytes_') ||
      key.startsWith('lastSync_') ||
      key == 'warmupFrom' ||
      key == 'warmupTo' ||
      key.startsWith('readingsIndexBuilt');
}

/// One-time move from the download cache to the bundled content.
///
/// Deterministic and idempotent:
///  * a cached document is kept (in the overlay) only when it is newer than
///    the bundled one — its own `updatedAt`/`importedAt` is later and its
///    text differs; otherwise the bundle wins;
///  * a document the bundle does not have is kept only when it was updated
///    after the bundle was built;
///  * the former boxes are deleted only after they were read;
///  * the flag is written last: an interrupted run simply runs again;
///  * user data (settings, own prayers, highlights, favourites, Bible and
///    Compendium copies) is not touched.
class ContentMigration {
  ContentMigration(this._meta, {ContentStore? store})
    : _store = store ?? ContentStore.instance;

  final Box _meta;
  final ContentStore _store;

  bool get isDone => _meta.get(kContentModelKey) == kContentModel;

  /// Number of former documents carried over (diagnostics and tests).
  int carried = 0;

  Future<void> run() async {
    if (isDone) return;
    for (final name in kLegacyContentBoxes) {
      if (!await Hive.boxExists(name)) continue;
      final box = Hive.isBoxOpen(name)
          ? Hive.box(name)
          : await Hive.openBox(name);
      if (box.isNotEmpty) await _carryOver(name, box);
      await box.deleteFromDisk();
    }
    for (final name in kLegacyDerivedBoxes) {
      if (!await Hive.boxExists(name)) continue;
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).deleteFromDisk();
      } else {
        await Hive.deleteBoxFromDisk(name);
      }
    }
    await _meta.deleteAll(_meta.keys.where(isLegacyCacheMetaKey).toList());
    await _meta.put(kContentModelKey, kContentModel);
    if (carried > 0) _store.revision.value++;
    if (kDebugMode) {
      debugPrint('[ContentMigration] done, $carried newer documents kept');
    }
  }

  Future<void> _carryOver(String name, Box box) async {
    await _store.ensureLoaded([name]);
    final collection = _store.collection(name);
    final bundleVersion = collection.baselineVersion;
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final doc = Map<String, dynamic>.from(raw);
      final id = key.toString();
      final updated = _time(doc['updatedAt'] ?? doc['importedAt']);
      if (updated == null) continue;
      final bundled = collection.baselineDocument(id);
      final bundledTime = bundled == null
          ? bundleVersion
          : _time(bundled['updatedAt'] ?? bundled['importedAt']) ??
                bundleVersion;
      if (updated <= bundledTime) continue;
      final hash = documentHash(doc);
      if (bundled != null && hash == documentHash(bundled)) continue;
      await collection.put(
        id,
        doc,
        hash: hash,
        version: updated > bundleVersion ? updated : bundleVersion + 1,
      );
      carried++;
    }
  }

  static int? _time(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch;
    }
    return null;
  }
}
