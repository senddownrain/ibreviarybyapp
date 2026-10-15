import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';

// The recording test needs the build flag:
//   flutter test --dart-define=ANALYTICS_LOCAL=true test/analytics/local_analytics_test.dart
void main() {
  test(
    'without ANALYTICS_LOCAL the glue does nothing',
    () async {
      expect(kAnalyticsLocal, isFalse);
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
      );
      await LocalAnalytics.start(router);
      expect(LocalAnalytics.instance, isNull);
    },
    skip: kAnalyticsLocal ? 'flag is on' : null,
  );

  testWidgets(
    'local analytics records a scrolled read from routes and scroll metrics',
    (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'x',
        packageName: 'x',
        version: '1.0.0',
        buildNumber: '6',
        buildSignature: '',
      );
      Hive.init(Directory.systemTemp.createTempSync('analytics_hive').path);

      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const Scaffold(body: Text('settings')),
          ),
          GoRoute(
            path: '/prayers/prayer/:id',
            builder: (_, s) => Scaffold(
              body: ListView(
                children: [
                  for (var i = 0; i < 80; i++)
                    SizedBox(height: 100, child: Text('line $i')),
                ],
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => AnalyticsScrollListener(child: child!),
        ),
      );

      await tester.runAsync(() => LocalAnalytics.start(router));
      final analytics = LocalAnalytics.instance!;

      router.go('/prayers/prayer/import-15-malitvy-za-semi');
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2400));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5300)),
      );

      router.go('/prayers/prayer/ClosedPriestPrayer0001');
      await tester.pumpAndSettle();
      router.go('/settings');
      await tester.pumpAndSettle();

      final cells = [
        for (final p in analytics.snapshot())
          ...(p['cells']! as List).cast<Map>(),
      ];
      final read = cells
          .where((c) => c['content_id'] == 'prayer:import-15-malitvy-za-semi')
          .toList();
      expect(read.any((c) => c['e'] == 'screen_view'), isTrue);
      expect(
        read.any((c) => c['metric'] == 'fv' && c['bucket'] == '5_15s'),
        isTrue,
      );
      final sd = read.firstWhere((c) => c['metric'] == 'sd');
      expect(
        ['p25_50', 'p50_75'].contains(sd['bucket']),
        isTrue,
        reason: '${sd['bucket']}',
      );
      expect(
        cells.any((c) => '${c['content_id']}'.contains('ClosedPriest')),
        isFalse,
      );
      expect(analytics.snapshot().first['app_version'], '1.0');
      expect(analytics.snapshot().first['platform'], 'android');
    },
    skip: !kAnalyticsLocal,
  );
}
