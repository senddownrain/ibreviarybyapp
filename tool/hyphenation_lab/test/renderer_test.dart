import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyphenation_lab/be_hyphenator.dart';
import 'package:hyphenation_lab/fixtures.dart';
import 'package:hyphenation_lab/justified_hyphen_text.dart';
import 'package:hyphenation_lab/lab_core.dart';

import 'support.dart';

late BelarusianHyphenator h;

RenderHyphenatedJustifiedText rendered(WidgetTester t) {
  late RenderHyphenatedJustifiedText out;
  void v(Element e) {
    final ro = e.renderObject;
    if (ro is RenderHyphenatedJustifiedText) {
      out = ro;
      return;
    }
    e.visitChildren(v);
  }

  t.binding.rootElement!.visitChildren(v);
  return out;
}

Future<RenderHyphenatedJustifiedText> pump(
  WidgetTester t, {
  required TextSpan span,
  required double width,
}) async {
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: HyphenatedJustifiedText(text: span, hyphenator: h),
        ),
      ),
    ),
  );
  return rendered(t);
}

/// Reconstructs the paragraph text from laid-out lines: a hyphen line joins
/// to the next one without a space (the painted '-' is not text).
String rebuild(List<HyphLine> lines) {
  final b = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    b.write(lines[i].text);
    if (i == lines.length - 1) break;
    if (!lines[i].endsWithHyphen && !lines[i].text.endsWith('-')) {
      b.write(lines[i].isLast ? '\n' : ' ');
    }
  }
  return b.toString();
}

