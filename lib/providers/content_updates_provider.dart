import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_updater.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

/// Where the content update stands, in the reader's terms.
enum ContentUpdatePhase {
  /// Nothing running; [ContentUpdateState.lastCheck] tells when it last ran.
  idle,

  /// Asking whether newer texts exist (one small request).
  checking,

  /// Newer texts are being downloaded and switched on.
  updating,
}

class ContentUpdateState {
  const ContentUpdateState({
    this.phase = ContentUpdatePhase.idle,
    this.lastCheck,
    this.lastUpdate,
    this.failed = false,
    this.appReleaseReason,
  });

  final ContentUpdatePhase phase;
  final DateTime? lastCheck;
  final DateTime? lastUpdate;

  /// The last attempt did not finish (the current texts stay).
  final bool failed;

  /// The published content needs the next app release (a rebuild of the
  /// corpus or a newer schema); null when nothing waits for it. Persisted.
  final AppReleaseReason? appReleaseReason;

  /// One message for both reasons: «прыйдуць з абнаўленнем праграмы».
  bool get awaitsAppRelease => appReleaseReason != null;

  bool get isBusy =>
      phase == ContentUpdatePhase.checking ||
      phase == ContentUpdatePhase.updating;

  ContentUpdateState copyWith({
    ContentUpdatePhase? phase,
    DateTime? lastCheck,
    DateTime? lastUpdate,
    bool? failed,
    AppReleaseReason? appReleaseReason,
    bool clearAppRelease = false,
  }) => ContentUpdateState(
    phase: phase ?? this.phase,
    lastCheck: lastCheck ?? this.lastCheck,
    lastUpdate: lastUpdate ?? this.lastUpdate,
    failed: failed ?? this.failed,
    appReleaseReason: clearAppRelease
        ? null
        : appReleaseReason ?? this.appReleaseReason,
  );
}

const kContentLastCheckKey = 'contentLastCheck';
const kContentLastUpdateKey = 'contentLastUpdate';

/// Persisted «needs the next app release»: the reason (`rebuild` or
/// `schema`) and the published content version it was found for.
const kContentAppReleaseReasonKey = 'contentRequiresAppReleaseReason';
const kContentAppReleaseVersionKey = 'contentRequiresAppReleaseVersion';

/// Content version (ms) of the last update applied on this device.
const kContentUpdateVersionKey = 'contentUpdateVersion';

/// Version of the texts on the device (About screen): the newer of the
/// bundle and the last applied update.
DateTime? contentDate() {
  if (!Hive.isBoxOpen('meta')) return null;
  final bundled = HiveService.content.bundleContentVersion;
  final updated = HiveService.metaBox.get(kContentUpdateVersionKey);
  final version = updated is num && updated.toInt() > bundled
      ? updated.toInt()
      : bundled;
  return version > 0 ? DateTime.fromMillisecondsSinceEpoch(version) : null;
}

/// How often the app asks on its own.
const kContentCheckInterval = Duration(hours: 24);

final contentUpdaterProvider = Provider<ContentUpdater>(
  (ref) => ContentUpdater(),
);

/// The one network activity of the content: a daily version check, and a
/// download only when something changed.
///
/// * The check is one small request, on any network; a content patch is
///   downloaded and switched on right away, on any network — patches are
///   small by construction (the publishing safeguard of MyBrev).
/// * A rebuild-sized diff is not installed as a patch: it comes with the
///   next app release.
/// * Every failure keeps the current texts; no screen ever waits for this.
class ContentUpdatesNotifier extends Notifier<ContentUpdateState> {
  Future<void>? _running;

  @override
  ContentUpdateState build() {
    ref.listen(connectivityProvider, (previous, next) {
      if (previous?.value == false && next.value == true) {
        unawaited(checkIfDue());
      }
    });
    final reason = HiveService.metaBox.get(kContentAppReleaseReasonKey);
    return ContentUpdateState(
      lastCheck: HiveService.getMetaTime(kContentLastCheckKey),
      lastUpdate: HiveService.getMetaTime(kContentLastUpdateKey),
      appReleaseReason: AppReleaseReason.values
          .where((value) => value.name == reason)
          .firstOrNull,
    );
  }

  /// At launch and when the app returns: at most once a day — and at every
  /// launch while an app release is awaited, so the flag clears as soon as
  /// the new app's bundle matches what is published.
  Future<void> checkIfDue() async {
    final last = state.lastCheck;
    if (!state.awaitsAppRelease &&
        last != null &&
        DateTime.now().difference(last) < kContentCheckInterval) {
      return;
    }
    await check();
  }

  /// «Праверыць абнаўленні» (also the daily check).
  Future<void> check() => _running ??= _check().whenComplete(() {
    _running = null;
  });

  Future<void> _check() async {
    if (ref.read(isOfflineProvider)) return;
    state = state.copyWith(phase: ContentUpdatePhase.checking, failed: false);
    try {
      final updater = ref.read(contentUpdaterProvider);
      final result = await updater.check();
      final now = DateTime.now();
      await HiveService.setMetaTime(kContentLastCheckKey, now);
      state = state.copyWith(lastCheck: now);
      switch (result.kind) {
        case ContentCheckKind.current:
          await _setAppRelease(null);
          state = state.copyWith(phase: ContentUpdatePhase.idle);
        case ContentCheckKind.appReleaseRequired:
          debugPrint(
            '[ContentUpdates] ${result.reason!.name}: content '
            '${result.contentVersion} needs the next app release',
          );
          await _setAppRelease(result.reason, result.contentVersion);
          state = state.copyWith(phase: ContentUpdatePhase.idle);
        case ContentCheckKind.patch:
          final plan = result.plan!;
          state = state.copyWith(phase: ContentUpdatePhase.updating);
          await updater.apply(plan);
          final applied = DateTime.now();
          await HiveService.setMetaTime(kContentLastUpdateKey, applied);
          await HiveService.metaBox.put(
            kContentUpdateVersionKey,
            plan.contentVersion,
          );
          await _setAppRelease(null);
          state = state.copyWith(
            phase: ContentUpdatePhase.idle,
            lastUpdate: applied,
          );
      }
    } catch (error) {
      debugPrint('[ContentUpdates] check failed: $error');
      state = state.copyWith(phase: ContentUpdatePhase.idle, failed: true);
    }
  }

  /// Persists (or clears) the «next app release» status.
  Future<void> _setAppRelease(AppReleaseReason? reason, [int? version]) async {
    final meta = HiveService.metaBox;
    if (reason == null) {
      await meta.deleteAll([
        kContentAppReleaseReasonKey,
        kContentAppReleaseVersionKey,
      ]);
      state = state.copyWith(clearAppRelease: true);
    } else {
      await meta.putAll({
        kContentAppReleaseReasonKey: reason.name,
        kContentAppReleaseVersionKey: version,
      });
      state = state.copyWith(appReleaseReason: reason);
    }
  }
}

final contentUpdatesProvider =
    NotifierProvider<ContentUpdatesNotifier, ContentUpdateState>(
      ContentUpdatesNotifier.new,
    );
