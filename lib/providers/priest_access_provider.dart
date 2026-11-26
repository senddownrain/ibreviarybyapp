import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/models/priest_access_content.dart';
import 'package:mybrev_flutter/services/access_sets_v2_code.dart';
import 'package:mybrev_flutter/services/access_sets_v2_gateway.dart';
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
    this.mode = AccessSetsMode.suspended,
    this.allowedSets = const {},
    this.profileRevision,
    this.pendingDisable = false,
    this.canAddCode = false,
    this.canLoadCatalog = false,
    this.catalogLoading = false,
    this.quotaBlocked = false,
    this.generation = 0,
  });
  final bool registered;
  final bool busy;

  /// Only an online, server-verified grant may populate this view.
  final PrayerAccessContent? content;
  final PrayerAccessContent? publicContent;
  final String? error;
  final String helpText;
  final AccessSetsMode mode;
  final Set<String> allowedSets;
  final int? profileRevision;
  final bool pendingDisable;
  final bool canAddCode;
  final bool canLoadCatalog;
  final bool catalogLoading;
  final bool quotaBlocked;
  final int generation;
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
  if (content.prayers.entries.any(
        (entry) => policy.prayerRestricted(entry.value, id: entry.key),
      ) ||
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

typedef _AccessCheck = ({
  AccessSetsMode? mode,
  PriestDeviceGrant? legacy,
  AccessV2Grant? grant,
  AccessEntitlements? entitlements,
});

class PriestAccessController extends StateNotifier<PriestAccessState> {
  PriestAccessController(
    this.gateway,
    this.storage, {
    this.persistPublic,
    AccessSetsV2Gateway? accessSets,
    AccessSetsCatalog? catalog,
  }) : _accessSets =
           accessSets ??
           (gateway is FirebasePriestAccess ? gateway.accessSetsV2 : null),
       _catalog = catalog,
       super(const PriestAccessState());

  final PriestAccessGateway gateway;
  final PriestAccessStorage storage;
  final Future<void> Function(PrayerAccessContent)? persistPublic;
  final AccessSetsV2Gateway? _accessSets;
  final AccessSetsCatalog? _catalog;
  late final AccessSetsCatalog? _canonical =
      _catalog ??
      (_accessSets == null ? null : IndexedAccessSetsCatalog(_accessSets));
  Map<String, dynamic> _record = {};
  String? _uid;
  _AccessCheck? _confirmed;
  int _generation = 0;
  int _visibilityEpoch = 0;
  bool _online = true, _foreground = true, _ready = false;
  bool _quotaBlocked = false;
  bool _helpLoaded = false;
  AccessSetsMode? _publicMode;
  AccessSetsCatalogSession? _catalogSession;
  Future<void>? _catalogRequest;
  Future<void>? _checking;
  Future<void>? _initializing;
  Future<void>? _activation;
  Future<void>? _revocation;
  Future<void> _writes = Future<void>.value();
  Future<void> _clearing = Future<void>.value();
  final _watches = <StreamSubscription<dynamic>>[];
  Timer? _retry;
  int _retrySeconds = 5;

  String? get _pending => _record['pendingDisableUid'] as String?;
  bool _current(int generation) =>
      mounted && generation == _generation && _online && _foreground;

  void _scheduleRetry() {
    if (!mounted ||
        !_online ||
        !_foreground ||
        _quotaBlocked ||
        (_uid == null && _record['verifiedUid'] == null && _pending == null) ||
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
    bool catalogLoading = false,
  }) {
    if (!mounted) return;
    final access = _confirmed;
    state = PriestAccessState(
      registered: registered ?? state.registered,
      busy: busy,
      content: content,
      publicContent: publicContent ?? state.publicContent,
      error: error,
      helpText: helpText ?? state.helpText,
      mode: access == null
          ? AccessSetsMode.suspended
          : access.mode ?? AccessSetsMode.legacy,
      allowedSets: access == null ? const {} : _allowedSets(access),
      profileRevision: access?.entitlements?.revision,
      pendingDisable: _pending != null,
      catalogLoading: catalogLoading,
      quotaBlocked: _quotaBlocked,
      generation: _generation,
      canLoadCatalog:
          access != null &&
          access.mode != AccessSetsMode.suspended &&
          (access.mode == AccessSetsMode.canonical
              ? _allowedSets(access).isNotEmpty
              : access.legacy?.active == true),
      canAddCode:
          access?.mode == AccessSetsMode.canonical &&
          (access?.legacy == null || access?.grant == null),
    );
  }

  Set<String> _allowedSets(_AccessCheck access) => Set.unmodifiable({
    if (access.legacy?.active == true) 'priest',
    ...?access.entitlements?.allowedSets,
  });

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      _record = await storage.read();
      if (!mounted) return;
      _ready = true;
      _set(registered: _record['verifiedUid'] is String && _pending == null);
      await refresh();
    } catch (_) {
      _set(error: const PriestAccessException('STORAGE').message);
      _initializing = null;
    }
  }

  Future<void> _flushRevocation() =>
      _revocation ??= _revoke().whenComplete(() => _revocation = null);

  Future<void> _revoke() async {
    final pending = _pending;
    if (pending == null) return;
    if (_record['confirmedDisableUid'] != pending) {
      if (_uid != pending) throw const PriestAccessException('REVOKED');
      await Future.wait([
        gateway.disable(pending),
        if (_accessSets != null) _revokeV2(pending),
      ]);
      _record['confirmedDisableUid'] = pending;
      // Keep the readback result across a crash between sign-out and cleanup.
      try {
        await _save();
      } catch (_) {
        // Both grants are already revoked on the server.
      }
    }
    if (_uid == pending) {
      await gateway.signOut();
      _uid = null;
    }
    _record.remove('pendingDisableUid');
    _record.remove('confirmedDisableUid');
    _record.remove('verifiedUid');
    _record.remove('v2RulesUid');
    await _save();
  }

  Future<void> _revokeV2(String uid) async {
    final mode = await _accessSets!.readMode(uid);
    if (mode != null) {
      if (_record['v2RulesUid'] != uid) {
        _record['v2RulesUid'] = uid;
        await _save();
      }
      await _accessSets.revokeOwn(uid);
    } else if (_record['v2RulesUid'] == uid) {
      // A rollback or partial outage may hide an already accessible registry.
      throw const PriestAccessException('GRANT_UNREADABLE');
    }
    // With two owner reads denied and no prior S1 observation for this UID,
    // only the legacy registry is present in the deployed contract.
  }

  Future<void> _stopWatching() async {
    final watches = _watches.toList();
    _watches.clear();
    await Future.wait(watches.map((watch) => watch.cancel()));
  }

  Future<void> _clearMemory() {
    final stopping = _stopWatching();
    return _clearing = _clearing
        .catchError((Object _) {})
        .then((_) async {
          try {
            await stopping;
          } finally {
            await gateway.clearProtectedMemory();
          }
        })
        .catchError((Object _) {});
  }

  void _invalidate({String? error, bool busy = false}) {
    ++_generation;
    _confirmed = null;
    _catalogSession = null;
    _catalogRequest = null;
    _set(
      error: _quotaBlocked
          ? const PriestAccessException('QUOTA_EXHAUSTED').message
          : error,
      busy: busy,
    );
  }

  Future<_AccessCheck> _check(String uid) async {
    final legacy = await gateway.grant(uid);
    final mode = await _accessSets?.readMode(uid);
    final grant = mode == null ? null : await _accessSets!.readGrant(uid);
    final entitlements =
        mode == AccessSetsMode.canonical && grant?.active == true
        ? await _accessSets!.readEntitlements(uid, grant!)
        : null;
    return (
      mode: mode,
      legacy: legacy,
      grant: grant,
      entitlements: entitlements,
    );
  }

  void _blockQuota(Object error) {
    if (error is PriestAccessException && error.quotaExhausted) {
      _quotaBlocked = true;
      _retry?.cancel();
    }
  }

  Future<void> _failRead(Object error) async {
    _blockQuota(error);
    _invalidate(
      error: error is PriestAccessException
          ? error.message
          : const PriestAccessException('SERVICE_UNAVAILABLE').message,
    );
    await _clearMemory();
    _scheduleRetry();
  }

  void _watchAccess(String uid, _AccessCheck access, int generation) {
    if (access.mode == null && access.legacy?.active != true) return;

    void changed({Object? error}) {
      if (!_current(generation)) return;
      if (error != null) _blockQuota(error);
      final message = error is PriestAccessException ? error.message : null;
      _invalidate(error: message);
      unawaited(
        _clearMemory().then((_) {
          if (error == null ||
              (error is PriestAccessException && error.revoked)) {
            return refresh();
          }
          _scheduleRetry();
        }),
      );
    }

    // The legacy listener is safe for missing own grants too. It can detect
    // a second branch being added or removed by another tab on the same UID.
    _watches.add(
      gateway.watchGrant(uid).listen((grant) {
        if (grant?.active != access.legacy?.active) changed();
      }, onError: (Object error) => changed(error: error)),
    );
    if (access.mode case final mode?) {
      _watches.add(
        _accessSets!
            .watch(
              uid,
              mode: mode,
              grant: access.grant,
              entitlements: access.entitlements,
            )
            .listen(
              (_) => changed(),
              onError: (Object error) => changed(error: error),
            ),
      );
    }
  }

  Future<void> refresh() => _refresh();

  Future<void> _refresh({String? activationError}) =>
      _checking ??= _confirmAccess(
        activationError: activationError,
      ).whenComplete(() => _checking = null);

  Future<void> _confirmAccess({String? activationError}) async {
    if (!mounted ||
        !_ready ||
        state.busy ||
        _activation != null ||
        _revocation != null ||
        !_online ||
        !_foreground ||
        _quotaBlocked) {
      return;
    }
    final hadPrivateContent = state.content != null;
    _invalidate(busy: true);
    final generation = _generation;
    try {
      if (hadPrivateContent) {
        await _clearMemory();
      } else {
        await _stopWatching();
      }
      await _clearing;
      if (!_current(generation)) return;
      final restoredUid = await gateway.restoreSession();
      if (!_current(generation)) return;
      _uid = restoredUid;
      await _flushRevocation();
      if (!_current(generation)) return;
      final uid = _uid;
      final access = uid == null ? null : await _check(uid);
      if (!_current(generation)) return;
      if (access?.mode != null) _record['v2RulesUid'] = uid;
      // Keep the existing physical public refresh once per process and again
      // at a rollout change. Resume never reads either protected collection.
      var public = state.publicContent;
      final mode = access?.mode ?? AccessSetsMode.legacy;
      if (public == null || mode != _publicMode) {
        public = (await gateway.publicContent()).publicOnly;
        if (!_current(generation)) return;
        await persistPublic?.call(public);
        if (!_current(generation)) return;
        _publicMode = mode;
      }

      final registered =
          access?.legacy?.active == true || access?.grant?.active == true;
      if (registered) {
        _record['verifiedUid'] = uid;
      } else {
        _record.remove('verifiedUid');
      }
      try {
        await _save();
      } catch (_) {
        // This field is a UI hint. Confirmed server rights remain authoritative.
      }
      if (!_current(generation)) return;
      _confirmed = access;
      if (uid != null && access != null) _watchAccess(uid, access, generation);
      if (access?.mode == AccessSetsMode.canonical) {
        _catalogSession = _canonical!.open(
          _allowedSets(access!),
          () => _current(generation) && !_quotaBlocked,
        );
      }
      final revoked =
          access?.legacy?.active == false || access?.grant?.active == false;
      final projectionDenied =
          access?.mode == AccessSetsMode.canonical &&
          access?.grant?.active == true &&
          access?.entitlements == null;
      _set(
        registered: registered,
        publicContent: public,
        error:
            activationError ??
            (!registered && revoked
                ? const PriestAccessException('ACCESS_REQUIRED').message
                : projectionDenied ||
                      (registered && access?.mode == AccessSetsMode.suspended)
                ? const PriestAccessException('SERVICE_UNAVAILABLE').message
                : null),
      );
      _retry?.cancel();
      if (projectionDenied) {
        // Its projection listener cannot stay subscribed while Rules deny it.
        _scheduleRetry();
      } else {
        _retrySeconds = 5;
      }
      final lastActive = access?.legacy?.lastActiveAt;
      if (uid != null &&
          access?.legacy?.active == true &&
          lastActive != null &&
          DateTime.now().difference(lastActive) >= const Duration(hours: 1)) {
        unawaited(
          gateway.recordActivity(uid).catchError((Object error) {
            if (_current(generation) &&
                error is PriestAccessException &&
                error.quotaExhausted) {
              return _failRead(error);
            }
          }),
        );
      }
      try {
        if (_helpLoaded) return;
        final help = await gateway.help();
        if (_current(generation)) {
          _helpLoaded = true;
          _set(
            content: state.content,
            helpText: help,
            error: state.error,
            catalogLoading: state.catalogLoading,
          );
        }
      } catch (error) {
        if (_current(generation) &&
            error is PriestAccessException &&
            error.quotaExhausted) {
          await _failRead(error);
        }
      }
    } catch (error) {
      if (!_current(generation)) return;
      await _failRead(error);
    }
  }

  /// A navigation edge or an explicit user action requests a full catalog.
  /// Concurrent routes reuse one result for the current authorization session.
  Future<void> loadCatalog() async {
    final visibilityEpoch = _visibilityEpoch;
    await initialize();
    await _checking;
    if (!mounted ||
        visibilityEpoch != _visibilityEpoch ||
        !_online ||
        !_foreground ||
        !state.canLoadCatalog ||
        _quotaBlocked ||
        state.content != null) {
      return;
    }
    final request = _catalogRequest ??= _loadConfirmedCatalog();
    try {
      await request;
    } finally {
      if (identical(_catalogRequest, request)) _catalogRequest = null;
    }
  }

  Future<void> _loadConfirmedCatalog() async {
    final uid = _uid!;
    final generation = _generation;
    _set(error: state.error, catalogLoading: true);
    try {
      final public = state.publicContent!;
      final private = _catalogSession == null
          ? await gateway.protectedContent(uid)
          : await _catalogSession!.load(public);
      if (!_current(generation)) return;
      final safePublic = public.mergeProtected(private).publicOnly;
      if (safePublic.prayers.length != public.prayers.length ||
          safePublic.categories.length != public.categories.length) {
        await persistPublic?.call(safePublic);
      }
      if (!_current(generation)) return;
      _set(
        content: safePublic.mergeProtected(private),
        publicContent: safePublic,
        error: state.error,
      );
    } catch (error) {
      if (_current(generation)) await _failRead(error);
    }
  }

  Future<void> retryAfterQuota() async {
    if (!_quotaBlocked || !_online || !_foreground || !mounted) return;
    _quotaBlocked = false;
    await refresh();
  }

  Future<void> activate(String input, String deviceName) async {
    await initialize();
    if (!mounted ||
        !_ready ||
        state.busy ||
        _pending != null ||
        _activation != null ||
        _quotaBlocked) {
      return;
    }
    final code = parseAccessSetsV2Code(input);
    final legacyProof = code == null ? priestCodeProof(input) : null;
    if ((code == null && legacyProof == null) ||
        (code != null && _accessSets == null)) {
      _set(
        content: state.content,
        error: const PriestAccessException('INVALID_CODE').message,
      );
      return;
    }
    if (!_online || !_foreground) {
      _set(error: const PriestAccessException('OFFLINE').message);
      return;
    }
    _invalidate(busy: true);
    final generation = _generation;
    String? error;
    final operation = () async {
      await _stopWatching();
      await _clearing;
      if (!_current(generation)) return;
      final uid = _uid = await gateway.ensureAnonymousSession();
      if (!_current(generation)) return;
      final name = String.fromCharCodes(deviceName.trim().runes.take(120));
      if (code != null) {
        if (await _accessSets!.readMode(uid) != AccessSetsMode.canonical) {
          throw const PriestAccessException('INVALID_CODE');
        }
        if (!_current(generation)) return;
        _record['v2RulesUid'] = uid;
        await _save();
        if (!_current(generation)) return;
        await _accessSets.activate(uid, code, name);
      } else {
        final existing = await gateway.grant(uid);
        if (existing != null && !existing.active) {
          throw const PriestAccessException('REVOKED');
        }
        if (!_current(generation)) return;
        if (existing == null) {
          await gateway.createGrant(uid, legacyProof!, name);
        }
        if ((await gateway.grant(uid))?.active != true) {
          throw const PriestAccessException('ACCESS_REQUIRED');
        }
      }
    }();
    _activation = operation;
    try {
      await operation;
    } catch (failure) {
      _blockQuota(failure);
      error = failure is PriestAccessException
          ? failure.message
          : const PriestAccessException('SERVICE_UNAVAILABLE').message;
    } finally {
      _activation = null;
    }
    if (_quotaBlocked) {
      await _failRead(const PriestAccessException('QUOTA_EXHAUSTED'));
      return;
    }
    if (!_current(generation)) {
      if (mounted && _pending == null) _scheduleRetry();
      return;
    }
    _set(error: error);
    await _refresh(activationError: error);
  }

  Future<void> disable() async {
    await initialize();
    if (!mounted || !_ready || _pending != null) return;
    _retry?.cancel();
    _invalidate(busy: true);
    final generation = _generation;
    final activation = _activation;
    var durable = false;
    try {
      if (_uid == null && activation != null) {
        // An in-flight sign-in may be the only source of the pending UID.
        try {
          await activation;
        } catch (_) {}
      }
      if (!mounted) return;
      final uid = _uid ?? _record['verifiedUid'] as String?;
      _record.remove('verifiedUid');
      if (uid != null) _record['pendingDisableUid'] = uid;
      _set(registered: false, busy: true);
      try {
        await _save();
        durable = true;
      } catch (_) {
        // Try delivering the revoke even if writing the local intent fails.
      }
      if (activation != null) {
        try {
          await activation;
        } catch (_) {}
      }
      await _clearMemory();
      if (!_current(generation)) throw const PriestAccessException('OFFLINE');
      if (_quotaBlocked) throw const PriestAccessException('QUOTA_EXHAUSTED');
      await _flushRevocation();
      _set(registered: false);
    } catch (error) {
      _blockQuota(error);
      _set(
        registered: false,
        error: _quotaBlocked
            ? const PriestAccessException('QUOTA_EXHAUSTED').message
            : durable
            ? 'Доступ выключаны на гэтай прыладзе. Адкліканне будзе паўторана пры злучэнні.'
            : 'Не атрымалася захаваць адкліканне. Доступ выключаны; папрасіце адміністратара праверыць дазвол прылады.',
      );
      await _clearMemory();
      if (_pending != null) _scheduleRetry();
    }
  }

  void suspend({bool? online, bool? foreground}) {
    ++_visibilityEpoch;
    _retry?.cancel();
    if (online != null) _online = online;
    if (foreground != null) _foreground = foreground;
    _invalidate();
    unawaited(_clearMemory());
  }

  Future<void> resume({bool? online, bool? foreground}) async {
    final changed =
        (online != null && online != _online) ||
        (foreground != null && foreground != _foreground);
    if (online != null) _online = online;
    if (foreground != null) _foreground = foreground;
    if (changed && _online && _foreground) {
      await _checking;
      if (_confirmed == null) await refresh();
    }
  }

  Future<Map<String, dynamic>?> readPrayer(String id) async {
    final uid = _uid;
    final access = _confirmed;
    final generation = _generation;
    if (uid == null ||
        access == null ||
        _pending != null ||
        !_current(generation) ||
        !state.canLoadCatalog ||
        _quotaBlocked ||
        id.isEmpty ||
        id.contains('/')) {
      return null;
    }
    try {
      final prayer = access.mode == AccessSetsMode.canonical
          ? await _catalogSession!.readPrayer(id, state.publicContent!)
          : await gateway.readProtectedPrayer(uid, id);
      return _current(generation) ? prayer : null;
    } catch (error) {
      if (_current(generation)) {
        await _failRead(error);
      }
    }
    return null;
  }

  @override
  void dispose() {
    _retry?.cancel();
    ++_generation;
    unawaited(_stopWatching());
    super.dispose();
  }
}

final protectedPrayerProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, id) {
      ref.watch(
        priestAccessProvider.select(
          (state) => (state.generation, state.canLoadCatalog),
        ),
      );
      return ref.read(priestAccessProvider.notifier).readPrayer(id);
    });
