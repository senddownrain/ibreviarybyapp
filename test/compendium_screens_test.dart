import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mybrev_flutter/constants/compendium.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/screens/compendium_reader_screens.dart';
import 'package:mybrev_flutter/screens/compendium_screen.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';
import 'package:mybrev_flutter/widgets/compendium/compendium_widgets.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

import 'support/compendium_fixture.dart';

final _dataset = readBundledCompendium();
final _aliases = readCompendiumAliasFile();

void main() {
  group('root', () {
    testWidgets('shows the four parts, attribution and requests a refresh', (
      tester,
    ) async {
      var refreshes = 0;
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router, onRefresh: () => refreshes++));
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
      expect(refreshes, 1);

      await tester.scrollUntilVisible(
        find.byKey(const Key('compendium-source')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Catholic.by', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Libreria Editrice Vaticana', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('source attribution opens Catholic.by externally', (
      tester,
    ) async {
      final opened = <Uri>[];
      var result = true;
      final router = _router(initialLocation: '/prayers/compendium/question/1');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _app(
          router,
          launcher: (uri) async {
            opened.add(uri);
            return result;
          },
        ),
      );
      await tester.pumpAndSettle();
      final source = find.byKey(const Key('compendium-source'));
      await tester.ensureVisible(source);
      await tester.pumpAndSettle();
      await tester.tap(source);
      await tester.pump();
      expect(opened.single.toString(), kCompendiumSourceUrl);
      expect(
        kCompendiumSourceUrl,
        'https://catholic.by/3/lib/documents/kasciol/3963-kampendyj-katekhizisa-katalitskaga-kastsjola',
      );

      result = false;
      await tester.tap(source);
      await tester.pump();
      expect(find.text('Не ўдалося адкрыць сайт'), findsOneWidget);
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

  group('navigation', () {
    testWidgets('part outline → topic with expandable rows → question', (
      tester,
    ) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('compendium-part-p2')));
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/part/p2');
      expect(find.text('ЧАСТКА ДРУГАЯ'), findsOneWidget);
      expect(find.text('САКРАМЭНТАЛЬНАЯ ЭКАНОМІЯ'), findsOneWidget);

      final groupId = _index().getQuestion(252)!.groupId;
      final row = find.byKey(ValueKey('compendium-group-$groupId'));
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/topic/$groupId');
      expect(find.byType(ReaderScaffold), findsOneWidget);
      expect(find.byType(ReaderContextHeader), findsOneWidget);
      expect(find.byType(ReaderContentSurface), findsOneWidget);
      expect(find.byKey(const Key('text-scale-open')), findsOneWidget);
      expect(find.text('САКРАМЭНТ ХРОСТУ'), findsOneWidget);
      expect(find.byKey(const ValueKey('compendium-answer-252')), findsNothing);

      final toggle = find.byKey(
        const ValueKey('compendium-question-toggle-252'),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('compendium-answer-252')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('compendium-refs-252')), findsOneWidget);

      final open = find.byKey(const ValueKey('compendium-open-question-252'));
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/question/252');

      await tester.tap(find.byKey(const Key('reader-chrome-back')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('compendium-answer-252')),
        findsOneWidget,
        reason: 'expanded rows are kept for the session',
      );
    });

    testWidgets('question reader: context, pager and existing text scale', (
      tester,
    ) async {
      final router = _router(
        initialLocation: '/prayers/compendium/question/42',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router, fontSize: 24));
      await tester.pumpAndSettle();

      final question = _index().getQuestion(42)!;
      expect(find.text('ПЫТАННЕ 42'), findsOneWidget);
      expect(find.text(question.question), findsOneWidget);
      expect(find.byType(ReaderContentSurface), findsOneWidget);
      final answer = tester.widget<Text>(
        find
            .descendant(
              of: find.byKey(const ValueKey('compendium-answer-42')),
              matching: find.byType(Text),
            )
            .first,
      );
      expect(answer.style?.fontSize, 24, reason: 'reader font size setting');

      final next = find.byKey(const Key('compendium-next'));
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/question/43');
      expect(find.text('ПЫТАННЕ 43'), findsOneWidget);

      final center = find.byKey(const Key('compendium-center'));
      await tester.ensureVisible(center);
      await tester.pumpAndSettle();
      await tester.tap(center);
      await tester.pumpAndSettle();
      expect(
        _location(router),
        '/prayers/compendium/topic/${_index().getQuestion(43)!.groupId}',
      );
    });

    testWidgets('unknown deep links show not-found states', (tester) async {
      for (final (location, message) in [
        ('/prayers/compendium/question/999', 'Пытанне 999 не знойдзена'),
        ('/prayers/compendium/question/abc', 'Пытанне abc не знойдзена'),
        ('/prayers/compendium/topic/missing', 'Тэма не знойдзена'),
        ('/prayers/compendium/part/p9', 'Частка не знойдзена'),
      ]) {
        final router = _router(initialLocation: location);
        await tester.pumpWidget(_app(router));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget, reason: location);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    });

    testWidgets('large system text does not overflow on a narrow screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final location in [
        '/prayers/compendium',
        '/prayers/compendium/part/p1',
        '/prayers/compendium/question/26',
      ]) {
        final router = _router(initialLocation: location);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 900),
              textScaler: TextScaler.linear(2),
            ),
            child: _app(router),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    });
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

final _compendiumIndex = CompendiumIndex(_dataset);

CompendiumIndex _index() => _compendiumIndex;

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
              builder: (context, state) =>
                  CompendiumPartScreen(partId: state.pathParameters['partId']!),
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
  void Function()? onRefresh,
  bool bundleFails = false,
  double? fontSize,
  Future<bool> Function(Uri)? launcher,
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith(() => _TestSettingsNotifier(fontSize)),
    liturgicalSeasonColorProvider.overrideWithValue(Colors.indigo),
    ...compendiumOverrides(
      _dataset,
      aliases: _aliases,
      onRefresh: onRefresh,
      bundleFails: bundleFails,
    ),
    compendiumLinkLauncherProvider.overrideWithValue(
      launcher ?? (uri) async => true,
    ),
  ],
  child: MaterialApp.router(routerConfig: router),
);

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(this.fontSize);
  final double? fontSize;

  @override
  SettingsState build() => fontSize == null
      ? const SettingsState()
      : SettingsState(fontSize: fontSize!);
}
