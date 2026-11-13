import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/discovery/discovery_providers.dart';
import 'package:mybrev_flutter/discovery/discovery_storage.dart';
import 'package:mybrev_flutter/review/app_review_controller.dart';
import 'package:mybrev_flutter/review/app_review_host.dart';
import 'package:mybrev_flutter/review/app_review_state.dart';
import 'package:mybrev_flutter/review/app_review_storage.dart';
import 'package:mybrev_flutter/review/native_review_adapter.dart';

class _Adapter implements NativeReviewAdapter {
  int requests = 0;
  @override
  Future<bool> requestReview() async => ++requests > 0;
  @override
  Future<bool> openStoreListing() async => true;
}

void main() {
  late _Adapter adapter;
  late GoRouter router;

  Future<void> pump(WidgetTester tester, {bool eligible = true}) async {
    adapter = _Adapter();
    final storage = MemoryAppReviewStorage();
    final first = DateTime.now().subtract(const Duration(days: 30));
    if (eligible) {
      storage.value = AppReviewState(
        firstLaunchMs: first.millisecondsSinceEpoch,
        usageDays: [
          for (var i = 1; i <= 5; i++)
            AppReviewController.dayKey(first.add(Duration(days: i))),
        ],
      ).encode();
    }
    router = GoRouter(
      initialLocation: '/hours',
      routes: [
        GoRoute(
          path: '/hours',
          builder: (context, state) => const Scaffold(
            body: AppReviewHost(
              idle: Duration(seconds: 2),
              child: Text('root'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'ora/:id',
              builder: (context, state) => const Scaffold(body: Text('reader')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appReviewVersionProvider.overrideWithValue(() async => '1.0+6'),
          discoveryStorageProvider.overrideWithValue(MemoryDiscoveryStorage()),
          appReviewStorageProvider.overrideWithValue(storage),
          nativeReviewAdapterProvider.overrideWithValue(adapter),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no request on launch or while staying on the root', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(adapter.requests, 0);
  });

  testWidgets('not while reading; once after returning and idling', (
    tester,
  ) async {
    await pump(tester);
    router.go('/hours/ora/1');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(adapter.requests, 0, reason: 'never inside a text');
    router.go('/hours');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(adapter.requests, 0, reason: 'idle not elapsed yet');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(adapter.requests, 1);
  });

  testWidgets('leaving again before the idle ends cancels it', (tester) async {
    await pump(tester);
    router.go('/hours/ora/1');
    await tester.pumpAndSettle();
    router.go('/hours');
    await tester.pump(const Duration(seconds: 1));
    router.go('/hours/ora/2');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(adapter.requests, 0);
  });

  testWidgets('a new install is never asked', (tester) async {
    await pump(tester, eligible: false);
    router.go('/hours/ora/1');
    await tester.pumpAndSettle();
    router.go('/hours');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(adapter.requests, 0);
  });
}
