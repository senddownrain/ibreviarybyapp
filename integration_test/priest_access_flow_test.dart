// Actual Firebase SDK + mybrev Rules, exclusively local demo emulators.
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:mybrev_flutter/firebase_options.dart';
import 'package:mybrev_flutter/main.dart' as app;
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/router/router.dart';
import 'package:mybrev_flutter/services/firebase_priest_access.dart';
import 'package:mybrev_flutter/services/priest_access_gateway.dart';
import 'package:mybrev_flutter/services/priest_access_storage.dart';
import 'package:mybrev_flutter/services/priest_code.dart';
import 'package:mybrev_flutter/services/hive_service.dart';

const code = 'A2B3-C4D5-E6F7-G8H9-J2K3-L4M5';
const nextCode = 'N2P3-Q4R5-S6T7-U8V9-W2X3-Y4Z5';
const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
const port = int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8088);
const base =
    'http://$host:$port/v1/projects/demo-rules/databases/(default)/documents';
Map<String, dynamic> value(Object? v) => switch (v) {
  null => {'nullValue': null},
  bool v => {'booleanValue': v},
  String v => {'stringValue': v},
  DateTime v => {'timestampValue': v.toUtc().toIso8601String()},
  List v => {
    'arrayValue': {'values': v.map(value).toList()},
  },
  _ => throw ArgumentError('Unsupported fixture'),
};
Future<void> seed(
  String path,
  Map<String, dynamic> data, {
  String? mask,
}) async {
  final response = await http.patch(
    Uri.parse(
      '$base/$path${mask == null ? '' : '?updateMask.fieldPaths=$mask'}',
    ),
    headers: {
      'Authorization': 'Bearer owner',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'fields': data.map((k, v) => MapEntry(k, value(v)))}),
  );
  expect(response.statusCode, 200);
}

Future<http.Response> deviceRead(String uid, String collection) async {
  final auth = FirebaseAuth.instanceFor(
    app: Firebase.app(FirebasePriestAccess.appName),
  );
  final token = await auth.currentUser!.getIdToken();
  // Emulator only. Credentials stay in headers and are never logged.
  return http.get(
    Uri.parse('$base/$collection/$uid'),
    headers: {'Authorization': 'Bearer $token'},
  );
}

