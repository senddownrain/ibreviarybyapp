import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/ordo/day_union.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';

/// Ordo notes are decoded only when the Ordo is opened (lazy, after the
/// Hours core).
final ordoNotesReadyProvider = FutureProvider<void>((ref) async {
  await ContentStore.instance.ensureLoaded(kOrdoNotesCollections);
});

/// The Ordo of one date for the selected dioceses.
final ordoDayUnionProvider = Provider.family<OrdoDayUnion, String>((ref, iso) {
  ref.watch(cacheEpochProvider);
  final dioceses = ref.watch(dioceseSelectionProvider).ordered;
  final engine = OrdoRuntime.engine;
  return buildOrdoDayUnion([
    for (final diocese in dioceses) engine.resolve(iso, diocese: diocese),
  ]);
});
