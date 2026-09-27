import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:mybrev_flutter/models/compendium.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';
import 'package:mybrev_flutter/utils/retry.dart';

/// Bundled seed, Hive cache and validation for the Compendium.
///
/// - The gzipped canonical dataset ships with the app and is decoded lazily,
///   off the UI isolate, the first time the Compendium is opened. It is never
///   part of the startup path.
/// - Box `compendium` holds a synced copy: one entry per unit (Firestore
///   `compendium/{unitId}`) plus [metaKey] (`compendiumMeta/current`). It is
///   used only while it is complete, valid and newer than the bundle.
class CompendiumRepository {
  const CompendiumRepository._();

  static const assetPath = 'assets/compendium/compendium.json.gz';
  static const aliasesAssetPath =
      'assets/compendium/compendium_search_aliases.json';
  static const boxName = 'compendium';
  static const metaKey = 'meta';

  /// Version stamp written into every stored unit, so that a write that was
  /// interrupted between units and meta is never read as a mixed dataset.
  static const versionField = '_contentVersion';

  static Future<CompendiumDataset>? _bundled;

  /// The bundled canonical dataset (memoised; retried after a failure).
  static Future<CompendiumDataset> loadBundled([AssetBundle? bundle]) {
    if (bundle != null) return _decodeAsset(bundle);
    return _bundled ??= _decodeAsset(rootBundle).catchError((Object error) {
      _bundled = null;
      throw error;
    });
  }

  static Future<CompendiumDataset> _decodeAsset(AssetBundle bundle) async {
    final data = await bundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return compute(decodeBundledCompendium, bytes);
  }

  /// Content version of the bundled dataset, or 0 if it cannot be read.
  static Future<int> bundledContentVersion() async {
    try {
      return (await loadBundled()).meta.contentVersion;
    } catch (_) {
      return 0;
    }
  }

