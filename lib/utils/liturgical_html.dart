/// Semantic preparation for legacy liturgical HTML.
///
/// The web application styles psalm metadata, strophes and cadence signs
/// separately. Flutter HTML needs explicit classes for the same result.
final _paragraphPattern = RegExp(
  r'<p\b([^>]*)>([\s\S]*?)</p>',
  caseSensitive: false,
);
final _breakPattern = RegExp(r'<br\s*/?>', caseSensitive: false);
final _cadencePattern = RegExp(
  r'(?:\*|&#0*42;|&#x0*2a;|&ast;|†|&#0*8224;|&#x0*2020;|&dagger;)',
  caseSensitive: false,
);
final _asteriskPattern = RegExp(
  r'(?:\*|&#0*42;|&#x0*2a;|&ast;)',
  caseSensitive: false,
);

String removeBreakAfterCadenceMarker(String html) => html.replaceAllMapped(
  RegExp(
    r'((?:\*|&#0*42;|&#x0*2a;|&ast;|†|&#0*8224;|&#x0*2020;|&dagger;)(?:\s|&nbsp;)*(?:</(?:span|font|strong|b|em|i)>\s*)*)(?:<br\s*/?>\s*)+',
    caseSensitive: false,
  ),
  (match) => '${match.group(1)} ',
);

@Deprecated('Use removeBreakAfterCadenceMarker')
String removeBreakAfterAsterisk(String html) =>
    removeBreakAfterCadenceMarker(html);

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
  _normalizeLegacyPresentation(
    _normalizeRubricColors(
      _markInlineReadingReference(_markLeadingMetadata(html)),
    ),
  ),
);

String formatPsalmHtml(String html) {
  var value = removeBreakAfterCadenceMarker(html);

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
    _normalizeLegacyPresentation(
      _normalizeRubricColors(_markLeadingMetadata(value, limit: null)),
    ),
  );
}

/// Adds tap targets to the already formatted strophes of a psalm.
///
/// Odd and even strophes represent the two choirs. When [selectedChoir] is
/// set, strophes belonging to the other choir receive a muted style hook.
String preparePsalmChoirHtml(String html, {int? selectedChoir}) {
  return html.replaceAllMapped(_paragraphPattern, (match) {
    final attributes = match.group(1) ?? '';
    final content = match.group(2) ?? '';
    if (!RegExp(
      r'''\bclass\s*=\s*["'][^"']*\bpsalm-strophe\b''',
      caseSensitive: false,
    ).hasMatch(attributes)) {
      return match.group(0)!;
    }

    final choir =
        RegExp(
          r'\bpsalm-strophe-even\b',
          caseSensitive: false,
        ).hasMatch(attributes)
        ? 2
        : 1;
    final mutedClass = selectedChoir != null && selectedChoir != choir
        ? ' psalm-choir-muted'
        : '';

    return '<p$attributes><a href="psalm-choir:$choir" '
        'class="psalm-choir-strophe$mutedClass">$content</a></p>';
  });
}

String _markInlineReadingReference(String html) => html.replaceAllMapped(
  _paragraphPattern,
  (paragraph) {
    final content = paragraph.group(2) ?? '';
    final visible = _visibleText(content);
    if (!RegExp(
      r'^(?:ПЕРШАЕ|ДРУГОЕ|КАРОТКАЕ)?\s*ЧЫТАННЕ(?:\s|$)',
      caseSensitive: false,
    ).hasMatch(visible)) {
      return paragraph.group(0)!;
    }
    final marked = content.replaceFirstMapped(
      RegExp(r'\(([^<>]{1,80})\)'),
      (match) =>
          '<span class="liturgical-reading-reference">${match.group(0)}</span>',
    );
    return '<p${paragraph.group(1) ?? ''}>$marked</p>';
  },
);

