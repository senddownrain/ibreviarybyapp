// Flutter glue for the local-only analytics collector.
//
// Decision D-10 = B (docs/analytics-privacy.md in the mybrev repository):
// local counting only in test builds (internal testing, TestFlight). It runs
// only when the app is built with `--dart-define=ANALYTICS_LOCAL=true`; every
// entry point below is behind that compile-time constant, so a normal build
// has nothing to run. No network, no device or installation identifiers.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/analytics/collector.dart';
import 'package:mybrev_flutter/analytics/public_inventory.dart';
import 'package:mybrev_flutter/analytics/route_mapper.dart';
import 'package:mybrev_flutter/models/mass_ritual.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Compile-time switch; false in every normal build.
const bool kAnalyticsLocal = bool.fromEnvironment('ANALYTICS_LOCAL');

const String _boxName = 'analytics_local_v1';
const String _packetsKey = 'packets';
const int _maxStoredBytes = 64 * 1024;

class LocalAnalytics with WidgetsBindingObserver {
  LocalAnalytics._(this._collector, this._router);

  static LocalAnalytics? instance;

  final AnalyticsCollector _collector;
  final GoRouter _router;
  Box<String>? _box;
  Uri? _lastUri;
  AnalyticsTarget? _target;
  bool _sawScrollable = false;
  bool _fitsReported = false;

  static String? _platform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return null; // not part of contract v1
    }
  }

  /// Starts local counting. Does nothing unless built with ANALYTICS_LOCAL=true.
  static Future<void> start(GoRouter router) async {
    if (!kAnalyticsLocal || instance != null) return;
    final platform = _platform();
    if (platform == null) return;
    var version = '0.0';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    // Monotonic clock: wall-clock jumps would otherwise cause clock anomalies.
    final stopwatch = Stopwatch()..start();
    final base = DateTime.now().toUtc().millisecondsSinceEpoch;
    final collector = AnalyticsCollector(
      platform: platform,
      appVersion: version,
      enabled: true,
      publicIds: kAnalyticsPublicIds,
      now: () => base + stopwatch.elapsedMilliseconds,
    );
    final analytics = LocalAnalytics._(collector, router);
    await analytics._restore();
    instance = analytics;
    WidgetsBinding.instance.addObserver(analytics);
    router.routerDelegate.addListener(analytics._onRoute);
    analytics._onRoute();
  }

  Future<void> _restore() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      _box = box;
      final stored = box.get(_packetsKey);
      if (stored != null) {
        final decoded = jsonDecode(stored);
        if (decoded is List) _collector.importPackets(decoded);
      }
      _collector.pruneOlderThan();
    } catch (_) {
      _collector.reportError('storage_unavailable');
    }
  }

  void _onRoute() {
    final uri = _router.routerDelegate.currentConfiguration.uri;
    if (uri == _lastUri) return;
    _lastUri = uri;
    final next = mapLocation(
      uri,
      massOrderPrayerId: kMassRitual.primaryPrayerId,
    );
    if (_target != next) {
      // A material that never showed a scrollable text (loader, "not found")
      // is not a read.
      if (_target?.contentId != null && !_sawScrollable) {
        _collector.discardView();
      }
      _sawScrollable = false;
      _fitsReported = false;
    }
    _target = next;
    if (next == null) {
      _collector.leaveView();
      return;
    }
    _collector.enterView(section: next.section, contentId: next.contentId);
  }

  /// Called from [AnalyticsScrollListener]. Plain in-memory arithmetic only.
  void onScrollMetrics(ScrollMetrics metrics, int depth) {
    if (depth != 0 || metrics.axis != Axis.vertical) return;
    if (metrics.viewportDimension < 200) return;
    _sawScrollable = true;
    final target = _target;
    if (target == null) return;
    if (metrics.maxScrollExtent <= 1) {
      if (!_fitsReported) {
        _fitsReported = true;
        _collector.enterView(
          section: target.section,
          contentId: target.contentId,
          fits: true,
        );
      }
      return;
    }
    final total = metrics.maxScrollExtent + metrics.viewportDimension;
    _collector.reportScroll(
      (metrics.pixels + metrics.viewportDimension) / total,
    );
  }

  /// Screens may report the displayed text length (characters, markup stripped)
  /// once per build to enable the `er` metric. Not called by any screen yet.
  void reportTextLength(int totalChars) {
    final target = _target;
    if (target == null) return;
    _collector.enterView(
      section: target.section,
      contentId: target.contentId,
      totalChars: totalChars,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _collector.setVisible(true);
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _collector.setVisible(false);
      case AppLifecycleState.paused:
        _collector.setVisible(false);
        _persist();
      case AppLifecycleState.detached:
        _collector.flush();
        _persist();
    }
  }

  /// Closed visits as contract packets (JSON-compatible), for testers.
  List<Map<String, Object?>> snapshot() => _collector.snapshot();

  void _persist() {
    final box = _box;
    if (box == null) return;
    try {
      var packets = _collector.snapshot();
      var encoded = jsonEncode(packets);
      while (utf8.encode(encoded).length > _maxStoredBytes &&
          packets.isNotEmpty) {
        packets = packets.sublist(1); // oldest day first
        _collector.reportError('queue_overflow');
        encoded = jsonEncode(packets);
      }
      box.put(_packetsKey, encoded);
      if (kDebugMode) debugPrint('[analytics-local] $encoded');
    } catch (_) {
      _collector.reportError('storage_unavailable');
    }
  }
}

/// Wraps the app and forwards vertical scroll metrics of top-level scrollables
/// to [LocalAnalytics]. Never rebuilds anything and never consumes a notification.
class AnalyticsScrollListener extends StatelessWidget {
  const AnalyticsScrollListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) {
        LocalAnalytics.instance?.onScrollMetrics(n.metrics, n.depth);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          LocalAnalytics.instance?.onScrollMetrics(n.metrics, n.depth);
          return false;
        },
        child: child,
      ),
    );
  }
}
