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
    testWidgets('part → section → subsection → topic → question', (
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

      await tester.tap(find.byKey(const ValueKey('compendium-section-p2-s2')));
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/node/p2-s2');
      expect(find.text('СЕМ САКРАМЭНТАЎ КАСЦЁЛА'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('compendium-subsection-p2-s2-ch1')),
      );
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/node/p2-s2-ch1');

      final groupId = _index().getQuestion(252)!.groupId;
      await tester.tap(find.byKey(ValueKey('compendium-group-$groupId')));
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

      // Back walks up the same levels.
      for (final location in [
        '/prayers/compendium/node/p2-s2-ch1',
        '/prayers/compendium/node/p2-s2',
        '/prayers/compendium/part/p2',
        '/prayers/compendium',
      ]) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_location(router), location);
      }
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
        ('/prayers/compendium/node/p9-s9', 'Раздзел не знойдзены'),
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
        '/prayers/compendium/node/p1-s1',
        '/prayers/compendium/node/p1-s2-ch2',
        '/prayers/compendium/node/p3-s2-ch1',
        '/prayers/compendium/node/p4-s2',
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

  group('source hierarchy', () {
    testWidgets('Part I is a compact outline of its sections only', (
      tester,
    ) async {
      final router = await _open(tester, '/prayers/compendium/part/p1');
      addTearDown(router.dispose);

      expect(find.text('ЧАСТКА ПЕРШАЯ'), findsOneWidget);
      expect(find.text('ВЫЗНАННЕ ВЕРЫ'), findsOneWidget);
      expect(_rowKeys(tester), [
        'compendium-section-p1-s1',
        'compendium-section-p1-s2',
      ]);
      final items = _listItems(tester);
      expect(items.whereType<CompendiumSectionRow>(), hasLength(2));
      expect(items.whereType<CompendiumQuestionRow>(), isEmpty);
      expect(items.whereType<CompendiumSubsectionRow>(), isEmpty);
      expect(items.whereType<CompendiumTopicRow>(), isEmpty);
      // Questions 1–5 and the subsections are not flattened onto the part.
      for (final number in [1, 2, 3, 4, 5]) {
        expect(find.text(_index().getQuestion(number)!.question), findsNothing);
      }
      expect(find.text('ЧАЛАВЕК — «СВЯТЫНЯ» БОГА'), findsNothing);
      expect(find.textContaining('ГЛАВА'), findsNothing);
      expect(find.textContaining('ПАДРАЗДЗЕЛ'), findsNothing);

      final section = find.byKey(const ValueKey('compendium-section-p1-s1'));
      for (final text in [
        'РАЗДЗЕЛ ПЕРШЫ',
        '«ВЕРУ» — «ВЕРЫМ»',
        'Пытанні 1–32',
      ]) {
        expect(
          find.descendant(of: section, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.descendant(
          of: section,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('compendium-section-p1-s2')),
          matching: find.text('Пытанні 33–217'),
        ),
        findsOneWidget,
      );

      await tester.tap(section);
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/node/p1-s1');
    });

    testWidgets('Section «ВЕРУ» — «ВЕРЫМ»: question 1, then its subsections; '
        'questions 2–5 on their subsection', (tester) async {
      final router = await _open(tester, '/prayers/compendium/node/p1-s1');
      addTearDown(router.dispose);

      expect(find.byType(CompendiumNodeScreen), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('compendium-node-label')))
            .data,
        'РАЗДЗЕЛ ПЕРШЫ',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('compendium-node-title')))
            .data,
        '«ВЕРУ» — «ВЕРЫМ»',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('compendium-node-context')))
            .data,
        'ЧАСТКА ПЕРШАЯ',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('compendium-node-range')))
            .data,
        'Пытанні 1–32',
      );
      expect(_rowKeys(tester), [
        'compendium-question-row-1',
        'compendium-subsection-p1-s1-ch1',
        'compendium-subsection-p1-s1-ch2',
        'compendium-subsection-p1-s1-ch3',
      ]);
      expect(
        _listItems(tester).whereType<CompendiumSubsectionRow>().map(
          (row) => row.node.displayLabel,
        ),
        ['ПАДРАЗДЗЕЛ ПЕРШЫ', 'ПАДРАЗДЗЕЛ ДРУГІ', 'ПАДРАЗДЗЕЛ ТРЭЦІ'],
      );
      expect(find.textContaining('ГЛАВА'), findsNothing);
      // No fake container for the untitled lead-in.
      expect(find.text('Пытанне 1'), findsNothing);
      expect(
        find.byKey(const ValueKey('compendium-group-p1-s1-intro')),
        findsNothing,
      );

      final row = find.byKey(const ValueKey('compendium-question-row-1'));
      expect(tester.widget(row), isA<CompendiumQuestionRow>());
      expect(
        find.descendant(
          of: row,
          matching: find.text('Які Божы намер адносна чалавека?'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('1')),
        findsOneWidget,
      );
      final subsection = find.byKey(
        const ValueKey('compendium-subsection-p1-s1-ch1'),
      );
      for (final text in [
        'ПАДРАЗДЗЕЛ ПЕРШЫ',
        'ЧАЛАВЕК — «СВЯТЫНЯ» БОГА',
        'Пытанні 2–5',
      ]) {
        expect(
          find.descendant(of: subsection, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        tester.getTopLeft(row).dy,
        lessThan(tester.getTopLeft(subsection).dy),
      );
      // Questions 2–5 belong to the subsection, one level down.
      expect(find.text(_index().getQuestion(2)!.question), findsNothing);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/question/1');
      expect(find.byType(CompendiumQuestionScreen), findsOneWidget);
      expect(find.text('ПЫТАННЕ 1'), findsOneWidget);
      expect(find.text('ЧАСТКА ПЕРШАЯ · «ВЕРУ» — «ВЕРЫМ»'), findsOneWidget);
      expect(
        find.byKey(const Key('compendium-center')),
        findsNothing,
        reason: 'question 1 has no topic to open',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/node/p1-s1');

      await tester.tap(subsection);
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/node/p1-s1-ch1');
      expect(
        tester
            .widget<Text>(find.byKey(const Key('compendium-node-label')))
            .data,
        'ПАДРАЗДЗЕЛ ПЕРШЫ',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('compendium-node-title')))
            .data,
        'ЧАЛАВЕК — «СВЯТЫНЯ» БОГА',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('compendium-node-context')))
            .data,
        'ЧАСТКА ПЕРШАЯ · «ВЕРУ» — «ВЕРЫМ»',
      );
      expect(_rowKeys(tester), [
        for (final number in [2, 3, 4, 5]) 'compendium-question-row-$number',
      ]);
      expect(find.textContaining('ГЛАВА'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('compendium-question-row-2')));
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/question/2');
    });

    testWidgets('dataset edge cases: direct questions and real owners', (
      tester,
    ) async {
      List<String> questions(Iterable<int> numbers) => [
        for (final number in numbers) 'compendium-question-row-$number',
      ];
      List<String> rows(
        String prefix,
        String parent,
        String infix,
        int count,
      ) => [
        for (var i = 1; i <= count; i++) 'compendium-$prefix-$parent-$infix$i',
      ];

      for (final (id, expected) in [
        // Questions directly under a section, before its subsections.
        (
          'p2-s1',
          [
            ...questions([218, 219, 220]),
            ...rows('subsection', 'p2-s1', 'ch', 2),
          ],
        ),
        (
          'p3-s2',
          [
            ...questions([434, 435, 436, 437, 438, 439, 440, 441]),
            ...rows('subsection', 'p3-s2', 'ch', 2),
          ],
        ),
        (
          'p3-s1',
          [
            ...questions([357]),
            ...rows('subsection', 'p3-s1', 'ch', 3),
          ],
        ),
        // Questions directly under a subsection, before its named topics.
        (
          'p1-s2-ch2',
          [
            ...questions([79, 80]),
            ...rows('group', 'p1-s2-ch2', 't', 6),
          ],
        ),
        (
          'p2-s2-ch1',
          [
            ...questions([251]),
            ...rows('group', 'p2-s2-ch1', 't', 3),
          ],
        ),
        (
          'p2-s2-ch2',
          [
            ...questions([295]),
            ...rows('group', 'p2-s2-ch2', 't', 2),
          ],
        ),
        (
          'p2-s2-ch3',
          [
            ...questions([321]),
            ...rows('group', 'p2-s2-ch3', 't', 2),
          ],
        ),
        (
          'p4-s1-ch3',
          [
            ...questions([567, 568]),
            ...rows('group', 'p4-s1-ch3', 't', 2),
          ],
        ),
        // A subsection with topics only.
        ('p1-s1-ch2', rows('group', 'p1-s1-ch2', 't', 3)),
        // A section without source chapters: its named topics directly.
        ('p4-s2', rows('group', 'p4-s2-intro', 't', 4)),
        // A section with its own named topic and subsections.
        (
          'p2-s2',
          [
            'compendium-group-p2-s2-intro-t1',
            ...rows('subsection', 'p2-s2', 'ch', 4),
          ],
        ),
      ]) {
        final router = await _open(tester, '/prayers/compendium/node/$id');
        expect(_rowKeys(tester), expected, reason: id);
        expect(find.textContaining('ГЛАВА'), findsNothing, reason: id);
        await _close(tester, router);
      }

      // Named topics show their real title and range, no generic level label.
      var router = await _open(tester, '/prayers/compendium/node/p4-s2');
      final topic = find.byKey(
        const ValueKey('compendium-group-p4-s2-intro-t2'),
      );
      expect(tester.widget(topic), isA<CompendiumTopicRow>());
      expect(
        find.descendant(
          of: topic,
          matching: find.text('«ПЕРАКАЗ УСЯГО ЕВАНГЕЛЛЯ»'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: topic, matching: find.text('Пытанні 579–581')),
        findsOneWidget,
      );
      expect(find.textContaining('ТЭМА'), findsNothing);
      expect(find.textContaining('ПАДРАЗДЗЕЛ'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('compendium-node-label')))
            .data,
        'РАЗДЗЕЛ ДРУГІ',
      );
      await tester.tap(topic);
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/topic/p4-s2-intro-t2');
      expect(find.byType(ReaderScaffold), findsOneWidget);
      await _close(tester, router);

      // The fourth subsection uses the masculine ordinal.
      router = await _open(tester, '/prayers/compendium/node/p2-s2');
      expect(
        _listItems(tester).whereType<CompendiumSubsectionRow>().map(
          (row) => row.node.displayLabel,
        ),
        [
          'ПАДРАЗДЗЕЛ ПЕРШЫ',
          'ПАДРАЗДЗЕЛ ДРУГІ',
          'ПАДРАЗДЗЕЛ ТРЭЦІ',
          'ПАДРАЗДЗЕЛ ЧАЦВЁРТЫ',
        ],
      );
      await _close(tester, router);

      // A source heading above a run of topics stays a plain caption.
      router = await _open(tester, '/prayers/compendium/node/p2-s1-ch2');
      expect(find.text('ЦЭЛЕБРАЦЫЯ ЛIТУРГII КАСЦЁЛА'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('ЦЭЛЕБРАЦЫЯ ЛIТУРГII КАСЦЁЛА')).dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('compendium-group-p2-s1-ch2-t1')),
              )
              .dy,
        ),
      );
      await _close(tester, router);

      // The quotation printed under a subsection heading is kept.
      router = await _open(tester, '/prayers/compendium/node/p1-s1-ch1');
      final citation = _index().getNode('p1-s1-ch1')!.leadCitations.single;
      expect(find.text(citation.text), findsOneWidget);
      await _close(tester, router);
    });

    testWidgets('a topic keeps its subtopic headings inside the reader', (
      tester,
    ) async {
      final group = _index().getGroup('p1-s2-ch3-t2')!;
      final headings = {
        for (final question in group.questions) ?question.subtopicTitle,
      };
      expect(headings.length, greaterThan(1));
      final router = await _open(
        tester,
        '/prayers/compendium/topic/p1-s2-ch3-t2',
      );
      addTearDown(router.dispose);
      expect(find.byType(ReaderScaffold), findsOneWidget);
      expect(find.byType(CompendiumNodeScreen), findsNothing);
      expect(
        tester
            .widget<ReaderContextHeader>(find.byType(ReaderContextHeader))
            .title,
        '«ВЕРУ Ў СВЯТЫ КАСЦЁЛ КАТАЛIЦКI»',
      );
      for (final heading in headings) {
        expect(
          find.text(heading, skipOffstage: false),
          findsWidgets,
          reason: 'subtopic heading «$heading» is reader content',
        );
      }
      for (final question in group.questions) {
        expect(
          find.byKey(
            ValueKey('compendium-question-toggle-${question.number}'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('audit: every structural screen lists exactly its own rows', (
      tester,
    ) async {
      final untitled = [
        for (final group in _index().groups.values)
          if (!group.hasSourceHeading) group.id,
      ];
      final listed = <int>[];
      final structural = [
        for (final part in _index().navigation)
          for (final node in part.descendants)
            if (node.isStructural) node,
      ];
      expect(structural, hasLength(4 + 8 + 20));
      for (final node in structural) {
        final router = await _open(tester, _nodeLocation(node));
        final items = _listItems(tester);
        final keys = _rowKeys(tester);
        expect(keys, _expectedRowKeys(node), reason: node.id);
        expect(
          tester.widget<ListView>(find.byType(ListView).first).key,
          isA<PageStorageKey<String>>(),
        );
        expect(
          find.byKey(const Key('compendium-search-dock')),
          findsOneWidget,
          reason: node.id,
        );
        if (node.kind == CompendiumNodeKind.part) {
          expect(
            items.every((item) => item is! CompendiumQuestionRow),
            isTrue,
            reason: 'a part lists sections only (${node.id})',
          );
          expect(keys, everyElement(startsWith('compendium-section-')));
        }
        for (final id in untitled) {
          expect(keys, isNot(contains('compendium-group-$id')), reason: id);
        }
        for (final item in items) {
          switch (item) {
            case CompendiumQuestionRow(:final question):
              listed.add(question.number);
            case CompendiumTopicRow(node: final topic):
              listed.addAll(topic.questions.map((q) => q.number));
              expect(topic.displayLabel, isNull);
            case CompendiumSubsectionRow(node: final subsection):
              expect(subsection.displayLabel, startsWith('ПАДРАЗДЗЕЛ '));
            case CompendiumSectionRow(node: final section):
              expect(section.displayLabel, startsWith('РАЗДЗЕЛ '));
            case Text(:final data):
              expect(data, isNot(startsWith('Пытан')), reason: node.id);
          }
        }
        expect(find.textContaining('ГЛАВА'), findsNothing, reason: node.id);
        expect(tester.takeException(), isNull, reason: node.id);
        await _close(tester, router);
      }
      expect(
        listed..sort(),
        [for (var number = 1; number <= 598; number++) number],
        reason: 'every question is reachable exactly once by drilling down',
      );
    });

    testWidgets('levels differ by typography and spacing, not colour', (
      tester,
    ) async {
      var router = await _open(tester, '/prayers/compendium/part/p1');
      final section = find.byKey(const ValueKey('compendium-section-p1-s1'));
      final sectionTitle = _textStyle(tester, section, '«ВЕРУ» — «ВЕРЫМ»');
      final sectionLabel = _textStyle(tester, section, 'РАЗДЗЕЛ ПЕРШЫ');
      final sectionPadding = _rowPadding(tester, section);
      await _close(tester, router);

      router = await _open(tester, '/prayers/compendium/node/p1-s1');
      final subsection = find.byKey(
        const ValueKey('compendium-subsection-p1-s1-ch1'),
      );
      final subsectionTitle = _textStyle(
        tester,
        subsection,
        'ЧАЛАВЕК — «СВЯТЫНЯ» БОГА',
      );
      final subsectionLabel = _textStyle(
        tester,
        subsection,
        'ПАДРАЗДЗЕЛ ПЕРШЫ',
      );
      final subsectionPadding = _rowPadding(tester, subsection);
      final q1 = find.byKey(const ValueKey('compendium-question-row-1'));
      final q1Style = _textStyle(tester, q1, _index().getQuestion(1)!.question);
      final q1Padding = _rowPadding(tester, q1);
      final q1Row = tester.widget(q1);
      final q1Badge = tester.getSize(
        find.descendant(of: q1, matching: find.byType(CompendiumBadge)),
      );
      // The section page header is a level above its subsection rows.
      final header = tester.widget<Text>(
        find.byKey(const Key('compendium-node-title')),
      );
      expect(header.style!.fontSize, greaterThan(subsectionTitle.fontSize!));
      await _close(tester, router);

      router = await _open(tester, '/prayers/compendium/node/p1-s2-ch2');
      final topic = find.byKey(const ValueKey('compendium-group-p1-s2-ch2-t1'));
      final topicTitle = _textStyle(
        tester,
        topic,
        _index().getNode('p1-s2-ch2-t1')!.title,
      );
      final topicPadding = _rowPadding(tester, topic);
      expect(
        find.descendant(of: topic, matching: find.byType(CompendiumBadge)),
        findsNothing,
      );
      final q79 = find.byKey(const ValueKey('compendium-question-row-79'));
      final q79Style = _textStyle(
        tester,
        q79,
        _index().getQuestion(79)!.question,
      );
      final q79Padding = _rowPadding(tester, q79);
      final q79Row = tester.widget(q79);
      final q79Badge = tester.getSize(
        find.descendant(of: q79, matching: find.byType(CompendiumBadge)),
      );
      final subsectionHeader = tester.widget<Text>(
        find.byKey(const Key('compendium-node-title')),
      );
      expect(
        subsectionHeader.style!.fontSize,
        lessThan(header.style!.fontSize!),
      );
      await _close(tester, router);

      // Section > Subsection > Topic.
      expect(sectionTitle.fontSize, greaterThan(subsectionTitle.fontSize!));
      expect(sectionLabel.fontSize, greaterThan(subsectionLabel.fontSize!));
      expect(sectionPadding, greaterThan(subsectionPadding));
      expect(subsectionPadding, greaterThan(topicPadding));
      expect(subsectionTitle.fontSize, topicTitle.fontSize);
      expect(
        subsectionTitle.fontWeight!.value,
        greaterThan(topicTitle.fontWeight!.value),
      );
      // Same accent and text colours on every level.
      expect(sectionLabel.color, subsectionLabel.color);
      expect(sectionTitle.color, subsectionTitle.color);
      expect(subsectionTitle.color, topicTitle.color);

      // A question row is identical whoever owns the question.
      expect(q1Row, isA<CompendiumQuestionRow>());
      expect(q79Row.runtimeType, q1Row.runtimeType);
      expect(q79Style, q1Style);
      expect(q79Padding, q1Padding);
      expect(q79Badge.height, q1Badge.height);
    });

    testWidgets('legacy untitled topic links resolve without fake titles', (
      tester,
    ) async {
      // One-question lead-in → the question reader.
      var router = _router(
        initialLocation: '/prayers/compendium/topic/p1-s1-intro',
      );
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      expect(find.byType(CompendiumQuestionScreen), findsOneWidget);
      expect(find.text('ПЫТАННЕ 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('compendium-answer-1')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();

      // Several lead-in questions → titled by the real chapter heading.
      router = _router(initialLocation: '/prayers/compendium/topic/p1-s1-ch1');
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      final header = find.byType(ReaderContextHeader);
      final widget = tester.widget<ReaderContextHeader>(header);
      expect(widget.title, 'ЧАЛАВЕК — «СВЯТЫНЯ» БОГА');
      expect(widget.eyebrow, 'ЧАСТКА ПЕРШАЯ · «ВЕРУ» — «ВЕРЫМ»');
      expect(widget.metadata, 'Пытанні 2–5');
      final previous = find.byKey(const Key('compendium-previous'));
      await tester.ensureVisible(previous);
      await tester.pumpAndSettle();
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(
        _location(router),
        '/prayers/compendium/question/1',
        reason: 'the untitled lead-in neighbour opens as its question',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();

      // A real named topic keeps working.
      router = _router(
        initialLocation: '/prayers/compendium/topic/p1-s1-ch2-t1',
      );
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      final topic = tester.widget<ReaderContextHeader>(
        find.byType(ReaderContextHeader),
      );
      expect(topic.title, 'БОЖАЕ АБ’ЯЎЛЕННЕ');
      expect(topic.eyebrow, 'ЧАСТКА ПЕРШАЯ · БОГ ВЫХОДЗІЦЬ НАСУСТРАЧ ЧАЛАВЕКУ');
      expect(topic.metadata, 'Пытанні 6–10');
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });
  });

  group('persistent search', () {
    testWidgets('the search dock is on every Compendium screen', (
      tester,
    ) async {
      for (final location in [
        '/prayers/compendium',
        '/prayers/compendium/part/p1',
        '/prayers/compendium/node/p1-s1',
        '/prayers/compendium/node/p1-s1-ch1',
        '/prayers/compendium/node/p4-s2',
        '/prayers/compendium/node/missing',
        '/prayers/compendium/topic/p1-s1-ch2-t1',
        '/prayers/compendium/topic/p1-s1-intro',
        '/prayers/compendium/question/1',
        '/prayers/compendium/question/999',
      ]) {
        final router = _router(initialLocation: location);
        await tester.pumpWidget(_app(router));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('compendium-search-dock')),
          findsOneWidget,
          reason: location,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    });

    testWidgets('search from a reader: global results, query kept, Back '
        'restores the reader', (tester) async {
      final router = _router(
        initialLocation: '/prayers/compendium/question/42',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('compendium-search-field'));

      // A hidden Russian alias matches; only Belarusian text is rendered.
      await tester.enterText(field, 'исповедь');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('compendium-search-overlay')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('compendium-results-count')), findsOneWidget);
      expect(find.text('ПЫТАННЕ 42'), findsNothing, reason: 'reader offstage');
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(
          (text.data ?? text.textSpan?.toPlainText() ?? '').toLowerCase(),
          isNot(contains('исповед')),
        );
      }
      final result = find.byKey(const ValueKey('compendium-result-296'));
      await tester.scrollUntilVisible(
        result,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('compendium-search-overlay')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.descendant(
          of: result,
          matching: find.text('ЧАСТКА ДРУГАЯ · САКРАМЭНТ ПАКАЯННЯ I ПАЯДНАННЯ'),
        ),
        findsOneWidget,
        reason: 'context uses real source headings',
      );
      await tester.tap(result);
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/question/296');
      expect(find.text('ПЫТАННЕ 296'), findsOneWidget);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'исповедь',
        reason: 'the query is kept on the next screen',
      );

      // Back → the results of the reader the search started from.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/question/42');
      expect(result, findsOneWidget);

      // Back again closes the search and restores the reader itself.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/question/42');
      expect(find.byKey(const Key('compendium-search-overlay')), findsNothing);
      expect(find.text('ПЫТАННЕ 42'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, 'исповедь');

      // Focusing the dock shows the kept results again; clearing restores
      // the reader.
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('compendium-search-overlay')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Ачысціць пошук'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('compendium-search-overlay')), findsNothing);
      expect(find.text('ПЫТАННЕ 42'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    });

    testWidgets('search from a part: number and Belarusian words', (
      tester,
    ) async {
      final router = _router(initialLocation: '/prayers/compendium/part/p4');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('compendium-search-field'));

      await tester.enterText(field, 'хрост');
      await tester.pumpAndSettle();
      expect(find.text('Знойдзена: 0'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('compendium-result-252')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('compendium-search-overlay')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.byKey(const ValueKey('compendium-result-252')),
        findsOneWidget,
        reason: 'search is global, not limited to Part IV',
      );

      await tester.enterText(field, '42');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('compendium-result-42')),
        findsOneWidget,
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/question/42');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/part/p4');
      expect(
        find.byKey(const ValueKey('compendium-result-42')),
        findsOneWidget,
      );
    });

    testWidgets('search from a section and a subsection: global results, '
        'one dock, query kept', (tester) async {
      final router = await _open(tester, '/prayers/compendium/node/p1-s1');
      addTearDown(router.dispose);
      final field = find.byKey(const Key('compendium-search-field'));
      final overlay = find.byKey(const Key('compendium-search-overlay'));
      expect(find.byKey(const Key('compendium-search-dock')), findsOneWidget);

      await tester.enterText(field, 'исповедь');
      await tester.pumpAndSettle();
      expect(overlay, findsOneWidget);
      expect(
        find.byKey(const ValueKey('compendium-question-row-1')),
        findsNothing,
        reason: 'the section is offstage while results are shown',
      );
      final result = find.byKey(const ValueKey('compendium-result-296'));
      await tester.scrollUntilVisible(
        result,
        200,
        scrollable: find
            .descendant(of: overlay, matching: find.byType(Scrollable))
            .first,
      );
      expect(
        tester.widget(result),
        isA<CompendiumQuestionRow>(),
        reason: 'results use the same question row',
      );
      await tester.tap(result);
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/question/296');

      // Back → the results of the section; Back again → the section itself.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/node/p1-s1');
      expect(result, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/node/p1-s1');
      expect(overlay, findsNothing);
      expect(
        find.byKey(const ValueKey('compendium-question-row-1')),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(field).controller!.text, 'исповедь');

      // The query follows the user down to the subsection.
      await tester.tap(
        find.byKey(const ValueKey('compendium-subsection-p1-s1-ch1')),
      );
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/node/p1-s1-ch1');
      expect(find.byKey(const Key('compendium-search-dock')), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, 'исповедь');
      expect(overlay, findsNothing);
      expect(
        find.byKey(const ValueKey('compendium-question-row-2')),
        findsOneWidget,
      );

      // Exact-number search from the subsection.
      await tester.enterText(field, '80');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('compendium-result-80')),
        findsOneWidget,
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(_location(router), '/prayers/compendium/question/80');
    });

    testWidgets('a topic id on the node route opens the topic reader', (
      tester,
    ) async {
      for (final (id, location) in [
        ('p1-s1-ch2-t1', '/prayers/compendium/topic/p1-s1-ch2-t1'),
        // A technical reading group keeps its legacy behaviour.
        ('p1-s1-intro', '/prayers/compendium/topic/p1-s1-intro'),
      ]) {
        final router = await _open(tester, '/prayers/compendium/node/$id');
        expect(_location(router), location);
        expect(find.byType(ReaderScaffold), findsOneWidget);
        expect(find.byKey(const Key('compendium-search-dock')), findsOneWidget);
        await _close(tester, router);
      }
    });

    testWidgets('section and subsection lists scroll fully above the dock', (
      tester,
    ) async {
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
          '/prayers/compendium/part/p1',
          '/prayers/compendium/node/p3-s2',
          '/prayers/compendium/node/p1-s2-ch2',
          '/prayers/compendium/node/p4-s2',
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
          final dock = tester.getRect(
            find.byKey(const Key('compendium-search-dock')),
          );
          // The header starts below the floating back button.
          expect(
            tester.getRect(find.byKey(const Key('compendium-node-label'))).top,
            greaterThanOrEqualTo(
              tester.getRect(find.byTooltip('Назад').first).bottom,
            ),
            reason: '$name $location',
          );
          await tester.fling(
            find.byType(ListView).first,
            const Offset(0, -20000),
            4000,
          );
          await tester.pumpAndSettle();
          final source = tester.getRect(
            find.byKey(const Key('compendium-source')),
          );
          expect(
            source.bottom,
            lessThanOrEqualTo(dock.top),
            reason: '$name $location',
          );
          expect(
            dock.bottom,
            lessThanOrEqualTo(size.height - math.max(bottom, gesture)),
            reason: '$name: the dock clears the system inset',
          );
          expect(
            find.byKey(const Key('compendium-search-dock')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull, reason: '$name $location');
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
        }
      }
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('the reader footer scrolls fully above the search dock', (
      tester,
    ) async {
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
          '/prayers/compendium/question/598',
          '/prayers/compendium/topic/p4-s1-ch3-t2',
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
          await tester.fling(
            find.byType(CustomScrollView),
            const Offset(0, -20000),
            4000,
          );
          await tester.pumpAndSettle();
          final source = tester.getRect(
            find.byKey(const Key('compendium-source')),
          );
          final dock = tester.getRect(
            find.byKey(const Key('compendium-search-dock')),
          );
          expect(
            source.bottom,
            lessThanOrEqualTo(dock.top),
            reason: '$name $location',
          );
          expect(
            dock.bottom,
            lessThanOrEqualTo(size.height - math.max(bottom, gesture)),
            reason: '$name: the dock clears the system inset',
          );
          expect(tester.takeException(), isNull, reason: '$name $location');
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
        }
      }
      debugDefaultTargetPlatformOverride = null;
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

/// Pumps a fresh app at [location]; the caller disposes the router.
Future<GoRouter> _open(WidgetTester tester, String location) async {
  final router = _router(initialLocation: location);
  await tester.pumpWidget(_app(router));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _close(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(const SizedBox.shrink());
  router.dispose();
}

/// Every item of the visible list screen, including rows the lazy list has
/// not built yet.
List<Widget> _listItems(WidgetTester tester) {
  final finder = find.byType(ListView).first;
  final delegate =
      tester.widget<ListView>(finder).childrenDelegate
          as SliverChildBuilderDelegate;
  final context = tester.element(finder);
  return [
    for (var i = 0; i < delegate.childCount!; i++)
      delegate.builder(context, i)!,
  ];
}

/// Keys of the rows of the visible list screen, in order.
List<String> _rowKeys(WidgetTester tester) => [
  for (final item in _listItems(tester))
    if (item.key case ValueKey<String>(:final value)) value,
];

/// Row keys a structural node must render: its direct questions, then its
/// children as destinations.
List<String> _expectedRowKeys(CompendiumNavNode node) => [
  for (final question in node.directQuestions)
    'compendium-question-row-${question.number}',
  for (final child in node.children)
    switch (child.kind) {
      CompendiumNodeKind.part ||
      CompendiumNodeKind.section => 'compendium-section-${child.id}',
      CompendiumNodeKind.chapter => 'compendium-subsection-${child.id}',
      CompendiumNodeKind.topic => 'compendium-group-${child.id}',
    },
];

String _nodeLocation(CompendiumNavNode node) =>
    node.kind == CompendiumNodeKind.part
    ? compendiumPartLocation(node.id)
    : compendiumNodeLocation(node.id);

/// Style of the [text] inside [row].
TextStyle _textStyle(WidgetTester tester, Finder row, String text) => tester
    .widget<Text>(find.descendant(of: row, matching: find.text(text)))
    .style!;

double _rowPadding(WidgetTester tester, Finder row) => tester
    .widget<CompendiumListRow>(
      find.descendant(of: row, matching: find.byType(CompendiumListRow)),
    )
    .verticalPadding;

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
  void Function()? onRefresh,
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
      onRefresh: onRefresh,
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
