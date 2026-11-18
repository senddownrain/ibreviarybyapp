import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';
import 'package:mybrev_flutter/utils/retry.dart';
import 'package:mybrev_flutter/services/priest_access_policy.dart';

/// Firestore collection of the version manifest (MyBrev
/// `npm run content:manifest`).
const kContentManifestCollection = 'contentManifest';

/// Above these a diff is a rebuild of the corpus, not a content patch, and
/// is left to the next app release (the bundle). Looser than the publishing
/// safeguard (MyBrev `content:manifest`), which blocks such diffs first.
const kPatchMaxBytes = 12 * 1024 * 1024;

/// A patch never replaces more than half of an existing collection.
const kPatchMaxChangedShare = 0.5;

/// …counted only above this many changed documents (small collections).
const kPatchChangedFloor = 50;

/// What the update check reads from the network.
abstract class ContentRemote {
  /// `contentManifest/current`: per collection digest, count, version.
  Future<Map<String, dynamic>?> fetchCurrent();

  /// `contentManifest/<collection>`: per document hash and size.
  Future<Map<String, dynamic>?> fetchCollectionManifest(String collection);

  /// Documents by id; an id that no longer exists is absent from the result.
  Future<Map<String, Map<String, dynamic>>> fetchDocuments(
    String collection,
    List<String> ids,
  );
}

