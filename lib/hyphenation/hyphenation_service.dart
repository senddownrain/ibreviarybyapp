import 'package:flutter/foundation.dart';

import 'package:mybrev_flutter/hyphenation/be_hyphenator.dart';

/// Loads the Belarusian hyphenation patterns once (bundled asset, no network)
/// and tells listeners when they are ready. Until then — or if loading fails —
/// prose falls back to the standard renderer with the adaptive alignment, so
/// hyphenation is strictly an enhancement.
class BelarusianHyphenation {
  BelarusianHyphenation._();

  static final ValueNotifier<BelarusianHyphenator?> notifier =
      ValueNotifier<BelarusianHyphenator?>(null);
  static Future<void>? _loading;

  static BelarusianHyphenator? get current => notifier.value;

  static Future<void> ensureLoaded() => _loading ??= () async {
    try {
      notifier.value = await BelarusianHyphenator.loadAsset();
    } catch (error, stack) {
      // Keep the safe fallback (adaptive alignment, no hyphens).
      debugPrint('Belarusian hyphenation unavailable: $error\n$stack');
    }
  }();

  @visibleForTesting
  static void debugSet(BelarusianHyphenator? value) {
    notifier.value = value;
    _loading = Future<void>.value();
  }
}
