import 'package:flutter/foundation.dart';

/// Development log of the data layer.
///
///   CACHE HIT · CACHE MISS · FETCH START · FETCH END · PREFETCH ·
///   STALE DATA · NETWORK ERROR
///
/// Messages are closures and the whole call is removed in release builds
/// (`assert`), so logging has no production cost and nothing of it can
/// reach the UI.
abstract final class DataLog {
  /// Set by tests to capture events.
  @visibleForTesting
  static void Function(String event, String subject)? sink;

  static void cacheHit(String Function() subject) => _log('CACHE HIT', subject);
  static void cacheMiss(String Function() subject) =>
      _log('CACHE MISS', subject);
  static void fetchStart(String Function() subject) =>
      _log('FETCH START', subject);
  static void fetchEnd(String Function() subject) => _log('FETCH END', subject);
  static void prefetch(String Function() subject) => _log('PREFETCH', subject);
  static void stale(String Function() subject) => _log('STALE DATA', subject);
  static void networkError(String Function() subject) =>
      _log('NETWORK ERROR', subject);

  static void _log(String event, String Function() subject) {
    assert(() {
      final text = subject();
      final capture = sink;
      if (capture != null) {
        capture(event, text);
      } else {
        debugPrint('[data] $event  $text');
      }
      return true;
    }());
  }
}
