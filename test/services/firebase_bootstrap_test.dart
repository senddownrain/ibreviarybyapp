import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/services/firebase_bootstrap.dart';

const _options = FirebaseOptions(
  apiKey: 'key',
  appId: 'app',
  messagingSenderId: 'sender',
  projectId: 'project',
);

void main() {
  test('initializes with the given options', () async {
    FirebaseOptions? seen;
    await ensureFirebaseInitialized(
      options: _options,
      initialize: (o) async => seen = o,
    );
    expect(seen, _options);
  });

  test('reuses a natively created default app on duplicate-app', () async {
    var lookups = 0;
    await ensureFirebaseInitialized(
      options: _options,
      initialize: (_) async =>
          throw FirebaseException(plugin: 'core', code: 'duplicate-app'),
      defaultApp: () {
        lookups++;
        throw StateError('stub');
      },
    ).onError<StateError>((_, __) {});
    expect(lookups, 1);
  });

  test('rethrows other Firebase errors', () async {
    expect(
      ensureFirebaseInitialized(
        options: _options,
        initialize: (_) async =>
            throw FirebaseException(plugin: 'core', code: 'network'),
      ),
      throwsA(isA<FirebaseException>()),
    );
  });
}
