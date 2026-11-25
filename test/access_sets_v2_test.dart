import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/services/access_sets_v2_code.dart';
import 'package:mybrev_flutter/services/access_sets_v2_gateway.dart';
import 'package:mybrev_flutter/services/priest_access_gateway.dart';

import 'priest_access_test.dart' show MemoryStorage, SparkGateway, validCode;

const syntheticCode = 'MARI-20261124-ABCDEFGHJKLMNPQR-STUVWXYZ23456789ABCDEFGH';
const privateMarker = 'S7 synthetic private text';

class TestAccessSets implements AccessSetsV2Gateway {
  AccessSetsMode? mode = AccessSetsMode.canonical;
  AccessV2Grant? grant;
  AccessEntitlements? profile = AccessEntitlements('example', ['marian'], 1);
  final events = StreamController<void>.broadcast();
  final pages = <(AccessContentKind, String, String?)>[];
  final reads = <(AccessContentKind, String)>[];
  Completer<void>? pauseRead;
  bool canRevoke = true;
  bool quotaOnPayload = false;
  int accessReads = 0;
  String? revokedUid;
  String? activatedUid;
  final indexes = <String, List<String>>{
    'marian': ['marian-one', 'shared'],
    'priest': ['priest-one', 'shared'],
  };

  @override
  Future<AccessSetsMode?> readMode(String uid) async {
    accessReads++;
    return mode;
  }

  @override
  Future<AccessV2Grant?> readGrant(String uid) async => grant;
  @override
  Future<AccessEntitlements?> readEntitlements(
    String uid,
    AccessV2Grant grant,
  ) async => profile;

  @override
  Future<void> activate(
    String uid,
    AccessSetsV2Code code,
    String deviceName,
  ) async {
    expect(deviceName.length, lessThanOrEqualTo(120));
    if (code.canonical != syntheticCode) {
      throw const PriestAccessException('INVALID_CODE');
    }
    activatedUid = uid;
    grant = (codeId: code.codeId, active: true);
  }

  @override
  Future<void> revokeOwn(String uid) async {
    if (!canRevoke) throw const PriestAccessException('OFFLINE');
    revokedUid = uid;
    if (grant case final previous?) {
      grant = (codeId: previous.codeId, active: false);
    }
  }

  @override
  Stream<void> watch(
    String uid, {
    required AccessSetsMode mode,
    required AccessV2Grant? grant,
    required AccessEntitlements? entitlements,
  }) => events.stream;

  @override
  Future<AccessIndexPage> listIds(
    AccessContentKind kind,
    String setId, {
    int pageSize = 50,
    String? after,
  }) async {
    pages.add((kind, setId, after));
    if (kind == AccessContentKind.categories) {
      return (ids: <String>[], cursor: null);
    }
    final ids = indexes[setId]!;
    if (ids.length > 2) return (ids: ids, cursor: null);
    // Force a cursor on a small synthetic catalog.
    return after == null
        ? (ids: ids.take(1).toList(), cursor: ids.first)
        : (ids: ids.skip(1).toList(), cursor: null);
  }

  @override
  Future<Map<String, dynamic>?> readContent(
    AccessContentKind kind,
    String id,
  ) async {
    reads.add((kind, id));
    if (quotaOnPayload) {
      throw const PriestAccessException('QUOTA_EXHAUSTED');
    }
    await pauseRead?.future;
    final effective = indexes.entries
        .where((entry) => entry.value.contains(id))
        .map((entry) => entry.key)
        .toList();
    if (effective.isEmpty) return null;
    return {
      'id': id,
      'title': id,
      'text': privateMarker,
      'accessSchemaVersion': 2,
      'accessSets': effective,
      'effectiveAccessSets': effective,
      'contentHash': '0' * 64,
    };
  }
}

