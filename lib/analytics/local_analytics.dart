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

/// Below this much rendered text the screen is a loader or a "not found" page,
/// not a text: such a visit is not a read.
const int kMinReadableChars = 60;

/// Section a feature use is attributed to when the current screen is a catalog.
const Map<String, String> _catalogSection = {
  'hours_list': 'hours',
  'prayers_home': 'prayers',
  'prayers_all': 'prayers',
  'favorites': 'prayers',
  'songs': 'songs',
  'bible_books': 'bible',
  'compendium_home': 'compendium',
};

/// Reports one successful use of a whitelisted feature (test builds only).
/// Pass only the feature id from the contract: never a value, id or text.
void analyticsFeature(String featureId) {
  if (!kAnalyticsLocal) return;
  LocalAnalytics.instance?.featureUse(featureId);
}

/// The Bible chapter screen names the book it shows: opened from the tab the
/// address is a bare `/bible` and the book comes from the remembered place.
void analyticsBibleBook(String versionId, String bookId) {
  if (!kAnalyticsLocal) return;
  LocalAnalytics.instance?.reportBibleBook(versionId, bookId);
}

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
  bool _confirmed = false;
  void Function()? _measureText;

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

  /// The location the reader actually sees. A page opened with `context.push`
  /// is an imperative match whose own match list carries its location, while
  /// `currentConfiguration.uri` keeps naming the page underneath it.
  Uri _currentUri() {
    final configuration = _router.routerDelegate.currentConfiguration;
    final last = configuration.lastOrNull;
    return (last is ImperativeRouteMatch ? last.matches : configuration).uri;
  }

  void _onRoute() {
    final uri = _currentUri();
    if (uri == _lastUri) return;
    _lastUri = uri;
    final next = mapLocation(
      uri,
      massOrderPrayerId: kMassRitual.primaryPrayerId,
    );
    if (_target != next) {
      _finishTextVisit();
      _sawScrollable = false;
      _fitsReported = false;
      _confirmed = false;
    }
    _target = next;
    if (next == null) {
      _collector.leaveView();
      return;
    }
    _collector.enterView(
      section: next.section,
      contentId: next.contentId,
      catalogId: next.catalogId,
    );
  }

  /// Before leaving a text screen: take a last measurement while it is still
  /// mounted, then keep the visit only if real text was shown. Text that was
  /// shown without ever being scrollable fits the screen (`sd=fit`).
  void _finishTextVisit() {
    final target = _target;
    if (target == null || target.contentId == null) return;
    _measureText?.call();
    if (!_confirmed) {
      _collector.discardView();
    } else if (!_sawScrollable && !_fitsReported) {
      _collector.reportFits(true);
    }
  }

  /// A meter inside the reader reports how much text is on screen; it is
  /// registered while mounted so the last measurement can be taken on leave.
  void attachMeter(void Function() measure) => _measureText = measure;
  void detachMeter(void Function() measure) {
    if (identical(_measureText, measure)) _measureText = null;
  }

  /// Called from the reader scroll listener. Plain in-memory arithmetic only.
  ///
  /// [trailingBlank]: empty reserve at the end of the scroll view. A view that
  /// scrolls by no more than that shows all of its text at once (`sd=fit`).
  void onScrollMetrics(
    ScrollMetrics metrics,
    int depth, {
    double trailingBlank = 0,
  }) {
    if (depth != 0 || metrics.axis != Axis.vertical) return;
    if (metrics.viewportDimension < 200) return;
    final target = _target;
    if (target == null || target.contentId == null) return;
    _sawScrollable = true;
    if (metrics.maxScrollExtent <= 1 + trailingBlank) {
      if (!_fitsReported) {
        _fitsReported = true;
        _collector.reportFits(true);
      }
      return;
    }
    if (_fitsReported) {
      // Content grew after it first fitted (late loading): it scrolls now.
      _fitsReported = false;
      _collector.reportFits(false);
    }
    final total = metrics.maxScrollExtent + metrics.viewportDimension;
    _collector.reportScroll(
      (metrics.pixels + metrics.viewportDimension) / total,
    );
  }

  /// The reader reports how many characters of text are rendered (never the
  /// text itself). Below [kMinReadableChars] the screen is a loader or an error.
  void reportTextLength(int totalChars) {
    final target = _target;
    if (target == null || target.contentId == null) return;
    if (totalChars < kMinReadableChars) return;
    _confirmed = true;
    _collector.enterView(
      section: target.section,
      contentId: target.contentId,
      totalChars: totalChars,
    );
  }

  void reportBibleBook(String versionId, String bookId) {
    if (versionId != 'bel' && versionId != 'ru') return;
    final next = AnalyticsTarget('bible', 'bible:$versionId:$bookId');
    if (_target == next) return;
    _finishTextVisit();
    _sawScrollable = false;
    _fitsReported = false;
    _confirmed = false;
    _target = next;
    _collector.enterView(section: next.section, contentId: next.contentId);
  }

  /// One successful use of a whitelisted feature on the current screen.
  void featureUse(String featureId) {
    final target = _target;
    final section = target?.section ?? _catalogSection[target?.catalogId];
    if (section == null) return;
    _collector.featureUse(featureId, section);
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
      var packets = _collector.snapshot(includeOpen: true);
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
