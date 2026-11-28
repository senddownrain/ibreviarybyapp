import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyphenation_lab/be_hyphenator.dart';
import 'package:hyphenation_lab/justified_hyphen_text.dart';
import 'package:hyphenation_lab/lab_core.dart';
import 'package:hyphenation_lab/lab_scene.dart';

import 'real_readings.dart';
import 'support.dart';

/// Stage 2: the same REAL readings (from assets/content, read-only) in
/// A (today) | AD (adaptive, the safe app change) | B2 | D.
const cols = [Mode.a, Mode.ad, Mode.b2, Mode.d];

late BelarusianHyphenator hyph;
final rows = <Map<String, Object?>>[];

LabPalette pal(bool dark) => dark ? LabPalette.darkTheme : LabPalette.light;

Widget sheet({
  required String? plain,
  required String? html,
  required String title,
  required String family,
  required double scale,
  required double width,
  required bool dark,
}) {
  Widget col(Mode m) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: const Color(0xFF444444),
          padding: const EdgeInsets.all(6),
          child: Text(
            '${m.tag} · ${m.label}',
            style: const TextStyle(
              fontFamily: 'Literata',
              fontSize: 12,
              color: Color(0xFFFFFFFF),
            ),
          ),
        ),
        LabReading(
          mode: m,
          scenario: html != null ? Scenario.html : Scenario.plain,
          family: family,
          scale: scale,
          palette: pal(dark),
          hyphenator: hyph,
          plainText: plain,
          htmlText: html,
          title: title,
        ),
      ],
    ),
  );
  return Container(
    color: const Color(0xFF888888),
    padding: const EdgeInsets.all(6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in cols) ...[col(m), const SizedBox(width: 6)],
      ],
    ),
  );
}

LabMetrics? metricsOf(WidgetTester t, Mode m, double width, TextStyle base) {
  final stats = <LineStat>[];
  var innerW = width - 2 * gutter;
  var spaceW = 1.0;
  var justified = m != Mode.c && m != Mode.d;
  final seen = <RenderObject>{};
  void deep(Element e) {
    final ro = e.renderObject;
    if (ro is RenderHyphenatedJustifiedText) {
      for (final l in ro.lines) {
        spaceW = l.spaceWidth;
        stats.add(
          LineStat(
            l.text,
            l.spaces == 0
                ? l.naturalWidth
                : l.width - l.stretch * l.spaces * l.spaceWidth,
            l.spaces,
            l.isLast,
            l.endsWithHyphen,
          ),
        );
      }
      return;
    }
    if (ro is RenderParagraph &&
        RegExp(r'[А-Яа-я]').hasMatch(ro.text.toPlainText())) {
      if (!seen.add(ro)) return;
      final r = measureRender(
        ro,
        justified: ro.textAlign == TextAlign.justify,
        base: base,
      );
      stats.addAll(r.lines);
      spaceW = r.spaceWidth;
      innerW = ro.size.width;
      justified = ro.textAlign == TextAlign.justify;
      return;
    }
    e.visitChildren(deep);
  }

  t.binding.rootElement!.visitChildren(deep);
  if (stats.isEmpty) return null;
  return LabMetrics(
    width: innerW,
    spaceWidth: spaceW,
    lines: stats,
    justified: m == Mode.b2 ? true : (m == Mode.d ? false : justified),
  );
}

