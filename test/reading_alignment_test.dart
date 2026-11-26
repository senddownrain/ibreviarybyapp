import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/utils/reading_alignment.dart';

// flutter_test draws text with the square "Ahem" face: one character is one
// em wide, so characters per line = width / fontSize, exactly.
const _style = TextStyle(fontSize: 10);

void main() {
  group('effectiveProseAlignment', () {
    test('keeps justify when the line holds enough characters', () {
      expect(
        effectiveProseAlignment(
          selected: TextAlign.justify,
          maxWidth: 360, // 36 characters
          style: _style,
        ),
        TextAlign.justify,
      );
    });

    test('falls back to left just below the threshold', () {
      expect(
        effectiveProseAlignment(
          selected: TextAlign.justify,
          maxWidth: 359, // 35.9 characters
          style: _style,
        ),
        TextAlign.left,
      );
    });

    test('an explicit left choice always stays left', () {
      for (final width in [100.0, 360.0, 2000.0]) {
        expect(
          effectiveProseAlignment(
            selected: TextAlign.left,
            maxWidth: width,
            style: _style,
          ),
          TextAlign.left,
        );
      }
    });

    test('larger type switches to left, smaller type returns to justify', () {
      TextAlign at(double size) => effectiveProseAlignment(
        selected: TextAlign.justify,
        maxWidth: 400,
        style: TextStyle(fontSize: size),
      );
      expect(at(10), TextAlign.justify); // 40 characters
      expect(at(12), TextAlign.left); // 33 characters
      expect(at(10), TextAlign.justify); // back again: no hidden state
    });

    test('follows the system text scale', () {
      TextAlign at(double scale) => effectiveProseAlignment(
        selected: TextAlign.justify,
        maxWidth: 400,
        style: _style,
        textScaler: TextScaler.linear(scale),
      );
      expect(at(1), TextAlign.justify);
      expect(at(1.5), TextAlign.left);
    });

    test('unbounded or empty width never changes the choice', () {
      for (final width in [double.infinity, 0.0, -1.0]) {
        expect(
          effectiveProseAlignment(
            selected: TextAlign.justify,
            maxWidth: width,
            style: _style,
          ),
          TextAlign.justify,
        );
      }
    });

    test('does not touch the saved setting', () {
      const saved = SettingsState();
      final shown = effectiveProseAlignment(
        selected: saved.textAlignment,
        maxWidth: 100,
        style: _style,
      );
      expect(shown, TextAlign.left);
      expect(saved.textAlignment, TextAlign.justify);
    });
  });

  group('AdaptiveProseAlignment', () {
    Future<TextAlign> pumpAt(
      WidgetTester tester, {
      required double width,
      TextAlign selected = TextAlign.justify,
      double fontSize = 10,
    }) async {
      TextAlign? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: AdaptiveProseAlignment(
                selected: selected,
                style: TextStyle(fontSize: fontSize),
                builder: (context, alignment) {
                  seen = alignment;
                  return Text('x', textAlign: alignment);
                },
              ),
            ),
          ),
        ),
      );
      return seen!;
    }

    testWidgets('reacts to the width it is given and recovers', (tester) async {
      expect(await pumpAt(tester, width: 300), TextAlign.left);
      expect(await pumpAt(tester, width: 420), TextAlign.justify);
      expect(await pumpAt(tester, width: 300), TextAlign.left);
    });

    testWidgets('explicit left is never turned into justify', (tester) async {
      expect(
        await pumpAt(tester, width: 1000, selected: TextAlign.left),
        TextAlign.left,
      );
    });
  });
}
