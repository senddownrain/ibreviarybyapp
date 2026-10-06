import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/content/content_updater.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/services/compendium_repository.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

/// Where the content update stands, in the reader's terms.
enum ContentUpdatePhase {
  /// Nothing running; [ContentUpdateState.lastCheck] tells when it last ran.
  idle,

  /// Asking whether newer texts exist (one small request).
  checking,

  /// Newer texts are being downloaded.
  updating,

  /// A large update waits for consent (mobile data).
  waitingForConsent,

  /// A large update waits for Wi-Fi (the reader chose so).
  waitingForWifi,
}

class ContentUpdateState {
  const ContentUpdateState({
    this.phase = ContentUpdatePhase.idle,
    this.lastCheck,
    this.lastUpdate,
    this.pendingBytes = 0,
    this.failed = false,
  });

  final ContentUpdatePhase phase;
  final DateTime? lastCheck;
  final DateTime? lastUpdate;

  /// Size of the update waiting for consent or Wi-Fi.
  final int pendingBytes;

  /// The last attempt did not finish (the current texts stay).
  final bool failed;

  bool get isBusy =>
      phase == ContentUpdatePhase.checking ||
      phase == ContentUpdatePhase.updating;

  ContentUpdateState copyWith({
    ContentUpdatePhase? phase,
    DateTime? lastCheck,
    DateTime? lastUpdate,
    int? pendingBytes,
    bool? failed,
  }) => ContentUpdateState(
    phase: phase ?? this.phase,
    lastCheck: lastCheck ?? this.lastCheck,
    lastUpdate: lastUpdate ?? this.lastUpdate,
    pendingBytes: pendingBytes ?? this.pendingBytes,
    failed: failed ?? this.failed,
  );
}

const kContentLastCheckKey = 'contentLastCheck';
const kContentLastUpdateKey = 'contentLastUpdate';

/// Content version (ms) of the last update applied on this device.
const kContentUpdateVersionKey = 'contentUpdateVersion';

/// Date of the texts on the device: the newer of the bundle and the last
/// applied update.
DateTime? contentDate() {
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

/// Compendium check (meta first, units only when newer).
final compendiumSyncProvider = Provider<CompendiumSync>(
  (ref) => CompendiumSync(
    remote: FirestoreCompendiumRemote(FirebaseFirestore.instance),
    bundledVersion: CompendiumRepository.bundledContentVersion,
  ),
);

/// The one network activity of the content: a daily version check, and a
/// download only when something changed.
///
/// * Small check on any network; a small update downloads right away.
/// * A large update on mobile data asks first («Загрузіць» / «Пачакаць
///   Wi-Fi»); waiting for Wi-Fi resumes by itself when Wi-Fi appears.
/// * Every failure keeps the current texts.
class ContentUpdatesNotifier extends Notifier<ContentUpdateState> {
  ContentUpdatePlan? _pending;
  Future<void>? _running;

  @override
  ContentUpdateState build() {
    ref.listen(connectivityProvider, (previous, next) {
      if (next.value != true) return;
      if (state.phase == ContentUpdatePhase.waitingForWifi &&
          !ref.read(isOnMobileDataProvider)) {
        unawaited(_applyPending());
      } else if (previous?.value == false) {
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
      final plan = await ref.read(contentUpdaterProvider).check();
      final now = DateTime.now();
      await HiveService.setMetaTime(kContentLastCheckKey, now);
      state = state.copyWith(lastCheck: now);
      await _checkCompendium();
      if (plan == null) {
        state = state.copyWith(phase: ContentUpdatePhase.idle);
        return;
      }
      _pending = plan;
      if (plan.bytes > kLargeUpdateBytes && ref.read(isOnMobileDataProvider)) {
        state = state.copyWith(
          phase: ContentUpdatePhase.waitingForConsent,
          pendingBytes: plan.bytes,
        );
        return;
      }
      await _applyPending();
    } catch (error) {
      debugPrint('[ContentUpdates] check failed: $error');
      state = state.copyWith(phase: ContentUpdatePhase.idle, failed: true);
    }
  }

  Future<void> _checkCompendium() async {
    try {
      if (await ref.read(compendiumSyncProvider).run() ==
          CompendiumSyncOutcome.updated) {
        HiveService.content.revision.value++;
      }
    } catch (error) {
      // The Compendium keeps its current text; the next check retries.
      debugPrint('[ContentUpdates] Compendium: $error');
    }
  }

  /// «Загрузіць» on mobile data.
  Future<void> downloadNow() => _applyPending();

  /// «Пачакаць Wi-Fi».
  void waitForWifi() {
    if (_pending == null) return;
    state = state.copyWith(phase: ContentUpdatePhase.waitingForWifi);
  }

  Future<void> _applyPending() async {
    final plan = _pending;
    if (plan == null) return;
    state = state.copyWith(phase: ContentUpdatePhase.updating, failed: false);
    try {
      await ref.read(contentUpdaterProvider).apply(plan);
      _pending = null;
      final now = DateTime.now();
      await HiveService.setMetaTime(kContentLastUpdateKey, now);
      await HiveService.metaBox.put(
        kContentUpdateVersionKey,
        plan.contentVersion,
      );
      state = ContentUpdateState(lastCheck: state.lastCheck, lastUpdate: now);
    } catch (error) {
      debugPrint('[ContentUpdates] update failed: $error');
      _pending = null;
      state = state.copyWith(
        phase: ContentUpdatePhase.idle,
        pendingBytes: 0,
        failed: true,
      );
    }
  }
}

final contentUpdatesProvider =
    NotifierProvider<ContentUpdatesNotifier, ContentUpdateState>(
      ContentUpdatesNotifier.new,
    );
