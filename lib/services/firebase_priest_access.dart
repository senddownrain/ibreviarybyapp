import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/models/priest_access_content.dart';
import 'package:mybrev_flutter/services/access_sets_v2_code.dart';
import 'package:mybrev_flutter/services/access_sets_v2_gateway.dart';
import 'package:mybrev_flutter/services/priest_access_gateway.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';

part 'firebase_access_sets_v2.dart';

/// Shared Spark claim/grant batch contract from mybrev, no Functions/HTTP API.
class FirebasePriestAccess implements PriestAccessGateway {
  static const appName = 'mybrev-priest';
  static const _server = GetOptions(source: Source.server);
  static const _timeout = Duration(seconds: 15);
  FirebaseApp? _app;
  FirebaseAuth? _auth;
  platform.FirebaseFirestorePlatform? _privateDb;
  Future<void>? _initializing;
  Future<void> _clearing = Future<void>.value();
  bool _closed = false;
  late final AccessSetsV2Gateway accessSetsV2 = _FirebaseAccessSetsV2(this);

  Future<void> _initialize() async {
    await _clearing;
    if (_closed) throw const PriestAccessException('SERVICE_UNAVAILABLE');
    if (_initializing != null) {
      await _initializing;
      return;
    }
    if (_privateDb != null) return;
    await (_initializing ??= _create().whenComplete(
      () => _initializing = null,
    ));
  }

  Future<void> _create() async {
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
    const useEmulators = bool.fromEnvironment('PRIEST_USE_EMULATORS');
    if ((useEmulators || host.isNotEmpty) &&
        (!kDebugMode ||
            !useEmulators ||
            !['localhost', '127.0.0.1', '10.0.2.2'].contains(host) ||
            Firebase.app().options.projectId != 'demo-rules')) {
      throw const PriestAccessException('SERVICE_UNAVAILABLE');
    }
    _app =
        Firebase.apps.where((app) => app.name == appName).firstOrNull ??
        await Firebase.initializeApp(
          name: appName,
          options: Firebase.app().options,
        );
    _auth = FirebaseAuth.instanceFor(app: _app!);
    // A fresh delegate is required after terminate: cloud_firestore caches its
    // high-level wrapper by app name, including a terminated web delegate.
    final db = platform.FirebaseFirestorePlatform.instanceFor(
      app: _app!,
      databaseId: '(default)',
    );
    // Must precede every grant/text read. Default public Firestore is untouched.
    db.settings = const Settings(persistenceEnabled: false);
    // FlutterFire Web maps false to setLogLevel('silent'). Failed SDK writes
    // must not print their full activation payload/proof, even in debug builds.
    await FirebaseFirestore.setLoggingEnabled(false);
    if (useEmulators) {
      await _auth!.useAuthEmulator(
        host,
        const int.fromEnvironment(
          'FIREBASE_AUTH_EMULATOR_PORT',
          defaultValue: 9099,
        ),
      );
      const port = int.fromEnvironment(
        'FIRESTORE_EMULATOR_PORT',
        defaultValue: 8089,
      );
      if (kIsWeb) {
        db.useEmulator(host, port);
      } else {
        db.settings = db.settings.copyWith(
          host: '$host:$port',
          sslEnabled: false,
        );
      }
    }
    if (kIsWeb) await _auth!.setPersistence(Persistence.LOCAL);
    await _auth!.authStateChanges().first.timeout(_timeout);
    _privateDb = db;
  }

  Future<T> _run<T>(
    Future<T> Function() task, {
    bool activation = false,
    bool readingGrant = false,
    bool timeoutTask = true,
  }) async {
    try {
      await _initialize();
      return timeoutTask ? await task().timeout(_timeout) : await task();
    } on PriestAccessException {
      rethrow;
    } on TimeoutException {
      throw const PriestAccessException('OFFLINE');
    } on FirebaseAuthException catch (error) {
      if (kDebugMode) debugPrint('[PriestAccess] Auth error: ${error.code}');
      throw PriestAccessException(switch (error.code) {
        'operation-not-allowed' => 'AUTH_DISABLED',
        'network-request-failed' => 'OFFLINE',
        'too-many-requests' => 'TOO_MANY_ATTEMPTS',
        _ => 'SERVICE_UNAVAILABLE',
      });
    } on FirebaseException catch (error) {
      if (kDebugMode) {
        debugPrint('[PriestAccess] Firestore error: ${error.code}');
      }
      throw PriestAccessException(switch (error.code) {
        'permission-denied' =>
          activation
              ? 'INVALID_CODE'
              : readingGrant
              ? 'GRANT_UNREADABLE'
              : 'ACCESS_REQUIRED',
        'unauthenticated' => 'ACCESS_REQUIRED',
        'unavailable' || 'deadline-exceeded' => 'OFFLINE',
        'resource-exhausted' => 'TOO_MANY_ATTEMPTS',
        _ => 'SERVICE_UNAVAILABLE',
      });
    } catch (error) {
      // Only the exception type is logged; SDK errors can contain payloads.
      if (kDebugMode) {
        debugPrint('[PriestAccess] SDK error: ${error.runtimeType}');
      }
      throw const PriestAccessException('SERVICE_UNAVAILABLE');
    }
  }

