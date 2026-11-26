part of 'firebase_priest_access.dart';

/// Uses the same named Auth and disposable Firestore memory delegate as legacy.
class _FirebaseAccessSetsV2 implements AccessSetsV2Gateway {
  _FirebaseAccessSetsV2(this._owner);

  final FirebasePriestAccess _owner;
  static const _timeout = FirebasePriestAccess._timeout;
  bool _s1Confirmed = false;

  platform.FirebaseFirestorePlatform get _db => _owner._privateDb!;
  platform.DocumentReferencePlatform get _mode =>
      _db.doc('priestContentControl/accessSetsV2');
  platform.DocumentReferencePlatform _grant(String uid) =>
      _db.doc('accessDeviceGrantsV2/$uid');
  platform.DocumentReferencePlatform _entitlements(String profileId) =>
      _db.doc('accessProfilesV2/$profileId/client/entitlements');

  Map<String, dynamic>? _data(platform.DocumentSnapshotPlatform snapshot) {
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw const PriestAccessException('OFFLINE');
    }
    final data = snapshot.data();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  AccessSetsMode _modeData(Map<String, dynamic>? data) {
    if (data == null) return AccessSetsMode.legacy;
    return switch (data['mode']) {
      'legacy' => AccessSetsMode.legacy,
      'canonical' => AccessSetsMode.canonical,
      _ => AccessSetsMode.suspended,
    };
  }

  AccessV2Grant? _grantData(Map<String, dynamic>? data, String uid) {
    if (data == null) return null;
    if (data
        case {
          'uid': String owner,
          'codeId': String codeId,
          'status': String status,
        }
        when owner == uid &&
            RegExp('^$_symbolsForId{16}\$').hasMatch(codeId) &&
            (status == 'active' || status == 'revoked')) {
      return (codeId: codeId, active: status == 'active');
    }
    throw const PriestAccessException('GRANT_UNREADABLE');
  }

  static const _symbolsForId = '[ABCDEFGHJKLMNPQRSTUVWXYZ2-9]';

  AccessEntitlements _entitlementData(
    Map<String, dynamic>? data,
    String profileId,
  ) {
    if (data case {'allowedSets': List sets, 'revision': int revision}
        when revision >= 1 &&
            sets.every((id) => id is String && accessSetId.hasMatch(id))) {
      return AccessEntitlements(profileId, sets.cast<String>(), revision);
    }
    throw const PriestAccessException('SERVICE_UNAVAILABLE');
  }

  @override
  Future<AccessSetsMode?> readMode(String uid) => _owner._run(() async {
    _owner._own(uid);
    try {
      final mode = _modeData(_data(await _owner._get('auth.mode', _mode)));
      _s1Confirmed = true;
      return mode;
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied' || _s1Confirmed) rethrow;
      // Both owner-readable paths are denied by the pre-S1 rules. Preserve
      // legacy reads while those rules remain deployed.
      try {
        await _owner._get('auth.v2Grant', _grant(uid));
      } on FirebaseException catch (grantError) {
        if (grantError.code == 'permission-denied') return null;
        rethrow;
      }
      rethrow;
    }
  });

  @override
  Future<AccessV2Grant?> readGrant(String uid) => _owner._run(() async {
    _owner._own(uid);
    return _grantData(
      _data(await _owner._get('auth.v2Grant', _grant(uid))),
      uid,
    );
  }, readingGrant: true);

  @override
  Future<AccessEntitlements?> readEntitlements(
    String uid,
    AccessV2Grant grant,
  ) => _owner._run(() async {
    _owner._own(uid);
    if (!grant.active) return null;
    try {
      final code = _data(
        await _owner._get(
          'auth.codeProfile',
          _db.doc('accessCodesV2/${grant.codeId}/client/profile'),
        ),
      );
      final profile = code?['profileId'];
      if (profile is! String || !accessSetId.hasMatch(profile)) {
        throw const PriestAccessException('SERVICE_UNAVAILABLE');
      }
      return _entitlementData(
        _data(await _owner._get('auth.entitlements', _entitlements(profile))),
        profile,
      );
    } on FirebaseException catch (error) {
      // A disabled/revoked profile denies the projection. Legacy entitlement
      // is verified independently and can remain available.
      if (error.code == 'permission-denied') return null;
      rethrow;
    }
  });

