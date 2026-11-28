import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyphenation_lab/be_hyphenator.dart';
import 'package:hyphenation_lab/final_scene.dart';
import 'package:hyphenation_lab/justified_hyphen_text.dart';
import 'package:hyphenation_lab/lab_core.dart';
import 'package:hyphenation_lab/lab_scene.dart';

import 'real_readings.dart';
import 'support.dart';

/// Acceptance screenshots of the MERGED mode only (real texts, app styling).
late BelarusianHyphenator hyph;

List<RenderHyphenatedJustifiedText> renders(WidgetTester t) {
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

String chosen(List<RenderHyphenatedJustifiedText> r) {
  if (r.isEmpty) return 'стандартны рэндэрар, без зменаў';
  final b2 = r.where((x) => x.justify).length;
  if (b2 == r.length) return 'B2 (па шырыні + пераносы)';
  if (b2 == 0) return 'D (па левым краі + пераносы)';
  return 'B2/D';
}

Widget framed(String caption, Widget body, double width, bool dark) =>
    Container(
      width: width,
      color: dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFF3A3A3A),
            padding: const EdgeInsets.all(6),
            child: Text(
              caption,
              style: const TextStyle(
                fontFamily: 'Literata',
                fontSize: 11,
                color: Color(0xFFFFFFFF),
                height: 1.3,
              ),
            ),
          ),
          body,
        ],
      ),
    );

void main() {
  setUpAll(() async {
    await loadLabFonts();
    hyph = BelarusianHyphenator.fromTex(
      File('assets/patterns/hyph-be.tex').readAsStringSync(),
    );
  });

  final epistle = proseOf(
    loadRealReadings()
        .firstWhere((r) => r.id == 'easter-w5-d1--A' && r.field == 'reading2')
        .text,
  );

  Future<void> shot(
    WidgetTester t,
    String file,
    String what, {
    required double width,
    required double scale,
    required Widget Function(double scale, bool dark) build,
    bool dark = false,
    bool probe = true,
  }) async {
    Widget wrap(Widget child) => MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );
    t.view.physicalSize = Size(width * 2, 6000);
    t.view.devicePixelRatio = 2;
    await t.pumpWidget(
      wrap(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: build(scale, dark)),
        ),
      ),
    );
    final used = chosen(renders(t));
    final base = bodyStyle(
      'Literata',
      scale,
      dark ? LabPalette.darkTheme : LabPalette.light,
    );
    final cpl = (width - 2 * gutter) / averageAdvance(base);
    final caption =
        '$what · ширыня $width dp · шрыфт ${(scale * 100).round()} % · ${cpl.toStringAsFixed(1)} знакаў/радок (парог 36)\n'
        'захавана: па шырыні → ужыта: $used';
    await savePng(
      t,
      framed(caption, build(scale, dark), width, dark),
      'out/final/$file',
      width: width,
      height: 6000,
      pixelRatio: 2,
    );
  }

  FinalReading fr(
    String text,
    FinalKind kind,
    double scale,
    bool dark, {
    String? title,
  }) => FinalReading(
    kind: kind,
    text: text,
    family: 'Literata',
    scale: scale,
    palette: dark ? LabPalette.darkTheme : LabPalette.light,
    hyphenator: hyph,
    title: title,
  );

  testWidgets(
    '1 reading 360dp 100%',
    (t) => shot(
      t,
      '1_reading_360dp_100pct_B2.png',
      'Чытанне Імсы (easter-w5-d1--A)',
      width: 360,
      scale: 1.0,
      build: (s, d) => fr(epistle, FinalKind.plain, s, d),
    ),
  );
  testWidgets(
    '2 reading 360dp 180%',
    (t) => shot(
      t,
      '2_reading_360dp_180pct_D.png',
      'Тое ж чытанне',
      width: 360,
      scale: 1.8,
      build: (s, d) => fr(epistle, FinalKind.plain, s, d),
    ),
  );
  testWidgets(
    '2b reference AD without hyphens',
    (t) => shot(
      t,
      '2b_reference_AD_360dp_180pct_no_hyphens.png',
      'ДАВЕДКА: цяперашні AD (#149), без пераносаў',
      width: 360,
      scale: 1.8,
      build: (s, d) => LabReading(
        mode: Mode.ad,
        scenario: Scenario.plain,
        family: 'Literata',
        scale: s,
        palette: LabPalette.light,
        hyphenator: hyph,
        plainText: epistle,
        title: '',
      ),
    ),
  );
  final prayer = pickPrayer('Малітва да Маці Божай Балеснай');
  testWidgets(
    '3 prayer 390dp 100%',
    (t) => shot(
      t,
      '3_prayer_390dp_100pct_B2.png',
      'Малітвы (${prayer.$1})',
      width: 390,
      scale: 1.0,
      build: (s, d) =>
          fr(prayer.$2, FinalKind.markdown, s, d, title: prayer.$1),
    ),
  );
  final mixed = pickMixedHtml();
  testWidgets(
    '4 formatted html 390dp 100%',
    (t) => shot(
      t,
      '4_html_formatted_390dp_100pct.png',
      'Чытанне з рубрыкамі і выдзяленнем (HTML)',
      width: 390,
      scale: 1.0,
      build: (s, d) => fr(mixed, FinalKind.html, s, d),
    ),
  );
  final psalm = pickPsalmHtml();
  testWidgets(
    '5 psalm unchanged 390dp 100%',
    (t) => shot(
      t,
      '5_psalm_unchanged_390dp_100pct.png',
      'КАНТРОЛЬ: псальм (HTML)',
      width: 390,
      scale: 1.0,
      build: (s, d) => fr(psalm, FinalKind.psalmHtml, s, d),
    ),
  );
  testWidgets(
    '6 dark 390dp 100%',
    (t) => shot(
      t,
      '6_reading_390dp_100pct_dark_B2.png',
      'Чытанне, цёмная тэма',
      width: 390,
      scale: 1.0,
      dark: true,
      build: (s, d) => fr(epistle, FinalKind.plain, s, d),
    ),
  );
}