  void _own(String uid) {
    if (_auth?.currentUser?.uid != uid) {
      throw const PriestAccessException('ACCESS_REQUIRED');
    }
  }

  @override
  Future<String?> restoreSession() => _run(() async => _auth!.currentUser?.uid);
  @override
  Future<String> ensureAnonymousSession() => _run(() async {
    final user = _auth!.currentUser ?? (await _auth!.signInAnonymously()).user;
    if (user == null || !user.isAnonymous) {
      throw const PriestAccessException('SERVICE_UNAVAILABLE');
    }
    return user.uid;
  });
  platform.DocumentReferencePlatform _grant(String uid) =>
      _privateDb!.collection('priestDeviceGrants').doc(uid);
  PriestDeviceGrant? _grantData(platform.DocumentSnapshotPlatform snapshot) {
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw const PriestAccessException('OFFLINE');
    }
    final data = snapshot.data();
    if (data == null) return null;
    // New Rules reject owner reads of legacy proof-bearing grants until the
    // field-only web migration. Never mistake an incomplete rollout for revoke.
    if (data.containsKey('activationProof')) {
      throw const PriestAccessException('GRANT_UNREADABLE');
    }
    return PriestDeviceGrant(
      snapshot.id,
      data['uid'] == snapshot.id && data['status'] == 'active',
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<PriestDeviceGrant?> grant(String uid) => _run(() async {
    _own(uid);
    return _grantData(await _grant(uid).get(_server));
  }, readingGrant: true);
  @override
  Stream<PriestDeviceGrant?> watchGrant(String uid) {
    // Called only after a successful server grant check. Forward cancellation
    // directly: async* + await-for can wait for another Firestore event forever
    // when the installation goes offline, preventing memory cleanup/resume.
    _own(uid);
    var serverSeen = false;
    return _grant(uid)
        .snapshots(
          includeMetadataChanges: true,
          listenSource: ListenSource.defaultSource,
        )
        .transform(
          StreamTransformer.fromHandlers(
            handleData: (snapshot, sink) {
              if (serverSeen && snapshot.metadata.isFromCache) {
                sink.addError(const PriestAccessException('OFFLINE'));
                return;
              }
              if (!snapshot.metadata.isFromCache) serverSeen = true;
              if (!snapshot.metadata.isFromCache &&
                  !snapshot.metadata.hasPendingWrites) {
                sink.add(_grantData(snapshot));
              }
            },
            handleError: (Object error, StackTrace trace, sink) {
              sink.addError(
                PriestAccessException(
                  error is FirebaseException &&
                          error.code == 'permission-denied'
                      ? 'GRANT_UNREADABLE'
                      : 'OFFLINE',
                ),
                trace,
              );
            },
          ),
        );
  }

  @override
  Future<void> createGrant(String uid, String proof, String deviceName) => _run(
    () async {
      _own(uid);
      try {
        try {
          final batch = _privateDb!.batch();
          batch.set('priestActivationClaims/$uid', {
            'uid': uid,
            'activationProof': proof,
            'createdAt': FieldValue.serverTimestamp(),
          });
          batch.set('priestDeviceGrants/$uid', {
            'uid': uid,
            'status': 'active',
            'deviceName': deviceName.isEmpty ? 'Flutter' : deviceName,
            'client': 'Flutter',
            'platform': kIsWeb ? 'Web' : defaultTargetPlatform.name,
            'label': deviceName,
            'activatedAt': FieldValue.serverTimestamp(),
            'lastActiveAt': FieldValue.serverTimestamp(),
            'revokedAt': null,
          });
          // Both documents must be NEW; Rules validate their post-batch state.
          // No claim get/list, no proof in the readable grant, no legacy fallback.
          await batch.commit().timeout(_timeout);
        } finally {
          // Unlike Firestore Lite, the full SDK caches its own claim write.
          // Discard that client on success, denial AND timeout, keeping Auth.
          await clearProtectedMemory();
        }
      } on FirebaseException catch (error) {
        // Another browser tab may have registered the restored UID meanwhile.
        // Only a fresh, acknowledged server grant can resolve that race.
        if (error.code == 'permission-denied' &&
            (await grant(uid))?.active == true) {
          return;
        }
        rethrow;
      }
    },
    activation: true,
    // The commit has its own timeout. An outer timeout could return before
    // finally finishes destroying the SDK cache / pending offline write queue.
    timeoutTask: false,
  );
  @override
  Future<void> disable(String uid) => _run(() async {
    _own(uid);
    final snapshot = await _grant(uid).get(_server);
    if (_grantData(snapshot)?.active == true) {
      await _grant(uid).update({
        FieldPath(['status']): 'revoked',
        FieldPath(['revokedAt']): FieldValue.serverTimestamp(),
      });
      if (_grantData(await _grant(uid).get(_server))?.active != false) {
        throw const PriestAccessException('SERVICE_UNAVAILABLE');
      }
    }
  }, readingGrant: true);
  @override
  Future<void> signOut() => _run(() => _auth!.signOut());
  @override
  Future<void> recordActivity(String uid) => _run(() async {
    _own(uid);
    await _grant(uid).update({
      FieldPath(['lastActiveAt']): FieldValue.serverTimestamp(),
    });
  });
  @override
  Future<String> help() => _run(
    () async =>
        (await _privateDb!
                .collection('priestAccessPublic')
                .doc('help')
                .get(_server))
            .data()?['helpText']
            ?.toString() ??
        '',
  );
  Map<String, Map<String, dynamic>> _documents(
    platform.QuerySnapshotPlatform snapshot, {
    bool protected = false,
  }) {
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw const PriestAccessException('OFFLINE');
    }
    return {
      for (final item in snapshot.docs)
        item.id: firestoreToStorable({
          ...Map<String, dynamic>.from(item.data()!),
          'id': item.id,
          if (protected) 'effectivePriestOnly': true,
        }),
    };
  }

