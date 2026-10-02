import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/widgets/psalm_choir_html.dart';

void main() {
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
