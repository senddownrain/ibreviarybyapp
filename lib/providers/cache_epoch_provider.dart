import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/content/content_store.dart';

/// Changes whenever the effective content changes (bundle decoded, update
/// applied) so content providers rebuild.
final cacheEpochProvider = StateProvider<int>((ref) {
  final revision = ContentStore.instance.revision;
  void bump() => ref.controller.state++;
  revision.addListener(bump);
  ref.onDispose(() => revision.removeListener(bump));
  return revision.value;
});
