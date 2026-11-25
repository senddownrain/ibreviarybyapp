import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/hyphenation/be_hyphenator.dart';
import 'package:mybrev_flutter/hyphenation/hyphenation_service.dart';
import 'package:mybrev_flutter/hyphenation/justified_hyphen_text.dart';
import 'package:mybrev_flutter/utils/reading_alignment.dart';
import 'package:mybrev_flutter/widgets/hyphenated_prose.dart';

// flutter_test draws text with the square "Ahem" face: one character is one em,
// so characters per line = width / fontSize exactly.
const _style = TextStyle(fontSize: 10, height: 1.5);

late BelarusianHyphenator hyph;

const prose =
    'Умілаваныя, прыступаючы да Пана, жывога каменя, адкінутага людзьмі, але выбранага '
    'Богам, каштоўнага, і вы самі, як жывыя камяні, будуйцеся ў дом духоўны, святарства святое.';

Widget host(Widget child, double width) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

List<RenderHyphenatedJustifiedText> hyphRenders(WidgetTester t) {
  final out = <RenderHyphenatedJustifiedText>[];
  void v(Element e) {
    final ro = e.renderObject;
    if (ro is RenderHyphenatedJustifiedText) {
      out.add(ro);
      return;
    }
    e.visitChildren(v);
  }

  t.binding.rootElement!.visitChildren(v);
  return out;
}

