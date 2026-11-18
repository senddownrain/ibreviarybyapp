import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:mybrev_flutter/review/app_review_policy.dart';
import 'package:mybrev_flutter/review/app_review_state.dart';
import 'package:mybrev_flutter/review/app_review_storage.dart';
import 'package:mybrev_flutter/review/native_review_adapter.dart';

/// Debug/test only. Release builds ignore the define entirely.
const bool kAppReviewQa = bool.fromEnvironment('APP_REVIEW_QA');
bool get appReviewQaActive => kAppReviewQa && kDebugMode;

typedef ReviewVersionLoader = Future<String> Function();

Future<String> _packageVersion() async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
}

/// Records local use, decides when the system review request may be called and
/// owns the manual store link. No network, no analytics.
class AppReviewController extends ChangeNotifier {
  AppReviewController({
    required this.storage,
    required this.adapter,
    DateTime Function()? clock,
    this.policy = const AppReviewPolicy(),
    ReviewVersionLoader? version,
  }) : _clock = clock ?? DateTime.now,
       _version = version ?? _packageVersion;

  final AppReviewStorage storage;
  final NativeReviewAdapter adapter;
  final AppReviewPolicy policy;
  final DateTime Function() _clock;
  final ReviewVersionLoader _version;

  AppReviewState _state = const AppReviewState();
  Future<void>? _loading;
  bool _requesting = false;

  AppReviewState get state => _state;
  bool get autoPromptDisabled => _state.autoPromptDisabled;

  Future<void> load() => _loading ??= () async {
    try {
      _state = AppReviewState.decode(await storage.read());
    } catch (error) {
      // No storage means no automatic prompt (first launch stays unknown).
      debugPrint('[Review] state unavailable: $error');
    }
  }();

  Future<void> _save(AppReviewState next) async {
    _state = next;
    notifyListeners();
    try {
      await storage.write(next.encode());
    } catch (error) {
      debugPrint('[Review] state not saved: $error');
    }
  }

  static String dayKey(DateTime local) =>
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';

  /// Call once per app session start. Fixes the first-launch time and adds
  /// today to the distinct-days list.
  Future<void> recordUse() async {
    await load();
    final now = _clock();
    var next = _state.firstLaunchMs == null
        ? _state.copyWith(firstLaunchMs: now.millisecondsSinceEpoch)
        : _state;
    next = next.withUsageDay(dayKey(now.toLocal()));
    if (next.encode() != _state.encode()) await _save(next);
  }

  Future<void> setAutoPromptDisabled(bool value) async {
    await load();
    if (_state.autoPromptDisabled == value) return;
    await _save(_state.copyWith(autoPromptDisabled: value));
  }

  /// `null` = eligible by the stored numbers.
  Future<ReviewBlock?> eligibility() async {
    await load();
    return policy.evaluate(_state, now: _clock(), version: await _version());
  }

  /// Calls the system review API when every local condition holds and the
  /// caller reports a calm moment ([calm]). The attempt is stored *before* the
  /// call, so a crash or a double trigger can never ask twice. Returns whether
  /// the native API was called (not whether anything was shown or rated).
  Future<bool> maybeRequest({required bool Function() calm}) async {
    if (_requesting) return false;
    _requesting = true;
    try {
      if (await eligibility() != null) return false;
      // Re-check after the awaits: the screen may have changed meanwhile.
      if (!calm()) return false;
      final version = await _version();
      await _save(_state.withAttempt(_clock().millisecondsSinceEpoch, version));
      await adapter.requestReview();
      return true;
    } finally {
      _requesting = false;
    }
  }

  /// Always the store page, regardless of the switch or the quota.
  Future<bool> openStore() => adapter.openStoreListing();

  /// QA only (debug builds with APP_REVIEW_QA): forget the review state alone.
  Future<void> debugReset() async {
    if (!appReviewQaActive) return;
    await storage.clear();
    _state = const AppReviewState();
    _loading = null;
    notifyListeners();
  }
}

final appReviewStorageProvider = Provider<AppReviewStorage>(
  (ref) => HiveAppReviewStorage(),
);
final nativeReviewAdapterProvider = Provider<NativeReviewAdapter>(
  (ref) => InAppReviewAdapter(),
);

final appReviewVersionProvider = Provider<ReviewVersionLoader>(
  (ref) => _packageVersion,
);

final appReviewControllerProvider = Provider<AppReviewController>((ref) {
  final controller = AppReviewController(
    storage: ref.watch(appReviewStorageProvider),
    adapter: ref.watch(nativeReviewAdapterProvider),
    version: ref.watch(appReviewVersionProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