// Test-only adversarial CACHE read: no request to the unreadable server claim.
// A full SDK can otherwise read its own successful write despite server Rules.
Future<void> expectNoCachedClaim(String uid) async {
  final db = platform.FirebaseFirestorePlatform.instanceFor(
    app: Firebase.app(FirebasePriestAccess.appName),
    databaseId: '(default)',
  );
  db.settings = Settings(
    persistenceEnabled: false,
    host: '$host:$port',
    sslEnabled: false,
  );
  try {
    final cached = await db
        .collection('priestActivationClaims')
        .doc(uid)
        .get(const GetOptions(source: Source.cache));
    expect(
      cached.data() == null,
      true,
      reason: 'Claim must leave no SDK cache',
    );
  } on FirebaseException catch (error) {
    expect(
      error.code,
      'unavailable',
    ); // No cached document in the fresh client.
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Spark Auth/Rules, UI/catalog, session restore, rotation, offline, revoke and disable',
    (tester) async {
      expect(const bool.fromEnvironment('PRIEST_USE_EMULATORS'), true);
      expect(['127.0.0.1', 'localhost', '10.0.2.2'], contains(host));
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseFirestore.instance.useFirestoreEmulator(host, port);
      await HiveService.init();
      final gateway = FirebasePriestAccess(),
          storage = SecurePriestAccessStorage();
      final previous = await storage.read();
      final restartPhase = (previous['testRestartCheck'] as int?) ?? 0;
      final restart =
          restartPhase > 0 ||
          const bool.fromEnvironment('PRIEST_RESTART_CHECK');
      if (!restart) {
        await gateway.signOut();
        await storage.write({});
        await seed('priestAccess/settings', {
          'activeCodeProof': priestCodeProof(code),
          'changedAt': DateTime.now(),
          'helpText': '',
        });
        await seed('priestAccessPublic/help', {
          'helpText': 'fixture@example.test',
        });
        await seed('prayerCategories/spark-public', {
          'name': 'Адкрытыя малітвы',
          'tags': ['spark-public'],
        });
        await seed('prayers/spark-public', {
          'title': 'Адкрытая малітва',
          'text': 'PUBLIC-SPARK-FIXTURE',
          'tags': ['spark-public'],
        });
        await seed('priestProtectedCategories/spark-root', {
          'name': 'Закрытыя абрады',
          'tags': ['spark-root'],
          'priestOnly': true,
        });
        await seed('priestProtectedCategories/spark-child', {
          'name': 'Укладзеныя абрады',
          'tags': ['spark-child'],
          'parentId': 'spark-root',
        });
        await seed('priestProtectedPrayers/spark-single', {
          'title': 'Малітва святара',
          'text': 'PRIVATE-SPARK-SENTINEL',
          'tags': ['spark-public'],
          'priestOnly': true,
        });
        await seed('priestProtectedPrayers/spark-nested', {
          'title': 'Укладзеная малітва',
          'text': 'PRIVATE-SPARK-NESTED',
          'tags': ['spark-child', 'spark-public'],
        });
      }
      final controller = PriestAccessController(
        gateway,
        storage,
        persistPublic: persistPublicPrayerContent,
      );
      await controller.initialize();
      final container = ProviderContainer(
        overrides: [priestAccessProvider.overrideWith((_) => controller)],
      );
      Future<void> waitFor(bool Function() ready) async {
        for (var i = 0; i < 300 && !ready(); i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(ready(), true, reason: controller.state.error);
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> screen(String name) async {
        const controlPort = int.fromEnvironment(
          'PRIEST_TEST_CONTROL_PORT',
          defaultValue: 8784,
        );
        expect(
          (await http.post(
            Uri.parse('http://$host:$controlPort/screen'),
            body: name,
          )).statusCode,
          200,
        );
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const app.MyBrevApp(),
        ),
      );
      await waitFor(() => find.byType(MaterialApp).evaluate().isNotEmpty);
      await screen('startup');
      if (restart) {
        // The lifecycle widget rechecks connectivity after its first frame.
        // Wait for that server check rather than inspecting its transient state.
        await waitFor(() => controller.state.content != null);
        expect(controller.state.registered, true);
        expect(await gateway.restoreSession(), previous['verifiedUid']);
        expect(
          controller.state.content!.prayers.containsKey('spark-single'),
          true,
        );
        await screen(restartPhase == 1 ? 'restart-process' : 'restart-reboot');
        if (restartPhase == 1) {
          await storage.write({...await storage.read(), 'testRestartCheck': 2});
        } else {
          await controller.disable();
          expect(controller.state.content, null);
          await storage.write({});
          if (container
              .read(settingsProvider)
              .favoriteIds
              .contains('spark-single')) {
            await container
                .read(settingsProvider.notifier)
                .toggleFavorite('spark-single');
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await gateway.close();
        binding.reportData = {'restartUidRetained': true};
        return;
      }
      expect(await gateway.restoreSession(), null);
      expect(controller.state.content, null);
      router.go('/settings');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('priest-code')));
      await screen('inactive');
      await controller.activate(nextCode, 'Pixel 7 Spark');
      expect(controller.state.registered, false);
      expect(controller.state.error, contains('Няправільны'));
      final rejectedUid = await gateway.restoreSession();
      await expectNoCachedClaim(rejectedUid!);
      for (final collection in [
        'priestDeviceGrants',
        'priestActivationClaims',
      ]) {
        final response = await http.get(
          Uri.parse('$base/$collection/$rejectedUid'),
          headers: {'Authorization': 'Bearer owner'},
        );
        expect(
          response.statusCode,
          404,
          reason: 'Rejected batch must leave neither document',
        );
      }
      // Queue a real SDK batch while its network is disabled. Its timeout must
      // finish destroying the memory client before returning, preserve Auth,
      // and prevent the queued proof from being replayed after reconnection.
      final pausedDb = platform.FirebaseFirestorePlatform.instanceFor(
        app: Firebase.app(FirebasePriestAccess.appName),
        databaseId: '(default)',
      );
      pausedDb.settings = Settings(
        persistenceEnabled: false,
        host: '$host:$port',
        sslEnabled: false,
      );
      await pausedDb.disableNetwork();
      await expectLater(
        gateway.createGrant(
          rejectedUid,
          priestCodeProof(code)!,
          'Timeout test',
        ),
        throwsA(
          isA<PriestAccessException>().having((e) => e.code, 'code', 'OFFLINE'),
        ),
      );
      expect(
        Firebase.apps.any((a) => a.name == FirebasePriestAccess.appName),
        false,
        reason: 'Cleanup must complete before the timeout is reported',
      );
      expect(await gateway.restoreSession(), rejectedUid);
      await expectNoCachedClaim(rejectedUid);
      expect(await gateway.grant(rejectedUid), null);
      await controller.activate(code, 'Pixel 7 Spark');
      await waitFor(() => controller.state.content != null);
      final uid = await gateway.restoreSession();
      expect(uid, isNotNull);
      expect(
        uid,
        rejectedUid,
        reason: 'Neither denial nor timeout replaces UID',
      );
      await expectNoCachedClaim(uid!);
      final ownGrant = await deviceRead(uid, 'priestDeviceGrants');
      expect(ownGrant.statusCode, 200);
      expect(
        (jsonDecode(ownGrant.body)['fields'] as Map).keys,
        isNot(contains('activationProof')),
      );
      expect(
        (await deviceRead(uid, 'priestActivationClaims')).statusCode,
        403,
        reason: 'Even the activated owner must not read the bearer proof',
      );
      expect(
        FirebaseAuth.instance.currentUser,
        null,
        reason: 'Default/admin Auth must stay untouched',
      );
      await tester.ensureVisible(find.text('Доступ актываваны'));
      await screen('active');
      if (!container
          .read(settingsProvider)
          .favoriteIds
          .contains('spark-single')) {
        await container
            .read(settingsProvider.notifier)
            .toggleFavorite('spark-single');
      }
      expect(
        container
            .read(favoritePrayersProvider)
            .any((p) => p.id == 'spark-single'),
        true,
      );
      container.read(prayersFilterProvider.notifier).setSearch('PRIVATE-SPARK');
      expect(container.read(filteredPrayersProvider).length, 2);
      container.read(prayersFilterProvider.notifier).clearFilters();
      router.go('/prayer/spark-single');
      await waitFor(
        () =>
            find.textContaining('PRIVATE-SPARK-SENTINEL').evaluate().isNotEmpty,
      );
      await screen('reader');
      await seed('priestAccess/settings', {
        'activeCodeProof': priestCodeProof(nextCode),
        'changedAt': DateTime.now(),
        'helpText': '',
      });
      await controller.refresh();
      expect(controller.state.content, isNotNull);
      controller.suspend(online: false);
      await tester.pump();
      expect(controller.state.content, null);
      expect(
        container
            .read(favoritePrayersProvider)
            .any((p) => p.id == 'spark-single'),
        false,
      );
      expect(
        container.read(settingsProvider).favoriteIds,
        contains('spark-single'),
      );
      expect(await controller.readPrayer('spark-single'), null);
      await controller.resume(online: true);
      expect(await gateway.restoreSession(), uid);
      expect(controller.state.content, isNotNull);
      await screen('restored');
      await seed('priestDeviceGrants/$uid', {
        'status': 'revoked',
      }, mask: 'status');
      await waitFor(() => !controller.state.registered);
      expect(controller.state.content, null);
      expect(await controller.readPrayer('spark-single'), null);
      await expectLater(
        gateway.readProtectedPrayer(uid, 'spark-single'),
        throwsA(isA<Exception>()),
      );
      await screen('revoked');
      await gateway.signOut();
      await controller.activate(nextCode, 'Second installation');
      expect(controller.state.content, isNotNull);
      final secondUid = await gateway.restoreSession();
      controller.suspend(online: false);
      await controller.disable();
      expect((await storage.read())['pendingDisableUid'], secondUid);
      expect(await controller.readPrayer('spark-single'), null);
      await controller.resume(online: true);
      expect((await storage.read())['pendingDisableUid'], null);
      expect(await gateway.restoreSession(), null);
      await controller.activate(nextCode, 'Restart installation');
      expect(controller.state.content, isNotNull);
      router.go('/settings');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Доступ актываваны'));
      await screen('final-active');
      await storage.write({...await storage.read(), 'testRestartCheck': 1});
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await gateway.close();
      binding.reportData = {
        'authAndRules': true,
        'protectedOnlineOnly': true,
        'defaultAuthUnaffected': true,
      };
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