void main() {
  setUpAll(() async {
    await loadLabFonts();
    h = BelarusianHyphenator.fromTex(
      File('assets/patterns/hyph-be.tex').readAsStringSync(),
    );
  });

  testWidgets('B2: source text is never modified (copy/semantics are clean)', (
    t,
  ) async {
    final span = buildPlainSpan(
      bodyStyle('Literata', 1.8, LabPalette.light),
      LabPalette.light,
    );
    final ro = await pump(t, span: span, width: 288);
    final source = span.toPlainText(includeSemanticsLabels: false);
    expect(ro.plainText, source);
    expect(ro.plainText.contains('­'), isFalse);
    expect(ro.plainText.contains('-\n'), isFalse);
    expect(ro.plainText.contains('​'), isFalse);
    final sem = t.getSemantics(find.byType(HyphenatedJustifiedText));
    expect(sem.label, source);
  });

  testWidgets('B2: lines reassemble to the original text, never overflow', (
    t,
  ) async {
    final fonts = readerFonts;
    for (final f in fonts) {
      for (final scale in [1.0, 1.5, 1.8]) {
        for (final w in [288.0, 328.0, 358.0, 398.0]) {
          final span = buildPlainSpan(
            bodyStyle(f, scale, LabPalette.light),
            LabPalette.light,
          );
          final ro = await pump(t, span: span, width: w);
          final source = span.toPlainText(includeSemanticsLabels: false);
          final ctx = '$f ${scale}x w=$w';
          expect(
            rebuild(ro.lines),
            source.replaceAll(RegExp(r'\n+'), '\n'),
            reason: ctx,
          );
          for (final l in ro.lines) {
            expect(
              l.naturalWidth,
              lessThanOrEqualTo(w + 0.5),
              reason: '$ctx overflow in "${l.text}"',
            );
          }
          expect(ro.size.width, w);
        }
      }
    }
  });

  testWidgets(
    'B2: break rules — no lone letters, no split refs/numbers, no hyphen runs > 3',
    (t) async {
      for (final w in [288.0, 328.0, 358.0, 398.0]) {
        final span = buildPlainSpan(
          bodyStyle('Literata', 1.8, LabPalette.light),
          LabPalette.light,
        );
        final ro = await pump(t, span: span, width: w);
        final lines = ro.lines;
        var run = 0;
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i];
          run = l.endsWithHyphen ? run + 1 : 0;
          expect(
            run,
            lessThanOrEqualTo(3),
            reason: 'w=$w more than 3 hyphens in a row',
          );
          if (l.endsWithHyphen) {
            final tail = l.text.split(' ').last;
            expect(
              RegExp(r'[0-9]').hasMatch(tail),
              isFalse,
              reason: 'hyphen inside number/ref "$tail"',
            );
            expect(
              tail.replaceAll(RegExp("['’]"), '').length,
              greaterThanOrEqualTo(2),
              reason: 'lone letter before hyphen "$tail"',
            );
            final head = lines[i + 1].text.split(' ').first;
            expect(
              head.length,
              greaterThanOrEqualTo(3),
              reason: 'short tail "$head" starts next line',
            );
          }
        }
      }
    },
  );

  testWidgets(
    'B2: stable under width/theme/font changes (no exceptions, same text)',
    (t) async {
      for (var w = 240.0; w <= 480; w += 7) {
        for (final p in [LabPalette.light, LabPalette.darkTheme]) {
          final span = buildPlainSpan(
            bodyStyle('Kurale', 1.8, p),
            p,
            highlight: true,
          );
          final ro = await pump(t, span: span, width: w);
          expect(ro.plainText, span.toPlainText(includeSemanticsLabels: false));
          expect(ro.size.height, greaterThan(0));
        }
      }
    },
  );

  testWidgets(
    'B2: HTML paragraph stays ONE span tree (styles survive, nbsp glues)',
    (t) async {
      final p = LabPalette.light;
      final paras = htmlToParagraphSpans(
        htmlFixture,
        bodyStyle('Literata', 1.5, p),
        p,
      );
      expect(paras.length, 2);
      final ro = await pump(t, span: paras[0], width: 328);
      final text = ro.plainText;
      expect(text.contains('Тыт 2, 3–5'), isTrue, reason: 'nbsp preserved');
      // a line may never separate "Мц" from "5," (nbsp-glued)
      for (final l in ro.lines) {
        expect(l.text.endsWith('Мц'), isFalse);
      }
      // the em/strong/rubric chunks exist in one paragraph tree
      final styles = <TextStyle?>[];
      void walk(InlineSpan s) {
        if (s is TextSpan) {
          styles.add(s.style);
          s.children?.forEach(walk);
        }
      }

      walk(paras[0]);
      expect(styles.any((s) => s?.fontStyle == FontStyle.italic), isTrue);
      expect(styles.any((s) => s?.fontWeight == FontWeight.w700), isTrue);
    },
  );

  testWidgets('B2: sentence recognizers still receive taps', (t) async {
    var tapped = 0;
    final p = LabPalette.light;
    final span = TextSpan(
      style: bodyStyle('Literata', 1.0, p),
      children: [
        TextSpan(
          text: 'Першае сказанне. ',
          recognizer: (TapGestureRecognizer()..onTap = () => tapped = 1),
        ),
        TextSpan(
          text: 'Другое сказанне, дабраслаўлёны.',
          recognizer: (TapGestureRecognizer()..onTap = () => tapped = 2),
        ),
      ],
    );
    await pump(t, span: span, width: 300);
    await t.tapAt(const Offset(10, 8));
    expect(tapped, 1);
  });

  // -------------------------------------------------------------------------
  // The decisive U+00AD facts for THIS Flutter (B1 control).
  // -------------------------------------------------------------------------
  testWidgets(
    'B1 control: soft hyphen breaks lines but paints NO hyphen; text is polluted',
    (t) async {
      final root = Platform.environment['FLUTTER_ROOT'];
      final version = root == null
          ? '?'
          : File('$root/bin/internal/engine.version').existsSync()
          ? File('$root/bin/internal/engine.version').readAsStringSync().trim()
          : '?';
      // ignore: avoid_print
      print('FLUTTER under test: root=$root $version');
      const style = TextStyle(
        fontFamily: 'Literata',
        fontSize: 28,
        color: Colors.black,
      );
      const word = 'Дабраслаў­ленне';
      final fit = TextPainter(
        text: const TextSpan(text: 'Дабраслаў', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final width = fit.width + 4; // only the first part fits
      final tp = TextPainter(
        text: const TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      expect(
        tp.computeLineMetrics().length,
        2,
        reason: 'engine DOES break at U+00AD',
      );

      // Paint the first line and look for ink beyond the prefix (a hyphen).
      final key = GlobalKey();
      t.view.physicalSize = const Size(400, 200);
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: Colors.white,
                width: width,
                height: 100,
                child: const Text(word, style: style),
              ),
            ),
          ),
        ),
      );
      late int inkRight;
      await t.runAsync(() async {
        final img =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bd = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        inkRight = 0;
        for (var y = 0; y < 45; y++) {
          for (var x = 0; x < img.width; x++) {
            if (bd.getUint8((y * img.width + x) * 4) < 128)
              inkRight = x > inkRight ? x : inkRight;
          }
        }
      });
      final dash = TextPainter(
        text: const TextSpan(text: '-', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      // With a drawn hyphen the ink would reach ~ fit.width + dash.width.
      expect(
        inkRight,
        lessThan(fit.width + dash.width * 0.5),
        reason: 'no hyphen glyph is drawn at the soft break',
      );
      // And the soft hyphen stays in the string (copy/selection pollution).
      expect(word.contains('­'), isTrue);
    },
  );
}