  @override
  Future<void> activate(
    String uid,
    AccessSetsV2Code code,
    String deviceName,
  ) => _owner._run(
    () async {
      _owner._own(uid);
      final previous = await readGrant(uid);
      if (previous != null) {
        _confirm(previous, code.codeId);
        return;
      }
      Object? commitError;
      try {
        final batch = _db.batch();
        batch.set('accessActivationClaimsV2/$uid', {
          'uid': uid,
          'codeId': code.codeId,
          'activationProof': accessSetsV2CodeProof(code.canonical),
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(_grant(uid).path, {
          'uid': uid,
          'codeId': code.codeId,
          'status': 'active',
          'deviceName': deviceName.isEmpty ? 'Flutter' : deviceName,
          'client': 'Flutter',
          'platform': kIsWeb ? 'Web' : defaultTargetPlatform.name,
          'label': '',
          'activatedAt': FieldValue.serverTimestamp(),
          'lastActiveAt': FieldValue.serverTimestamp(),
          'revokedAt': null,
        });
        await batch.commit().timeout(_timeout);
      } catch (error) {
        commitError = error;
      } finally {
        await _owner.clearProtectedMemory();
      }
      // A timed-out or rejected commit can still have raced a successful grant
      // for this UID. Read back from a fresh delegate before interpreting it.
      final confirmed = await readGrant(uid);
      if (confirmed == null && commitError != null) throw commitError;
      _confirm(confirmed, code.codeId);
    },
    activation: true,
    timeoutTask: false,
  );

  void _confirm(AccessV2Grant? grant, String codeId) {
    if (grant == null) throw const PriestAccessException('SERVICE_UNAVAILABLE');
    if (!grant.active) throw const PriestAccessException('REVOKED');
    if (grant.codeId != codeId) {
      throw const PriestAccessException('INVALID_CODE');
    }
  }

  @override
  Future<void> revokeOwn(String uid) => _owner._run(
    () async {
      final grant = await readGrant(uid);
      if (grant?.active != true) return;
      try {
        await _grant(uid)
            .update({
              FieldPath(['status']): 'revoked',
              FieldPath(['revokedAt']): FieldValue.serverTimestamp(),
            })
            .timeout(_timeout);
      } on FirebaseException {
        if ((await readGrant(uid))?.active == false) return;
        rethrow;
      }
      if ((await readGrant(uid))?.active != false) {
        throw const PriestAccessException('SERVICE_UNAVAILABLE');
      }
    },
    readingGrant: true,
    timeoutTask: false,
  );

  @override
  Future<AccessIndexPage> listIds(
    AccessContentKind kind,
    String setId, {
    int pageSize = 50,
    String? after,
  }) => _owner._run(() async {
    if (!accessSetId.hasMatch(setId) || pageSize < 1 || pageSize > 100) {
      throw const PriestAccessException('SERVICE_UNAVAILABLE');
    }
    var query = _db
        .collection('accessSetsV2/$setId/${kind.name}')
        .orderBy([
          [FieldPath.documentId, false],
        ])
        .limit(pageSize);
    if (after != null) query = query.startAfter([after]);
    final page = await _owner._query('index.${kind.name}', query);
    if (page.metadata.isFromCache || page.metadata.hasPendingWrites) {
      throw const PriestAccessException('OFFLINE');
    }
    final ids = page.docs.map((doc) => doc.id).toList(growable: false);
    return (ids: ids, cursor: ids.length == pageSize ? ids.last : null);
  });

  @override
  Future<Map<String, dynamic>?> readContent(
    AccessContentKind kind,
    String id,
  ) => _owner._run(() async {
    if (id.isEmpty || id.contains('/')) return null;
    try {
      final data = _data(
        await _owner._get(
          'payload.${kind.name}',
          _db.collection(kind.collection).doc(id),
        ),
      );
      return data == null
          ? null
          : firestoreToStorable({
              ...data,
              'id': id,
              'effectivePriestOnly': true,
            });
    } on FirebaseException catch (error) {
      // An index entry never authorizes its payload. A missing or
      // conflicting document is omitted; the provider rechecks entitlements.
      if (error.code == 'permission-denied') return null;
      rethrow;
    }
  });

  @override
  Stream<void> watch(
    String uid, {
    required AccessSetsMode mode,
    required AccessV2Grant? grant,
    required AccessEntitlements? entitlements,
  }) {
    _owner._own(uid);
    final subscriptions = <StreamSubscription<dynamic>>[];
    late final StreamController<void> events;
    void failure(Object error, StackTrace trace) {
      final code = error is FirebaseException ? error.code : '';
      events.addError(
        PriestAccessException(switch (code) {
          'permission-denied' => 'ACCESS_REQUIRED',
          'resource-exhausted' => 'QUOTA_EXHAUSTED',
          _ => 'OFFLINE',
        }),
        trace,
      );
    }

    void listen(
      String operation,
      platform.DocumentReferencePlatform reference,
      bool Function(Map<String, dynamic>?) matches,
    ) {
      var serverSeen = false;
      subscriptions.add(
        reference
            .snapshots(
              includeMetadataChanges: true,
              listenSource: ListenSource.defaultSource,
            )
            .listen((snapshot) {
              if (snapshot.metadata.isFromCache && !serverSeen) return;
              try {
                final data = _data(snapshot);
                _owner._audit(operation, snapshot.exists ? 1 : 0);
                if (!matches(data)) events.add(null);
                serverSeen = true;
              } catch (error, trace) {
                failure(error, trace);
              }
            }, onError: failure),
      );
    }

    events = StreamController<void>(
      onListen: () {
        listen('watch.mode', _mode, (data) => _modeData(data) == mode);
        listen(
          'watch.v2Grant',
          _grant(uid),
          (data) => _grantData(data, uid) == grant,
        );
        if (entitlements != null) {
          final profileId = entitlements.profileId;
          listen(
            'watch.entitlements',
            _entitlements(profileId),
            (data) => entitlements.matches(_entitlementData(data, profileId)),
          );
        }
        subscriptions.add(
          _owner._auth!.idTokenChanges().listen((user) {
            if (user?.uid != uid) events.add(null);
          }, onError: failure),
        );
      },
      onCancel: () async {
        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );
      },
    );
    return events.stream;
  }
}
