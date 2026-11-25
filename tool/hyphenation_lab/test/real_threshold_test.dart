import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyphenation_lab/lab_core.dart';

import 'real_readings.dart';
import 'support.dart';

/// Measures how "loose" stock justified text is on REAL readings as a function
/// of characters per line, to choose the adaptive-alignment threshold.
void main() {
  setUpAll(loadLabFonts);

  test(
    'real readings: justify looseness vs characters per line',
    () {
      final texts = sampleReadings();
      expect(texts.length, greaterThan(100));
      final rows = <Map<String, Object?>>[];
      for (final f in readerFonts) {
        for (final scale in [0.7, 0.85, 1.0, 1.25, 1.5, 1.8]) {
          for (final width in [288.0, 328.0, 358.0, 398.0, 520.0, 680.0]) {
            final style = bodyStyle(f, scale, LabPalette.light);
            final cpl = width / averageAdvance(style);
            for (final r in texts) {
              final span = TextSpan(style: style, text: proseOf(r.text));
              final m = measureStock(span, width, justified: true, base: style);
              if (m.body.isEmpty) continue;
              rows.add({
                'id': r.id,
                'field': r.field,
                'font': f,
                'scale': scale,
                'width': width,
                'cpl': double.parse(cpl.toStringAsFixed(1)),
                'lines': m.lineCount,
                'badShare': double.parse(m.badShare.toStringAsFixed(3)),
                'looseShare': double.parse(m.looseShare.toStringAsFixed(3)),
                'maxStretch': double.parse(m.maxStretch.toStringAsFixed(2)),
              });
            }
          }
        }
      }
      File('out/real_threshold.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(rows));
      expect(rows, isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
