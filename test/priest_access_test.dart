import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/services/priest_access_gateway.dart';
import 'package:mybrev_flutter/services/priest_access_policy.dart';
import 'package:mybrev_flutter/services/priest_access_storage.dart';
import 'package:mybrev_flutter/services/priest_code.dart';

const validCode = 'A2B3-C4D5-E6F7-G8H9-J2K3-L4M5';
const wrongCode = 'N2P3-Q4R5-S6T7-U8V9-W2X3-Y4Z5';

class MemoryStorage implements PriestAccessStorage {
  Map<String, dynamic> record = {};
  bool failWrites = false;
  @override
  Future<Map<String, dynamic>> read() async => Map.of(record);
  @override
  Future<void> write(Map<String, dynamic> data) async {
    if (failWrites) throw StateError('storage unavailable');
    record = jsonDecode(jsonEncode(data));
  }
}

const categories = {
  'public': <String, dynamic>{
    'name': 'Public',
    'tags': ['public'],
  },
  'root': <String, dynamic>{
    'name': 'Root',
    'tags': ['root'],
    'priestOnly': true,
  },
  'child': <String, dynamic>{
    'name': 'Child',
    'tags': ['child'],
    'parentId': 'root',
  },
  'leaf': <String, dynamic>{
    'name': 'Leaf',
    'tags': ['leaf'],
    'parentId': 'child',
  },
};
const prayers = {
  'public': <String, dynamic>{
    'title': 'Public',
    'text': 'public text',
    'tags': ['public'],
  },
  'single': <String, dynamic>{
    'title': 'Single',
    'text': 'secret single',
    'priestOnly': true,
    'tags': ['public'],
  },
  'nested': <String, dynamic>{
    'title': 'Nested',
    'text': 'secret nested',
    'tags': ['leaf', 'public'],
  },
  'explicit': <String, dynamic>{
    'title': 'Explicit',
    'text': 'secret explicit',
    'categoryId': 'child',
  },
};

/// Controller fake only. Authoritative Rules/Auth are separately exercised
/// against the real Firebase Emulator by the native integration suite.
class SparkGateway implements PriestAccessGateway {
  String expectedProof = priestCodeProof(validCode)!;
  String? uid;
  bool active = false, exists = false, offline = false, unreadable = false;
  int signups = 0, activations = 0, reads = 0, clears = 0;
  Completer<void>? pauseContent, pauseReader, pauseActivation;
  final events = StreamController<PriestDeviceGrant?>.broadcast();
  void check() {
    if (offline) throw const PriestAccessException('OFFLINE');
  }

  void authorize(String id) {
    check();
    if (!active || uid != id) {
      throw const PriestAccessException('ACCESS_REQUIRED');
    }
  }

  @override
  Future<String?> restoreSession() async => uid;
  @override
  Future<String> ensureAnonymousSession() async {
    check();
    return uid ??= 'uid-${++signups}';
  }

  @override
  Future<PriestDeviceGrant?> grant(String id) async {
    check();
    if (unreadable) throw const PriestAccessException('GRANT_UNREADABLE');
    return exists ? PriestDeviceGrant(id, active) : null;
  }

  @override
  Stream<PriestDeviceGrant?> watchGrant(String id) => events.stream;
  @override
  Future<void> createGrant(String id, String proof, String deviceName) async {
    check();
    await pauseActivation?.future;
    if (proof != expectedProof || exists) {
      throw const PriestAccessException('INVALID_CODE');
    }
    exists = active = true;
    activations++;
  }

  @override
  Future<void> disable(String id) async {
    check();
    if (uid != id) throw const PriestAccessException('ACCESS_REQUIRED');
    active = false;
  }

  @override
  Future<void> signOut() async {
    uid = null;
    exists = false;
  }

  @override
  Future<void> recordActivity(String id) async => authorize(id);
  @override
  Future<String> help() async => 'contact@example.test';
  @override
  Future<PrayerAccessContent> publicContent() async {
    check();
    return const PrayerAccessContent(prayers, categories).publicOnly;
  }

  @override
  Future<PrayerAccessContent> protectedContent(String id) async {
    authorize(id);
    reads++;
    await pauseContent?.future;
    return PrayerAccessContent(
      {
        for (final e in prayers.entries)
          if (e.key != 'public') e.key: e.value,
      },
      {
        for (final e in categories.entries)
          if (e.key != 'public') e.key: e.value,
      },
    );
  }

  @override
  Future<Map<String, dynamic>?> readProtectedPrayer(
    String id,
    String prayerId,
  ) async {
    authorize(id);
    reads++;
    await pauseReader?.future;
    return prayers[prayerId];
  }

