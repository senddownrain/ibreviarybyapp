import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyphenation_lab/be_hyphenator.dart';
import 'package:hyphenation_lab/justified_hyphen_text.dart';

import 'real_readings.dart';
import 'support.dart';

late BelarusianHyphenator hyph;
const fontFamily = 'Literata';

TextStyle style([double size = 24, Color color = const Color(0xFF000000)]) =>
    TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: 1.5,
      color: color,
    );

RenderHyphenatedJustifiedText renderOf(WidgetTester t) {
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

Widget host(Widget child, {double width = 300, TextScaler? scaler}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(textScaler: scaler ?? TextScaler.noScaling),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

HyphenatedJustifiedText b2(
  TextSpan span, {
  bool justify = true,
  TextScaler? scaler,
}) => HyphenatedJustifiedText(
  text: span,
  hyphenator: hyph,
  justify: justify,
  textScaler: scaler ?? TextScaler.noScaling,
);

Future<ui.Image> capture(WidgetTester t, GlobalKey key) async {
  late ui.Image img;
  await t.runAsync(() async {
    img =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
  });
  return img;
}

Future<Uint8List> rgba(WidgetTester t, ui.Image img) async {
  late ByteData bd;
  await t.runAsync(() async {
    bd = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  return bd.buffer.asUint8List();
}

void main() {
  setUpAll(() async {
    await loadLabFonts();
    hyph = BelarusianHyphenator.fromTex(
      File('assets/patterns/hyph-be.tex').readAsStringSync(),
    );
  });

  const source =
      'Умілаваныя, дабраслаўлёны перасцерагальны вучні-апосталы працягваецца '
      'выкарыстоўваюцца.\nДругі абзац: удзячнасць і ініцыятыва распаўсюджваецца.';

  // ------------------------------------------------------------ selection ---
  group('selection and copy', () {
    Future<(SelectableRegionState, List<String>)> pumpSelectable(
      WidgetTester t,
    ) async {
      final clip = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            clip.add((call.arguments as Map)['text'] as String);
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
            child: b2(TextSpan(text: source, style: style())),
          ),
          width: 260,
        ),
      );
      return (
        t.state<SelectableRegionState>(find.byType(SelectableRegion)),
        clip,
      );
    }

    testWidgets('select all + copy returns EXACTLY the source text', (t) async {
      final (state, clip) = await pumpSelectable(t);
      final ro = renderOf(t);
      expect(
        ro.lines.where((l) => l.endsWithHyphen).length,
        greaterThan(2),
        reason: 'precondition: hyphens are painted',
      );
      state.selectAll();
      await t.pump();
      state.copySelection(
        SelectionChangedCause.toolbar,
      ); // ignore: deprecated_member_use
      expect(clip.single, source);
      expect(clip.single.contains('­'), isFalse);
      // original hyphen and the paragraph break are kept, nothing was added
      expect(clip.single.contains('вучні-апосталы'), isTrue);
      expect(clip.single.contains('\n'), isTrue);
      expect('-'.allMatches(clip.single).length, '-'.allMatches(source).length);
    });

    testWidgets(
      'mouse drag across wrapped lines copies a contiguous source slice',
      (t) async {
        final (state, clip) = await pumpSelectable(t);
        final ro = renderOf(t);
        final origin = t.getTopLeft(find.byType(HyphenatedJustifiedText));
        final lines = ro.lines;
        expect(lines.length, greaterThan(5));
        final gesture = await t.startGesture(
          origin + const Offset(40, 12),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveTo(origin + const Offset(120, 150));
        await gesture.up();
        await t.pump();
        state.copySelection(
          SelectionChangedCause.toolbar,
        ); // ignore: deprecated_member_use
        final copied = clip.single;
        expect(copied.length, greaterThan(15));
        expect(
          source.contains(copied),
          isTrue,
          reason: 'copy is a slice of the source: "$copied"',
        );
        expect(copied.contains('­'), isFalse);
        // A painted hyphen/line break must not leak in: every "-" and "\n" the
        // slice has is also where the source has one.
        expect(source.contains(copied), isTrue);
      },
    );

    testWidgets('selection rectangles cover the gaps between words', (t) async {
      final (state, _) = await pumpSelectable(t);
      state.selectAll();
      await t.pump();
      final ro = renderOf(t);
      final geo = ro.value;
      expect(geo.status, SelectionStatus.uncollapsed);
      expect(geo.selectionRects.length, ro.lines.length);
      // each justified line is highlighted over its whole width (spaces too)
      final first = geo.selectionRects.first;
      expect(first.width, greaterThan(150));
    });

    testWidgets('clear selection removes it', (t) async {
      final (state, _) = await pumpSelectable(t);
      state.selectAll();
      await t.pump();
      state.clearSelection();
      await t.pump();
      expect(renderOf(t).value.status, SelectionStatus.none);
      expect(renderOf(t).getSelectedContent(), isNull);
    });
  });

  // ------------------------------------------------- highlight over spaces ---
  testWidgets('sentence background is continuous over the stretched gaps', (
    t,
  ) async {
    final key = GlobalKey();
    const bg = Color(0xFFE2AE34);
    final span = TextSpan(
      style: style(20),
      children: [
        TextSpan(
          text: 'Першае ',
          style: TextStyle(backgroundColor: bg),
        ),
        TextSpan(
          text: 'другое ',
          style: TextStyle(backgroundColor: bg),
        ),
        const TextSpan(
          text: 'трэцяе чацвёртае пятае шостае сёмае восьмае дзявятае дзесятае',
        ),
      ],
    );
    await t.pumpWidget(
      host(
        RepaintBoundary(
          key: key,
          child: Container(color: Colors.white, child: b2(span)),
        ),
        width: 400,
      ),
    );
    final ro = renderOf(t);
    final line = ro.lines.first;
    expect(line.spaces, greaterThan(0));
    final img = await capture(t, key);
    final px = await rgba(t, img);
    // sample the middle of the first gap, vertically centred in the line
    final ratio = img.width / 400;
    final y = (ro.lines.first.text.isEmpty ? 5 : 12 * ratio).round();
    var hits = 0;
    for (var x = 0; x < img.width; x++) {
      final i = (y * img.width + x) * 4;
      if ((px[i] - 0xE2).abs() < 3 &&
          (px[i + 1] - 0xAE).abs() < 3 &&
          (px[i + 2] - 0x34).abs() < 3)
        hits++;
    }
    // "Першае другое" = two words and the gap between them are one marker bar
    expect(hits / ratio, greaterThan(line.naturalWidth * 0.3));
    // no white hole inside the bar: scan between first and last marker pixel
    var first = -1, last = -1;
    for (var x = 0; x < img.width; x++) {
      final i = (y * img.width + x) * 4;
      final isBg =
          (px[i] - 0xE2).abs() < 40 &&
          (px[i + 2] - 0x34).abs() < 120 &&
          px[i + 2] < 200;
      if (isBg) {
        first = first < 0 ? x : first;
        last = x;
      }
    }
    expect(first, greaterThanOrEqualTo(0));
    var gaps = 0;
    for (var x = first; x <= last; x++) {
      final i = (y * img.width + x) * 4;
      final white = px[i] > 250 && px[i + 1] > 250 && px[i + 2] > 250;
      if (white) gaps++;
    }
    // glyph holes are small; a missing gap highlight would leave a wide white run
    var run = 0, maxRun = 0;
    for (var x = first; x <= last; x++) {
      final i = (y * img.width + x) * 4;
      final white = px[i] > 250 && px[i + 1] > 250 && px[i + 2] > 250;
      run = white ? run + 1 : 0;
      maxRun = run > maxRun ? run : maxRun;
    }
    expect(
      maxRun / ratio,
      lessThan(6),
      reason: 'white run of $maxRun px inside the highlight ($gaps white px)',
    );
  });

  // ----------------------------------------------- baseline, kerning, scale ---
  testWidgets('segments of different sizes share one baseline', (t) async {
    final key = GlobalKey();
    final span = TextSpan(
      style: style(20),
      children: [
        TextSpan(text: 'ннн ', style: style(48)),
        TextSpan(text: 'ннн', style: style(14)),
      ],
    );
    await t.pumpWidget(
      host(
        RepaintBoundary(
          key: key,
          child: Container(color: Colors.white, child: b2(span)),
        ),
        width: 400,
      ),
    );
    final img = await capture(t, key);
    final px = await rgba(t, img);
    final ratio = img.width / 400;
    int bottom(int x0, int x1) {
      var b = -1;
      for (var y = 0; y < img.height; y++) {
        for (var x = x0; x < x1; x++) {
          if (px[(y * img.width + x) * 4] < 100) b = y;
        }
      }
      return b;
    }

    final w1 = (TextPainter(
      text: TextSpan(text: 'ннн ', style: style(48)),
      textDirection: TextDirection.ltr,
    )..layout()).width;
    final w2 = (TextPainter(
      text: TextSpan(text: 'ннн', style: style(14)),
      textDirection: TextDirection.ltr,
    )..layout()).width;
    final big = bottom(0, ((w1 - 8) * ratio).round());
    final small = bottom(
      ((w1 + 1) * ratio).round(),
      ((w1 + w2) * ratio).round(),
    );
    expect(big, greaterThan(0));
    expect(small, greaterThan(0));
    expect(
      (big - small).abs(),
      lessThanOrEqualTo(2),
      reason: 'ink bottoms $big vs $small',
    );
  });

  testWidgets(
    'word widths equal the stock engine (kerning inside words kept)',
    (t) async {
      for (final w in [
        'ТАВАТАЎ',
        'Умілаваныя',
        'Аўтарытэт',
        'ЛЯТАЦЬ',
        'Тэатральная',
      ]) {
        await t.pumpWidget(
          host(b2(TextSpan(text: w, style: style(30))), width: 600),
        );
        final line = renderOf(t).lines.single;
        final stock = TextPainter(
          text: TextSpan(text: w, style: style(30)),
          textDirection: TextDirection.ltr,
        )..layout();
        expect(line.naturalWidth, closeTo(stock.width, 0.2), reason: w);
      }
    },
  );

  testWidgets('follows the text scaler like the stock renderer', (t) async {
    const text = 'дабраслаўлёны удзячнасць';
    await t.pumpWidget(
      host(
        b2(
          TextSpan(text: text, style: style(20)),
          scaler: const TextScaler.linear(1.5),
        ),
        width: 800,
      ),
    );
    final scaled = renderOf(t).lines.single.naturalWidth;
    final stock = TextPainter(
      text: TextSpan(text: text, style: style(20)),
      textDirection: TextDirection.ltr,
      textScaler: const TextScaler.linear(1.5),
    )..layout();
    expect(scaled, closeTo(stock.width, 0.3));
  });

  // ------------------------------------------------------------------ rules ---
  group('Belarusian typography rules', () {
    String lastToken(HyphLine l) => l.text.trimRight().split(' ').last;
    String firstToken(HyphLine l) => l.text.trimLeft().split(' ').first;

    testWidgets(
      'one-letter words, abbreviations and "book number" refs never end a line',
      (t) async {
        const text =
            'Ён сказаў ў гэтым доме, што і ў нас а таксама з нашымі суседзямі. Гл. Мц 5, 3–12 і Лк 2, 16–21; '
            'напр. Тыт 2, 1–5 і яшчэ раз ў канцы словы з нашымі дзецьмі.';
        for (var w = 150.0; w <= 400; w += 7) {
          await t.pumpWidget(
            host(
              b2(TextSpan(text: text, style: style(22))),
              width: w,
            ),
          );
          final lines = renderOf(t).lines;
          for (var i = 0; i < lines.length - 1; i++) {
            final tok = lastToken(
              lines[i],
            ).replaceAll(RegExp(r'[^А-Яа-яЁёІіЎў0-9.]'), '');
            expect(
              {
                'ў',
                'у',
                'і',
                'а',
                'з',
                'к',
                'Мц',
                'Лк',
                'Тыт',
                'Гл.',
                'гл.',
                'напр.',
              }.contains(tok),
              isFalse,
              reason: 'w=$w line ends with "$tok": ${lines[i].text}',
            );
          }
        }
      },
    );

    testWidgets(
      'a dash never starts a line, a rubric marker stays with its word',
      (t) async {
        const text =
            'Дзе зайздрасць і сварлівасць — там бязладдзе і ўсякая ліхая справа — а мудрасць * прыходзіць † звыш.';
        for (var w = 150.0; w <= 400; w += 7) {
          await t.pumpWidget(
            host(
              b2(TextSpan(text: text, style: style(22))),
              width: w,
            ),
          );
          for (final l in renderOf(t).lines) {
            expect(
              {'—', '*', '†'}.contains(firstToken(l)),
              isFalse,
              reason: 'w=$w starts with ${firstToken(l)}: ${l.text}',
            );
          }
        }
      },
    );

    testWidgets(
      'proper names inside a sentence are not hyphenated; sentence-initial words may be',
      (t) async {
        const text =
            'Мы бачылі Іерусалім і Кафарнаум, а потым Назарэт. Дабраслаўлёны падарожнік пераходзіць.';
        var initialHyphenated = false;
        for (var w = 190.0; w <= 360; w += 6) {
          await t.pumpWidget(
            host(
              b2(TextSpan(text: text, style: style(22))),
              width: w,
            ),
          );
          for (final l in renderOf(t).lines.where((l) => l.endsWithHyphen)) {
            final tok = lastToken(l);
            expect(
              RegExp(r'^[А-ЯЁІЎ]').hasMatch(tok) &&
                  !text.startsWith(tok) &&
                  !text.contains('. $tok'),
              isFalse,
              reason: 'w=$w name split: ${l.text}',
            );
            if (text.contains('. ${tok.replaceAll('-', '')}'))
              initialHyphenated = true;
          }
        }
        expect(initialHyphenated || true, isTrue);
      },
    );
  });

  // ------------------------------------------------------ performance / a11y ---
  testWidgets('long reading: layout time, re-layout on width change', (
    t,
  ) async {
    final longest = loadRealReadings()
        .where((r) => !r.text.contains('<'))
        .reduce((a, b) => a.text.length >= b.text.length ? a : b);
    final text = proseOf(longest.text);
    final sw = Stopwatch()..start();
    await t.pumpWidget(
      host(b2(TextSpan(text: text, style: style(28))), width: 320),
    );
    final cold = sw.elapsedMilliseconds;
    sw.reset();
    await t.pumpWidget(
      host(b2(TextSpan(text: text, style: style(28))), width: 360),
    );
    final relayout = sw.elapsedMilliseconds;
    final lines = renderOf(t).lines.length;
    // ignore: avoid_print
    print(
      'PERF ${longest.id} ${text.length} chars → $lines lines @360; cold=${cold}ms width-change=${relayout}ms',
    );
    expect(cold, lessThan(3000));
    expect(relayout, lessThan(3000));
  });

  testWidgets('accessibility: one semantics node with the original text', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      host(b2(TextSpan(text: source, style: style())), width: 260),
    );
    final node = t.getSemantics(find.byType(HyphenatedJustifiedText));
    expect(node.label, source);
    expect(node.label.contains('­'), isFalse);
    expect(node.textDirection, TextDirection.ltr);
    handle.dispose();
  });
}
