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
///
/// An update of several collections becomes active all at once (see
/// [commit]): readers see either the previous or the new content, never a
/// mix, also after a crash at any point.
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

  /// Staged generation: every overlay write of one update, then [_readyKey].
  static const stagingBoxName = 'content_staging';
  static const _readyKey = '__ready__';

  ContentCollection collection(String name) =>
      _collections[name] ?? (throw ArgumentError('Unknown collection $name'));

  /// Time of the bundled content (ms), 0 before the manifest is read.
  int get bundleContentVersion =>
      (bundleManifest?['contentVersion'] as num?)?.toInt() ?? 0;

  /// Opens the overlay boxes. [bundle] false: collections start empty and
  /// ready (tests seed them through the overlay API).
  Future<void> open({AssetBundle? bundle, bool loadBundle = true}) async {
    _bundle = bundle;
    bundleManifest = null;
    _bundleEnabled = loadBundle;
    _loading.clear();
    for (final item in _collections.values) {
      await item._open();
    }
    await _recover();
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

  /// An old cache may have a later download timestamp but an older calendar
  /// revision. Select the bundled calendar as one unit, never mix its layers.
  bool get calendarUsesBaseline {
    final meta = collection('liturgicalCalendarMeta');
    final baseline = meta.baselineDocument('current');
    if (baseline == null || !areLoaded(kOrdoCalendarCollections)) return false;
    final effective = meta.get('current');
    if (effective is! Map || effective['schemaVersion'] != 1) return true;
    final baseRevision = (baseline['revision'] as num?)?.toInt() ?? 0;
    final revision = (effective['revision'] as num?)?.toInt() ?? 0;
    if (revision < baseRevision) return true;
    // One revision identifies one set of definitions. A different set under
    // the same revision is an unfinished/stale publication, not an update.
    return revision == baseRevision &&
        kOrdoCalendarCollections.skip(1).any((name) {
          final item = collection(name);
          return item.digest() != contentDigest(item._baselineHashes);
        });
  }

  int get calendarRevision {
    final meta = collection('liturgicalCalendarMeta');
    final raw = calendarUsesBaseline
        ? meta.baselineDocument('current')
        : meta.get('current');
    return raw is Map ? (raw['revision'] as num?)?.toInt() ?? 0 : 0;
  }

  void _validateCalendarGeneration(
    Map<String, Map<String, Map<String, dynamic>?>> ops,
  ) {
    if (!ops.keys.any(kOrdoCalendarCollections.contains)) return;
    final meta = collection('liturgicalCalendarMeta');
    if (meta.baselineDocument('current') == null) return;
    final current = calendarUsesBaseline
        ? meta.baselineDocument('current')
        : meta.get('current');
    final writesMeta =
        ops['liturgicalCalendarMeta']?.containsKey('current') ?? false;
    final metaOps = ops['liturgicalCalendarMeta'];
    final metaWrite = metaOps == null ? null : metaOps['current'];
    final next = writesMeta
        ? (metaWrite == null ? null : metaWrite['d'])
        : current;
    final changesDefinitions = kOrdoCalendarCollections
        .skip(1)
        .any((name) => ops[name]?.isNotEmpty ?? false);
    final nextRevision = next is Map
        ? (next['revision'] as num?)?.toInt() ?? 0
        : 0;
    if (next is! Map ||
        next['schemaVersion'] != 1 ||
        nextRevision < calendarRevision ||
        (changesDefinitions && nextRevision <= calendarRevision)) {
      throw StateError(
        'Calendar update requires schema 1 and a larger revision for changed definitions',
      );
    }
  }

  /// Starts loading everything in the background, liturgy first.
  void preloadAll() {
    _preload = ensureLoaded(kLiturgicalCollections)
        .then((_) => ensureLoaded(kContentCollections))
        .catchError((Object error) {
          debugPrint('[ContentStore] preload failed: $error');
        });
  }

  Future<void>? _preload;

  /// Completes when the background preload and every load already started
  /// have finished. Whoever closes Hive (tests, a storage reset) awaits it
  /// first: a late load reconciles its overlay box and must not meet a
  /// closed one.
  Future<void> idle() async {
    await _preload;
    await Future.wait(_loading.values.map((f) => f.catchError((Object _) {})));
  }

  /// Makes one update active, all collections at once.
  ///
  /// ```text
  /// 1. stage    every overlay write into `content_staging`   crash → old content
  /// 2. ready    one write of the READY marker                 crash → replayed at start
  /// 3. write    the overlay boxes                             crash → replayed at start
  /// 4. switch   every collection's view in one synchronous step → new content
  /// 5. clean    the staging box
  /// ```
  ///
  /// [stopAfter] (tests only) ends the run after a phase, as a crash would.
  ///
  /// Commits run one after another (never two generations in staging at
  /// once), and each first finishes a READY generation an earlier commit
  /// left behind (an I/O failure without a restart): staging is never
  /// cleared while it still holds an unfinished READY update.
  Future<void> commit(
    Map<String, Map<String, Map<String, dynamic>?>> ops,
    int version, {
    @visibleForTesting ContentCommitPhase? stopAfter,
  }) {
    final run = (_commitTail ?? Future<void>.value()).then(
      (_) => _commit(ops, version, stopAfter: stopAfter),
    );
    _commitTail = run.catchError((Object _) {});
    return run;
  }

  Future<void>? _commitTail;

  Future<void> _commit(
    Map<String, Map<String, Map<String, dynamic>?>> ops,
    int version, {
    ContentCommitPhase? stopAfter,
  }) async {
    await _recover();
    if (_bundleEnabled && ops.keys.any(kOrdoCalendarCollections.contains)) {
      await ensureLoaded(kOrdoCalendarCollections);
      _validateCalendarGeneration(ops);
    }
    final staging = await _stagingBox();
    await staging.clear();
    await staging.putAll({
      for (final MapEntry(key: name, value: entries) in ops.entries)
        for (final MapEntry(key: id, value: entry) in entries.entries)
          '$name\u0000$id': entry ?? const {'drop': true},
    });
    await staging.flush();
    if (stopAfter == ContentCommitPhase.staged) return;
    await staging.put(_readyKey, {'v': version, 'n': staging.length});
    await staging.flush();
    if (stopAfter == ContentCommitPhase.ready) return;
    await _replay(
      staging,
      crashBeforeSwitch: stopAfter == ContentCommitPhase.written,
    );
  }

  Future<Box> _stagingBox() async => Hive.isBoxOpen(stagingBoxName)
      ? Hive.box(stagingBoxName)
      : await Hive.openBox(stagingBoxName);

  /// At start and before every commit: a READY generation is finished
  /// (replaying is idempotent), an unfinished preparation is dropped.
  Future<void> _recover() async {
    final staging = await _stagingBox();
    if (staging.isEmpty) return;
    if (staging.containsKey(_readyKey)) {
      debugPrint('[ContentStore] finishing an interrupted update');
      await _replay(staging);
    } else {
      debugPrint('[ContentStore] dropping an unfinished update');
      await staging.clear();
    }
  }

  Future<void> _replay(Box staging, {bool crashBeforeSwitch = false}) async {
    final byCollection = <String, Map<String, Map<String, dynamic>?>>{};
    for (final key in staging.keys) {
      if (key == _readyKey) continue;
      final parts = key.toString().split('\u0000');
      if (parts.length != 2 || !_collections.containsKey(parts[0])) continue;
      final raw = staging.get(key);
      final entry = raw is Map ? Map<String, dynamic>.from(raw) : null;
      (byCollection[parts[0]] ??= {})[parts[1]] =
          entry == null || entry['drop'] == true ? null : entry;
    }
    for (final MapEntry(key: name, value: entries) in byCollection.entries) {
      await collection(name)._writeOverlay(entries);
    }
    if (crashBeforeSwitch) return;
    // One synchronous step: no reader can see some collections new and
    // others old.
    for (final name in byCollection.keys) {
      collection(name)._reloadView();
    }
    revision.value++;
    await staging.clear();
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

  /// What readers see of the overlay. Replaced as a whole when an update is
  /// switched on, so a read never meets half of an update.
  Map<String, Map> _view = const {};
  List<String>? _keys;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  String get overlayBoxName => 'content_$name';
  bool get isLoaded => _loaded;
  int get baselineVersion => _baselineVersion;

  Future<void> _open() async {
    _overlay = Hive.isBoxOpen(overlayBoxName)
        ? Hive.box(overlayBoxName)
        : await Hive.openBox(overlayBoxName);
    _reloadView(notify: false);
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
    if (overlay == null || !overlay.isOpen || overlay.isEmpty) return;
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
    try {
      await overlay.deleteAll(stale);
    } on HiveError {
      // Storage was closed under a late load: nothing left to reconcile.
      if (overlay.isOpen) rethrow;
      return;
    }
    _reloadView();
  }

  void _reloadView({bool notify = true}) {
    final overlay = _overlay;
    _view = overlay == null
        ? const {}
        : {
            for (final key in overlay.keys)
              if (overlay.get(key) case final Map entry) key.toString(): entry,
          };
    if (notify) _changed();
  }

  /// Writes overlay entries ([ops] value null = remove the entry) without
  /// touching what readers see; [_reloadView] switches them on.
  Future<void> _writeOverlay(Map<String, Map<String, dynamic>?> ops) async {
    final overlay = _overlay!;
    final puts = <String, Map<String, dynamic>>{
      for (final MapEntry(:key, :value) in ops.entries) key: ?value,
    };
    final drops = [
      for (final MapEntry(:key, :value) in ops.entries)
        if (value == null) key,
    ];
    if (puts.isNotEmpty) await overlay.putAll(puts);
    if (drops.isNotEmpty) await overlay.deleteAll(drops);
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
    final raw = _view[key];
    return raw == null ? null : Map<String, dynamic>.from(raw);
  }

  /// The effective document, or null.
  dynamic get(Object? key) {
    final raw = _view[key];
    if (raw != null) {
      if (raw['x'] == true) return null;
      return raw['d'];
    }
    return _baseline[key];
  }

  bool containsKey(Object? key) => get(key) != null;

  Iterable<String> get keys => _keys ??= _effectiveKeys();

  List<String> _effectiveKeys() {
    final keys = <String>{..._baseline.keys};
    for (final MapEntry(:key, value: raw) in _view.entries) {
      if (raw['x'] == true) {
        keys.remove(key);
      } else {
        keys.add(key);
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
    for (final MapEntry(:key, value: raw) in _view.entries) {
      if (raw['x'] == true) {
        hashes.remove(key);
      } else {
        hashes[key] = raw['h'] as String?;
      }
    }
    return hashes;
  }

  String digest() => contentDigest(effectiveHashes());

  /// Overlay operations that bring this collection to the published
  /// documents ([docs] value null = deletion): id → new overlay entry, or
  /// null = remove the overlay entry (back to the bundle, or nothing).
  /// Every document carries the hash it was published with and the content
  /// version it belongs to.
  Map<String, Map<String, dynamic>?> planUpdate(
    Map<String, Map<String, dynamic>?> docs,
    Map<String, String> hashes,
    int version,
  ) {
    final ops = <String, Map<String, dynamic>?>{};
    for (final MapEntry(:key, :value) in docs.entries) {
      final hash = hashes[key];
      if (value == null) {
        // Deleting a document the bundle never had leaves nothing behind.
        ops[key] = _baseline.containsKey(key)
            ? {'x': true, 'h': hash, 'v': version}
            : null;
      } else if (hash != null && hash == _baselineHashes[key]) {
        // The update returns to the bundled text: no overlay needed.
        ops[key] = null;
      } else {
        ops[key] = {'d': value, 'h': hash, 'v': version};
      }
    }
    return ops;
  }

  /// [planUpdate] written and switched on for this collection alone (tests,
  /// single-collection callers). Several collections: [ContentStore.commit].
  Future<void> applyUpdate(
    Map<String, Map<String, dynamic>?> docs,
    Map<String, String> hashes,
    int version,
  ) async {
    await _writeOverlay(planUpdate(docs, hashes, version));
    _reloadView();
  }

  /// A document written outside an update (former cache, tests): version
  /// now, hash unknown unless given.
  Future<void> put(String key, Map data, {String? hash, int? version}) async {
    await _overlay!.put(key, {
      'd': data,
      'h': hash,
      'v': version ?? DateTime.now().millisecondsSinceEpoch,
    });
    _reloadView();
  }

  Future<void> putAll(Map<String, Map> docs) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _overlay!.putAll({
      for (final entry in docs.entries)
        entry.key: {'d': entry.value, 'h': null, 'v': now},
    });
    _reloadView();
  }

  /// Drops every update (the bundle is read again).
  Future<void> clearOverlay() async {
    await _overlay!.clear();
    _reloadView();
  }

  /// Hive is append-only: removing a formerly protected document must also
  /// discard the old serialized frames from the live overlay file.
  Future<void> compactOverlay() async => _overlay!.compact();

  /// An app release with another bundle, without rebuilding the app (tests):
  /// the new baseline, then the same reconciliation as at a real start.
  @visibleForTesting
  Future<void> debugReplaceBaseline(
    Map<String, Map<String, dynamic>> docs,
    Map<String, String> hashes,
    int version,
  ) async {
    _setBaseline(docs, hashes, version);
    await _reconcileWithBaseline();
  }

  /// The overlay entry of [key] (diagnostics, migration and tests).
  Map<String, dynamic>? overlayEntry(String key) => _overlayEntry(key);

  /// Bundled document of [key], ignoring the overlay.
  Map<String, dynamic>? baselineDocument(String key) => _baseline[key];

  Iterable<String> get baselineKeys => _baseline.keys;

  int get overlayLength => _view.length;

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

/// Points of [ContentStore.commit] a test can stop at, as a crash would
/// (`stopAfter`).
enum ContentCommitPhase {
  /// Entries staged, no READY marker.
  staged,

  /// READY marker written, overlays not yet.
  ready,

  /// Overlays written, views not switched.
  written,
}