void main() {
  setUpAll(() {
    hyph = BelarusianHyphenator.fromTex(
      File('assets/hyphenation/hyph-be.tex').readAsStringSync(),
    );
  });
  setUp(() => BelarusianHyphenation.debugSet(hyph));
  tearDown(() => BelarusianHyphenation.debugSet(null));

  group('proseLayoutFor (same ≥36 rule as the shipped adaptive alignment)', () {
    ProseLayout at(
      double w, {
      TextAlign saved = TextAlign.justify,
      BelarusianHyphenator? h,
      TextScaler s = TextScaler.noScaling,
    }) => proseLayoutFor(
      selected: saved,
      maxWidth: w,
      style: _style,
      textScaler: s,
      hyphenator: h ?? hyph,
    );

    test('B2 / D / fallback', () {
      expect(at(360), ProseLayout.b2);
      expect(at(359), ProseLayout.d);
      expect(at(1000, saved: TextAlign.left), ProseLayout.d);
      expect(
        at(360, h: null),
        ProseLayout.b2,
      ); // `h ?? hyph`; explicit null below
      expect(
        proseLayoutFor(
          selected: TextAlign.justify,
          maxWidth: 360,
          style: _style,
          textScaler: TextScaler.noScaling,
          hyphenator: null,
        ),
        ProseLayout.fallback,
      );
      expect(at(360, s: const TextScaler.linear(1.5)), ProseLayout.d);
    });

    test('agrees with effectiveProseAlignment for many widths and scales', () {
      for (final scale in [1.0, 1.25, 1.5, 1.8, 2.0]) {
        for (var w = 150.0; w <= 800; w += 13) {
          final shown = effectiveProseAlignment(
            selected: TextAlign.justify,
            maxWidth: w,
            style: _style,
            textScaler: TextScaler.linear(scale),
          );
          expect(
            at(w, s: TextScaler.linear(scale)),
            shown == TextAlign.justify ? ProseLayout.b2 : ProseLayout.d,
          );
        }
      }
    });
  });

  group('block classification', () {
    bool isProse(String html) =>
        isProseParagraph(parseFragment(html).nodes.whereType<dynamic>().first);

    test(
      'running text qualifies; verses, rubrics, classes, centering, short lines do not',
      () {
        expect(isProse('<p>$prose</p>'), isTrue);
        expect(
          isProse(
            '<p>Умілаваныя, <em>старэйшыя</em> жанчыны павінны <strong>годна</strong> паводзіць сябе, як належыць святым.</p>',
          ),
          isTrue,
        );
        expect(isProse('<p class="semantic-last">$prose</p>'), isTrue);
        expect(
          isProse(
            '<p>Божа, мой Божа, Цябе шукаю, *<br />Цябе прагне душа мая, каб убачыць Тваю сілу і славу.</p>',
          ),
          isFalse,
        );
        expect(isProse('<p>$prose †</p>'), isFalse);
        expect(isProse('<p class="liturgical-rubric">$prose</p>'), isFalse);
        expect(isProse('<p class="psalm-strophe">$prose</p>'), isFalse);
        expect(isProse('<p style="text-align: center;">$prose</p>'), isFalse);
        expect(isProse('<p style="text-indent: 18pt;">$prose</p>'), isFalse);
        expect(
          isProse(
            '<p><span class="liturgical-rubric-inline">ПЕРШАЕ ЧЫТАННЕ ПЕРШАЕ ЧЫТАННЕ ПЕРШАЕ ЧЫТАННЕ</span></p>',
          ),
          isFalse,
        );
        expect(isProse('<p>Кароткі радок.</p>'), isFalse);
        expect(isProse('<p>$prose<img src="x"/></p>'), isFalse);
        expect(isProse('<div>$prose</div>'), isFalse);
      },
    );

    test('splitProseBlocks keeps everything that is not prose in order', () {
      final blocks = splitProseBlocks(
        '<h2>Загаловак</h2><p>$prose</p><ul><li>раз</li></ul>'
        '<p class="liturgical-rubric">Рубрыка</p><p>$prose</p>',
      );
      expect(
        [for (final b in blocks) b.prose != null],
        [false, true, false, true],
      );
      expect(blocks.first.html, contains('<h2>'));
      expect(blocks[2].html, contains('<ul>'));
      expect(blocks[2].html, contains('liturgical-rubric'));
    });
  });

  group('HyphenatedProse', () {
    testWidgets(
      'uses the hyphenation renderer, B2 on wide lines and D on narrow ones',
      (t) async {
        final span = TextSpan(text: prose, style: _style);
        await t.pumpWidget(
          host(
            HyphenatedProse(
              span: span,
              selected: TextAlign.justify,
              style: _style,
            ),
            400,
          ),
        );
        expect(hyphRenders(t).single.justify, isTrue);
        await t.pumpWidget(
          host(
            HyphenatedProse(
              span: span,
              selected: TextAlign.justify,
              style: _style,
            ),
            300,
          ),
        );
        expect(hyphRenders(t).single.justify, isFalse);
        await t.pumpWidget(
          host(
            HyphenatedProse(
              span: span,
              selected: TextAlign.left,
              style: _style,
            ),
            900,
          ),
        );
        expect(hyphRenders(t).single.justify, isFalse);
      },
    );

    testWidgets(
      'falls back to the stock renderer with adaptive alignment when patterns are missing',
      (t) async {
        BelarusianHyphenation.debugSet(null);
        final span = TextSpan(text: prose, style: _style);
        await t.pumpWidget(
          host(
            HyphenatedProse(
              span: span,
              selected: TextAlign.justify,
              style: _style,
            ),
            400,
          ),
        );
        expect(hyphRenders(t), isEmpty);
        expect(
          t.widget<RichText>(find.byType(RichText).first).textAlign,
          TextAlign.justify,
        );
        await t.pumpWidget(
          host(
            HyphenatedProse(
              span: span,
              selected: TextAlign.justify,
              style: _style,
            ),
            300,
          ),
        );
        expect(
          t.widget<RichText>(find.byType(RichText).first).textAlign,
          TextAlign.left,
        );
      },
    );

    testWidgets(
      'switches from fallback to hyphenation when the patterns finish loading',
      (t) async {
        BelarusianHyphenation.debugSet(null);
        final span = TextSpan(text: prose, style: _style);
        await t.pumpWidget(
          host(
            HyphenatedProse(
              span: span,
              selected: TextAlign.justify,
              style: _style,
            ),
            400,
          ),
        );
        expect(hyphRenders(t), isEmpty);
        BelarusianHyphenation.notifier.value = hyph;
        await t.pump();
        expect(hyphRenders(t), hasLength(1));
      },
    );

    testWidgets(
      'select all + copy returns the source text without added hyphens',
      (t) async {
        final clip = <String>[];
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (c) async {
            if (c.method == 'Clipboard.setData')
              clip.add((c.arguments as Map)['text'] as String);
            return null;
          },
        );
        addTearDown(
          () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await t.pumpWidget(
          host(
            SelectionArea(
              child: HyphenatedProse(
                span: TextSpan(text: prose, style: _style),
                selected: TextAlign.justify,
                style: _style,
              ),
            ),
            400,
          ),
        );
        expect(
          hyphRenders(t).single.lines.any((l) => l.endsWithHyphen),
          isTrue,
        );
        final st = t.state<SelectableRegionState>(
          find.byType(SelectableRegion),
        );
        st.selectAll();
        await t.pump();
        st.copySelection(
          SelectionChangedCause.toolbar,
        ); // ignore: deprecated_member_use
        expect(clip.single, prose);
      },
    );
  });

  group('HyphenatedHtml', () {
    final styles = <String, Style>{
      'body': Style(
        fontSize: FontSize(10),
        lineHeight: LineHeight(1.5),
        margin: Margins.zero,
      ),
      'p': Style(margin: Margins.only(bottom: 8)),
      '.liturgical-rubric-inline': Style(color: const Color(0xFF9B302A)),
    };

    testWidgets(
      'prose paragraphs are hyphenated, verses and rubrics stay with Html',
      (t) async {
        const html =
            '<p class="liturgical-rubric">ПЕРШАЕ ЧЫТАННЕ</p><p>$prose</p>'
            '<p>Божа, мой Божа, Цябе шукаю, *<br />Цябе прагне душа мая.</p>'
            '<p>Умілаваныя, <em>старэйшыя</em> жанчыны <span class="liturgical-rubric-inline">павінны</span> паводзіць сябе так, як належыць святым.</p>';
        await t.pumpWidget(
          host(
            const HyphenatedHtml(
              data: html,
              style: {},
              selected: TextAlign.justify,
            ),
            400,
          ),
        );
        // empty style map is accepted (no crash) …
        await t.pumpWidget(
          host(
            HyphenatedHtml(
              data: html,
              style: styles,
              selected: TextAlign.justify,
            ),
            400,
          ),
        );
        final renders = hyphRenders(t);
        expect(renders, hasLength(2));
        expect(renders.first.plainText, prose);
        expect(renders.last.plainText.contains('старэйшыя'), isTrue);
        expect(
          find.byType(Html),
          findsNWidgets(2),
          reason: 'rubric before + verse chunk after the first prose paragraph',
        );
      },
    );

    testWidgets(
      'patterns not loaded → exactly the old single Html (nothing split)',
      (t) async {
        BelarusianHyphenation.debugSet(null);
        const html =
            '<p>$prose</p><p>Божа, мой Божа, Цябе шукаю, *<br />Цябе прагне душа мая.</p>';
        await t.pumpWidget(
          host(
            HyphenatedHtml(
              data: html,
              style: styles,
              selected: TextAlign.justify,
            ),
            400,
          ),
        );
        expect(hyphRenders(t), isEmpty);
        expect(find.byType(Html), findsOneWidget);
        expect(t.widget<Html>(find.byType(Html)).data, html);
      },
    );

    testWidgets('no prose paragraph → exactly the old single Html', (t) async {
      const html =
          '<p class="liturgical-rubric">ПЕРШАЕ ЧЫТАННЕ</p><p>Божа, мой Божа, Цябе шукаю, *<br />Цябе прагне душа мая.</p>';
      await t.pumpWidget(
        host(
          HyphenatedHtml(
            data: html,
            style: styles,
            selected: TextAlign.justify,
          ),
          400,
        ),
      );
      expect(hyphRenders(t), isEmpty);
      expect(find.byType(Html), findsOneWidget);
    });

    testWidgets('inline classes keep their colour; links stay tappable spans', (
      t,
    ) async {
      const html =
          '<p>Умілаваныя, <span class="liturgical-rubric-inline">рубрыка тут</span> і звычайны тэкст, які павінен перанесціся недзе ў канцы радка.</p>';
      await t.pumpWidget(
        host(
          HyphenatedHtml(
            data: html,
            style: styles,
            selected: TextAlign.justify,
          ),
          400,
        ),
      );
      final ro = hyphRenders(t).single;
      expect(ro.plainText.startsWith('Умілаваныя, рубрыка тут'), isTrue);
    });
  });
}
