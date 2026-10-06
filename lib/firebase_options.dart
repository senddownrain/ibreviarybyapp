import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public client configuration for the existing ibreviaryby Firebase project.
/// Web: https://ibreviaryby.web.app/__/firebase/init.json
/// Native: android/app/google-services.json and ios/Runner/GoogleService-Info.plist.
/// These identifiers grant no admin access; Firestore rules control data access.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError('Use Chrome, Android or iOS for Mybrev.'),
    };
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDmdP5MpLLIX0RWuYXbYsDDgPqbLHCi_sM',
    appId: '1:344097781816:web:93ffb2d167ed7765fd8ecd',
    messagingSenderId: '344097781816',
    projectId: 'ibreviaryby',
    authDomain: 'ibreviaryby.firebaseapp.com',
    storageBucket: 'ibreviaryby.firebasestorage.app',
    measurementId: 'G-2DRL5J5KYY',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyBqZtw0FW1n9TELjTUHQ5Z-VGx3Sb98alg',
    appId: '1:344097781816:android:92f6c24311cce114fd8ecd',
    messagingSenderId: '344097781816',
    projectId: 'ibreviaryby',
    storageBucket: 'ibreviaryby.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyCArtMF8yXpWsRYcN_EWnNFRztaIK8PKZk',
    appId: '1:344097781816:ios:e3feba9d3a782b7dfd8ecd',
    messagingSenderId: '344097781816',
    projectId: 'ibreviaryby',
    storageBucket: 'ibreviaryby.firebasestorage.app',
    iosBundleId: 'by.mybrev.testflight2026',
  );
}
