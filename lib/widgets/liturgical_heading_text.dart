import 'package:flutter/material.dart';

/// Keeps whole words in navigation headings at large accessibility sizes.
/// Reader documents retain their own typography and text scaling.
class LiturgicalHeadingText extends StatelessWidget {
  const LiturgicalHeadingText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxWidth,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) => maxWidth != null
      ? _fit(context, maxWidth!)
      : LayoutBuilder(
          builder: (context, constraints) =>
              _fit(context, constraints.maxWidth),
        );

  Widget _fit(BuildContext context, double availableWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    double measureWords(TextScaler measuredScaler) {
      var widestWord = 0.0;
      for (final word in text.split(RegExp(r'\s+'))) {
        final measurement = TextPainter(
          text: TextSpan(text: word, style: effectiveStyle),
          textScaler: measuredScaler,
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        if (measurement.width > widestWord) {
          widestWord = measurement.width;
        }
        measurement.dispose();
      }
      return widestWord;
    }

    var fittedScaler = scaler;
    if (availableWidth.isFinite &&
        availableWidth > 1 &&
        measureWords(scaler) > availableWidth) {
      final fontSize = effectiveStyle.fontSize ?? 14;
      var lower = 0.0;
      var upper = scaler.scale(fontSize) / fontSize;
      // Letter spacing is not scaled with font size; measure the fitted result.
      for (var i = 0; i < 12; i++) {
        final middle = (lower + upper) / 2;
        if (measureWords(scaler.clamp(maxScaleFactor: middle)) <=
            availableWidth - 1) {
          lower = middle;
        } else {
          upper = middle;
        }
      }
      fittedScaler = scaler.clamp(maxScaleFactor: lower);
    }
    return Text(
      text,
      style: style,
      textAlign: textAlign,
      textScaler: fittedScaler,
    );
  }
}