void main() {
  test('quota stops the payload queue and disables automatic retry', () async {
    final legacy = SparkGateway();
    final v2 = TestAccessSets();
    final controller = PriestAccessController(
      legacy,
      MemoryStorage(),
      accessSets: v2,
    );
    addTearDown(() async {
      controller.dispose();
      await v2.events.close();
      await legacy.close();
    });
    var timers = 0;
    await runZoned(
      () async {
        await controller.activate(syntheticCode, 'Device');
        v2.indexes['marian'] = [for (var i = 0; i < 20; i++) 'quota-$i'];
        v2.quotaOnPayload = true;
        await controller.loadCatalog();
        expect(controller.state.quotaBlocked, true);
        expect(controller.state.content, isNull);
        expect(v2.reads.length, inInclusiveRange(1, 4));
        final attempts = (v2.accessReads, v2.pages.length, v2.reads.length);
        controller.suspend(foreground: false);
        await controller.resume(foreground: true);
        await controller.loadCatalog();
        await controller.readPrayer('quota-0');
        expect((v2.accessReads, v2.pages.length, v2.reads.length), attempts);
        expect(timers, 0);

        v2.quotaOnPayload = false;
        await controller.retryAfterQuota();
        expect(controller.state.canLoadCatalog, true);
        expect(controller.state.content, isNull);
        await controller.loadCatalog();
        expect(controller.state.content?.prayers.containsKey('quota-0'), true);
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          timers++;
          return parent.createTimer(zone, duration, callback);
        },
      ),
    );
  });

  test('every pinned S1 JavaScript/Dart code vector', () {
    final vectors =
        jsonDecode(
              File(
                'test/fixtures/access-sets-v2-code-vectors.json',
              ).readAsStringSync(),
            )
            as Map;
    for (final vector in vectors['valid'] as List) {
      final code = parseAccessSetsV2Code(vector['input']);
      expect(code?.codeId, vector['codeId']);
      expect(code?.canonical, vector['canonical']);
      expect(accessSetsV2CodeProof(code!.canonical), vector['proof']);
    }
    for (final invalid in vectors['invalid'] as List) {
      expect(parseAccessSetsV2Code(invalid), isNull);
    }
  });

  late SparkGateway legacy;
  late TestAccessSets v2;
  late MemoryStorage storage;
  late PriestAccessController controller;
  late List<PrayerAccessContent> persisted;
  setUp(() async {
    legacy = SparkGateway();
    v2 = TestAccessSets();
    storage = MemoryStorage();
    persisted = [];
    controller = PriestAccessController(
      legacy,
      storage,
      accessSets: v2,
      persistPublic: (snapshot) async => persisted.add(snapshot),
    );
    await controller.initialize();
  });

  tearDown(() async {
    controller.dispose();
    await v2.events.close();
    await legacy.close();
  });

  test(
    'startup, resume and a deep link never request a catalog page',
    () async {
      await controller.activate(syntheticCode, 'Device');
      expect(controller.state.canLoadCatalog, true);
      expect(controller.state.content, isNull);
      expect(v2.pages, isEmpty);
      expect(v2.reads, isEmpty);
      expect(
        (await controller.readPrayer('marian-one'))?['text'],
        privateMarker,
      );
      expect(v2.pages, isEmpty);
      expect(v2.reads, [(AccessContentKind.prayers, 'marian-one')]);

      await Future.wait([controller.loadCatalog(), controller.loadCatalog()]);
      final pageCount = v2.pages.length;
      final payloadCount = v2.reads.length;
      expect(pageCount, 3);
      expect(payloadCount, 2);
      await controller.loadCatalog();
      await controller.readPrayer('shared');
      expect(v2.pages, hasLength(pageCount));
      expect(v2.reads, hasLength(payloadCount));

      controller.suspend(foreground: false);
      await controller.resume(foreground: true);
      expect(controller.state.canLoadCatalog, true);
      expect(controller.state.content, isNull);
      expect(v2.pages, hasLength(pageCount));
      expect(v2.reads, hasLength(payloadCount));
      expect(
        (await controller.readPrayer('marian-one'))?['text'],
        privateMarker,
      );
      expect(v2.pages, hasLength(pageCount));
      expect(v2.reads, hasLength(payloadCount + 1));
    },
  );

  test(
    'pre-S1 disable revokes legacy and completes without a V2 registry',
    () async {
      v2.mode = null;
      await controller.activate(validCode, 'Device');
      expect(controller.state.canLoadCatalog, true);
      expect(storage.record['v2RulesUid'], isNull);
      await controller.disable();
      expect(legacy.active, false);
      expect(legacy.uid, isNull);
      expect(controller.state.pendingDisable, false);
      expect(v2.revokedUid, isNull);
    },
  );

  test(
    'a previously observed S1 registry cannot be skipped on rollback',
    () async {
      await controller.activate(validCode, 'Device');
      await controller.activate(syntheticCode, 'Device');
      final uid = legacy.uid;
      v2.mode = null;
      await controller.disable();
      expect(legacy.active, false);
      expect(v2.grant?.active, true);
      expect(legacy.uid, uid);
      expect(storage.record['pendingDisableUid'], uid);
      expect(controller.state.pendingDisable, true);
    },
  );

  test(
    'guest and marian-only never use the legacy mirror or persist private data',
    () async {
      expect(legacy.signups, 0);
      expect(controller.state.content, isNull);
      expect(await controller.readPrayer('marian-one'), isNull);
      await controller.activate(syntheticCode, 'Device');
      await controller.loadCatalog();
      expect(controller.state.allowedSets, {'marian'});
      expect(controller.state.profileRevision, 1);
      expect(controller.state.content!.prayers.keys, {
        'public',
        'marian-one',
        'shared',
      });
      expect(legacy.reads, 0);
      expect(await controller.readPrayer('priest-one'), isNull);
      expect(
        (await controller.readPrayer('marian-one'))?['text'],
        privateMarker,
      );
      expect(persisted.expand((snapshot) => snapshot.prayers.keys).toSet(), {
        'public',
      });
      expect(
        storage.record.keys,
        unorderedEquals(['verifiedUid', 'v2RulesUid']),
      );
      controller.suspend(online: false);
      expect(controller.state.content, isNull);
      expect(controller.state.publicContent!.prayers.keys, ['public']);
      expect(await controller.readPrayer('marian-one'), isNull);
      await controller.resume(online: true);
      expect(controller.state.allowedSets, {'marian'});
      expect(legacy.signups, 1);
    },
  );

  test(
    'prior legacy UID adds V2 without losing priest or reusing payload reads',
    () async {
      v2.mode = AccessSetsMode.legacy;
      await controller.activate(validCode, 'Device');
      await controller.loadCatalog();
      final uid = legacy.uid;
      expect(controller.state.content!.prayers.keys, contains('single'));
      final mirrorReads = legacy.reads;
      v2.mode = AccessSetsMode.canonical;
      await controller.refresh();
      await controller.loadCatalog();
      expect(controller.state.allowedSets, {'priest'});
      expect(controller.state.canAddCode, true);
      expect(controller.state.content!.prayers.keys, isNot(contains('single')));
      v2.profile = AccessEntitlements('example', [
        'priest',
        'marian',
        'marian',
      ], 3);
      v2.reads.clear();
      await controller.activate(syntheticCode, 'Device');
      await controller.loadCatalog();
      expect(v2.activatedUid, uid);
      expect(legacy.signups, 1);
      expect(legacy.reads, mirrorReads);
      expect(controller.state.allowedSets, {'priest', 'marian'});
      expect(controller.state.profileRevision, 3);
      expect(
        v2.pages,
        contains((AccessContentKind.prayers, 'marian', 'marian-one')),
      );
      expect(v2.reads.where((entry) => entry.$2 == 'shared'), hasLength(1));
      v2.profile = null;
      await controller.refresh();
      await controller.loadCatalog();
      expect(controller.state.allowedSets, {'priest'});
      expect(
        controller.state.content!.prayers.containsKey('marian-one'),
        false,
      );
      v2.mode = AccessSetsMode.suspended;
      await controller.refresh();
      expect(controller.state.mode, AccessSetsMode.suspended);
      expect(controller.state.content, isNull);
      expect(controller.state.registered, true);
      v2.mode = AccessSetsMode.legacy;
      await controller.refresh();
      await controller.loadCatalog();
      expect(controller.state.content!.prayers.keys, contains('single'));
    },
  );

  test(
    'one branch revoke discards a racing reader and preserves independent rights',
    () async {
      await controller.activate(validCode, 'Device');
      await controller.activate(syntheticCode, 'Device');
      final pause = v2.pauseRead = Completer<void>();
      final reader = controller.readPrayer('marian-one');
      await Future<void>.delayed(Duration.zero);
      v2.grant = (codeId: v2.grant!.codeId, active: false);
      v2.events.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.content?.prayers.containsKey('marian-one'),
        isNot(true),
      );
      v2.pauseRead = null;
      pause.complete();
      expect(await reader, isNull);
      await Future<void>.delayed(Duration.zero);
      await controller.loadCatalog();
      expect(controller.state.allowedSets, {'priest'});
      expect(
        controller.state.content!.prayers.keys,
        isNot(contains('marian-one')),
      );
    },
  );

  test(
    'partial offline revocation retries both branches with the same UID',
    () async {
      await controller.activate(validCode, 'Device');
      await controller.activate(syntheticCode, 'Device');
      await controller.loadCatalog();
      final uid = legacy.uid;
      v2.canRevoke = false;
      await controller.disable();
      expect(legacy.active, false);
      expect(v2.grant!.active, true);
      expect(legacy.uid, uid);
      expect(controller.state.pendingDisable, true);
      expect(controller.state.content, isNull);
      expect(storage.record['pendingDisableUid'], uid);
      v2.canRevoke = true;
      await controller.refresh();
      expect(v2.revokedUid, uid);
      expect(v2.grant!.active, false);
      expect(legacy.uid, isNull);
      expect(controller.state.pendingDisable, false);
    },
  );
}
