/// Semantic preparation for legacy liturgical HTML.
///
/// The web application styles psalm metadata, strophes and cadence signs
/// separately. Flutter HTML needs explicit classes for the same result.
final _paragraphPattern = RegExp(
  r'<p\b([^>]*)>([\s\S]*?)</p>',
  caseSensitive: false,
);
final _breakPattern = RegExp(r'<br\s*/?>', caseSensitive: false);
final _cadencePattern = RegExp(r'(?:\*|&#0*42;|&ast;|†|&#0*8224;|&dagger;)');
final _asteriskPattern = RegExp(r'(?:\*|&#0*42;|&ast;)');

String removeBreakAfterAsterisk(String html) => html.replaceAllMapped(
  RegExp(
    r'((?:\*|&#0*42;|&ast;)(?:\s|&nbsp;)*(?:</(?:span|font|strong|b|em|i)>\s*)*)(?:<br\s*/?>\s*)+',
    caseSensitive: false,
  ),
  (match) => '${match.group(1)} ',
);

String markLiturgicalCadenceSigns(String html) {
  final out = StringBuffer();
  final tagPattern = RegExp(r'<[^>]*>');
  var cursor = 0;
  for (final tag in tagPattern.allMatches(html)) {
    out.write(_markCadenceInText(html.substring(cursor, tag.start)));
    out.write(tag.group(0));
    cursor = tag.end;
  }
  out.write(_markCadenceInText(html.substring(cursor)));
  return out.toString();
}

String _markCadenceInText(String text) => text.replaceAllMapped(
  _cadencePattern,
  (match) => '<span class="psalm-marker">${match.group(0)}</span>',
);

String formatLiturgicalHtml(String html) => markLiturgicalCadenceSigns(
  _normalizeRubricColors(_markLeadingMetadata(html)),
);

String formatPsalmHtml(String html) {
  var value = removeBreakAfterAsterisk(html);

  var stropheIndex = 0;
  value = value.replaceAllMapped(_paragraphPattern, (match) {
    final attributes = match.group(1) ?? '';
    final content = match.group(2) ?? '';
    if (!_asteriskPattern.hasMatch(content)) return match.group(0)!;

    final strophes = <String>[];
    var cursor = 0;
    var current = '';
    for (final br in _breakPattern.allMatches(content)) {
      current += content.substring(cursor, br.start);
      if (_asteriskPattern.hasMatch(current)) {
        if (current.trim().isNotEmpty) strophes.add(current);
        current = '';
      } else {
        current += br.group(0)!;
      }
      cursor = br.end;
    }
    current += content.substring(cursor);
    if (current.trim().isNotEmpty) strophes.add(current);

    return strophes.map((strophe) {
      stropheIndex += 1;
      final parity = stropheIndex.isEven ? ' psalm-strophe-even' : '';
      return '<p${_withClass(attributes, 'psalm-strophe$parity')}>$strophe</p>';
    }).join();
  });

  return markLiturgicalCadenceSigns(
    _normalizeRubricColors(_markLeadingMetadata(value)),
  );
}

String _normalizeRubricColors(String html) {
  return html.replaceAllMapped(
    RegExp(r'<(span|font)\b([^>]*)>', caseSensitive: false),
    (match) {
      final attributes = match.group(2) ?? '';
      final hasRubricColor = RegExp(
        r'''(?:color\s*:\s*(?:red|#ff0000)|color\s*=\s*["']?(?:red|#ff0000))''',
        caseSensitive: false,
      ).hasMatch(attributes);
      if (!hasRubricColor) return match.group(0)!;

      var cleaned = attributes
          .replaceAll(
            RegExp(r'color\s*:\s*(?:red|#ff0000)\s*;?', caseSensitive: false),
            '',
          )
          .replaceAll(
            RegExp(
              r'''\s+color\s*=\s*(?:["'](?:red|#ff0000)["']|(?:red|#ff0000))''',
              caseSensitive: false,
            ),
            '',
          );
      cleaned = _withClass(cleaned, 'liturgical-rubric-inline');
      return '<${match.group(1)}$cleaned>';
    },
  );
}

String _markLeadingMetadata(String html) {
  var remaining = 2;
  var canMark = true;
  return html.replaceAllMapped(_paragraphPattern, (match) {
    final attributes = match.group(1) ?? '';
    final content = match.group(2) ?? '';
    final visible = _visibleText(content);

    if (RegExp(
      r'^(?:ПЕРШАЕ|ДРУГОЕ)\s+ЧЫТАННЕ\s*$',
      caseSensitive: false,
    ).hasMatch(visible)) {
      return '<p${_withClass(attributes, 'liturgical-heading')}>$content</p>';
    }

    final centered = RegExp(
      r'text-align\s*:\s*center',
      caseSensitive: false,
    ).hasMatch(attributes);
    final emphasized = _fullyWrapped(
      content,
      RegExp(
        r'^\s*<(?:em|i|strong|b)\b[^>]*>[\s\S]*</(?:em|i|strong|b)>\s*$',
        caseSensitive: false,
      ),
    );
    final red = RegExp(
      r'''(?:color\s*:\s*(?:#ff0000|red)|color\s*=\s*["']?red)''',
      caseSensitive: false,
    ).hasMatch(content);

    if (centered || (canMark && remaining > 0 && (emphasized || red))) {
      if (remaining > 0) remaining -= 1;
      return '<p${_withClass(attributes, 'liturgical-subheading')}>$content</p>';
    }

    if (!RegExp(
      r'^(?:ПЕРШАЕ|ДРУГОЕ|КАРОТКАЕ)\s+ЧЫТАННЕ',
      caseSensitive: false,
    ).hasMatch(visible)) {
      canMark = false;
    }
    return match.group(0)!;
  });
}

bool _fullyWrapped(String content, RegExp pattern) {
  final normalized = content
      .replaceAll(_breakPattern, '')
      .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
      .trim();
  return pattern.hasMatch(normalized);
}

String _visibleText(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll(RegExp(r'&nbsp;|&#x0*20;', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _withClass(String attributes, String className) {
  final classPattern = RegExp(
    r'''\bclass\s*=\s*(["'])(.*?)\1''',
    caseSensitive: false,
  );
  final match = classPattern.firstMatch(attributes);
  if (match == null) return '$attributes class="$className"';
  final quote = match.group(1)!;
  final classes = match.group(2)!;
  final replacement = 'class=$quote$classes $className$quote';
  return attributes.replaceRange(match.start, match.end, replacement);
}
