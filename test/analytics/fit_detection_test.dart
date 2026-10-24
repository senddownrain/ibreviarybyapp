import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:package_info_plus/package_info_plus.dart';

// sd = fit must follow the visibility of the text, not the reachability of the
// last pixel of the scroll view: the reader reserves blank space below the text
// (ReaderContentSurface.bottomSpacing + the system / dock inset), and that blank
// space alone must not turn a fully visible text into a "scrolled" read.
//   flutter test --dart-define=ANALYTICS_LOCAL=true test/analytics/fit_detection_test.dart
const _id = 'import-01-malitvy-na-kozhny-dzen-tydnya';
const _bottomInset = 34.0;
const _topInset = 47.0;

const _line =
    'Кароткая малітва, якая цалкам змяшчаецца на экране і чытаецца хутка.';

Widget _shortText() => const Text(_line);

Widget _tallText(int lines) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [for (var i = 0; i < lines; i++) Text('$_line $i')],
);

Widget _reader(Widget content) =>
    ReaderScaffold(semanticLabel: 'test reader', content: content);

GoRouter _router(Widget Function() content) => GoRouter(
  initialLocation: '/settings',
  routes: [
    GoRoute(
      path: '/settings',
      builder: (_, _) => const Scaffold(body: Text('settings')),
    ),
    GoRoute(path: '/prayers/prayer/:id', builder: (_, _) => _reader(content())),
  ],
);

void _setView(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(
    top: _topInset,
    bottom: _bottomInset,
  );
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// Height of everything up to the end of the reserve, with the view tall enough
/// for no scrolling: the shortest viewport in which the whole page fits.
Future<double> _pageHeight(
  WidgetTester tester,
  Widget Function() content,
) async {
  await tester.pumpWidget(MaterialApp(home: _reader(content())));
  await tester.pumpAndSettle();
  return tester
      .getBottomLeft(find.byKey(const Key('reader-content-surface')))
      .dy;
}

double _maxExtent(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .maxScrollExtent;

Future<void> _start(WidgetTester tester, GoRouter router) async {
  PackageInfo.setMockInitialValues(
    appName: 'x',
    packageName: 'x',
    version: '1.0.0',
    buildNumber: '6',
    buildSignature: '',
  );
  Hive.init(Directory.systemTemp.createTempSync('analytics_fit').path);
  LocalAnalytics.instance = null;
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.runAsync(() => LocalAnalytics.start(router));
}

Future<void> _wait(WidgetTester tester, int ms) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

List<Map> _cells() => [
  for (final p in LocalAnalytics.instance!.snapshot())
    ...(p['cells']! as List).cast<Map>(),
];

String? _sd() {
  final sd = _cells().where(
    (c) => c['content_id'] == 'prayer:$_id' && c['metric'] == 'sd',
  );
  return sd.isEmpty ? null : sd.first['bucket'] as String;
}

/// Opens the prayer, lets it be read for a while, leaves it.
Future<void> _read(
  WidgetTester tester,
  GoRouter router, {
  Future<void> Function()? whileOpen,
}) async {
  unawaited(router.push('/prayers/prayer/$_id'));
  await tester.pumpAndSettle();
  await whileOpen?.call();
  await _wait(tester, 5300);
  router.pop();
  await tester.pumpAndSettle();
}

void main() {
  const phone = Size(393, 852);

  group(
    'sd = fit',
    () {
      testWidgets('a two-line text in a roomy viewport is fit', (tester) async {
        _setView(tester, phone);
        final router = _router(_shortText);
        await _start(tester, router);
        await _read(tester, router);
        expect(_sd(), 'fit');
      });

      testWidgets(
        'a text that ends within the screen is fit although the blank reserve '
        'below it makes the view scrollable by a few points',
        (tester) async {
          // Page height without the reserve of the last 42 + 34 points.
          _setView(tester, phone);
          final page = await _pageHeight(tester, () => _tallText(8));
          // The text itself ends 76 points above `page`; leave 30 points of the
          // reserve outside the viewport.
          final size = Size(393, page - 30);
          _setView(tester, size);
          final router = _router(() => _tallText(8));
          await _start(tester, router);
          await _read(
            tester,
            router,
            whileOpen: () async {
              expect(_maxExtent(tester), closeTo(30, 1));
            },
          );
          expect(_sd(), 'fit');
        },
      );

      testWidgets('the same page on a small phone (320x720) stays fit', (
        tester,
      ) async {
        _setView(tester, const Size(320, 720));
        final router = _router(_shortText);
        await _start(tester, router);
        await _read(tester, router);
        expect(_sd(), 'fit');
      });

      testWidgets('a text that overflows the viewport is not fit', (
        tester,
      ) async {
        _setView(tester, phone);
        final router = _router(() => _tallText(60));
        await _start(tester, router);
        await _read(
          tester,
          router,
          whileOpen: () async {
            expect(_maxExtent(tester), greaterThan(76));
          },
        );
        expect(_sd(), isNot('fit'));
        expect(_sd(), isNotNull);
      });

      testWidgets('a text hidden by just a few lines is not fit', (
        tester,
      ) async {
        _setView(tester, phone);
        final page = await _pageHeight(tester, () => _tallText(8));
        // Viewport shorter than the text by about two lines (> the reserve).
        _setView(tester, Size(393, page - 76 - 40));
        final router = _router(() => _tallText(8));
        await _start(tester, router);
        await _read(
          tester,
          router,
          whileOpen: () async {
            expect(_maxExtent(tester), greaterThan(76));
          },
        );
        expect(_sd(), isNot('fit'));
      });

      testWidgets('a long text read to the end reaches p100', (tester) async {
        _setView(tester, phone);
        final router = _router(() => _tallText(60));
        await _start(tester, router);
        await _read(
          tester,
          router,
          whileOpen: () async {
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -20000),
            );
            await tester.pumpAndSettle();
          },
        );
        expect(_sd(), 'p100');
      });

      testWidgets('a larger font turns a fitting text into a scrolling one', (
        tester,
      ) async {
        _setView(tester, phone);
        final router = _router(() => _tallText(5));
        await _start(tester, router);
        await _read(tester, router);
        expect(_sd(), 'fit', reason: 'five lines fit at the normal size');

        LocalAnalytics.instance = null;
        _setView(tester, phone, textScale: 2);
        final big = _router(() => _tallText(5));
        await _start(tester, big);
        await _read(
          tester,
          big,
          whileOpen: () async {
            expect(_maxExtent(tester), greaterThan(76));
          },
        );
        expect(_sd(), isNot('fit'));
      });
    },
    skip: !kAnalyticsLocal ? 'needs --dart-define=ANALYTICS_LOCAL=true' : null,
  );
}
