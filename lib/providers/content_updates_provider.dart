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
    this.awaitsAppRelease = false,
  });

  final ContentUpdatePhase phase;
  final DateTime? lastCheck;
  final DateTime? lastUpdate;

  /// The last attempt did not finish (the current texts stay).
  final bool failed;

  /// The published change is a rebuild of the corpus: it comes with the
  /// next app release, not as a patch.
  final bool awaitsAppRelease;

  bool get isBusy =>
      phase == ContentUpdatePhase.checking ||
      phase == ContentUpdatePhase.updating;

  ContentUpdateState copyWith({
    ContentUpdatePhase? phase,
    DateTime? lastCheck,
    DateTime? lastUpdate,
    bool? failed,
    bool? awaitsAppRelease,
  }) => ContentUpdateState(
    phase: phase ?? this.phase,
    lastCheck: lastCheck ?? this.lastCheck,
    lastUpdate: lastUpdate ?? this.lastUpdate,
    failed: failed ?? this.failed,
    awaitsAppRelease: awaitsAppRelease ?? this.awaitsAppRelease,
  );
}

const kContentLastCheckKey = 'contentLastCheck';
const kContentLastUpdateKey = 'contentLastUpdate';

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
    return ContentUpdateState(
      lastCheck: HiveService.getMetaTime(kContentLastCheckKey),
      lastUpdate: HiveService.getMetaTime(kContentLastUpdateKey),
    );
  }

  /// At launch and when the app returns: at most once a day.
  Future<void> checkIfDue() async {
    final last = state.lastCheck;
    if (last != null &&
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
      final plan = await updater.check();
      final now = DateTime.now();
      await HiveService.setMetaTime(kContentLastCheckKey, now);
      state = state.copyWith(lastCheck: now, awaitsAppRelease: false);
      if (plan == null) {
        state = state.copyWith(phase: ContentUpdatePhase.idle);
        return;
      }
      if (plan.isRebuildSized) {
        debugPrint(
          '[ContentUpdates] ${plan.documents} documents / ${plan.bytes} B: '
          'a rebuild, left to the next app release',
        );
        state = state.copyWith(
          phase: ContentUpdatePhase.idle,
          awaitsAppRelease: true,
        );
        return;
      }
      state = state.copyWith(phase: ContentUpdatePhase.updating);
      await updater.apply(plan);
      final applied = DateTime.now();
      await HiveService.setMetaTime(kContentLastUpdateKey, applied);
      await HiveService.metaBox.put(
        kContentUpdateVersionKey,
        plan.contentVersion,
      );
      state = state.copyWith(
        phase: ContentUpdatePhase.idle,
        lastUpdate: applied,
      );
    } catch (error) {
      debugPrint('[ContentUpdates] check failed: $error');
      state = state.copyWith(phase: ContentUpdatePhase.idle, failed: true);
    }
  }
}

final contentUpdatesProvider =
    NotifierProvider<ContentUpdatesNotifier, ContentUpdateState>(
      ContentUpdatesNotifier.new,
    );
