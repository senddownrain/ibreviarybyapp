import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/widgets/psalm_choir_html.dart';

void main() {
  for (final mode in PsalmodyMode.values) {
    testWidgets('strophe alignment: ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(240, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ValueNotifier<int?>(null);
      addTearDown(controller.dispose);
      final html = formatPsalmHtml(
        [
          for (var i = 1; i <= 6; i++)
            '<p${i == 6 ? ' class="semantic-last"' : ''}>Страфа $i † '
                'працяг $i з доўгім тэкстам для некалькіх '
                'аўтаматычных пераносаў на вузкім экране * '
                'яшчэ $i † канец $i *</p>',
        ].join(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PsalmodyScope(
            controller: controller,
            mode: mode,
            child: Scaffold(
              body: SingleChildScrollView(
                child: PsalmChoirHtml(
                  html: html,
                  style: {
                    'body': Style(fontSize: FontSize(16)),
                    'p': Style(textAlign: TextAlign.right),
                    '.psalm-strophe': Style(margin: Margins.only(bottom: 8)),
                    '.psalm-strophe-even': Style(
                      margin: Margins.only(left: 16, bottom: 8),
                    ),
                    '.psalm-strophe-even.semantic-last': Style(
                      margin: Margins.only(left: 16),
                    ),
                  },
                  textColor: Colors.black,
                  rubricColor: Colors.red,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder line(String prefix) => find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().trimLeft().startsWith(prefix),
      );
      final origin = tester.getTopLeft(line('Страфа 1')).dx;
      for (var i = 1; i <= 6; i++) {
        final first = line('Страфа $i');
        final left = tester.getTopLeft(first).dx;
        expect(
          tester.renderObject<RenderParagraph>(first).textAlign,
          TextAlign.left,
        );
        expect(
          left - origin,
          closeTo(
            mode == PsalmodyMode.alternatingStanzas && i.isEven ? 16 : 0,
            .01,
          ),
        );
        if (mode != PsalmodyMode.alternatingStanzas) {
          for (final prefix in ['† працяг $i', 'яшчэ $i', '† канец $i']) {
            final continuation = line(prefix);
            final paragraph = tester.renderObject<RenderParagraph>(
              continuation,
            );
            final continuationLeft = tester.getTopLeft(continuation).dx;
            expect(
              continuationLeft - left,
              closeTo(mode == PsalmodyMode.leftBreakIndent ? 16 * .75 : 0, .01),
            );
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: paragraph.text.toPlainText().length,
              ),
            );
            final physicalLines = <double, double>{};
            for (final box in boxes) {
              physicalLines.update(
                box.top,
                (left) => box.left < left ? box.left : left,
                ifAbsent: () => box.left,
              );
            }
            if (prefix.startsWith('працяг')) {
              expect(physicalLines.length, greaterThan(1));
            }
            for (final x in physicalLines.values) {
              // Paragraph shaping can round glyph bounds to subpixels.
              expect(x, closeTo(0, .5));
            }
          }
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tap selects a choir and a second tap clears it', (tester) async {
    final html = formatPsalmHtml(
      '<p>Першы радок *<br>другі радок</p>'
      '<p>Трэці радок *<br>чацвёрты радок</p>',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PsalmChoirHtml(
            html: html,
            style: const {},
            textColor: Colors.black,
            rubricColor: Colors.red,
          ),
        ),
      ),
    );

    String renderedHtml() => tester.widget<Html>(find.byType(Html)).data!;

    expect(renderedHtml(), isNot(contains('psalm-choir-muted')));
    final firstStrophe = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere(
          (widget) => widget.text.toPlainText().contains('Першы радок'),
        );
    expect(_colorOfCadence(firstStrophe.text as TextSpan), Colors.red);

    void tapFirstChoirLink() {
      final richText = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere(
            (widget) => widget.text.toPlainText().contains('Першы радок'),
          );
      final recognizer = _firstTapRecognizer(richText.text as TextSpan);
      expect(recognizer, isNotNull);
      recognizer!.onTap!();
    }

    tapFirstChoirLink();
    await tester.pump();
    expect(renderedHtml(), contains('psalm-choir-muted'));

    tapFirstChoirLink();
    await tester.pump();
    expect(renderedHtml(), isNot(contains('psalm-choir-muted')));
  });
}

Color? _colorOfCadence(TextSpan span, [Color? inherited]) {
  final color = span.style?.color ?? inherited;
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) {
      final found = _colorOfCadence(child, color);
      if (found != null) return found;
    }
  }
  if (span.text?.contains('*') ?? false) return color;
  return null;
}

TapGestureRecognizer? _firstTapRecognizer(TextSpan span) {
  if (span.recognizer case final TapGestureRecognizer recognizer) {
    return recognizer;
  }
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) {
      final recognizer = _firstTapRecognizer(child);
      if (recognizer != null) return recognizer;
    }
  }
  return null;
}
