import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyphenation_lab/be_hyphenator.dart';
import 'package:hyphenation_lab/justified_hyphen_text.dart';
import 'package:hyphenation_lab/lab_core.dart';
import 'package:hyphenation_lab/lab_scene.dart';

import 'support.dart';

late BelarusianHyphenator hyph;
final rows = <Map<String, Object?>>[];

LabPalette pal(bool dark) => dark ? LabPalette.darkTheme : LabPalette.light;

Widget sheet({
  required Scenario scenario,
  required String family,
  required double scale,
  required double width,
  required bool dark,
}) {
  final p = pal(dark);
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
              color: Colors.white,
            ),
          ),
        ),
        LabReading(
          mode: m,
          scenario: scenario,
          family: family,
          scale: scale,
          palette: p,
          hyphenator: hyph,
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
        for (final m in Mode.values) ...[col(m), const SizedBox(width: 6)],
      ],
    ),
  );
}

/// Collects per-mode metrics from the rendered tree.
Map<Mode, LabMetrics> collect(
  WidgetTester tester,
  double width,
  String family,
  double scale,
  bool dark,
) {
  final out = <Mode, LabMetrics>{};
  final base = bodyStyle(family, scale, pal(dark));
  final readings = find.byType(LabReading).evaluate().toList();
  for (var i = 0; i < readings.length; i++) {
    final w = readings[i].widget as LabReading;
    final stats = <LineStat>[];
    double? spaceW;
    var innerW = width - 2 * gutter;
    var justified = w.mode != Mode.c;
    if (w.mode == Mode.b2) {
      void visit(Element e) {
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
        } else {
          e.visitChildren(visit);
        }
        if (ro is RenderHyphenatedJustifiedText) return;
      }

      void walk(Element e) {
        visit(e);
      }

      // Visit sub-tree of this reading.
      readings[i].visitChildren(walk);
      // visit() stops at the render object; descend manually for nested ones.
      stats.clear();
      void deep(Element e) {
        final ro = e.renderObject;
        if (ro is RenderHyphenatedJustifiedText &&
            identical(e.widget.runtimeType, HyphenatedJustifiedText)) {
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
        e.visitChildren(deep);
      }

      readings[i].visitChildren(deep);
      out[w.mode] = LabMetrics(
        width: innerW,
        spaceWidth: spaceW ?? 1,
        lines: stats,
        justified: true,
      );
    } else {
      // Every RichText in this reading (plain: one; html: one per paragraph).
      final all = <LineStat>[];
      final seen = <RenderParagraph>{};
      var sw = 1.0;
      void deep(Element e) {
        final ro = e.renderObject;
        if (ro is RenderParagraph &&
            RegExp(r'[А-Яа-я]').hasMatch(ro.text.toPlainText())) {
          // flutter_html wraps text in placeholder-only paragraphs: skip those
          // and measure only the paragraphs that carry letters (once each).
          if (!seen.add(ro)) return;
          final m = measureRender(ro, justified: justified, base: base);
          all.addAll(m.lines);
          sw = m.spaceWidth;
          innerW = ro.size.width;
          return;
        }
        e.visitChildren(deep);
      }

      readings[i].visitChildren(deep);
      out[w.mode] = LabMetrics(
        width: innerW,
        spaceWidth: sw,
        lines: all,
        justified: justified,
      );
    }
  }
  return out;
}

void record(
  String id,
  Scenario sc,
  String family,
  double scale,
  double width,
  bool dark,
  Map<Mode, LabMetrics> m,
) {
  for (final e in m.entries) {
    final x = e.value;
    rows.add({
      'id': id,
      'scenario': sc.name,
      'font': family,
      'scale': scale,
      'width': width,
      'theme': dark ? 'dark' : 'light',
      'mode': e.key.tag,
      'lines': x.lineCount,
      'bad': x.bad,
      'loose': x.loose,
      'veryLoose': x.veryLoose,
      'singleWord': x.singleWord,
      'maxStretch': double.parse(x.maxStretch.toStringAsFixed(2)),
      'meanStretch': double.parse(x.meanStretch.toStringAsFixed(2)),
      'meanSlack': double.parse(x.meanSlack.toStringAsFixed(3)),
      'shortRagged': x.shortRagged,
      'hyphenLines': x.hyphenLines,
      'consecutiveHyphen': x.consecutiveHyphen,
    });
  }
}

void main() {
  setUpAll(() async {
    await loadLabFonts();
    hyph = BelarusianHyphenator.fromTex(
      File('assets/patterns/hyph-be.tex').readAsStringSync(),
    );
  });
  tearDownAll(() {
    File('out/metrics.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(rows));
  });

  Future<void> run(
    WidgetTester tester,
    String id,
    Scenario sc,
    String family,
    double scale,
    double width,
    bool dark, {
    bool png = true,
  }) async {
    final w = sheet(
      scenario: sc,
      family: family,
      scale: scale,
      width: width,
      dark: dark,
    );
    final wrapped = MediaQuery(
      data: MediaQueryData(size: Size(width * 4, 4000)),
      child: w,
    );
    if (png) {
      await savePng(
        tester,
        wrapped,
        'out/$id.png',
        width: width * 4 + 60,
        pixelRatio: 1.5,
      );
    } else {
      tester.view.physicalSize = Size(width * 4 + 60, 4000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(alignment: Alignment.topLeft, child: wrapped),
        ),
      );
      await tester.pump();
    }
    record(
      id,
      sc,
      family,
      scale,
      width,
      dark,
      collect(tester, width, family, scale, dark),
    );
  }

  // Key PNG sheets: narrow screen + large font (the user's complaint) and more.
  final png = <(Scenario, String, double, double, bool)>[
    for (final w in [320.0, 360.0, 390.0, 430.0])
      for (final s in [1.0, 1.5, 1.8])
        (Scenario.plain, 'Literata', s, w, false),
    for (final f in ['SourceSerif4', 'OldStandardTT', 'Kurale'])
      (Scenario.plain, f, 1.8, 360.0, false),
    (Scenario.plain, 'Literata', 1.8, 320.0, true),
    (Scenario.plain, 'SourceSerif4', 1.5, 390.0, true),
    (Scenario.highlight, 'Literata', 1.5, 360.0, false),
    (Scenario.highlight, 'Literata', 1.8, 320.0, true),
    (Scenario.html, 'Literata', 1.5, 360.0, false),
    (Scenario.html, 'Literata', 1.8, 320.0, false),
    (Scenario.html, 'SourceSerif4', 1.5, 390.0, true),
  ];
  for (final c in png) {
    final id =
        '${c.$1.name}_${c.$2}_${(c.$3 * 100).round()}_${c.$4.round()}_${c.$5 ? 'dark' : 'light'}';
    testWidgets(
      'sheet $id',
      (tester) => run(tester, id, c.$1, c.$2, c.$3, c.$4, c.$5),
    );
  }

  // Metrics-only sweep (no PNG): all fonts × widths × scales, plain + html.
  for (final f in readerFonts) {
    for (final w in [320.0, 360.0, 390.0, 430.0]) {
      for (final s in [1.0, 1.5, 1.8]) {
        for (final sc in [Scenario.plain, Scenario.html]) {
          final id = 'sweep_${sc.name}_${f}_${(s * 100).round()}_${w.round()}';
          testWidgets(
            id,
            (tester) => run(tester, id, sc, f, s, w, false, png: false),
          );
        }
      }
    }
  }
}
