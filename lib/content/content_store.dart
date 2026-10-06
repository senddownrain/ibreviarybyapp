import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';

/// The app's canonical content: the bundle shipped inside the package plus
/// a small Hive layer of documents updated after that bundle.
///
/// ```text
/// bundled baseline (assets/content, read-only)
///   + update overlay (Hive `content_<collection>`: newer documents, deletions)
///   = effective collection
/// ```
///
/// Reads are synchronous once a collection is loaded. Hive never holds the
/// whole corpus: only what changed since the app was built.
class ContentStore {
  ContentStore._();

  static final ContentStore instance = ContentStore._();

  final Map<String, ContentCollection> _collections = {
    for (final name in kContentCollections) name: ContentCollection._(name),
  };
  final Map<String, Future<void>> _loading = {};
  AssetBundle? _bundle;
  bool _bundleEnabled = true;

  /// Bundle manifest (`assets/content/manifest.json`), once read.
  Map<String, dynamic>? bundleManifest;

  /// Bumped after any change of the effective content (update applied,
  /// overlay written). UI providers rebuild on it.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  ContentCollection collection(String name) =>
      _collections[name] ?? (throw ArgumentError('Unknown collection $name'));

  /// Time of the bundled content (ms), 0 before the manifest is read.
  int get bundleContentVersion =>
      (bundleManifest?['contentVersion'] as num?)?.toInt() ?? 0;

  /// Opens the overlay boxes. [bundle] false: collections start empty and
  /// ready (tests seed them through the overlay API).
  Future<void> open({AssetBundle? bundle, bool loadBundle = true}) async {
    _bundle = bundle;
    _bundleEnabled = loadBundle;
    _loading.clear();
    for (final item in _collections.values) {
      await item._open();
    }
    if (!loadBundle) {
      for (final item in _collections.values) {
        item._setBaseline(const {}, const {}, 0);
      }
    }
  }

  bool isLoaded(String name) => collection(name).isLoaded;

  bool areLoaded(Iterable<String> names) => names.every(isLoaded);

  /// Loads the bundled baseline of [names] (each once; decoding runs in an
  /// isolate). Completes immediately for loaded collections.
  Future<void> ensureLoaded(Iterable<String> names) =>
      Future.wait([for (final name in names) _ensure(name)]);

  Future<void> _ensure(String name) {
    final item = collection(name);
    if (item.isLoaded) return Future.value();
    return _loading[name] ??= _load(item).whenComplete(() {
      if (!item.isLoaded) _loading.remove(name);
    });
  }

  Future<void> _load(ContentCollection item) async {
    if (!_bundleEnabled) return;
    final bundle = _bundle ?? rootBundle;
    bundleManifest ??=
        jsonDecode(await bundle.loadString('$kContentAssetDir/manifest.json'))
            as Map<String, dynamic>;
    final watch = Stopwatch()..start();
    final data = await bundle.load('$kContentAssetDir/${item.name}.json.gz');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final decoded = await compute(decodeContentCollection, bytes);
    item._setBaseline(decoded.docs, decoded.hashes, decoded.contentVersion);
    await item._reconcileWithBaseline();
    if (kDebugMode) {
      debugPrint(
        '[ContentStore] ${item.name}: ${decoded.docs.length} docs '
        'in ${watch.elapsedMilliseconds} ms',
      );
    }
    revision.value++;
  }

  /// Starts loading everything in the background, liturgy first.
  void preloadAll() {
    unawaited(
      ensureLoaded(kLiturgicalCollections).then(
        (_) => ensureLoaded(kContentCollections),
        onError: (Object error) {
          debugPrint('[ContentStore] preload failed: $error');
        },
      ),
    );
  }

  /// Bytes kept by the update overlay (documents newer than the bundle).
  int overlayBytes() =>
      _collections.values.fold(0, (sum, item) => sum + item.overlayBytes());
}

/// One effective collection. Mirrors the read API of a Hive box so the
/// lookup code is unchanged: `get`, `keys`, `values`, `length`.
class ContentCollection {
  ContentCollection._(this.name);

  final String name;

  Map<String, Map<String, dynamic>> _baseline = const {};
  Map<String, String> _baselineHashes = const {};
  int _baselineVersion = 0;
  bool _loaded = false;
  Box? _overlay;
  List<String>? _keys;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  String get overlayBoxName => 'content_$name';
  bool get isLoaded => _loaded;
  int get baselineVersion => _baselineVersion;

  Future<void> _open() async {
    _overlay = Hive.isBoxOpen(overlayBoxName)
        ? Hive.box(overlayBoxName)
        : await Hive.openBox(overlayBoxName);
    _loaded = false;
    _baseline = const {};
    _baselineHashes = const {};
    _changed();
  }

  void _setBaseline(
    Map<String, Map<String, dynamic>> docs,
    Map<String, String> hashes,
    int version,
  ) {
    _baseline = docs;
    _baselineHashes = hashes;
    _baselineVersion = version;
    _loaded = true;
    _changed();
  }

