import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/firebase_options.dart';

void main() {
  final config =
      jsonDecode(File('android/app/google-services.json').readAsStringSync())
          as Map<String, dynamic>;
  final project = config['project_info'] as Map<String, dynamic>;

  void matchesRegisteredClient(FirebaseOptions options, String package) {
    final client = (config['client'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere(
          (client) =>
              client['client_info']['android_client_info']['package_name'] ==
              package,
        );
    expect(options.appId, client['client_info']['mobilesdk_app_id']);
    expect(options.apiKey, client['api_key'][0]['current_key']);
    expect(options.projectId, project['project_id']);
    expect(options.messagingSenderId, project['project_number']);
    expect(options.storageBucket, project['storage_bucket']);
  }

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('ordinary Android options still match the store client', () {
    matchesRegisteredClient(
      DefaultFirebaseOptions.android,
      'by.mybrev.playtest2026',
    );
  });

  test('personal Android options match the existing independent client', () {
    matchesRegisteredClient(
      DefaultFirebaseOptions.androidPersonal,
      'com.example.ibrevapp',
    );
    expect(
      DefaultFirebaseOptions.androidPersonal.appId,
      isNot(DefaultFirebaseOptions.android.appId),
    );
  });

  test('Android build mode selects the matching native Firebase client', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const personal = bool.fromEnvironment('MYBREV_PERSONAL_ANDROID');
    matchesRegisteredClient(
      DefaultFirebaseOptions.currentPlatform,
      personal ? 'com.example.ibrevapp' : 'by.mybrev.playtest2026',
    );
  });

  test('the Android personal mode does not change iOS options', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(DefaultFirebaseOptions.currentPlatform, DefaultFirebaseOptions.ios);
  });
}
