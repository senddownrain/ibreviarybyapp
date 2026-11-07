import 'package:flutter/painting.dart';
import 'package:html/parser.dart' as parser;
import 'package:mybrev_flutter/models/reader_alignment.dart';

final _nonProsePrefix = RegExp(
  r'^\s*(?:[VRКСНДЛЦ]\.\s|℣|℟|[-–—•]\s|\d+[.)]\s)',
);

/// Fixed lineation, list items and liturgical labels opt out of prose alignment.
TextAlign proseTextAlign(
  ReaderAlignment alignment,
  String text, {
  bool enabled = true,
}) =>
    enabled &&
        !RegExp(r'[\r\n*†]').hasMatch(text) &&
        !_nonProsePrefix.hasMatch(text)
    ? alignment.textAlign
    : TextAlign.start;

const readerProseClass = 'reader-prose';

/// Marks only prose paragraphs. Inline markup, recognizers and links remain
/// intact. No caller in the Liturgy of the Hours uses this projection.
String prepareReaderProseHtml(String html) {
  final fragment = parser.parseFragment(html);
  for (final p in fragment.querySelectorAll('p')) {
    p.classes.remove(readerProseClass);
    if (p.querySelector(
              'br, .prayer-speaker, .mass-role, .liturgical-rubric-inline, .psalm-marker',
            ) !=
            null ||
        RegExp(r'[*†]').hasMatch(p.text) ||
        _nonProsePrefix.hasMatch(p.text)) {
      continue;
    }
    var excluded = false;
    for (var node = p; ;) {
      if (const {
            'li',
            'ul',
            'ol',
            'pre',
            'nav',
            'table',
          }.contains(node.localName) ||
          node.attributes.containsKey('data-role') ||
          node.attributes['style']?.contains('text-align') == true ||
          node.classes.any(
            (c) => RegExp(
              r'rubric|psalm|hymn|strophe|respons|antiphon|reference|metadata|heading|prayer-speaker|mass-(?:role|comment|posture|alternative)',
            ).hasMatch(c),
          )) {
        excluded = true;
        break;
      }
      final parent = node.parent;
      if (parent == null) break;
      node = parent;
    }
    if (!excluded) p.classes.add(readerProseClass);
  }
  return fragment.outerHtml;
}
