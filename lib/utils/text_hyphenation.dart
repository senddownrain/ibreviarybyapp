import 'package:flutter/material.dart';
import 'package:hyphenatorx/hyphenatorx.dart';
import 'package:hyphenatorx/languages/language_ru.dart';

const softHyphen = '\u00AD';

final Hyphenator _readerHyphenator = Hyphenator(
  Language_ru(),
  symbol: softHyphen,
);

/// Adds optional line-break points using the Russian TeX patterns.
///
/// The soft hyphen is invisible unless Flutter wraps the word at that point.
/// Source content is never changed; this function is used only for rendering.
String hyphenateReaderText(String text) {
  if (text.isEmpty || text.contains(softHyphen)) return text;
  return _readerHyphenator.hyphenateText(text);
}

/// Hyphenates visible text while leaving HTML tags and entities intact.
String hyphenateReaderHtml(String html) {
  if (html.isEmpty) return html;
  final protected = RegExp(
    r'<[^>]*>|&(?:#[0-9]+|#x[0-9a-f]+|[a-z][a-z0-9]+);',
    caseSensitive: false,
  );
  final result = StringBuffer();
  var cursor = 0;
  for (final match in protected.allMatches(html)) {
    result.write(hyphenateReaderText(html.substring(cursor, match.start)));
    result.write(match.group(0));
    cursor = match.end;
  }
  result.write(hyphenateReaderText(html.substring(cursor)));
  return result.toString();
}

/// Measures the available width and inserts visible hyphens plus hard line
/// breaks where Flutter would otherwise move the complete word.
String wrapReaderText(
  String text, {
  required TextStyle style,
  required double maxWidth,
  TextDirection textDirection = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  if (text.isEmpty || !maxWidth.isFinite || maxWidth <= 0) return text;
  final fontSize = style.fontSize ?? 14;
  final measuredStyle = style.copyWith(fontSize: textScaler.scale(fontSize));
  final source = text.replaceAll(softHyphen, '');
  return source
      .split('\n')
      .map((line) {
        final wrapped = _readerHyphenator
            .wrap(
              Text(line, textDirection: textDirection),
              measuredStyle,
              maxWidth,
            )
            .textStr;
        // Let Flutter keep handling ordinary word wrapping. Retain only the hard
        // breaks created after a dictionary-approved visible hyphen.
        return wrapped.replaceAllMapped(RegExp(r'(?<!-)\n'), (_) => ' ');
      })
      .join('\n');
}

/// Wraps visible HTML text fragments while preserving tags and entities.
String wrapReaderHtml(
  String html, {
  required TextStyle style,
  required double maxWidth,
  TextDirection textDirection = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  if (html.isEmpty || !maxWidth.isFinite || maxWidth <= 0) return html;
  final protected = RegExp(
    r'<[^>]*>|&(?:#[0-9]+|#x[0-9a-f]+|[a-z][a-z0-9]+);',
    caseSensitive: false,
  );
  final result = StringBuffer();
  var cursor = 0;
  for (final match in protected.allMatches(html)) {
    result.write(
      _wrapHtmlTextFragment(
        html.substring(cursor, match.start),
        style: style,
        maxWidth: maxWidth,
        textDirection: textDirection,
        textScaler: textScaler,
      ),
    );
    result.write(match.group(0));
    cursor = match.end;
  }
  result.write(
    _wrapHtmlTextFragment(
      html.substring(cursor),
      style: style,
      maxWidth: maxWidth,
      textDirection: textDirection,
      textScaler: textScaler,
    ),
  );
  return result.toString();
}

String _wrapHtmlTextFragment(
  String text, {
  required TextStyle style,
  required double maxWidth,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) {
  if (text.trim().isEmpty) return text;
  final leading = RegExp(r'^\s*').firstMatch(text)!.group(0)!;
  final trailing = RegExp(r'\s*$').firstMatch(text)!.group(0)!;
  final core = text.substring(leading.length, text.length - trailing.length);
  return '$leading${wrapReaderText(core, style: style, maxWidth: maxWidth, textDirection: textDirection, textScaler: textScaler)}$trailing';
}
