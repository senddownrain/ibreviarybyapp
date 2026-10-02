import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/router/router.dart';

void main() {
  test('mock route exists only with its compile-time flag', () {
    final registered = router.configuration.routes
        .whereType<GoRoute>()
        .any((route) => route.path == readerConsistencyLabRoute);
    expect(registered, readerConsistencyLabEnabled);
    expect(
      readerConsistencyLabEnabled,
      const bool.fromEnvironment('IBREVIARY_READER_CONSISTENCY_LAB'),
    );
  });
}
