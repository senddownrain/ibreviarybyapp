/// Display-only preparation of day texts. The resolved snapshot keeps the
/// source exactly as the shared contract produces it.
library;

import 'package:mybrev_flutter/novena/novena_definition.dart';
import 'package:mybrev_flutter/utils/prayer_legacy_html.dart';

final _html = RegExp(r'</?[a-z][^>]*>', caseSensitive: false);
final _rubricOpen = RegExp(r'^ {0,3}:::rubric\s*$');

/// A section cut from a prayer can keep half of a `:::rubric` fence; such a
/// half would be printed as text.
String _balanceFences(String source) {
  final lines = source.split('\n');
  final drop = <int>{};
  int? open;
  for (var i = 0; i < lines.length; i++) {
    if (_rubricOpen.hasMatch(lines[i])) {
      if (open != null) drop.add(open);
      open = i;
    } else if (lines[i].trim() == ':::') {
      open == null ? drop.add(i) : open = null;
    }
  }
  if (open != null) drop.add(open);
  if (drop.isEmpty) return source;
  return [
    for (var i = 0; i < lines.length; i++)
      if (!drop.contains(i)) lines[i],
  ].join('\n');
}

String novenaDisplayText(String source) => _html.hasMatch(source)
    ? prayerLegacyHtmlToMarkdown(source)
    : _balanceFences(source.replaceAll('\r\n', '\n'));

String novenaDisplayMarkdown(NovenaBlock block) {
  final text = novenaDisplayText(block.markdown);
  return block.kind == 'rubric' && !text.contains(':::')
      ? ':::rubric\n$text\n:::'
      : text;
}

String _plain(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll(RegExp(r'[#*_«»"().:,]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The linked prayer already opens with its own title.
bool novenaStartsWithTitle(String markdown, String title) {
  final first = markdown
      .split('\n')
      .map(_plain)
      .where((line) => line.isNotEmpty)
      .firstOrNull;
  return first == _plain(title);
}