  @override
  Future<void> clearProtectedMemory() async {
    clears++;
  }

  @override
  Future<void> close() async {
    await events.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'exact official web normalization/proof vectors, including Unicode rejection',
    () {
      final vectors =
          jsonDecode(
                File(
                  'test/fixtures/priest-code-vectors.json',
                ).readAsStringSync(),
              )
              as List;
      for (final vector in vectors) {
        expect(normalizePriestCode(vector['input']), vector['normalized']);
        expect(priestCodeProof(vector['input']), vector['proof']);
      }
    },
  );
  test(
    'inherited categories, multi-tags, explicit IDs, dangling links and cycles fail closed',
    () {
      final policy = PriestAccessPolicy({
        ...categories,
        'broken': {'parentId': 'missing'},
        'a': {'parentId': 'b'},
        'b': {'parentId': 'a'},
      });
      expect(policy.categoryRestricted('public'), false);
      for (final id in ['root', 'child', 'leaf', 'broken', 'a', 'b']) {
        expect(policy.categoryRestricted(id), true);
      }
      expect(policy.prayerRestricted(prayers['public']!), false);
      for (final id in ['single', 'nested', 'explicit']) {
        expect(policy.prayerRestricted(prayers[id]!), true);
      }
      expect(
        policy.prayerRestricted({
          'categoryIds': ['public', 'missing'],
        }),
        true,
      );
    },
  );
  test(
    'APK source bundle has no explicitly or transitively protected documents',
    () {
      final cats = decodeContentCollection(
        File('assets/content/prayerCategories.json.gz').readAsBytesSync(),
      );
      final docs = decodeContentCollection(
        File('assets/content/prayers.json.gz').readAsBytesSync(),
      );
      final policy = PriestAccessPolicy(cats.docs);
      expect(cats.docs.keys.where(policy.categoryRestricted), isEmpty);
      expect(docs.docs.values.where(policy.prayerRestricted), isEmpty);
    },
  );
  test(
    'merge preserves IDs, deduplicates and never persists protected storage documents',
    () {
      const public = PrayerAccessContent({
        'same': {'text': 'old public'},
      }, {});
      const private = PrayerAccessContent({
        'same': {'text': 'new private'},
      }, {});
      final merged = public.mergeProtected(private);
      expect(merged.prayers.length, 1);
      expect(merged.prayers['same']!['text'], 'new private');
      expect(merged.publicOnly.prayers, isEmpty);
    },
  );
  test(
    'first launch makes no anonymous account; server rejects wrong proof; restart/code rotation keeps UID',
    () async {
      final gateway = SparkGateway(), storage = MemoryStorage();
      var controller = PriestAccessController(gateway, storage);
      await controller.initialize();
      expect(gateway.signups, 0);
      expect(controller.state.content, null);
      await controller.activate(wrongCode, 'Phone');
      expect(controller.state.error, contains('Няправільны'));
      expect(gateway.active, false);
      await controller.activate(validCode, 'Phone');
      expect(controller.state.registered, true);
      expect(controller.state.content!.prayers.length, 4);
      final uid = gateway.uid;
      expect(jsonEncode(storage.record), isNot(contains(validCode)));
      expect(
        jsonEncode(storage.record),
        isNot(contains(gateway.expectedProof)),
      );
      expect(jsonEncode(storage.record), isNot(contains('secret single')));
      gateway.expectedProof = priestCodeProof(wrongCode)!;
      controller.dispose();
      controller = PriestAccessController(gateway, storage);
      await controller.initialize();
      expect(controller.state.content, isNotNull);
      expect(gateway.uid, uid);
      expect(gateway.signups, 1);
      expect(gateway.activations, 1);
      controller.dispose();
      await gateway.close();
    },
  );
  test(
    'offline/background clears texts, retains registration, reuses Auth on resume',
    () async {
      final gateway = SparkGateway();
      final controller = PriestAccessController(gateway, MemoryStorage());
      await controller.initialize();
      await controller.activate(validCode, '');
      controller.suspend(online: false);
      expect(controller.state.registered, true);
      expect(controller.state.content, null);
      expect(await controller.readPrayer('single'), null);
      await controller.resume(online: true);
      expect(controller.state.content, isNotNull);
      controller.suspend(foreground: false);
      await controller.resume(foreground: true);
      expect(controller.state.content, isNotNull);
      expect(gateway.signups, 1);
      gateway.offline = true;
      await controller.refresh();
      expect(controller.state.content, null);
      expect(controller.state.registered, true);
      gateway.offline = false;
      await controller.refresh();
      expect(controller.state.content, isNotNull);
      controller.dispose();
      await gateway.close();
    },
  );
  test(
    'server grant listener removes active reader and UI on individual revoke',
    () async {
      final gateway = SparkGateway();
      final controller = PriestAccessController(gateway, MemoryStorage());
      await controller.initialize();
      await controller.activate(validCode, '');
      gateway.active = false;
      gateway.events.add(PriestDeviceGrant(gateway.uid!, false));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.registered, false);
      expect(controller.state.content, null);
      expect(await controller.readPrayer('single'), null);
      controller.dispose();
      await gateway.close();
    },
  );
  test('server recovery retries without a connectivity change', () async {
    final gateway = SparkGateway();
    final controller = PriestAccessController(gateway, MemoryStorage());
    await controller.initialize();
    await controller.activate(validCode, '');
    gateway.offline = true;
    await controller.refresh();
    expect(controller.state.content, null);
    gateway.offline = false;
    await Future<void>.delayed(const Duration(seconds: 6));
    expect(controller.state.content, isNotNull);
    expect(gateway.signups, 1);
    controller.dispose();
    await gateway.close();
  });
  test(
    'proof cleanup rollout does not revoke or replace the restored UID',
    () async {
      final gateway = SparkGateway(), storage = MemoryStorage();
      var controller = PriestAccessController(gateway, storage);
      await controller.initialize();
      await controller.activate(validCode, '');
      final uid = gateway.uid;
      gateway.unreadable = true;
      await controller.refresh();
      expect(controller.state.content, null);
      expect(controller.state.registered, true);
      expect(storage.record['verifiedUid'], uid);
      controller.dispose();
      controller = PriestAccessController(gateway, storage);
      await controller.initialize();
      gateway.unreadable = false;
      await controller.refresh();
      expect(controller.state.content, isNotNull);
      expect(gateway.uid, uid);
      expect(gateway.signups, 1);
      expect(gateway.activations, 1);
      controller.dispose();
      await gateway.close();
    },
  );
  test(
    'offline disable persists intent and blocks all protected reads until server acknowledges after restart',
    () async {
      final gateway = SparkGateway(), storage = MemoryStorage();
      var controller = PriestAccessController(gateway, storage);
      await controller.initialize();
      await controller.activate(validCode, '');
      final uid = gateway.uid;
      final reads = gateway.reads;
      gateway.offline = true;
      await controller.disable();
      expect(storage.record['pendingDisableUid'], uid);
      expect(controller.state.content, null);
      expect(await controller.readPrayer('single'), null);
      controller.dispose();
      controller = PriestAccessController(gateway, storage);
      await controller.initialize();
      expect(gateway.reads, reads);
      gateway.offline = false;
      await controller.refresh();
      expect(gateway.active, false);
      expect(gateway.uid, null);
      expect(storage.record['pendingDisableUid'], null);
      expect(controller.state.registered, false);
      expect(controller.state.publicContent!.prayers.keys, ['public']);
      controller.dispose();
      await gateway.close();
    },
  );
  test('late reader and content cannot restore disabled access', () async {
    final gateway = SparkGateway();
    final controller = PriestAccessController(gateway, MemoryStorage());
    await controller.initialize();
    await controller.activate(validCode, '');
    gateway.pauseReader = Completer<void>();
    gateway.pauseContent = Completer<void>();
    final reader = controller.readPrayer('single'),
        refresh = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    await controller.disable();
    gateway.pauseReader!.complete();
    gateway.pauseContent!.complete();
    expect(await reader, null);
    await refresh;
    expect(controller.state.registered, false);
    expect(controller.state.content, null);
    controller.dispose();
    await gateway.close();
  });
  test('revocation clears content even when secure storage fails', () async {
    final gateway = SparkGateway(), storage = MemoryStorage();
    final controller = PriestAccessController(gateway, storage);
    await controller.initialize();
    await controller.activate(validCode, '');
    storage.failWrites = true;
    gateway.active = false;
    await controller.refresh();
    expect(controller.state.content, null);
    expect(controller.state.registered, false);
    controller.dispose();
    await gateway.close();
  });
  test(
    'failed durable disable signs out locally and cannot restore access',
    () async {
      final gateway = SparkGateway(), storage = MemoryStorage();
      final controller = PriestAccessController(gateway, storage);
      await controller.initialize();
      await controller.activate(validCode, '');
      storage.failWrites = true;
      await controller.disable();
      expect(gateway.uid, null);
      expect(gateway.active, false);
      expect(controller.state.content, null);
      expect(controller.state.registered, false);
      controller.dispose();
      await gateway.close();
    },
  );
}