  static Future<Map<String, dynamic>> loadAliases([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString(aliasesAssetPath);
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  // ── Synced copy ───────────────────────────────────────────────────────────

  static (int, String, CompendiumDataset)? _stored;

  /// The synced dataset if it is complete and valid, otherwise `null`.
  static CompendiumDataset? readStored() {
    if (!Hive.isBoxOpen(boxName)) return null;
    final box = Hive.box(boxName);
    final rawMeta = box.get(metaKey);
    if (rawMeta is! Map) return null;
    final meta = toJsonMap(rawMeta);
    final version = meta['contentVersion'];
    final ids = meta['unitIds'];
    if (version is! int || ids is! List) return null;
    final rawUnits = [for (final id in ids) box.get(id)];
    if (rawUnits.any((unit) => unit is! Map || unit[versionField] != version)) {
      return null;
    }
    final checksum = '${meta['checksum']}';
    final cached = _stored;
    if (cached != null && cached.$1 == version && cached.$2 == checksum) {
      return cached.$3;
    }
    final units = [
      for (final unit in rawUnits.cast<Map<dynamic, dynamic>>())
        toJsonMap(unit)..remove(versionField),
    ];
    final dataset = compendiumFromDocuments(meta, units);
    if (validateCompendiumDataset(dataset).isNotEmpty) return null;
    final parsed = CompendiumDataset.fromJson(dataset);
    _stored = (version, checksum, parsed);
    return parsed;
  }

  /// Replaces the synced copy with a validated dataset map. Units are written
  /// first and meta last; stale keys are removed only at the end.
  static Future<void> writeStored(Map<String, dynamic> dataset) async {
    final meta = Map<String, dynamic>.from(dataset['meta'] as Map);
    final version = meta['contentVersion'];
    final keep = <String>{metaKey};
    for (final unit in dataset['units'] as List) {
      final id = (unit as Map)['id'].toString();
      keep.add(id);
      await HiveService.putCached(boxName, id, {
        ...Map<String, dynamic>.from(unit),
        versionField: version,
      });
    }
    await HiveService.putCached(boxName, metaKey, {
      ...meta,
      'parts': dataset['parts'],
    });
    final box = Hive.box(boxName);
    for (final key in box.keys.toList()) {
      if (!keep.contains(key.toString())) {
        await HiveService.removeCached(boxName, key);
      }
    }
  }

  @visibleForTesting
  static void resetMemo() {
    _bundled = null;
    _stored = null;
  }
}

/// Decodes and validates the gzipped canonical dataset (runs in an isolate).
CompendiumDataset decodeBundledCompendium(Uint8List bytes) {
  final json = jsonDecode(utf8.decode(GZipDecoder().decodeBytes(bytes)));
  final errors = validateCompendiumDataset(json);
  if (errors.isNotEmpty) {
    throw FormatException('Bundled Compendium is invalid: ${errors.first}');
  }
  return CompendiumDataset.fromJson(Map<String, dynamic>.from(json as Map));
}

/// Deep copy of a Hive/Firestore map with `String` keys.
Map<String, dynamic> toJsonMap(Map<dynamic, dynamic> value) =>
    value.map((key, item) => MapEntry(key.toString(), _toJson(item)));

Object? _toJson(Object? value) => switch (value) {
  final Map<dynamic, dynamic> map => toJsonMap(map),
  final List<dynamic> list => [for (final item in list) _toJson(item)],
  _ => value,
};

// ── Firestore ───────────────────────────────────────────────────────────────

/// Remote source: `compendiumMeta/current` and the `compendium` collection.
abstract class CompendiumRemote {
  /// `null` when Firestore has no Compendium yet.
  Future<Map<String, dynamic>?> fetchMeta();

  /// Every unit document, with its document id as `id`.
  Future<List<Map<String, dynamic>>> fetchUnits();
}

class FirestoreCompendiumRemote implements CompendiumRemote {
  const FirestoreCompendiumRemote(this.db);

  final FirebaseFirestore db;

  static const metaCollection = 'compendiumMeta';
  static const metaDocument = 'current';
  static const unitsCollection = 'compendium';

  @override
  Future<Map<String, dynamic>?> fetchMeta() async {
    final snapshot = await retryFirestore(
      () => db
          .collection(metaCollection)
          .doc(metaDocument)
          .get(const GetOptions(source: Source.server)),
    );
    final data = snapshot.data();
    return snapshot.exists && data != null ? firestoreToStorable(data) : null;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchUnits() async {
    final snapshot = await retryFirestore(
      () => db
          .collection(unitsCollection)
          .get(const GetOptions(source: Source.server)),
    );
    return [
      for (final doc in snapshot.docs)
        firestoreToStorable({...doc.data(), 'id': doc.id}),
    ];
  }
}

enum CompendiumSyncOutcome { upToDate, updated, cancelled }

class CompendiumSyncException implements Exception {
  const CompendiumSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One Compendium refresh: one meta read, and the units only when Firestore
/// has a strictly newer, valid dataset. Any failure leaves the current
/// content (bundled or previously synced) untouched.
class CompendiumSync {
  const CompendiumSync({required this.remote, required this.bundledVersion});

  final CompendiumRemote remote;
  final Future<int> Function() bundledVersion;

  Future<CompendiumSyncOutcome> run({bool Function()? shouldCancel}) async {
    bool cancelled() => shouldCancel?.call() ?? false;
    final meta = await remote.fetchMeta();
    if (cancelled()) return CompendiumSyncOutcome.cancelled;
    if (meta == null) return CompendiumSyncOutcome.upToDate;
    final stored = CompendiumRepository.readStored()?.meta.contentVersion ?? 0;
    final bundled = await bundledVersion();
    final current = stored > bundled ? stored : bundled;
    if (!isNewerCompendium(meta, {
      'schemaVersion': kCompendiumSchemaVersion,
      'contentVersion': current,
    })) {
      return CompendiumSyncOutcome.upToDate;
    }
    final units = await remote.fetchUnits();
    if (cancelled()) return CompendiumSyncOutcome.cancelled;
    final dataset = compendiumFromDocuments(meta, units);
    final errors = validateCompendiumDataset(dataset);
    if (errors.isNotEmpty) {
      throw CompendiumSyncException(
        'даныя з базы не прайшлі праверку (${errors.first})',
      );
    }
    await CompendiumRepository.writeStored(dataset);
    return CompendiumSyncOutcome.updated;
  }
}
