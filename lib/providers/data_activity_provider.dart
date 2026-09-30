import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/sync_provider.dart';

/// What the data layer is doing, from the reader's point of view.
///
/// Only [pageLoading] may take over a screen. Everything below it happens
/// next to content that is already readable.
enum DataActivity {
  idle,

  /// The selected day has nothing to show yet.
  pageLoading,

  /// The selected day is shown and is being updated.
  refreshing,

  /// Nearby days are being prepared; the current screen is not affected.
  backgroundPrefetch,

  /// A download the user started in Settings.
  globalUpdate,
}

/// Number of silent prefetch jobs (neighbouring days) in flight.
final backgroundPrefetchCountProvider = StateProvider<int>((ref) => 0);

final dataActivityProvider = Provider<DataActivity>((ref) {
  final ready = ref.watch(selectedDateReadyProvider);
  final hasContent = ref.watch(
    dayOptionsProvider.select((options) => options.isNotEmpty),
  );
  if (ready.isLoading) {
    return hasContent ? DataActivity.refreshing : DataActivity.pageLoading;
  }
  final sync = ref.watch(syncStatusProvider);
  if (sync.isSyncing && !sync.background) return DataActivity.globalUpdate;
  if (sync.isSyncing || ref.watch(backgroundPrefetchCountProvider) > 0) {
    return DataActivity.backgroundPrefetch;
  }
  return DataActivity.idle;
});

/// The selected day is shown from the device while the network is away.
final showsSavedDataProvider = Provider<bool>((ref) {
  if (!ref.watch(isOfflineProvider)) return false;
  return ref.watch(dayOptionsProvider.select((options) => options.isNotEmpty));
});