void main() {
  setUpAll(() async {
    await loadLabFonts();
    hyph = BelarusianHyphenator.fromTex(
      File('assets/patterns/hyph-be.tex').readAsStringSync(),
    );
  });
  tearDownAll(() {
    File('out/real_modes.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(rows));
  });

  final all = loadRealReadings();
  RealReading pick(String id, String field) =>
      all.firstWhere((r) => r.id == id && r.field == field);
  final epistle = proseOf(pick('ordinary-w25-d1--B', 'reading2').text);
  final epistle2 = proseOf(pick('easter-w4-d1--A', 'reading2').text);
  final htmlReal = all.firstWhere((r) => r.text.contains('<p')).text;

  Future<void> sheetPng(
    WidgetTester t,
    String id, {
    String? plain,
    String? html,
    required String title,
    required String family,
    required double scale,
    required double width,
    bool dark = false,
  }) async {
    await savePng(
      t,
      sheet(
        plain: plain,
        html: html,
        title: title,
        family: family,
        scale: scale,
        width: width,
        dark: dark,
      ),
      'out/real/$id.png',
      width: width * cols.length + 12 * cols.length + 12,
      pixelRatio: 1.5,
    );
  }

  // --- PNG sheets ----------------------------------------------------------
  for (final w in [320.0, 360.0, 390.0, 430.0]) {
    for (final s in [1.0, 1.5, 1.8]) {
      final id = 'epistle_Literata_${(s * 100).round()}_${w.round()}_light';
      testWidgets(
        'sheet $id',
        (t) => sheetPng(
          t,
          id,
          plain: epistle,
          title: 'ordinary-w25-d1--B · reading2',
          family: 'Literata',
          scale: s,
          width: w,
        ),
      );
    }
  }
  for (final f in ['SourceSerif4', 'OldStandardTT', 'Kurale']) {
    final id = 'epistle_${f}_150_360_light';
    testWidgets(
      'sheet $id',
      (t) => sheetPng(
        t,
        id,
        plain: epistle2,
        title: 'easter-w4-d1--A · reading2',
        family: f,
        scale: 1.5,
        width: 360,
      ),
    );
    final id2 = 'epistle_${f}_180_320_light';
    testWidgets(
      'sheet $id2',
      (t) => sheetPng(
        t,
        id2,
        plain: epistle2,
        title: 'easter-w4-d1--A · reading2',
        family: f,
        scale: 1.8,
        width: 320,
      ),
    );
  }
  testWidgets(
    'sheet dark Literata',
    (t) => sheetPng(
      t,
      'epistle_Literata_180_320_dark',
      plain: epistle,
      title: 'ordinary-w25-d1--B · reading2',
      family: 'Literata',
      scale: 1.8,
      width: 320,
      dark: true,
    ),
  );
  testWidgets(
    'sheet dark SourceSerif4',
    (t) => sheetPng(
      t,
      'epistle_SourceSerif4_150_390_dark',
      plain: epistle2,
      title: 'easter-w4-d1--A · reading2',
      family: 'SourceSerif4',
      scale: 1.5,
      width: 390,
      dark: true,
    ),
  );
  testWidgets(
    'sheet html real',
    (t) => sheetPng(
      t,
      'html_real_Literata_150_360_light',
      html: htmlReal,
      title: 'real HTML reading (assets/content)',
      family: 'Literata',
      scale: 1.5,
      width: 360,
    ),
  );

  // --- metrics over a sample of real readings (no PNG) ---------------------
  final sample = sampleReadings(step: 40);
  for (final f in readerFonts) {
    for (final w in [320.0, 360.0, 390.0, 430.0]) {
      for (final s in [1.0, 1.5, 1.8]) {
        testWidgets('metrics ${f}_${(s * 100).round()}_${w.round()}', (
          t,
        ) async {
          t.view.physicalSize = Size(w, 60000);
          t.view.devicePixelRatio = 1;
          final base = bodyStyle(f, s, LabPalette.light);
          final agg = {for (final m in cols) m: <LineStat>[]};
          final shares = {for (final m in cols) m: 0};
          for (final r in sample) {
            for (final m in cols) {
              await t.pumpWidget(
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: w,
                      child: LabReading(
                        mode: m,
                        scenario: Scenario.plain,
                        family: f,
                        scale: s,
                        palette: LabPalette.light,
                        hyphenator: hyph,
                        plainText: proseOf(r.text),
                      ),
                    ),
                  ),
                ),
              );
              final x = metricsOf(t, m, w, base);
              if (x == null) continue;
              // A line is judged by the alignment actually in effect.
              shares[m] = shares[m]! + x.bad;
              agg[m]!.addAll(x.body);
              rows.add({
                'font': f,
                'scale': s,
                'width': w,
                'mode': m.tag,
                'id': r.id,
                'field': r.field,
                'lines': x.body.length,
                'bad': x.bad,
                'hyph': x.hyphenLines,
                'justified': x.justified,
              });
            }
          }
        });
      }
    }
  }
}
