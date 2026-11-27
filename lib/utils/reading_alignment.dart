import 'package:flutter/widgets.dart';

/// Below this many characters per line, justified Belarusian prose gets large
/// word gaps (hyphenation is not available in the stock Flutter renderer), so
/// the paragraph is shown left-aligned instead.
///
/// The original threshold of 36 was chosen from 152 real readings of `assets/content`
/// (4 reader fonts × scales 0.7–1.8 × widths 288–680 dp, see
/// `tool/hyphenation_lab/REPORT.md`): at ≥ 36 characters per line 5 % of the
/// kept paragraphs still have > 40 % loose lines and only 4 % of the
/// paragraphs switched to left would have looked good justified.
/// With the Belarusian hyphenating renderer, trial 28 for book-like prose.
/// The new threshold is a product choice pending visual acceptance.
const double kJustifyMinCharsPerLine = 28;

const _sample =
    'Умілаваныя, цяпер мы дзеці Божыя, але яшчэ не выявілася, чым будзем. '
    'Ведаем, што калі адкрыецца, мы будзем падобныя да Яго.';

final _advanceCache = <_AdvanceKey, double>{};
bool _watchingFonts = false;

class _AdvanceKey {
  const _AdvanceKey(
    this.family,
    this.size,
    this.weight,
    this.italic,
    this.spacing,
  );
  final String? family;
  final double size;
  final FontWeight? weight;
  final bool italic;
  final double? spacing;

  @override
  bool operator ==(Object other) =>
      other is _AdvanceKey &&
      family == other.family &&
      size == other.size &&
      weight == other.weight &&
      italic == other.italic &&
      spacing == other.spacing;

  @override
  int get hashCode => Object.hash(family, size, weight, italic, spacing);
}

/// Average advance of one character of Belarusian prose in [style] after the
/// system [textScaler] (so the result follows the reader font size).
double averageCharAdvance(
  TextStyle style, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  if (!_watchingFonts) {
    // A face that loads later has different advances: measure again.
    _watchingFonts = true;
    PaintingBinding.instance.systemFonts.addListener(_advanceCache.clear);
  }
  final size = textScaler.scale(style.fontSize ?? 16);
  final key = _AdvanceKey(
    style.fontFamily,
    size,
    style.fontWeight,
    style.fontStyle == FontStyle.italic,
    style.letterSpacing,
  );
  return _advanceCache.putIfAbsent(key, () {
    final painter = TextPainter(
      text: TextSpan(
        text: _sample,
        style: style.copyWith(fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final advance = painter.width / _sample.length;
    painter.dispose();
    return advance;
  });
}

/// Characters of prose that fit one line of [maxWidth].
double charsPerLine({
  required double maxWidth,
  required TextStyle style,
  TextScaler textScaler = TextScaler.noScaling,
}) => maxWidth / averageCharAdvance(style, textScaler: textScaler);

/// The alignment actually used to draw prose. The user's saved choice
/// ([selected]) is never modified: justified text temporarily falls back to
/// left-aligned while the line is too short, and returns when the font gets
/// smaller or the column wider. An explicit left choice always stays left.
TextAlign effectiveProseAlignment({
  required TextAlign selected,
  required double maxWidth,
  required TextStyle style,
  TextScaler textScaler = TextScaler.noScaling,
  double minCharsPerLine = kJustifyMinCharsPerLine,
}) {
  if (selected != TextAlign.justify || !maxWidth.isFinite || maxWidth <= 0) {
    return selected;
  }
  final cpl = charsPerLine(
    maxWidth: maxWidth,
    style: style,
    textScaler: textScaler,
  );
  return cpl >= minCharsPerLine ? TextAlign.justify : TextAlign.left;
}

/// Supplies [effectiveProseAlignment] for the width this widget is given.
class AdaptiveProseAlignment extends StatelessWidget {
  const AdaptiveProseAlignment({
    super.key,
    required this.selected,
    required this.style,
    required this.builder,
  });

  final TextAlign selected;
  final TextStyle style;
  final Widget Function(BuildContext context, TextAlign alignment) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => builder(
      context,
      effectiveProseAlignment(
        selected: selected,
        maxWidth: constraints.maxWidth,
        style: style,
        textScaler: MediaQuery.textScalerOf(context),
      ),
    ),
  );
}
