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
