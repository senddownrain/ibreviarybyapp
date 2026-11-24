import 'package:firebase_app_check_platform_interface/firebase_app_check_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _appleAttestation = MethodChannel('by.mybrev/app_attest');

/// Installs the provider before Auth or Firestore is used on this Firebase app.
Future<void> activateFirebaseAppCheck(FirebaseApp app) async {
  if (const bool.fromEnvironment('PRIEST_USE_EMULATORS')) return;

  const webSiteKey = String.fromEnvironment('FIREBASE_APP_CHECK_SITE_KEY');
  final siteKey = webSiteKey.trim();
  if (kIsWeb && siteKey.isEmpty) return;

  try {
    // The public FlutterFire singleton caches by name. The priest app deletes
    // and recreates its JS app under the same name to preserve Auth persistence.
    final appCheck = FirebaseAppCheckPlatform.instanceFor(app: app);
    final useDeviceCheck =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        await _appleAttestation.invokeMethod<bool>('isSupported') == false;
    await appCheck.activate(
      webProvider: kIsWeb ? ReCaptchaEnterpriseProvider(siteKey) : null,
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: useDeviceCheck
          ? AppleProvider.deviceCheck
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
    await appCheck.setTokenAutoRefreshEnabled(true);
  } catch (_) {
    // Provider setup must not prevent offline startup during monitoring.
    debugPrint('[AppCheck] Provider setup failed for ${app.name}.');
  }
}
