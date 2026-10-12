import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/models/priest_access_content.dart';
import 'package:mybrev_flutter/services/firebase_priest_access.dart';
import 'package:mybrev_flutter/services/priest_access_gateway.dart';
import 'package:mybrev_flutter/services/priest_access_policy.dart';
import 'package:mybrev_flutter/services/priest_access_storage.dart';
import 'package:mybrev_flutter/services/priest_code.dart';
export 'package:mybrev_flutter/models/priest_access_content.dart';

class PriestAccessState {
  const PriestAccessState({
    this.registered = false,
    this.busy = false,
    this.content,
    this.publicContent,
    this.error,
    this.helpText = '',
  });
  final bool registered;
  final bool busy;

  /// Only an online, server-verified grant may populate this view.
  final PrayerAccessContent? content;
  final PrayerAccessContent? publicContent;
  final String? error;
  final String helpText;
}

final priestAccessGatewayProvider = Provider<PriestAccessGateway>((ref) {
  final gateway = FirebasePriestAccess();
  ref.onDispose(() => unawaited(gateway.close()));
  return gateway;
});
final priestAccessStorageProvider = Provider<PriestAccessStorage>(
  (ref) => SecurePriestAccessStorage(),
);

/// Only physical PUBLIC snapshots enter the existing Hive content store.
/// Tombstones and compaction remove documents moved out of public storage.
Future<void> persistPublicPrayerContent(PrayerAccessContent content) async {
  final store = ContentStore.instance;
  await store.ensureLoaded(['prayers', 'prayerCategories']);
  final policy = PriestAccessPolicy(content.categories);
  if (content.prayers.values.any(policy.prayerRestricted) ||
      content.categories.keys.any(policy.categoryRestricted)) {
    throw const FormatException('Protected content in public snapshot');
  }
  final version = DateTime.now().millisecondsSinceEpoch;
  final ops = <String, Map<String, Map<String, dynamic>?>>{};
  var removedPrayers = false;
  for (final entry in {
    'prayers': content.prayers,
    'prayerCategories': content.categories,
  }.entries) {
    final collection = store.collection(entry.key);
    final documents = {
      for (final item in entry.value.entries)
        item.key: Map<String, dynamic>.from(item.value),
    };
    final hashes = {
      for (final item in documents.entries) item.key: documentHash(item.value),
    };
    final changes = <String, Map<String, dynamic>?>{
      for (final id in collection.keys)
        if (!documents.containsKey(id)) id: null,
      for (final item in documents.entries)
        if (collection.get(item.key) == null ||
            documentHash(collection.get(item.key) as Map) != hashes[item.key])
          item.key: item.value,
    };
    if (entry.key == 'prayers' && changes.values.any((doc) => doc == null)) {
      removedPrayers = true;
    }
    if (changes.isNotEmpty) {
      ops[entry.key] = collection.planUpdate(changes, hashes, version);
    }
  }
  if (ops.isNotEmpty) await store.commit(ops, version);
  if (removedPrayers) {
    await store.collection('prayers').compactOverlay();
    if (Hive.isBoxOpen(ContentStore.stagingBoxName)) {
      await Hive.box(ContentStore.stagingBoxName).compact();
    }
  }
}

final priestAccessProvider =
    StateNotifierProvider<PriestAccessController, PriestAccessState>((ref) {
      final controller = PriestAccessController(
        ref.watch(priestAccessGatewayProvider),
        ref.watch(priestAccessStorageProvider),
        persistPublic: persistPublicPrayerContent,
      );
      unawaited(controller.initialize());
      return controller;
    });

class PriestAccessController extends StateNotifier<PriestAccessState> {
  PriestAccessController(this.gateway, this.storage, {this.persistPublic})
    : super(const PriestAccessState());
  final PriestAccessGateway gateway;
  final PriestAccessStorage storage;
  final Future<void> Function(PrayerAccessContent)? persistPublic;
  Map<String, dynamic> _record = {};
  String? _uid;
  int _generation = 0;
  bool _online = true, _foreground = true, _ready = false;
  Future<void>? _initializing;
  Future<void> _writes = Future<void>.value();
  Future<void> _clearing = Future<void>.value();
  StreamSubscription<PriestDeviceGrant?>? _watch;
  Timer? _retry;
  int _retrySeconds = 5;

  void _scheduleRetry() {
    if (!mounted ||
        !_online ||
        !_foreground ||
        (_uid == null &&
            _record['verifiedUid'] == null &&
            _record['pendingDisableUid'] == null) ||
        _retry?.isActive == true) {
      return;
    }
    _retry = Timer(Duration(seconds: _retrySeconds), () {
      _retry = null;
      unawaited(refresh());
    });
    _retrySeconds = (_retrySeconds * 2).clamp(5, 300);
  }

  Future<void> _save() {
    final snapshot = Map<String, dynamic>.from(_record);
    return _writes = _writes
        .catchError((Object _) {})
        .then((_) => storage.write(snapshot));
  }