class FirestoreContentRemote implements ContentRemote {
  FirestoreContentRemote([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const _server = GetOptions(source: Source.server);

  @override
  Future<Map<String, dynamic>?> fetchCurrent() => _manifest('current');

  @override
  Future<Map<String, dynamic>?> fetchCollectionManifest(String collection) =>
      _manifest(collection);

  Future<Map<String, dynamic>?> _manifest(String id) async {
    final snap = await retryFirestore(
      () => _db.collection(kContentManifestCollection).doc(id).get(_server),
    );
    return snap.data();
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchDocuments(
    String collection,
    List<String> ids,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    // `whereIn` takes at most 30 values.
    for (var i = 0; i < ids.length; i += 30) {
      final batch = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await retryFirestore(
        () => _db
            .collection(collection)
            .where(FieldPath.documentId, whereIn: batch)
            .get(_server),
      );
      for (final doc in snap.docs) {
        result[doc.id] = firestoreToStorable({...doc.data(), 'id': doc.id});
      }
    }
    return result;
  }
}

/// Changes of one collection: documents to download, documents removed.
class CollectionUpdate {
  const CollectionUpdate({
    required this.collection,
    required this.download,
    required this.remove,
    required this.hashes,
    required this.bytes,
    this.changed = 0,
    this.existing = 0,
  });

  final String collection;
  final List<String> download;
  final List<String> remove;

  /// Documents of [download] the device already has (edits, not additions).
  final int changed;

  /// Documents of this collection on the device before the update.
  final int existing;

  /// Published hash of every document in [download].
  final Map<String, String> hashes;
  final int bytes;

  bool get isEmpty => download.isEmpty && remove.isEmpty;

  /// Most of an existing collection replaced: a rebuild, not a patch.
  bool get isRebuildSized {
    final replaced = changed + remove.length;
    return replaced > kPatchChangedFloor &&
        replaced > existing * kPatchMaxChangedShare;
  }
}

/// Everything that differs from the published content.
class ContentUpdatePlan {
  const ContentUpdatePlan({
    required this.contentVersion,
    required this.collections,
  });

  final int contentVersion;
  final List<CollectionUpdate> collections;

  bool get isEmpty => collections.every((item) => item.isEmpty);
  int get bytes => collections.fold(0, (total, item) => total + item.bytes);
  int get documents =>
      collections.fold(0, (total, item) => total + item.download.length);

  /// A rebuild of the corpus: it comes with the next app release.
  bool get isRebuildSized =>
      bytes > kPatchMaxBytes || collections.any((item) => item.isRebuildSized);
}

/// What a version check found.
enum ContentCheckKind {
  /// The device has the published content (or nothing is published).
  current,

  /// A small content patch: download, verify, activate.
  patch,

  /// Published, but this app cannot install it as a patch: it comes with
  /// the next app release (not an error).
  appReleaseRequired,
}

/// Why the next app release is needed (diagnostics; one UX for both).
enum AppReleaseReason {
  /// The diff is the size of a rebuild of the corpus.
  rebuild,

  /// The published content uses a newer schema than this app reads.
  schema,
}

class ContentCheck {
  const ContentCheck._(
    this.kind, {
    this.plan,
    this.reason,
    this.contentVersion,
  });

  const ContentCheck.current() : this._(ContentCheckKind.current);

  ContentCheck.patch(ContentUpdatePlan plan)
    : this._(
        ContentCheckKind.patch,
        plan: plan,
        contentVersion: plan.contentVersion,
      );

  const ContentCheck.appRelease(AppReleaseReason reason, {int? contentVersion})
    : this._(
        ContentCheckKind.appReleaseRequired,
        reason: reason,
        contentVersion: contentVersion,
      );

  final ContentCheckKind kind;

  /// The patch to apply ([ContentCheckKind.patch] only).
  final ContentUpdatePlan? plan;
  final AppReleaseReason? reason;

  /// Published content version this result refers to.
  final int? contentVersion;
}

/// Rejected update: nothing was activated, the current content stays.
class ContentUpdateRejected implements Exception {
  const ContentUpdateRejected(this.reason);
  final String reason;
  @override
  String toString() => 'ContentUpdateRejected: $reason';
}

/// Version check and update of the canonical content.
///
/// ```text
/// contentManifest/current (one small document)
///   digest equal to the device's      → nothing to do
///   different → contentManifest/<c>   → ids whose hash differs
///   download those documents          → verify each against its hash
///   all verified                      → activate (Hive overlay), else keep
/// ```
///
/// Two delivery channels: a small content change arrives here as a patch;
/// a rebuild of the corpus or a new schema arrives with the next app
/// release (the bundle) and is never installed as a patch.
class ContentUpdater {
  ContentUpdater({ContentRemote? remote, ContentStore? store})
    : _remote = remote ?? FirestoreContentRemote(),
      _store = store ?? ContentStore.instance;

  final ContentRemote _remote;
  final ContentStore _store;

  /// Compares the device with the published manifest.
  ///
  ///  * schema equal, digests equal          → current
  ///  * schema equal, a small diff           → patch
  ///  * schema equal, a rebuild-sized diff   → appReleaseRequired(rebuild)
  ///  * remote schema newer than this app's  → appReleaseRequired(schema)
  ///  * remote schema older (this app is newer) → current: nothing it can
  ///    install; the next publication catches up
  Future<ContentCheck> check() async {
    final current = await _remote.fetchCurrent();
    if (current == null) return const ContentCheck.current();
    final contentVersion = (current['contentVersion'] as num?)?.toInt() ?? 0;
    final schema = (current['schemaVersion'] as num?)?.toInt() ?? 0;
    if (schema > kContentSchemaVersion) {
      return ContentCheck.appRelease(
        AppReleaseReason.schema,
        contentVersion: contentVersion,
      );
    }
    if (schema < kContentSchemaVersion) return const ContentCheck.current();
    final published = (current['collections'] as Map?) ?? const {};
    final changes = <CollectionUpdate>[];
    for (final name in kContentCollections) {
      final remote = published[name];
      if (remote is! Map) continue;
      await _store.ensureLoaded([name]);
      final local = _store.collection(name);
      // A fresh bundled snapshot can precede publication of its collection
      // index. Never let an older index remove/replace those newer texts.
      final bundledEntry =
          (_store.bundleManifest?['collections'] as Map?)?[name];
      final minimumRemoteVersion = bundledEntry is Map
          ? (bundledEntry['minimumRemoteVersion'] as num?)?.toInt() ?? 0
          : 0;
      final remoteVersion = (remote['version'] as num?)?.toInt() ?? 0;
      if (minimumRemoteVersion > 0 && remoteVersion < minimumRemoteVersion) {
        continue;
      }
      if (remote['digest'] == local.digest()) continue;
      final manifest = await _remote.fetchCollectionManifest(name);
      if (manifest == null || manifest['digest'] != remote['digest']) {
        // Being republished right now; the next check picks it up.
        continue;
      }
      final hashes = (manifest['hashes'] as Map).cast<String, String>();
      final sizes = (manifest['sizes'] as Map?)?.cast<String, num>() ?? {};
      final localHashes = local.effectiveHashes();
      final download = [
        for (final entry in hashes.entries)
          if (localHashes[entry.key] != entry.value) entry.key,
      ]..sort();
      final remove = [
        for (final id in localHashes.keys)
          if (!hashes.containsKey(id)) id,
      ]..sort();
      changes.add(
        CollectionUpdate(
          collection: name,
          download: download,
          remove: remove,
          hashes: {for (final id in download) id: hashes[id]!},
          changed: download.where(localHashes.containsKey).length,
          existing: localHashes.length,
          bytes: download.fold(
            0,
            (total, id) => total + (sizes[id] ?? 0).toInt(),
          ),
        ),
      );
    }
    final plan = ContentUpdatePlan(
      contentVersion: contentVersion,
      collections: changes,
    );
    if (plan.isEmpty) return const ContentCheck.current();
    if (plan.isRebuildSized) {
      return ContentCheck.appRelease(
        AppReleaseReason.rebuild,
        contentVersion: contentVersion,
      );
    }
    return ContentCheck.patch(plan);
  }

  /// Downloads, verifies and activates [plan] as one generation
  /// ([ContentStore.commit]). Throws
  /// [ContentUpdateRejected] (or a network error) without changing
  /// anything when any document is missing or does not match its hash.
  Future<void> apply(ContentUpdatePlan plan) async {
    if (plan.isRebuildSized) {
      throw const ContentUpdateRejected(
        'A content rebuild requires a new bundled app release',
      );
    }
    final staged = <CollectionUpdate, Map<String, Map<String, dynamic>>>{};
    for (final update in plan.collections) {
      if (update.download.isEmpty) {
        staged[update] = const {};
        continue;
      }
      final docs = await _remote.fetchDocuments(
        update.collection,
        update.download,
      );
      for (final id in update.download) {
        final doc = docs[id];
        if (doc == null) {
          throw ContentUpdateRejected('${update.collection}/$id is missing');
        }
        if (documentHash(doc) != update.hashes[id]) {
          throw ContentUpdateRejected(
            '${update.collection}/$id does not match the manifest',
          );
        }
      }
      staged[update] = docs;
    }
    // Everything verified: one generation, active all at once.
    if (plan.collections.any(
      (c) => c.collection == 'prayers' || c.collection == 'prayerCategories',
    )) {
      await _store.ensureLoaded(['prayers', 'prayerCategories']);
      Map<String, Map<String, dynamic>> effective(String name) {
        final collection = _store.collection(name);
        final docs = {
          for (final id in collection.keys)
            id: Map<String, dynamic>.from(collection.get(id) as Map),
        };
        for (final entry in staged.entries.where(
          (e) => e.key.collection == name,
        )) {
          for (final id in entry.key.remove) {
            docs.remove(id);
          }
          docs.addAll(entry.value);
        }
        return docs;
      }

      final categories = effective('prayerCategories');
      final policy = PriestAccessPolicy(categories);
      if (categories.keys.any(policy.categoryRestricted) ||
          effective('prayers').entries.any(
            (entry) => policy.prayerRestricted(entry.value, id: entry.key),
          )) {
        throw const ContentUpdateRejected(
          'Protected content cannot enter the public cache',
        );
      }
    }
    await _store.commit({
      for (final MapEntry(key: update, value: docs) in staged.entries)
        update.collection: _store
            .collection(update.collection)
            .planUpdate(
              {
                for (final id in update.download) id: docs[id],
                for (final id in update.remove) id: null,
              },
              update.hashes,
              plan.contentVersion,
            ),
    }, plan.contentVersion);
    if (plan.collections.any(
      (update) => update.collection == 'prayers' && update.remove.isNotEmpty,
    )) {
      await _store.collection('prayers').compactOverlay();
    }
  }
}