String _normalizeLegacyPresentation(String html) => html.replaceAllMapped(
  RegExp(r'''\sstyle\s*=\s*(["'])(.*?)\1''', caseSensitive: false),
  (match) {
    var style = match.group(2) ?? '';
    style = style
        .replaceAll(
          RegExp(
            r'''(?:text-align|margin-left|font-size)\s*:[^;"']*;?''',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    return style.isEmpty
        ? ''
        : ' style=${match.group(1)}$style${match.group(1)}';
  },
);

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

String _markLeadingMetadata(String html, {int? limit = 2}) {
  var remaining = limit;
  var canMark = true;
  return html.replaceAllMapped(_paragraphPattern, (match) {
    final attributes = match.group(1) ?? '';
    final content = match.group(2) ?? '';
    final visible = _visibleText(content);

    // Explicit document roles own their typography. In particular, opening
    // rubrics must not be reclassified as smaller leading metadata merely
    // because all of their source text is red or emphasized.
    if (_hasClass(attributes, 'liturgical-rubric')) {
      return match.group(0)!;
    }

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
    final red = _allVisibleTextIsRubric(content, visible);

    final hasRoom = remaining == null || remaining! > 0;
    if (centered || (canMark && hasRoom && (emphasized || red))) {
      if (remaining != null && remaining! > 0) {
        remaining = remaining! - 1;
      }
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

bool _hasClass(String attributes, String className) {
  final match = RegExp(
    r'''\bclass\s*=\s*(["'])(.*?)\1''',
    caseSensitive: false,
  ).firstMatch(attributes);
  if (match == null) return false;
  return match
      .group(2)!
      .split(RegExp(r'\s+'))
      .any((value) => value.toLowerCase() == className.toLowerCase());
}

bool _allVisibleTextIsRubric(String content, String visible) {
  if (visible.isEmpty) return false;
  final styled = RegExp(
    r'''<(span|font)\b(?=[^>]*(?:color\s*:\s*(?:#ff0000|red)|color\s*=\s*["']?(?:#ff0000|red)))[^>]*>([\s\S]*?)</\1>''',
    caseSensitive: false,
  ).allMatches(content);
  if (styled.isEmpty) return false;
  final styledText = styled
      .map((match) => _visibleText(match.group(2)!))
      .join(' ');
  return _normalizeVisible(styledText) == _normalizeVisible(visible);
}

String _normalizeVisible(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

/// Removes a trailing antiphon only when composition already owns the exact
/// external antiphon. Generic psalm HTML is otherwise left untouched.
String stripEmbeddedAntiphon(String html, {String? externalAntiphon}) {
  final expected = _normalizeVisible(_visibleText(externalAntiphon ?? ''));
  if (expected.isEmpty) return html;
  final matches = _paragraphPattern.allMatches(html).toList();
  if (matches.isEmpty) return html;
  final last = matches.last;
  var actual = _normalizeVisible(_visibleText(last.group(2) ?? ''));
  actual = actual.replaceFirst(RegExp(r'^ант\.?\s*', caseSensitive: false), '');
  final normalizedExpected = expected.replaceFirst(
    RegExp(r'^ант\.?\s*', caseSensitive: false),
    '',
  );
  if (actual != normalizedExpected) return html;
  return html.replaceRange(last.start, last.end, '');
}

bool ownsStructuredPsalmPackage(String html) =>
    RegExp(
      r'''class\s*=\s*["'][^"']*\bora-ant\b''',
      caseSensitive: false,
    ).hasMatch(html) &&
    RegExp(
      r'''class\s*=\s*["'][^"']*\bora-psalm\b''',
      caseSensitive: false,
    ).hasMatch(html);

/// Removes only the legacy structural label already supplied by composition.
/// Source/reference/body content following a break remains intact.
String stripLeadingReadingHeading(String html, String structuralLabel) {
  final canonical = structuralLabel.toLowerCase().contains('другое')
      ? 'ДРУГОЕ ЧЫТАННЕ'
      : 'ПЕРШАЕ ЧЫТАННЕ';
  return html.replaceFirst(
    RegExp(
      '^\\s*(?:<[^>]+>\\s*)*${RegExp.escape(canonical)}\\s*(?:<br\\s*/?>|</p>)\\s*',
      caseSensitive: false,
    ),
    '',
  );
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