  void _set({
    bool? registered,
    bool busy = false,
    PrayerAccessContent? content,
    PrayerAccessContent? publicContent,
    String? error,
    String? helpText,
  }) {
    if (!mounted) return;
    state = PriestAccessState(
      registered: registered ?? state.registered,
      busy: busy,
      content: content,
      publicContent: publicContent ?? state.publicContent,
      error: error,
      helpText: helpText ?? state.helpText,
    );
  }

  bool _current(int generation) =>
      mounted && generation == _generation && _online && _foreground;
  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      _record = await storage.read();
      _ready = true;
      _set(
        registered:
            _record['verifiedUid'] is String &&
            _record['pendingDisableUid'] == null,
      );
      await refresh();
    } catch (_) {
      _set(error: const PriestAccessException('STORAGE').message);
      _initializing = null;
    }
  }

  Future<void> _flushRevocation() async {
    final pending = _record['pendingDisableUid'] as String?;
    if (pending == null) return;
    // Keep the Auth session until the server has acknowledged revocation.
    // If the session was lost, a UID alone cannot revoke the old installation.
    if (_uid != pending) throw const PriestAccessException('REVOKED');
    await gateway.disable(pending);
    await gateway.signOut();
    _uid = null;
    _record.remove('pendingDisableUid');
    _record.remove('verifiedUid');
    await _save();
  }

  Future<void> _clearMemory() async {
    final watch = _watch;
    _watch = null;
    _clearing = _clearing.catchError((Object _) {}).then((_) async {
      await watch?.cancel();
      await gateway.clearProtectedMemory();
    });
    try {
      await _clearing;
    } catch (_) {
      /* next entry retries initialization */
    }
  }

  void _watchGrant(String uid) {
    if (_watch != null) return;
    _watch = gateway
        .watchGrant(uid)
        .listen(
          (grant) {
            if (!mounted || _uid != uid || !_online || !_foreground) return;
            if (grant?.active != true) unawaited(_revoked());
          },
          onError: (Object error) {
            if (!mounted || _uid != uid) return;
            if (error is PriestAccessException && error.revoked) {
              unawaited(_revoked());
            } else {
              ++_generation;
              _set(
                error: error is PriestAccessException
                    ? error.message
                    : const PriestAccessException('OFFLINE').message,
              );
              unawaited(_clearMemory().whenComplete(_scheduleRetry));
            }
          },
        );
  }

  Future<void> _revoked() async {
    _retry?.cancel();
    ++_generation;
    _record.remove('verifiedUid');
    _set(
      registered: false,
      error: const PriestAccessException('ACCESS_REQUIRED').message,
    );
    try {
      await _save();
    } catch (_) {
      /* server remains authoritative */
    }
    await _clearMemory();
  }

  Future<void> refresh() async {
    if (!mounted || !_ready || state.busy || !_online || !_foreground) return;
    final generation = _generation;
    _set(busy: true, content: state.content);
    try {
      await _clearing;
      if (!_current(generation)) return;
      _uid = await gateway.restoreSession();
      await _flushRevocation();
      final uid = _uid;
      final grant = uid == null ? null : await gateway.grant(uid);
      if (!_current(generation)) return;
      if (grant != null && !grant.active) {
        await _revoked();
        return;
      }
      if (grant?.active != true) _record.remove('verifiedUid');
      final public = await gateway.publicContent();
      final private = grant?.active == true
          ? await gateway.protectedContent(uid!)
          : null;
      if (!_current(generation)) return;
      // Confirm again after downloading; never expose a response racing revoke.
      if (private != null && (await gateway.grant(uid!))?.active != true) {
        await _revoked();
        return;
      }
      if (!_current(generation)) return;
      final merged = private == null ? null : public.mergeProtected(private);
      final safePublic = merged?.publicOnly ?? public.publicOnly;
      await persistPublic?.call(safePublic);
      if (!_current(generation)) return;
      if (private != null) _record['verifiedUid'] = uid;
      await _save();
      if (!_current(generation)) return;
      _set(
        registered: private != null,
        content: merged,
        publicContent: safePublic,
      );
      _retry?.cancel();
      _retrySeconds = 5;
      if (private != null) {
        _watchGrant(uid!);
        if (grant!.lastActiveAt != null &&
            DateTime.now().difference(grant.lastActiveAt!) >=
                const Duration(hours: 1)) {
          unawaited(gateway.recordActivity(uid).catchError((Object _) {}));
        }
      }
      try {
        final help = await gateway.help();
        if (_current(generation)) _set(content: state.content, helpText: help);
      } catch (_) {
        /* contact is optional */
      }
    } on PriestAccessException catch (error) {
      if (!_current(generation)) return;
      if (error.revoked) {
        await _revoked();
        return;
      }
      _set(error: error.message);
      await _clearMemory();
      _scheduleRetry();
    } catch (_) {
      if (_current(generation)) {
        _set(error: const PriestAccessException('SERVICE_UNAVAILABLE').message);
      }
      await _clearMemory();
      _scheduleRetry();
    }
  }

  Future<void> activate(String code, String deviceName) async {
    await initialize();
    if (!_ready || state.busy || state.registered) return;
    final proof = priestCodeProof(code);
    if (proof == null) {
      _set(error: const PriestAccessException('INVALID_CODE').message);
      return;
    }
    if (!_online || !_foreground) {
      _set(error: const PriestAccessException('OFFLINE').message);
      return;
    }
    final generation = ++_generation;
    _set(busy: true);
    try {
      _uid = await gateway.restoreSession();
      await _flushRevocation();
      final uid = _uid = await gateway.ensureAnonymousSession();
      final existing = await gateway.grant(uid);
      if (existing != null && !existing.active) {
        throw const PriestAccessException('REVOKED');
      }
      if (!_current(generation)) return;
      if (existing == null) {
        await gateway.createGrant(
          uid,
          proof,
          deviceName.trim().substring(
            0,
            deviceName.trim().length.clamp(0, 120),
          ),
        );
      }
      if (!_current(generation)) {
        // Disable during an in-flight registration also revokes a late grant.
        if (_record['pendingDisableUid'] == uid) {
          try {
            await gateway.disable(uid);
          } catch (_) {
            /* durable intent retries */
          }
        }
        return;
      }
      if ((await gateway.grant(uid))?.active != true) {
        throw const PriestAccessException('ACCESS_REQUIRED');
      }
      _record['verifiedUid'] = uid;
      await _save();
      if (!_current(generation)) return;
      _set(registered: true);
      await refresh();
    } on PriestAccessException catch (error) {
      if (_current(generation)) {
        _set(error: error.message);
        if (error.code == 'OFFLINE' ||
            error.code == 'SERVICE_UNAVAILABLE' ||
            error.code == 'GRANT_UNREADABLE') {
          _scheduleRetry();
        }
      }
    } catch (_) {
      if (_current(generation)) {
        _set(error: const PriestAccessException('STORAGE').message);
      }
    }
  }

  Future<void> disable() async {
    await initialize();
    ++_generation;
    _record.remove('verifiedUid');
    if (_uid != null) _record['pendingDisableUid'] = _uid;
    _set(registered: false, busy: true);
    await _watch?.cancel();
    _watch = null;
    var durable = false;
    try {
      await _save();
      durable = true;
      if (!_online) throw const PriestAccessException('OFFLINE');
      await _flushRevocation();
      _set(registered: false);
    } catch (_) {
      if (!durable) {
        // Never let a failed secure-storage write silently restore this grant
        // on restart. Losing the Auth secret also prevents local resurrection.
        try {
          if (_uid != null && _online) await gateway.disable(_uid!);
        } catch (_) {}
        try {
          await gateway.signOut();
          _uid = null;
        } catch (_) {}
      }
      _set(
        registered: false,
        error: durable
            ? 'Доступ выключаны на гэтай прыладзе. Адкліканне будзе паўторана пры злучэнні.'
            : 'Не атрымалася захаваць адкліканне. Доступ выключаны; папрасіце адміністратара праверыць дазвол прылады.',
      );
    }
    await _clearMemory();
    if (_record['pendingDisableUid'] != null) _scheduleRetry();
  }

  void suspend({bool? online, bool? foreground}) {
    _retry?.cancel();
    if (online != null) _online = online;
    if (foreground != null) _foreground = foreground;
    ++_generation;
    _set();
    unawaited(_clearMemory());
  }

  Future<void> resume({bool? online, bool? foreground}) async {
    if (online != null) _online = online;
    if (foreground != null) _foreground = foreground;
    await refresh();
  }

  Future<Map<String, dynamic>?> readPrayer(String id) async {
    final uid = _uid;
    if (uid == null ||
        state.content == null ||
        _record['pendingDisableUid'] != null ||
        !_online ||
        !_foreground) {
      return null;
    }
    final generation = _generation;
    try {
      final prayer = await gateway.readProtectedPrayer(uid, id);
      final grant = await gateway.grant(uid);
      if (!_current(generation)) return null;
      if (grant?.active != true) {
        await _revoked();
        return null;
      }
      return prayer;
    } on PriestAccessException catch (error) {
      if (_current(generation)) {
        if (error.revoked) {
          await _revoked();
        } else {
          ++_generation;
          _set(error: error.message);
          await _clearMemory();
          _scheduleRetry();
        }
      }
      return null;
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    ++_generation;
    unawaited(_watch?.cancel());
    super.dispose();
  }
}

final protectedPrayerProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, id) {
      ref.watch(priestAccessProvider.select((state) => state.content));
      return ref.read(priestAccessProvider.notifier).readPrayer(id);
    });