  /// After an app update: an overlay document the new bundle already has
  /// (same hash, or a bundle at least as new) is dropped — the bundle wins.
  Future<void> _reconcileWithBaseline() async {
    final overlay = _overlay;
    if (overlay == null || overlay.isEmpty) return;
    final stale = <dynamic>[];
    for (final key in overlay.keys) {
      final entry = overlay.get(key);
      if (entry is! Map) {
        stale.add(key);
        continue;
      }
      final hash = entry['h'] as String?;
      final version = (entry['v'] as num?)?.toInt() ?? 0;
      if (version <= _baselineVersion ||
          (hash != null && hash == _baselineHashes[key])) {
        stale.add(key);
      }
    }
    if (stale.isEmpty) return;
    await overlay.deleteAll(stale);
    _changed();
  }

  void _changed() {
    _keys = null;
    changeCount++;
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Incremented synchronously by every change: an index compares it to the
  /// value it was built at.
  int changeCount = 0;

  /// Fires after any change.
  Stream<void> get changes => _changes.stream;

  Map<String, dynamic>? _overlayEntry(Object? key) {
    final raw = _overlay?.get(key);
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  /// The effective document, or null.
  dynamic get(Object? key) {
    final raw = _overlay?.get(key);
    if (raw is Map) {
      if (raw['x'] == true) return null;
      return raw['d'];
    }
    return _baseline[key];
  }

  bool containsKey(Object? key) => get(key) != null;

  Iterable<String> get keys => _keys ??= _effectiveKeys();

  List<String> _effectiveKeys() {
    final keys = <String>{..._baseline.keys};
    final overlay = _overlay;
    if (overlay != null) {
      for (final key in overlay.keys) {
        final raw = overlay.get(key);
        if (raw is Map && raw['x'] == true) {
          keys.remove(key.toString());
        } else {
          keys.add(key.toString());
        }
      }
    }
    return keys.toList(growable: false);
  }

  Iterable<dynamic> get values => keys.map(get);

  int get length => keys.length;
  bool get isEmpty => keys.isEmpty;
  bool get isNotEmpty => keys.isNotEmpty;

  /// Hash of the effective version of every document (null: unknown — a
  /// document carried over from the former cache, verified at the next
  /// update check).
  Map<String, String?> effectiveHashes() {
    final hashes = <String, String?>{
      for (final key in _baseline.keys) key: _baselineHashes[key],
    };
    final overlay = _overlay;
    if (overlay != null) {
      for (final key in overlay.keys) {
        final raw = overlay.get(key);
        if (raw is! Map) continue;
        if (raw['x'] == true) {
          hashes.remove(key.toString());
        } else {
          hashes[key.toString()] = raw['h'] as String?;
        }
      }
    }
    return hashes;
  }

  String digest() => contentDigest(effectiveHashes());

  /// Writes newer documents and deletions at once ([docs] value null =
  /// deletion). Every document carries the hash it was published with and
  /// the content version it belongs to.
  Future<void> applyUpdate(
    Map<String, Map<String, dynamic>?> docs,
    Map<String, String> hashes,
    int version,
  ) async {
    final entries = <String, Map<String, dynamic>>{};
    final obsolete = <String>[];
    for (final MapEntry(:key, :value) in docs.entries) {
      final hash = hashes[key];
      if (value == null) {
        // Deleting a document the bundle never had leaves nothing behind.
        if (_baseline.containsKey(key)) {
          entries[key] = {'x': true, 'h': hash, 'v': version};
        } else {
          obsolete.add(key);
        }
      } else if (hash != null && hash == _baselineHashes[key]) {
        // The update returns to the bundled text.
        obsolete.add(key);
      } else {
        entries[key] = {'d': value, 'h': hash, 'v': version};
      }
    }
    final overlay = _overlay!;
    if (entries.isNotEmpty) await overlay.putAll(entries);
    if (obsolete.isNotEmpty) await overlay.deleteAll(obsolete);
    _changed();
  }

  /// A document written outside an update (former cache, tests): version
  /// now, hash unknown unless given.
  Future<void> put(String key, Map data, {String? hash, int? version}) async {
    await _overlay!.put(key, {
      'd': data,
      'h': hash,
      'v': version ?? DateTime.now().millisecondsSinceEpoch,
    });
    _changed();
  }

  Future<void> putAll(Map<String, Map> docs) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _overlay!.putAll({
      for (final entry in docs.entries)
        entry.key: {'d': entry.value, 'h': null, 'v': now},
    });
    _changed();
  }

  /// Drops every update (the bundle is read again).
  Future<void> clearOverlay() async {
    await _overlay!.clear();
    _changed();
  }

  /// The overlay entry of [key] (diagnostics, migration and tests).
  Map<String, dynamic>? overlayEntry(String key) => _overlayEntry(key);

  /// Bundled document of [key], ignoring the overlay.
  Map<String, dynamic>? baselineDocument(String key) => _baseline[key];

  int get overlayLength => _overlay?.length ?? 0;

  int overlayBytes() {
    final overlay = _overlay;
    if (overlay == null) return 0;
    var bytes = 0;
    for (final value in overlay.values) {
      bytes += utf8.encode(jsonEncode(value)).length;
    }
    return bytes;
  }
}
