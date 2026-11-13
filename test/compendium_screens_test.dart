import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mybrev_flutter/constants/compendium.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/compendium_node_screen.dart';
import 'package:mybrev_flutter/screens/compendium_reader_screens.dart';
import 'package:mybrev_flutter/screens/compendium_screen.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_widgets.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

import 'support/compendium_fixture.dart';

final _dataset = readBundledCompendium();
final _aliases = readCompendiumAliasFile();

void main() {
  group('root', () {
    testWidgets('shows the four parts without inline source attribution', (tester) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('compendium-title')), findsOneWidget);
      expect(find.text(kCompendiumTitle), findsOneWidget);
      expect(find.text('598 пытанняў і адказаў'), findsOneWidget);
      for (final (id, numeral, range) in [
        ('p1', 'I', 'Пытанні 1–217'),
        ('p2', 'II', null),
        ('p3', 'III', null),
        ('p4', 'IV', 'Пытанні 534–598'),
      ]) {
        final row = find.byKey(ValueKey('compendium-part-$id'));
        expect(row, findsOneWidget, reason: id);
        expect(
          find.descendant(of: row, matching: find.text(numeral)),
          findsOneWidget,
        );
        if (range != null) {
          expect(
            find.descendant(of: row, matching: find.text(range)),
            findsOneWidget,
          );
        }
      }
      expect(find.text('ВЫЗНАННЕ ВЕРЫ'), findsOneWidget);
      expect(find.byKey(const Key('compendium-search-dock')), findsOneWidget);
      expect(
        find.byKey(const Key('prayer-filter-action')),
        findsNothing,
        reason: 'the Compendium dock is search-only',
      );

      expect(find.byKey(const Key('compendium-source')), findsNothing);
    });

    testWidgets('question references remain without inline source credit', (tester) async {
      final router = _router(initialLocation: '/prayers/compendium/question/1');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      final refs = tester.widget<Text>(
        find.byKey(const ValueKey('compendium-refs-1')),
      );
      final reader = ReaderTheme.of(
        tester.element(find.byKey(const ValueKey('compendium-refs-1'))),
      );
      expect(refs.style?.color, reader.muted);
      expect(refs.style?.height, ReaderTheme.referenceHeight);
      expect(find.byKey(const Key('compendium-source')), findsNothing);
      expect(find.textContaining('Catholic.by', findRichText: true), findsNothing);
    });

    testWidgets('bundle failure without a synced copy shows a retry', (
      tester,
    ) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router, bundleFails: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('compendium-error')), findsOneWidget);
      expect(find.text('Паўтарыць'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('results open a question and the query survives Back', (
      tester,
    ) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('compendium-search-field')),
        'исповедь',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('compendium-results-count')), findsOneWidget);
      expect(find.byKey(const ValueKey('compendium-part-p1')), findsNothing);
      final result = find.byKey(const ValueKey('compendium-result-296'));
      await tester.scrollUntilVisible(
        result,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(result);
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/question/296');
      expect(find.byType(ReaderScaffold), findsOneWidget);
      expect(find.text('ПЫТАННЕ 296'), findsOneWidget);

      await tester.tap(find.byKey(const Key('reader-chrome-back')));
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium');
      final field = tester.widget<TextField>(
        find.byKey(const Key('compendium-search-field')),
      );
      expect(field.controller!.text, 'исповедь', reason: 'query restored');
      expect(
        find.byKey(const ValueKey('compendium-result-296')),
        findsOneWidget,
        reason: 'results and their scroll position are restored',
      );
    });

    testWidgets('an exact number jumps to the question on submit', (
      tester,
    ) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('compendium-search-field'));
      await tester.enterText(field, '42');
      await tester.pumpAndSettle();
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('compendium-result-42')))
            .dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('compendium-search-dock'))).dy,
        ),
        reason: 'the exact number is the first result',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/question/42');
    });

    testWidgets('no match shows an empty state', (tester) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('compendium-search-field')),
        'зззззз',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('compendium-empty')), findsOneWidget);
      expect(find.text('Знойдзена: 0'), findsOneWidget);
    });
  });

  group('flat Part navigation', () {
    testWidgets('root → Part I shows section, q1, subsection and q2–5 inline', (
      tester,
    ) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('compendium-part-p1')));
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/part/p1');
      expect(find.text('ЧАСТКА ПЕРШАЯ'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('compendium-inline-p1-s1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('compendium-question-row-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('compendium-inline-p1-s1-ch1')),
        findsOneWidget,
      );
      for (final number in [1, 2]) {
        final row = find.byKey(ValueKey('compendium-question-row-$number'));
        expect(tester.widget(row), isA<CompendiumQuestionRow>());
      }
      for (final id in ['p1-s1', 'p1-s1-ch1']) {
        final heading = find.byKey(ValueKey('compendium-inline-$id'));
        expect(
          find.descendant(of: heading, matching: find.byType(InkWell)),
          findsNothing,
        );
        expect(
          find.descendant(
            of: heading,
            matching: find.byIcon(Icons.chevron_right_rounded),
          ),
          findsNothing,
        );
      }
      expect(find.byKey(const Key('compendium-search-dock')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('compendium-question-row-2')));
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/question/2');
    });

    testWidgets(
      'reader has canonical neighbours and returns to its question in Part',
      (tester) async {
        final router = _router(
          initialLocation: '/prayers/compendium/question/42',
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(_app(router, fontSize: 24));
        await tester.pumpAndSettle();
        expect(find.text('ПЫТАННЕ 42'), findsOneWidget);
        final answer = tester.widget<Text>(
          find
              .descendant(
                of: find.byKey(const ValueKey('compendium-answer-42')),
                matching: find.byType(Text),
              )
              .first,
        );
        expect(answer.style?.fontSize, 24);
        final next = find.byKey(const Key('compendium-next'));
        await tester.ensureVisible(next);
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(_location(router), '/prayers/compendium/question/43');
        final center = find.byKey(const Key('compendium-center'));
        await tester.ensureVisible(center);
        await tester.pumpAndSettle();
        expect(find.text('Да часткі'), findsOneWidget);
        await tester.tap(center);
        await tester.pumpAndSettle();
        expect(_location(router), '/prayers/compendium/part/p1');
        expect(
          find.byKey(const ValueKey('compendium-question-row-43')),
          findsOneWidget,
        );
      },
    );

    testWidgets('cold Part target and legacy links land on stable items', (
      tester,
    ) async {
      for (final (location, part, target) in [
        (
          '/prayers/compendium/part/p1?target=q079',
          'p1',
          'compendium-question-row-79',
        ),
        ('/prayers/compendium/node/p1-s1', 'p1', 'compendium-inline-p1-s1'),
        (
          '/prayers/compendium/node/p1-s1-ch1',
          'p1',
          'compendium-inline-p1-s1-ch1',
        ),
        (
          '/prayers/compendium/topic/p1-s1-ch2-t1',
          'p1',
          'compendium-inline-p1-s1-ch2-t1',
        ),
        (
          '/prayers/compendium/topic/p1-s1-intro',
          'p1',
          'compendium-question-row-1',
        ),
        (
          '/prayers/compendium/topic/p3-s2-intro',
          'p3',
          'compendium-question-row-434',
        ),
        (
          '/prayers/compendium/topic/p2-s2-intro',
          'p2',
          'compendium-question-row-250',
        ),
      ]) {
        final router = _router(initialLocation: location);
        await tester.pumpWidget(_app(router));
        await tester.pumpAndSettle();
        expect(
          _location(router),
          '/prayers/compendium/part/$part',
          reason: location,
        );
        expect(find.byKey(ValueKey(target)), findsOneWidget, reason: location);
        expect(find.byKey(const Key('compendium-search-dock')), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    });

    testWidgets(
      'search from a Part returns to results then restores its target',
      (tester) async {
        final router = _router(
          initialLocation: '/prayers/compendium/part/p1?target=q079',
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(_app(router));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('compendium-question-row-79')),
          findsOneWidget,
        );
        final field = find.byKey(const Key('compendium-search-field'));
        await tester.enterText(field, '42');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('compendium-result-42')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('compendium-result-42')));
        await tester.pumpAndSettle();
        expect(_location(router), '/prayers/compendium/question/42');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_location(router), '/prayers/compendium/part/p1');
        expect(
          find.byKey(const ValueKey('compendium-result-42')),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Ачысціць пошук'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('compendium-question-row-79')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Part and reader clear bottom dock at large text and safe insets',
      (tester) async {
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        addTearDown(tester.view.reset);
        for (final (name, platform, size, bottom, gesture, scale, dark)
            in _devices) {
          debugDefaultTargetPlatformOverride = platform;
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = size
            ..padding = FakeViewPadding(bottom: bottom)
            ..viewPadding = FakeViewPadding(bottom: bottom)
            ..systemGestureInsets = FakeViewPadding(bottom: gesture);
          for (final location in [
            '/prayers/compendium/part/p4?target=q598',
            '/prayers/compendium/question/598',
          ]) {
            final router = _router(initialLocation: location);
            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData.fromView(
                  tester.view,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: _app(router, dark: dark),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$name $location');
            expect(
              find.byKey(const Key('compendium-search-dock')),
              findsOneWidget,
            );
            final dock = tester.getRect(
              find.byKey(const Key('compendium-search-dock')),
            );
            expect(
              dock.bottom,
              lessThanOrEqualTo(size.height - math.max(bottom, gesture)),
            );
            final lastContent = location.contains('/part/')
                ? find.byKey(const ValueKey('compendium-question-row-598'))
                : find.byType(CompendiumPager);
            await tester.ensureVisible(lastContent);
            await tester.pumpAndSettle();
            expect(tester.getRect(lastContent).bottom, lessThanOrEqualTo(dock.top));
            expect(find.byKey(const Key('compendium-source')), findsNothing);
            await tester.pumpWidget(const SizedBox.shrink());
            router.dispose();
          }
        }
        debugDefaultTargetPlatformOverride = null;
      },
    );
  });

  test('the Compendium stays independent from prayers', () {
    for (final path in [
      'lib/models/compendium.dart',
      'lib/providers/compendium_provider.dart',
      'lib/services/compendium_repository.dart',
      'lib/utils/compendium_data.dart',
      'lib/utils/compendium_search.dart',
      'lib/screens/compendium_reader_screens.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(matches(RegExp(r'models/prayer\.dart|prayers_provider'))),
        reason: path,
      );
    }
  });
}

