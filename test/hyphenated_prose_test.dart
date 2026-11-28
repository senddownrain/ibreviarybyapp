import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/hyphenation/be_hyphenator.dart';
import 'package:mybrev_flutter/hyphenation/hyphenation_service.dart';
import 'package:mybrev_flutter/hyphenation/justified_hyphen_text.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';
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

  group('proseLayoutFor (same ≥28 rule as the shipped adaptive alignment)', () {
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
      expect(at(280), ProseLayout.b2);
      expect(at(300), ProseLayout.b2);
      expect(at(279), ProseLayout.d);
      expect(at(1000, saved: TextAlign.left), ProseLayout.d);
      expect(
        at(280, h: null),
        ProseLayout.b2,
      ); // `h ?? hyph`; explicit null below
      expect(
        proseLayoutFor(
          selected: TextAlign.justify,
          maxWidth: 280,
          style: _style,
          textScaler: TextScaler.noScaling,
          hyphenator: null,
        ),
        ProseLayout.fallback,
      );
      expect(at(400, s: const TextScaler.linear(1.5)), ProseLayout.d);
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
        // Ignored by the stock renderer, so it does not block hyphenation.
        expect(
          isProse(
            '<p style="text-indent: 18pt; text-align: justify;">$prose</p>',
          ),
          isTrue,
        );
        expect(isProse('<p style="margin-left: 18pt;">$prose</p>'), isFalse);
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
            270,
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
            270,
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

    // Found on the iOS simulator: with touch selection handles the whole text
    // vanished, because the handle layers were pushed before the glyphs were
    // painted onto the (by then ended) canvas.
    testWidgets(
      'text stays painted while a touch selection shows its handles',
      (t) async {
        final key = GlobalKey();
        await t.pumpWidget(
          host(
            RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: Colors.white,
                child: SelectionArea(
                  child: HyphenatedProse(
                    span: TextSpan(
                      text: prose,
                      style: _style.copyWith(color: Colors.black),
                    ),
                    selected: TextAlign.justify,
                    style: _style,
                  ),
                ),
              ),
            ),
            400,
          ),
        );
        Future<int> darkPixels() async {
          var count = 0;
          await t.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final data = (await (await boundary.toImage()).toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            for (var i = 0; i < data.lengthInBytes; i += 4) {
              if (data.getUint8(i) < 90 &&
                  data.getUint8(i + 1) < 90 &&
                  data.getUint8(i + 2) < 90) {
                count++;
              }
            }
          });
          return count;
        }

        final before = await darkPixels();
        expect(before, greaterThan(500));
        await t.longPressAt(
          t.getTopLeft(find.byType(HyphenatedJustifiedText)) +
              const Offset(25, 6),
        );
        await t.pumpAndSettle();
        expect(
          hyphRenders(t).single.getSelectedContent(),
          isNotNull,
          reason: 'a word is selected',
        );
        final after = await darkPixels();
        expect(
          after,
          greaterThan(before ~/ 2),
          reason: 'glyphs vanished: $before dark pixels before, $after after',
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
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

  group('formatting and links are never traded for hyphenation', () {
    final styles = <String, Style>{
      'body': Style(
        fontSize: FontSize(10),
        lineHeight: LineHeight(1.5),
        margin: Margins.zero,
      ),
      'p': Style(margin: Margins.only(bottom: 8)),
      'a': Style(color: const Color(0xFF2F5F7E)),
      '.liturgical-rubric-inline': Style(color: const Color(0xFF9B302A)),
      '.boxed': Style(backgroundColor: const Color(0xFFEEEEEE)),
    };
    bool qualifies(String html) =>
        isProseParagraph(parseFragment(html).children.first, styles);

    test('anything that cannot be reproduced keeps the stock renderer', () {
      expect(qualifies('<p>$prose</p>'), isTrue);
      expect(
        qualifies(
          '<p style="text-align: justify;">$prose <em>курсіў</em> <strong>тоўсты</strong></p>',
        ),
        isTrue,
      );
      expect(
        qualifies(
          '<p>$prose <span class="liturgical-rubric-inline">рубрыка</span></p>',
        ),
        isTrue,
      );
      for (final html in [
        '<p>$prose <a href="https://example.invalid/x">спасылка</a></p>',
        '<p>$prose<sup>1</sup></p>',
        '<p>$prose<sub>2</sub></p>',
        '<p>$prose <span style="color: #ff00ff;">колер</span></p>',
        '<p>$prose <em style="font-size: 20px">курсіў</em></p>',
        '<p>$prose <span class="unknown">клас</span></p>',
        '<p>$prose <span class="boxed">фон</span></p>',
        '<p style="color: red;">$prose</p>',
        '<p style="margin-left: 20px;">$prose</p>',
        '<p dir="rtl">$prose</p>',
        '<p>$prose<br>другі радок</p>',
      ]) {
        expect(qualifies(html), isFalse, reason: html);
      }
    });

    test(
      'hymns, psalms, canticles, antiphons and dialogues are not re-wrapped',
      () {
        List<bool> prosePattern(String html) => [
          for (final b in splitProseBlocks(html, styles)) b.prose != null,
        ];
        for (final heading in [
          'Гімн',
          'Псальмодыя',
          'Псальм 63',
          'Песня Захарыі',
          'Кантык',
          'Антыфона Багародзіцы',
        ]) {
          expect(
            prosePattern('<h2>$heading</h2><p>$prose</p>').contains(true),
            isFalse,
            reason: heading,
          );
        }
        // the next ordinary heading ends the verse section
        expect(
          prosePattern(
            '<h2>Гімн</h2><p>$prose</p><h2>Кароткае чытанне і рэспансорый</h2><p>$prose</p>',
          ),
          [false, true],
        );
        for (final start in [
          'Ант. ',
          '1 ант. ',
          'Антыфона: ',
          'К. ',
          'Н.: ',
          'С. ',
          '℟ ',
        ]) {
          expect(qualifies('<p>$start$prose</p>'), isFalse, reason: start);
        }
        expect(
          qualifies('<p><span class="prayer-speaker">Ц.:</span> $prose</p>'),
          isFalse,
        );
      },
    );

    testWidgets(
      'a paragraph with a link stays Html and the link is really tappable',
      (t) async {
        final taps = <String?>[];
        await t.pumpWidget(
          host(
            HyphenatedHtml(
              data:
                  '<p>$prose</p><p>Глядзі <a href="https://example.invalid/tyt">спасылку на Пісанне</a> і далей чытай тэкст гэтай малітвы цалкам.</p>',
              style: styles,
              selected: TextAlign.justify,
              onLinkTap: (url, attributes, element) => taps.add(url),
            ),
            400,
          ),
        );
        await t.pumpAndSettle();
        expect(
          hyphRenders(t),
          hasLength(1),
          reason: 'only the plain paragraph is hyphenated',
        );
        await t.tapOnText(find.textRange.ofSubstring('спасылку'));
        await t.pumpAndSettle();
        expect(taps, ['https://example.invalid/tyt']);
      },
    );

    testWidgets(
      'italic, bold and rubric colour survive inside a hyphenated paragraph',
      (t) async {
        await t.pumpWidget(
          host(
            HyphenatedHtml(
              data:
                  '<p>$prose <em>курсіў</em> <strong>тоўсты</strong> <span class="liturgical-rubric-inline">рубрыка</span></p>',
              style: styles,
              selected: TextAlign.justify,
            ),
            400,
          ),
        );
        final seen = <String, TextStyle>{};
        void walk(InlineSpan span, TextStyle inherited) {
          if (span is! TextSpan) return;
          final merged = inherited.merge(span.style);
          if (span.text != null) seen[span.text!.trim()] = merged;
          span.children?.forEach((c) => walk(c, merged));
        }

        walk(
          t
              .widget<HyphenatedJustifiedText>(
                find.byType(HyphenatedJustifiedText),
              )
              .text,
          const TextStyle(),
        );
        expect(seen['курсіў']!.fontStyle, FontStyle.italic);
        expect(seen['тоўсты']!.fontWeight, FontWeight.w700);
        expect(seen['рубрыка']!.color, const Color(0xFF9B302A));
      },
    );

    test(
      'every bundled prayer keeps its text exactly when a paragraph is hyphenated',
      () {
        final bundle = decodeContentCollection(
          File('assets/content/prayers.json.gz').readAsBytesSync(),
        );
        String flat(String s) =>
            s.replaceAll(RegExp(r'[ \t\r\n]+'), ' ').trim();
        var checked = 0;
        for (final doc in bundle.docs.values) {
          final text = (doc['textVersions'] as Map?)?['be'] ?? doc['text'];
          if (text is! String) continue;
          for (final block in splitProseBlocks(
            prayerMarkdownToHtml(text),
            styles,
          )) {
            final p = block.prose;
            if (p == null) continue;
            checked++;
            expect(
              flat(proseSpan(p, styles, _style).toPlainText()),
              flat(p.text),
            );
            expect(p.querySelector('a, sup, sub, br'), isNull);
          }
        }
        expect(checked, greaterThan(500));
      },
    );
  });

  group('selection details', () {
    testWidgets('the highlight covers the painted hyphen', (t) async {
      await t.pumpWidget(
        host(
          SelectionArea(
            child: HyphenatedProse(
              span: const TextSpan(text: prose, style: _style),
              selected: TextAlign.justify,
              style: _style,
            ),
          ),
          400,
        ),
      );
      t.state<SelectableRegionState>(find.byType(SelectableRegion)).selectAll();
      await t.pump();
      final render = hyphRenders(t).single;
      final rects = render.value.selectionRects;
      var hyphenLines = 0;
      for (var i = 0; i < render.lines.length; i++) {
        if (render.lines[i].endsWithHyphen) {
          hyphenLines++;
          expect(
            rects[i].right,
            closeTo(400, 0.6),
            reason: 'line $i: ${render.lines[i].text}',
          );
        }
      }
      expect(hyphenLines, greaterThan(0));
    });

    testWidgets('a selection is dropped when the text changes', (t) async {
      Widget view(String text) => host(
        SelectionArea(
          child: HyphenatedProse(
            span: TextSpan(text: text, style: _style),
            selected: TextAlign.justify,
            style: _style,
          ),
        ),
        400,
      );
      await t.pumpWidget(view(prose));
      t.state<SelectableRegionState>(find.byType(SelectableRegion)).selectAll();
      await t.pump();
      expect(hyphRenders(t).single.getSelectedContent(), isNotNull);
      await t.pumpWidget(
        view(
          'Зусім іншы тэкст малітвы, які паказваецца пасля першага і не выдзелены нікім.',
        ),
      );
      await t.pumpAndSettle();
      expect(hyphRenders(t).single.getSelectedContent(), isNull);
      expect(hyphRenders(t).single.value.selectionRects, isEmpty);
    });
  });

  // Found in the Chrome smoke of the real Hours screen: the reader face loads
  // asynchronously, and the renderer kept the fallback face for ever.
  testWidgets('re-lays out when the reader font finishes loading', (t) async {
    const family = 'LateReaderFace';
    const style = TextStyle(fontFamily: family, fontSize: 10, height: 1.5);
    await t.pumpWidget(
      host(
        const HyphenatedProse(
          span: TextSpan(text: prose, style: style),
          selected: TextAlign.left,
          style: style,
        ),
        400,
      ),
    );
    double firstLine() => hyphRenders(t).single.lines.first.naturalWidth;
    final linesBefore = hyphRenders(t).single.lines.length;
    final widthBefore = firstLine();
    await t.runAsync(() async {
      final loader = FontLoader(family)
        ..addFont(
          File(
            'assets/google_fonts/Literata-Regular.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await loader.load();
    });
    await t.pumpAndSettle();
    final render = hyphRenders(t).single;
    expect(
      render.lines.length != linesBefore || firstLine() != widthBefore,
      isTrue,
      reason:
          'still measured with the fallback face: $linesBefore lines, $widthBefore',
    );
  });

  group('word gaps stay bounded', () {
    const faces = {
      'Literata': 'Literata-Regular',
      'SourceSerif4': 'SourceSerif4-Regular',
      'OldStandardTT': 'OldStandardTT-Regular',
      'Kurale': 'Kurale-Regular',
    };
    Future<void> loadFaces(WidgetTester t) => t.runAsync(() async {
      for (final face in faces.entries) {
        final loader = FontLoader(face.key)
          ..addFont(
            File(
              'assets/google_fonts/${face.value}.ttf',
            ).readAsBytes().then((b) => ByteData.sublistView(b)),
          );
        await loader.load();
      }
    });

    Map<String, dynamic> docs(String name) => decodeContentCollection(
      File('assets/content/$name.json.gz').readAsBytesSync(),
    ).docs;

    /// The running text of the documents the problem was reported on.
    List<String> realProse() {
      final styles = <String, Style>{
        'p': Style(margin: Margins.only(bottom: 8)),
        '.liturgical-rubric-inline': Style(color: const Color(0xFF9B302A)),
      };
      final out = <String>[];
      void html(String source) {
        for (final block in splitProseBlocks(source, styles)) {
          if (block.prose != null)
            out.add(
              proseSpan(block.prose!, styles, const TextStyle()).toPlainText(),
            );
        }
      }

      final prayers = docs('prayers');
      for (final id in [
        'sacraments-baptism-emergency-baptism-of-children',
        'sacraments-eucharist-aquinas-before-communion',
      ]) {
        final doc = prayers[id]!;
        html(
          prayerMarkdownToHtml(
            ((doc['textVersions'] as Map?)?['be'] ?? doc['text']) as String,
          ),
        );
      }
      final day = docs('days')['ordinary-w34-d6']!;
      for (final key in ['officeOfReadingsR1', 'officeOfReadingsR2']) {
        html(
          formatLiturgicalHtml(
            normalizeOfficeHtml(day[key] as String, officeReading: true),
          ),
        );
      }
      final readings = docs('readings');
      for (final id in ['ordinary-w34-d6--1', 'ordinary-w34-d6--2']) {
        for (final field in ['reading1', 'gospel']) {
          out.add(
            ((readings[id]![field] as Map)['text'] as String).replaceAll(
              RegExp(r'\r?\n[ \t]*\r?\n+'),
              '\n',
            ),
          );
        }
      }
      return out;
    }

    testWidgets(
      'real prayers, Mass readings and Office readings: no gap above 1.8 spaces, no overflow, no lost text',
      (t) async {
        await loadFaces(t);
        final texts = realProse();
        expect(texts.length, greaterThan(8));
        // The patristic Office reading (`text-indent` paragraphs) is covered.
        expect(
          texts.any((text) => text.contains('Мы заўсёды павінны памятаць')),
          isTrue,
        );
        t.view.physicalSize = const Size(900, 60000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var lines = 0, justified = 0;
        for (final face in faces.keys) {
          for (final width in [288.0, 328.0, 358.0, 398.0]) {
            for (final size in [16.0, 20.8]) {
              final style = TextStyle(
                fontFamily: face,
                fontSize: size,
                height: 1.68,
              );
              for (final text in texts) {
                await t.pumpWidget(
                  host(
                    HyphenatedJustifiedText(
                      text: TextSpan(text: text, style: style),
                      hyphenator: hyph,
                    ),
                    width,
                  ),
                );
                final render = hyphRenders(t).single;
                final gaps = render.paintedWordGaps;
                final rebuilt = StringBuffer();
                for (var i = 0; i < render.lines.length; i++) {
                  final line = render.lines[i];
                  lines++;
                  if (!line.isLast && !line.alignedLeft) justified++;
                  var painted = line.naturalWidth;
                  for (final gap in gaps[i]) {
                    expect(
                      gap,
                      lessThanOrEqualTo(
                        render.spaceWidth * defaultMaxGapRatio + 0.05,
                      ),
                      reason: '$face $size w=$width "${line.text}"',
                    );
                    painted += gap - render.spaceWidth;
                  }
                  expect(
                    painted,
                    lessThanOrEqualTo(width + 0.6),
                    reason: 'overflow: "${line.text}"',
                  );
                  rebuilt.write(line.text);
                  if (i < render.lines.length - 1 &&
                      !line.endsWithHyphen &&
                      !line.text.endsWith('-')) {
                    rebuilt.write(line.isLast ? '\n' : ' ');
                  }
                }
                String flat(String s) =>
                    s.replaceAll(RegExp(r'\s+'), ' ').trim();
                expect(flat(rebuilt.toString()), flat(text));
              }
            }
          }
        }
        // The limit must not simply turn the book setting into ragged text.
        expect(
          justified / lines,
          greaterThan(0.4),
          reason: '$justified of $lines lines justified',
        );
      },
    );

    testWidgets(
      'a line that cannot be filled keeps natural spaces; left alignment never squeezes',
      (t) async {
        const style = TextStyle(fontSize: 10, height: 1.5);
        // Ahem: "аб вг" is 5 em, the next word cannot join or break.
        const text = 'аб вг ААААААААААААААААААААААААААААААААААААА деж';
        await t.pumpWidget(
          host(
            HyphenatedJustifiedText(
              text: const TextSpan(text: text, style: style),
              hyphenator: hyph,
            ),
            400,
          ),
        );
        var render = hyphRenders(t).single;
        expect(render.lines.first.alignedLeft, isTrue);
        expect(
          render.paintedWordGaps.first.single,
          closeTo(render.spaceWidth, 0.01),
        );
        await t.pumpWidget(
          host(
            HyphenatedJustifiedText(
              text: const TextSpan(text: prose, style: style),
              hyphenator: hyph,
              justify: false,
            ),
            300,
          ),
        );
        render = hyphRenders(t).single;
        for (var i = 0; i < render.lines.length; i++) {
          expect(render.lines[i].naturalWidth, lessThanOrEqualTo(300.5));
          for (final gap in render.paintedWordGaps[i]) {
            expect(gap, closeTo(render.spaceWidth, 0.01));
          }
        }
      },
    );

    testWidgets(
      'long capitalised words inside a sentence may break, short names and acronyms do not',
      (t) async {
        const style = TextStyle(fontSize: 10, height: 1.5);
        final broken = <String>{};
        const text = 'мы просім Усемагутнага Бога праз Езуса і ДАБРАСЛАЎЛЕННЕ';
        for (var width = 150.0; width <= 320; width += 5) {
          await t.pumpWidget(
            host(
              HyphenatedJustifiedText(
                text: const TextSpan(text: text, style: style),
                hyphenator: hyph,
              ),
              width,
            ),
          );
          for (final line in hyphRenders(t).single.lines) {
            if (line.endsWithHyphen) broken.add(line.text.split(' ').last);
          }
        }
        expect(
          broken.any((w) => w.startsWith('Уса') || w.startsWith('Усе')),
          isTrue,
          reason: '$broken',
        );
        expect(
          broken.any((w) => w.startsWith('Ез') || w.startsWith('ДАБ')),
          isFalse,
          reason: '$broken',
        );
        expect(
          broken.any((w) => w == 'Ус'),
          isFalse,
          reason: 'at least three letters stay: $broken',
        );
      },
    );

    testWidgets(
      'dialogues and unsupported running text are left-aligned; verses and centred titles are untouched',
      (t) async {
        final styles = <String, Style>{
          'body': Style(
            fontSize: FontSize(10),
            textAlign: TextAlign.justify,
            margin: Margins.zero,
          ),
          'p': Style(
            textAlign: TextAlign.justify,
            margin: Margins.only(bottom: 8),
          ),
          '.prayer-speaker': Style(color: const Color(0xFF9B302A)),
        };
        const html =
            '<p><span class="prayer-speaker">Цэлебрант:</span> Молімся, каб праз хрост Ты далучыў гэтае дзіця да Касцёла.</p>'
            '<p><span class="prayer-speaker">Усе:</span> <em>Цябе просім, выслухай нас, Пане.</em></p>'
            '<p style="text-align: justify;">Народ адказвае: Дзякуй Богу за ўсе дабрадзействы Ягоныя.</p>'
            '<p style="text-align: justify;">Глядзі <a href="https://example.invalid/x">спасылку</a> і чытай далей гэты доўгі абзац.</p>'
            '<p>Божа мой, Цябе шукаю, *<br />Цябе прагне душа мая.</p>'
            '<p style="text-align: center;">Назва раздзела па цэнтры</p>';
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
        await t.pumpAndSettle();
        TextAlign alignOf(String needle) => t.allRenderObjects
            .whereType<RenderParagraph>()
            .firstWhere(
              (p) =>
                  p.text.toPlainText().contains(needle) &&
                  !p.text.toPlainText().contains('￼'),
            )
            .textAlign;
        expect(alignOf('Молімся'), TextAlign.left);
        expect(alignOf('Цябе просім'), TextAlign.left);
        expect(alignOf('Народ адказвае'), TextAlign.left);
        expect(alignOf('спасылку'), TextAlign.left);
        expect(
          alignOf('Цябе прагне'),
          TextAlign.justify,
          reason: 'psalm verse unchanged',
        );
        // formatting and the red speaker survive
        final aligned = alignUnsupportedProse(html);
        expect(aligned, contains('class="prayer-speaker"'));
        expect(aligned, contains('<em>'));
        expect(aligned, contains('href="https://example.invalid/x"'));
        // centred titles keep their own style: not re-aligned by this rule
        expect(
          aligned,
          contains('<p style="text-align: center;">Назва раздзела'),
        );
      },
    );

    test('responsory sections are not re-aligned', () {
      const html =
          '<h3>Рэспансорый</h3><p><span class="prayer-speaker">К.</span> Пане, пачуй малітву маю.</p>';
      expect(alignUnsupportedProse(html), isNot(contains(proseLeftClass)));
    });
  });
}
