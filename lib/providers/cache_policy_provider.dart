import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

/// What the app may download on its own.
class CachePolicy {
  const CachePolicy({
    this.enabled = true,
    this.behind = 7,
    this.ahead = 7,
    this.prefetchNearby = true,
    this.wifiOnlyLarge = true,
  });

  /// Automatic updates in the background.
  final bool enabled;
  final int behind;
  final int ahead;

  /// Prepare the days around the one being read.
  final bool prefetchNearby;

  /// Large collections (Bible, songbook, Compendium, whole database) are
  /// downloaded automatically only on Wi-Fi.
  final bool wifiOnlyLarge;
}

class CachePolicyNotifier extends Notifier<CachePolicy> {
  @override
  CachePolicy build() {
    final box = HiveService.settingsBox;
    int window(String key) =>
        ((box.get(key, defaultValue: 7) as num).toInt()).clamp(0, 366);
    return CachePolicy(
      enabled: box.get('backgroundCacheEnabled', defaultValue: true) == true,
      behind: window('cacheDaysBehind'),
      ahead: window('cacheDaysAhead'),
      prefetchNearby: box.get('prefetchNearby', defaultValue: true) == true,
      wifiOnlyLarge: box.get('wifiOnlyLarge', defaultValue: true) == true,
    );
  }

  Future<void> update({
    bool? enabled,
    int? behind,
    int? ahead,
    bool? prefetchNearby,
    bool? wifiOnlyLarge,
  }) async {
    state = CachePolicy(
      enabled: enabled ?? state.enabled,
      behind: (behind ?? state.behind).clamp(0, 366),
      ahead: (ahead ?? state.ahead).clamp(0, 366),
      prefetchNearby: prefetchNearby ?? state.prefetchNearby,
      wifiOnlyLarge: wifiOnlyLarge ?? state.wifiOnlyLarge,
    );
    await HiveService.settingsBox.putAll({
      'backgroundCacheEnabled': state.enabled,
      'cacheDaysBehind': state.behind,
      'cacheDaysAhead': state.ahead,
      'prefetchNearby': state.prefetchNearby,
      'wifiOnlyLarge': state.wifiOnlyLarge,
    });
  }
}

final cachePolicyProvider = NotifierProvider<CachePolicyNotifier, CachePolicy>(
  CachePolicyNotifier.new,
);