/// Device matrix for the dock/inset checks:
/// (name, platform, size, bottom inset, gesture inset, text scale, dark).
const _devices = [
  (
    'narrow Android',
    TargetPlatform.android,
    Size(320, 640),
    0.0,
    0.0,
    1.0,
    false,
  ),
  (
    'Android 3-button',
    TargetPlatform.android,
    Size(412, 800),
    48.0,
    0.0,
    1.0,
    true,
  ),
  (
    'Android gestures',
    TargetPlatform.android,
    Size(412, 800),
    24.0,
    32.0,
    1.0,
    false,
  ),
  (
    'iPhone safe area',
    TargetPlatform.iOS,
    Size(390, 844),
    34.0,
    0.0,
    1.0,
    true,
  ),
  ('large text', TargetPlatform.iOS, Size(375, 667), 34.0, 0.0, 2.0, false),
];

String _location(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  final last = config.matches.last;
  return last is ImperativeRouteMatch ? last.matches.uri.path : config.uri.path;
}

GoRouter _router({String initialLocation = '/prayers/compendium'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/prayers',
      builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
      routes: [
        GoRoute(
          path: 'compendium',
          builder: (context, state) => const CompendiumScreen(),
          routes: [
            GoRoute(
              path: 'part/:partId',
              builder: (context, state) => CompendiumPartScreen(
                partId: state.pathParameters['partId']!,
                target: state.uri.queryParameters['target'],
              ),
            ),
            GoRoute(
              path: 'node/:nodeId',
              builder: (context, state) =>
                  CompendiumNodeScreen(nodeId: state.pathParameters['nodeId']!),
            ),
            GoRoute(
              path: 'topic/:topicId',
              builder: (context, state) => CompendiumTopicScreen(
                topicId: state.pathParameters['topicId']!,
              ),
            ),
            GoRoute(
              path: 'question/:number',
              builder: (context, state) => CompendiumQuestionScreen(
                number: state.pathParameters['number']!,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

Widget _app(
  GoRouter router, {
  bool bundleFails = false,
  double? fontSize,
  Future<bool> Function(Uri)? launcher,
  bool dark = false,
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith(() => _TestSettingsNotifier(fontSize)),
    liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
    ...compendiumOverrides(
      _dataset,
      aliases: _aliases,
      bundleFails: bundleFails,
    ),
    compendiumLinkLauncherProvider.overrideWithValue(
      launcher ?? (uri) async => true,
    ),
  ],
  child: MaterialApp.router(
    routerConfig: router,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    darkTheme: ThemeData(brightness: Brightness.dark),
  ),
);

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(this.fontSize);
  final double? fontSize;

  @override
  SettingsState build() => fontSize == null
      ? const SettingsState()
      : SettingsState(fontSize: fontSize!);
}
