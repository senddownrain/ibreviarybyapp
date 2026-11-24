import 'package:firebase_app_check_platform_interface/firebase_app_check_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/services/firebase_app_check.dart';

class _App implements FirebaseApp {
  _App(this.name);

  @override
  final String name;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AppCheckPlatform extends FirebaseAppCheckPlatform {
  _AppCheckPlatform(this.calls, {super.appInstance});

  final List<Object> calls;

  @override
  FirebaseAppCheckPlatform delegateFor({required FirebaseApp app}) =>
      _AppCheckPlatform(calls, appInstance: app);

  @override
  FirebaseAppCheckPlatform setInitialValues() => this;

  @override
  Future<void> activate({
    WebProvider? webProvider,
    AndroidProvider? androidProvider,
    AppleProvider? appleProvider,
  }) async {
    calls.add((app, androidProvider, appleProvider));
    if (webProvider != null) {
      calls.add((webProvider.runtimeType, webProvider.siteKey));
    }
  }

  @override
  Future<void> setTokenAutoRefreshEnabled(bool enabled) async {
    calls.add((app, enabled));
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const appleAttestation = MethodChannel('by.mybrev/app_attest');
  final calls = <Object>[];
  final originalPlatform = FirebaseAppCheckPlatform.instance;

  setUp(() {
    calls.clear();
    FirebaseAppCheckPlatform.instance = _AppCheckPlatform(calls);
  });

  tearDown(() {
    FirebaseAppCheckPlatform.instance = originalPlatform;
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      appleAttestation,
      null,
    );
  });

  if (const bool.fromEnvironment('PRIEST_USE_EMULATORS')) {
    test('skips attestation in the local Firebase mode', () async {
      await activateFirebaseAppCheck(_App('[DEFAULT]'));
      await activateFirebaseAppCheck(_App('mybrev-priest'));
      expect(calls, isEmpty);
    });
    return;
  }

  if (kIsWeb) {
    test('uses an Enterprise provider only when the Web key is set', () async {
      final app = _App('[DEFAULT]');
      const key = String.fromEnvironment('FIREBASE_APP_CHECK_SITE_KEY');
      await activateFirebaseAppCheck(app);
      expect(calls, [
        if (key.trim().isNotEmpty) ...[
          (
            app,
            AndroidProvider.playIntegrity,
            AppleProvider.appAttestWithDeviceCheckFallback,
          ),
          (ReCaptchaEnterpriseProvider, key.trim()),
          (app, true),
        ],
      ]);
    });
    return;
  }

  test(
    'installs Play Integrity on default and recreated priest apps',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final apps = [
        _App('[DEFAULT]'),
        _App('mybrev-priest'),
        _App('mybrev-priest'),
      ];
      for (final app in apps) {
        await activateFirebaseAppCheck(app);
      }
      expect(calls, [
        for (final app in apps) ...[
          (
            app,
            AndroidProvider.playIntegrity,
            AppleProvider.appAttestWithDeviceCheckFallback,
          ),
          (app, true),
        ],
      ]);
    },
  );

  for (final supported in [true, false]) {
    test(
      'selects the Apple provider (App Attest supported: $supported)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          appleAttestation,
          (call) async {
            expect(call.method, 'isSupported');
            return supported;
          },
        );
        final app = _App('[DEFAULT]');
        await activateFirebaseAppCheck(app);
        expect(calls, [
          (
            app,
            AndroidProvider.playIntegrity,
            supported
                ? AppleProvider.appAttestWithDeviceCheckFallback
                : AppleProvider.deviceCheck,
          ),
          (app, true),
        ]);
      },
    );
  }
}
