/// The app's Ordo engine, built from the effective content (bundle ⊕ update
/// overlay) of the calendar collections. Rebuilt — synchronously, on the
/// next read — whenever one of them changes, so a content update activates
/// new definitions together with the Propers of the same generation.
library;

import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/engine.dart';

class OrdoRuntime {
  OrdoRuntime._();

  static OrdoEngine? _engine;
  static String _builtAt = '';

  /// Number of rebuilds (diagnostics and tests).
  static int rebuilds = 0;

  static Iterable<Json> _documents(
    ContentStore store,
    String name, {
    bool baseline = false,
  }) sync* {
    final collection = store.collection(name);
    for (final key in baseline ? collection.baselineKeys : collection.keys) {
      final raw = baseline
          ? collection.baselineDocument(key)
          : collection.get(key);
      if (raw is Map) yield {...raw.cast<String, dynamic>(), 'id': key};
    }
  }

  static String _stamp(ContentStore store) => [
    for (final name in [...kOrdoCalendarCollections, ...kOrdoNotesCollections])
      '${store.collection(name).changeCount}:${store.isLoaded(name)}',
  ].join('|');

  /// The engine of the current content. Without the calendar collections
  /// (still decoding, or a test without the bundle) the engine knows only the
  /// temporal cycle — never a wrong celebration.
  static OrdoEngine get engine {
    final store = ContentStore.instance;
    final stamp = _stamp(store);
    final cached = _engine;
    if (cached != null && stamp == _builtAt) return cached;
    final baseline = store.calendarUsesBaseline;
    final metas = store.collection('liturgicalCalendarMeta');
    final meta = baseline
        ? metas.baselineDocument('current')
        : metas.get('current');
    final engine = OrdoEngine(
      !store.areLoaded(kOrdoCalendarCollections)
          ? OrdoDefinitions.empty
          : OrdoDefinitions.fromDocuments(
              celebrations: _documents(
                store,
                'liturgicalCelebrations',
                baseline: baseline,
              ),
              dioceseOverrides: _documents(
                store,
                'liturgicalDioceseOverrides',
                baseline: baseline,
              ),
              yearOverrides: _documents(
                store,
                'liturgicalYearOverrides',
                baseline: baseline,
              ),
              revision: meta is Map
                  ? ((meta['revision'] as num?)?.toInt() ?? 0)
                  : 0,
            ),
      notes: _documents(store, 'liturgicalOrdoNotes'),
    );
    _engine = engine;
    _builtAt = stamp;
    rebuilds++;
    return engine;
  }

  /// Whether the canonical Ordo notes are decoded (they load lazily).
  static bool get notesReady =>
      ContentStore.instance.areLoaded(kOrdoNotesCollections);
}
