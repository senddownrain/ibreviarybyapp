import 'package:firebase_core/firebase_core.dart';

/// Initializes the default Firebase app, tolerating one created natively.
///
/// On iOS the native layer may create `[DEFAULT]` from
/// `GoogleService-Info.plist` before Dart runs. Passing different options
/// (the debug-only emulator options) then fails with `core/duplicate-app`.
/// The native app is already registered by that point, so it is reused.
Future<void> ensureFirebaseInitialized({
  required FirebaseOptions options,
  Future<void> Function(FirebaseOptions options)? initialize,
  FirebaseApp Function()? defaultApp,
}) async {
  try {
    await (initialize ?? (o) => Firebase.initializeApp(options: o))(options);
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
    (defaultApp ?? Firebase.app)();
  }
}
