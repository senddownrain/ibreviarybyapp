import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:mybrev_flutter/firebase_options.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/services/access_sets_v2_code.dart';
import 'package:mybrev_flutter/services/access_sets_v2_gateway.dart';
import 'package:mybrev_flutter/services/firebase_priest_access.dart';
import 'package:mybrev_flutter/services/priest_access_storage.dart';
import 'package:mybrev_flutter/services/priest_code.dart';

const _host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
const _port = int.fromEnvironment(
  'FIRESTORE_EMULATOR_PORT',
  defaultValue: 8197,
);
const _legacy = 'A2B3-C4D5-E6F7-G8H9-J2K3-L4M5';
const _v2 = 'PRST-20240229-23456789ABCDEFGH-JKLMNPQRSTUVWXYZ23456789';
const _id = '23456789ABCDEFGH';

Object _field(Object? value) => switch (value) {
  null => {'nullValue': null},
  bool value => {'booleanValue': value},
  String value => {'stringValue': value},
  int value => {'integerValue': '$value'},
  DateTime value => {'timestampValue': value.toUtc().toIso8601String()},
  List value => {
    'arrayValue': {'values': value.map(_field).toList()},
  },
  _ => throw ArgumentError('Unsupported synthetic fixture'),
};

Future<void> _seed(String path, Map<String, Object?> fields) async {
  final response = await http.patch(
    Uri.parse(
      'http://$_host:$_port/v1/projects/demo-rules/databases/(default)/documents/$path',
    ),
    headers: {
      'Authorization': 'Bearer owner',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'fields': fields.map((key, value) => MapEntry(key, _field(value))),
    }),
  );
  expect(response.statusCode, 200, reason: path);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'shared UID, both SDK batches, canonical paging, rotation and revoke',
    (tester) async {
      expect(const bool.fromEnvironment('PRIEST_USE_EMULATORS'), true);
      expect(['127.0.0.1', 'localhost', '10.0.2.2'], contains(_host));
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      expect(Firebase.app().options.projectId, 'demo-rules');
      FirebaseFirestore.instance.useFirestoreEmulator(_host, _port);
      await _seed('priestContentControl/accessSetsV2', {'mode': 'legacy'});
      await _seed('priestAccess/settings', {
        'activeCodeProof': priestCodeProof(_legacy),
        'changedAt': DateTime.now(),
        'helpText': '',
      });
      await _seed('priestProtectedPrayers/s7-mirror', {
        'title': 'Synthetic mirror',
        'text': 'Synthetic legacy mirror',
      });
      await _seed('accessProfilesV2/s7-native', {
        'name': 'Synthetic native',
        'status': 'active',
        'allowedSets': ['marian'],
        'revision': 1,
        'updatedAt': DateTime.now(),
      });
      await _seed('accessProfilesV2/s7-native/client/entitlements', {
        'allowedSets': ['marian'],
        'revision': 1,
      });
      final issued = DateTime.now();
      final parsed = parseAccessSetsV2Code(_v2)!;
      Future<void> seedCode({required bool active}) =>
          _seed('accessCodesV2/$_id', {
            'profileId': 's7-native',
            'codeProof': accessSetsV2CodeProof(parsed.canonical),
            'status': active ? 'active' : 'disabled',
            'issuedAt': issued,
            'disabledAt': active ? null : DateTime.now(),
            'label': '',
          });
      await seedCode(active: true);
      await _seed('accessCodesV2/$_id/client/profile', {
        'profileId': 's7-native',
      });
      for (final set in ['priest', 'marian']) {
        await _seed('accessSetsV2/$set', {
          'status': 'active',
          'name': 'Synthetic $set set',
          'updatedAt': DateTime.now(),
        });
        await _seed('accessSetsV2/$set/prayers/s7-native-$set', {});
        await _seed('protectedPrayers/s7-native-$set', {
          'title': 'Synthetic $set',
          'text': 'Synthetic canonical $set',
          'effectiveAccessSets': [set],
          'accessSets': [set],
          'accessSchemaVersion': 2,
          'contentHash': 'synthetic',
        });
      }

      final gateway = FirebasePriestAccess();
      final storage = SecurePriestAccessStorage();
      await gateway.signOut();
      await storage.write({});
      var controller = PriestAccessController(gateway, storage);
      await controller.initialize();
      expect(await gateway.restoreSession(), isNull);
      await controller.activate(_legacy, 'S7 synthetic device');
      expect(controller.state.content?.prayers.keys, contains('s7-mirror'));
      final uid = (await gateway.restoreSession())!;

      controller.dispose();
      await gateway.clearProtectedMemory();
      controller = PriestAccessController(gateway, storage);
      addTearDown(() async {
        controller.dispose();
        await gateway.close();
      });
      await _seed('priestContentControl/accessSetsV2', {'mode': 'canonical'});
      await controller.initialize();
      expect(await gateway.restoreSession() == uid, true);
      expect(controller.state.allowedSets, {'priest'});
      expect(
        controller.state.content?.prayers.keys,
        isNot(contains('s7-mirror')),
      );
      await controller.activate(_v2, 'S7 synthetic device');
      expect(controller.state.allowedSets, {'priest', 'marian'});
      expect(await gateway.restoreSession() == uid, true);

      final v2 = gateway.accessSetsV2;
      final firstPage = await v2.listIds(
        AccessContentKind.prayers,
        'marian',
        pageSize: 1,
      );
      expect(firstPage.ids, ['s7-native-marian']);
      expect(firstPage.cursor, 's7-native-marian');
      expect(
        (await v2.listIds(
          AccessContentKind.prayers,
          'marian',
          pageSize: 1,
          after: firstPage.cursor,
        )).ids,
        isEmpty,
      );

      await seedCode(active: false);
      await controller.refresh();
      expect(controller.state.allowedSets, {'priest', 'marian'});
      expect(
        (await controller.readPrayer('s7-native-marian'))?['text'],
        'Synthetic canonical marian',
      );

      controller.suspend(online: false);
      await controller.disable();
      expect(controller.state.content, isNull);
      expect(controller.state.pendingDisable, true);
      expect(await gateway.restoreSession() == uid, true);
      await controller.resume(online: true);
      expect(await gateway.restoreSession(), isNull);
      expect(controller.state.pendingDisable, false);
      expect(controller.state.content, isNull);
    },
  );
}
