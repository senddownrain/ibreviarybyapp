import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:hyphenation_lab/be_hyphenator.dart';
import 'package:hyphenation_lab/final_scene.dart';
import 'package:hyphenation_lab/justified_hyphen_text.dart';
import 'package:hyphenation_lab/lab_core.dart';

import 'real_readings.dart';
import 'support.dart';

late BelarusianHyphenator hyph;

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

Widget app(Widget child, double width) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    backgroundColor: Colors.white,
    body: SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

FinalReading reading(
  String text, {
  FinalKind kind = FinalKind.plain,
  String family = 'Literata',
  double scale = 1.0,
  TextAlign saved = TextAlign.justify,
  LabPalette palette = LabPalette.light,
}) => FinalReading(
  kind: kind,
  text: text,
  family: family,
  scale: scale,
  palette: palette,
  hyphenator: hyph,
  saved: saved,
);

void main() {
  setUpAll(() async {
    await loadLabFonts();
    hyph = BelarusianHyphenator.fromTex(
      File('assets/patterns/hyph-be.tex').readAsStringSync(),
    );
  });

  final sample = sampleReadings(step: 60);

  group('automatic B2 / D choice (same ≥36 characters rule as #149)', () {
    test('decision table', () {
      final s = bodyStyle('Literata', 1.0, LabPalette.light);
      final adv = averageAdvance(s);
      double w(double cpl) => cpl * adv;
      expect(
        finalChoice(saved: TextAlign.justify, innerWidth: w(36.5), style: s),
        Hyph.b2,
      );
      expect(
        finalChoice(saved: TextAlign.justify, innerWidth: w(35.5), style: s),
        Hyph.d,
      );
      expect(
        finalChoice(saved: TextAlign.left, innerWidth: w(200), style: s),
        Hyph.d,
      );
      expect(
        finalChoice(
          saved: TextAlign.justify,
          innerWidth: w(60),
          style: s,
          textScaler: const TextScaler.linear(2),
        ),
        Hyph.d,
      );
    });

    test(
      'identical to the shipped adaptive rule for every font/scale/width',
      () {
        for (final f in readerFonts) {
          for (final scale in [1.0, 1.25, 1.5, 1.8]) {
            for (final width in [288.0, 328.0, 358.0, 398.0, 520.0]) {
              final s = bodyStyle(f, scale, LabPalette.light);
              final ad = adaptiveAlignment(width, s) == TextAlign.justify;
              final fin =
                  finalChoice(
                    saved: TextAlign.justify,
                    innerWidth: width,
                    style: s,
                  ) ==
                  Hyph.b2;
              expect(fin, ad, reason: '$f x$scale w=$width');
            }
          }
        }
      },
    );

    testWidgets(
      'the rendered renderer follows the choice; the saved value is not changed',
      (t) async {
        final text = sample.first.text;
        const saved = TextAlign.justify;
        for (final (scale, width, expectB2) in [
          (1.0, 390.0, true),
          (1.0, 320.0, false),
          (1.8, 390.0, false),
        ]) {
          await t.pumpWidget(
            app(reading(text, scale: scale, saved: saved), width),
          );
          final r = hyphRenders(t);
          expect(r, isNotEmpty);
          expect(
            r.every((x) => x.justify == expectB2),
            isTrue,
            reason: 'scale=$scale w=$width',
          );
        }
        await t.pumpWidget(app(reading(text, saved: TextAlign.left), 600));
        expect(
          hyphRenders(t).every((x) => !x.justify),
          isTrue,
          reason: 'saved left → always D',
        );
      },
    );
  });

  group('original text is preserved', () {
    testWidgets(
      'select all + copy returns the source text exactly (B2 and D)',
      (t) async {
        final text = proseOf(
          loadRealReadings()
              .firstWhere(
                (r) => r.id == 'easter-w5-d1--A' && r.field == 'reading2',
              )
              .text,
        );
        var anyHyphen = false;
        for (final width in [360.0, 320.0]) {
          final clip = <String>[];
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (c) async {
              if (c.method == 'Clipboard.setData')
                clip.add((c.arguments as Map)['text'] as String);
              return null;
            },
          );
          await t.pumpWidget(app(SelectionArea(child: reading(text)), width));
          anyHyphen |= hyphRenders(t).single.lines.any((l) => l.endsWithHyphen);
          final st = t.state<SelectableRegionState>(
            find.byType(SelectableRegion),
          );
          st.selectAll();
          await t.pump();
          st.copySelection(
            SelectionChangedCause.toolbar,
          ); // ignore: deprecated_member_use
          expect(clip.single, text);
          expect(clip.single.contains('­'), isFalse);
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        }
        expect(anyHyphen, isTrue, reason: 'precondition: hyphens are painted');
      },
    );

    testWidgets(
      'no overflow and lines reassemble to the text (real readings × fonts × widths × scales)',
      (t) async {
        for (final r in sample) {
          final text = proseOf(r.text);
          for (final f in readerFonts) {
            for (final scale in [1.0, 1.8]) {
              for (final width in [320.0, 390.0]) {
                for (final saved in [TextAlign.justify, TextAlign.left]) {
                  await t.pumpWidget(
                    app(
                      reading(text, family: f, scale: scale, saved: saved),
                      width,
                    ),
                  );
                  final ro = hyphRenders(t).single;
                  final ctx = '${r.id} $f x$scale w=$width $saved';
                  for (final l in ro.lines) {
                    expect(
                      l.naturalWidth,
                      lessThanOrEqualTo(width - 2 * gutter + 0.5),
                      reason: ctx,
                    );
                  }
                  final b = StringBuffer();
                  final lines = ro.lines;
                  for (var i = 0; i < lines.length; i++) {
                    b.write(lines[i].text);
                    if (i == lines.length - 1) break;
                    if (!lines[i].endsWithHyphen &&
                        !lines[i].text.endsWith('-')) {
                      b.write(lines[i].isLast ? '\n' : ' ');
                    }
                  }
                  expect(b.toString(), text, reason: ctx);
                }
              }
            }
          }
        }
      },
    );
  });

  group('formatting and block types', () {
    testWidgets(
      'prayer markdown: bold/italic kept, markers never shown, text copied clean',
      (t) async {
        final (_, md) = pickPrayer('Малітва да св. Юзафа');
        await t.pumpWidget(app(reading(md, kind: FinalKind.markdown), 390));
        final ro = hyphRenders(t).single;
        expect(ro.plainText.contains('**'), isFalse);
        expect(ro.plainText.contains('_'), isFalse);
        final stripped = md
            .replaceAll('\r', '')
            .split(RegExp(r'\n[ \t]*\n+'))
            .map(
              (p) => p
                  .trim()
                  .replaceFirst(RegExp(r'^#+\s+'), '')
                  .replaceAll('**', ''),
            )
            .where((p) => p.isNotEmpty)
            .join('\n');
        expect(ro.plainText.replaceAll('_', ''), stripped.replaceAll('_', ''));
        expect(ro.lines.isNotEmpty, isTrue);
      },
    );

    testWidgets(
      'mixed HTML: prose → hyphenation renderer; rubrics, headings and psalmody stay stock',
      (t) async {
        final html = pickMixedHtml();
        await t.pumpWidget(app(reading(html, kind: FinalKind.html), 390));
        final prose = hyphRenders(t);
        expect(
          prose,
          isNotEmpty,
          reason: 'the long prose paragraph is hyphenated',
        );
        expect(
          find.byType(Html),
          findsWidgets,
          reason: 'rubric/verse blocks use the existing renderer',
        );
        for (final ro in prose) {
          // no psalmody marker or rubric text leaked into the prose renderer
          expect(ro.plainText.contains('*'), isFalse);
          expect(ro.plainText.contains('ПЕРШАЕ ЧЫТАННЕ'), isFalse);
          expect(ro.plainText.contains('­'), isFalse);
        }
        // special characters in prose survive (nbsp / quotes / apostrophes decoded)
        final all = prose.map((r) => r.plainText).join();
        expect(
          all.contains('&nbsp;') ||
              all.contains('&laquo;') ||
              all.contains('&ndash;'),
          isFalse,
        );
      },
    );

    testWidgets(
      'psalm is not changed: no hyphenation renderer, pixels independent of saved/choice',
      (t) async {
        final psalm = pickPsalmHtml();
        Future<List<int>> shot(TextAlign saved, double w) async {
          final key = GlobalKey();
          await t.pumpWidget(
            app(
              RepaintBoundary(
                key: key,
                child: reading(psalm, kind: FinalKind.psalmHtml, saved: saved),
              ),
              w,
            ),
          );
          await t.pump();
          expect(hyphRenders(t), isEmpty);
          late ByteData bd;
          await t.runAsync(() async {
            final img =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            bd = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          });
          return bd.buffer.asUint8List();
        }

        expect(
          await shot(TextAlign.justify, 390),
          await shot(TextAlign.left, 390),
        );
        expect(
          psalm.contains('*<br'),
          isTrue,
          reason: 'cadence marks and verse breaks are in the source',
        );
      },
    );

    test('block classification: prose vs verse vs rubric', () {
      final doc = normalizeLegacyHtml(
        '<p><span style="color: #ff0000;">ПЕРШАЕ ЧЫТАННЕ</span><br />Кніга</p>'
        '<p style="text-align: center;"><em><span style="color: #ff0000;">Назва</span></em></p>'
        '<p>Божа, мой Божа, Цябе шукаю, *<br />Цябе прагне душа мая.</p>'
        '<p>Умілаваныя, <em>старэйшыя</em> жанчыны павінны паводзіць сябе годна.</p>',
      );
      final kinds = [
        for (final p in parseFragmentElements(doc)) classifyBlock(p),
      ];
      expect(kinds, [
        BlockKind.verse,
        BlockKind.rubric,
        BlockKind.verse,
        BlockKind.prose,
      ]);
    });
  });
}
