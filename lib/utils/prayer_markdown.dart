/// Minimal MyBrev Markdown → HTML for prayer display (web `renderPrayerMarkdown` subset).
String prayerMarkdownToHtml(String source) {
  if (source.trim().isEmpty) return '';

  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final out = StringBuffer();
  var inRubric = false;
  var paragraph = <String>[];

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    final joined = paragraph.join('<br>');
    out.writeln('<p>$joined</p>');
    paragraph = [];
  }

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    final trimmed = line.trim();

    if (trimmed == ':::rubric') {
      flushParagraph();
      inRubric = true;
      out.writeln('<div class="prayer-rubric">');
      continue;
    }
    if (trimmed == ':::' && inRubric) {
      flushParagraph();
      inRubric = false;
      out.writeln('</div>');
      continue;
    }

    final heading = RegExp(r'^(#{2,6})\s+(.+)$').firstMatch(trimmed);
    if (heading != null) {
      flushParagraph();
      final level = heading.group(1)!.length;
      out.writeln('<h$level>${_inlineMd(heading.group(2)!)}</h$level>');
      continue;
    }

    final list = RegExp(r'^([-+*]|\d+[.)])\s+(.+)$').firstMatch(trimmed);
    if (list != null) {
      flushParagraph();
      out.writeln('<p>• ${_inlineMd(list.group(2)!)}</p>');
      continue;
    }

    if (trimmed.isEmpty) {
      flushParagraph();
      continue;
    }

    paragraph.add(_inlineMd(line));
  }

  flushParagraph();
  if (inRubric) out.writeln('</div>');
  return out.toString();
}

String _inlineMd(String input) {
  var s = _escapeHtml(input);
  s = s.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*'),
    (m) => '<strong>${m.group(1)}</strong>',
  );
  s = s.replaceAllMapped(
    RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)'),
    (m) => '<em>${m.group(1)}</em>',
  );
  s = s.replaceAllMapped(
    RegExp(r'(?<![A-Za-zА-Яа-яЁёІіЎў])_(.+?)_(?![A-Za-zА-Яа-яЁёІіЎ])'),
    (m) => '<em>${m.group(1)}</em>',
  );
  s = s.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
    (m) => '<a href="${m.group(2)}">${m.group(1)}</a>',
  );
  return s;
}

String _escapeHtml(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
