import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

class CachePolicy {
  const CachePolicy({this.enabled = true, this.behind = 7, this.ahead = 7});
  final bool enabled;
  final int behind;
  final int ahead;
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
    );
  }

  Future<void> update({bool? enabled, int? behind, int? ahead}) async {
    state = CachePolicy(
      enabled: enabled ?? state.enabled,
      behind: (behind ?? state.behind).clamp(0, 366),
      ahead: (ahead ?? state.ahead).clamp(0, 366),
    );
    await HiveService.settingsBox.putAll({
      'backgroundCacheEnabled': state.enabled,
      'cacheDaysBehind': state.behind,
      'cacheDaysAhead': state.ahead,
    });
  }
}

final cachePolicyProvider = NotifierProvider<CachePolicyNotifier, CachePolicy>(
  CachePolicyNotifier.new,
);
