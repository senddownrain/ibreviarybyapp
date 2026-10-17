import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:package_info_plus/package_info_plus.dart';

// The recording tests need the build flag:
//   flutter test --dart-define=ANALYTICS_LOCAL=true test/analytics/local_analytics_test.dart
const _long = 'import-15-malitvy-za-semi';
const _short = 'import-01-malitvy-na-kozhny-dzen-tydnya';
const _loading = 'import-02-agulny-katekhizis';
const _closed = 'ClosedPriestPrayer0001';

Widget _reader(Widget content) =>
    ReaderScaffold(semanticLabel: 'test reader', content: content);

Widget _longText() => Column(
  children: [
    for (var i = 0; i < 60; i++)
      SizedBox(
        height: 100,
        child: Text(
          'Радок малітвы нумар $i з даволі доўгім тэкстам, каб яго можна было прачытаць.',
        ),
      ),
  ],
);

GoRouter _router() => GoRouter(
  initialLocation: '/settings',
  routes: [
    GoRoute(
      path: '/settings',
      builder: (_, _) => const Scaffold(body: Text('settings')),
    ),
    GoRoute(path: '/bible', builder: (_, _) => _reader(_longText())),
    GoRoute(
      path: '/prayers/songs',
      builder: (_, _) => const Scaffold(body: Text('songs list')),
    ),
    GoRoute(
      path: '/prayers/prayer/:id',
      builder: (_, state) {
        final id = state.pathParameters['id']!;
        if (id == _loading) {
          return _reader(const Center(child: CircularProgressIndicator()));
        }
        if (id == _short) {
          return _reader(
            const Text(
              'Кароткая малітва, якая цалкам змяшчаецца на экране і чытаецца за некалькі секунд.',
            ),
          );
        }
        return _reader(_longText());
      },
    ),
  ],
);

Future<void> _start(WidgetTester tester, GoRouter router) async {
  PackageInfo.setMockInitialValues(
    appName: 'x',
    packageName: 'x',
    version: '1.0.0',
    buildNumber: '6',
    buildSignature: '',
  );
  Hive.init(Directory.systemTemp.createTempSync('analytics_hive').path);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.runAsync(() => LocalAnalytics.start(router));
}

Future<void> _wait(WidgetTester tester, int ms) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

List<Map> _cells() => [
  for (final p in LocalAnalytics.instance!.snapshot())
    ...(p['cells']! as List).cast<Map>(),
];

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
      analyticsFeature('back_to_top'); // must be a harmless no-op
    },
    skip: kAnalyticsLocal ? 'flag is on' : null,
  );

  testWidgets(
    'a scrolled read, a short fitting read, a loader, a closed id and a catalog',
    (tester) async {
      final router = _router();
      await _start(tester, router);

      // 1. Long text, scrolled with the finger: fv, sd and er.
      router.go('/prayers/prayer/$_long');
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2400));
      await tester.pumpAndSettle();
      await _wait(tester, 5300);
      // 2. A closed id never counts, however long its text is.
      router.go('/prayers/prayer/$_closed');
      await tester.pumpAndSettle();
      await _wait(tester, 1300);
      // 3. A loader (no text) never counts.
      router.go('/prayers/prayer/$_loading');
      await tester.pump(const Duration(milliseconds: 300));
      await _wait(tester, 1300);
      // 4. A short text that fits the screen: sd = fit. Opened with `push`, as the
      // app's own lists do (the pushed page is an imperative route match).
      router.go('/settings');
      await tester.pumpAndSettle();
      unawaited(router.push('/prayers/prayer/$_short'));
      await tester.pumpAndSettle();
      await _wait(tester, 5300);
      router.pop();
      await tester.pumpAndSettle();
      // 4b. The Bible screen names its book itself when opened at a bare /bible.
      router.go('/settings');
      await tester.pumpAndSettle();
      router.go('/bible');
      await tester.pumpAndSettle();
      analyticsBibleBook('bel', 'gn');
      await tester.pumpAndSettle();
      await _wait(tester, 1300);
      // 5. A catalog screen.
      router.go('/prayers/songs');
      await tester.pumpAndSettle();
      await _wait(tester, 1300);
      analyticsFeature('theme_change');
      router.go('/settings');
      await tester.pumpAndSettle();

      final cells = _cells();
      final long = cells
          .where((c) => c['content_id'] == 'prayer:$_long')
          .toList();
      expect(long.any((c) => c['e'] == 'screen_view'), isTrue);
      expect(
        long.any((c) => c['metric'] == 'fv' && c['bucket'] == '5_15s'),
        isTrue,
      );
      final sd = long.firstWhere((c) => c['metric'] == 'sd');
      expect(
        ['p25_50', 'p50_75'].contains(sd['bucket']),
        isTrue,
        reason: '${sd['bucket']}',
      );
      expect(long.any((c) => c['metric'] == 'er'), isTrue);

      expect(
        cells.any((c) => '${c['content_id']}'.contains('ClosedPriest')),
        isFalse,
      );
      expect(cells.any((c) => c['content_id'] == 'prayer:$_loading'), isFalse);

      final short = cells
          .where((c) => c['content_id'] == 'prayer:$_short')
          .toList();
      expect(short.firstWhere((c) => c['metric'] == 'sd')['bucket'], 'fit');

      expect(
        cells.any(
          (c) => c['e'] == 'catalog_open' && c['catalog_id'] == 'songs',
        ),
        isTrue,
      );
      expect(
        cells.any(
          (c) =>
              c['e'] == 'feature_use' &&
              c['feature_id'] == 'theme_change' &&
              c['section'] == 'songs',
        ),
        isTrue,
      );

      final first = LocalAnalytics.instance!.snapshot().first;
      expect(first['schema_version'], 2);
      expect(first['app_version'], '1.0');
      expect(first['platform'], 'android');
      expect(first['region'], 'UNKNOWN');
    },
    skip: !kAnalyticsLocal,
  );
}