  @override
  Future<PrayerAccessContent> publicContent() async {
    try {
      // Ordinary readers do not need Anonymous Authentication.
      final db = FirebaseFirestore.instance;
      final snapshots = await Future.wait([
        db.collection('prayers').get(_server),
        db.collection('prayerCategories').get(_server),
      ]).timeout(_timeout);
      if (snapshots.any(
        (snapshot) =>
            snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites,
      )) {
        throw const PriestAccessException('OFFLINE');
      }
      return PrayerAccessContent(
        {
          for (final item in snapshots[0].docs)
            item.id: firestoreToStorable({...item.data(), 'id': item.id}),
        },
        {
          for (final item in snapshots[1].docs)
            item.id: firestoreToStorable({...item.data(), 'id': item.id}),
        },
      ).publicOnly;
    } on TimeoutException {
      throw const PriestAccessException('OFFLINE');
    } on FirebaseException {
      throw const PriestAccessException('OFFLINE');
    }
  }

  @override
  Future<PrayerAccessContent> protectedContent(String uid) => _run(() async {
    _own(uid);
    final snapshots = await Future.wait([
      _privateDb!.collection('priestProtectedPrayers').get(_server),
      _privateDb!.collection('priestProtectedCategories').get(_server),
    ]);
    return PrayerAccessContent(
      _documents(snapshots[0], protected: true),
      _documents(snapshots[1], protected: true),
    );
  });
  @override
  Future<Map<String, dynamic>?> readProtectedPrayer(String uid, String id) =>
      _run(() async {
        _own(uid);
        final snapshot = await _privateDb!
            .collection('priestProtectedPrayers')
            .doc(id)
            .get(_server);
        if (snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          throw const PriestAccessException('OFFLINE');
        }
        final data = snapshot.data();
        return data == null
            ? null
            : firestoreToStorable({
                ...Map<String, dynamic>.from(data),
                'id': id,
                'effectivePriestOnly': true,
              });
      });
  @override
  Future<void> clearProtectedMemory() {
    // Deleting the named App drops the memory Firestore client. Firebase Auth's
    // persisted session is restored under the same name; this is not signOut.
    return _clearing = _clearing.catchError((Object _) {}).then((_) async {
      await _initializing;
      final app = _app;
      final db = _privateDb;
      _app = null;
      _auth = null;
      _privateDb = null;
      try {
        if (db != null) await db.terminate();
      } finally {
        if (app != null) await app.delete();
      }
    });
  }

  @override
  Future<void> close() async {
    _closed = true;
    await clearProtectedMemory();
  }
}
