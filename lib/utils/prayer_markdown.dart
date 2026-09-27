/// Minimal MyBrev Markdown → HTML for prayer display (web `renderPrayerMarkdown` subset).
String prayerMarkdownToHtml(String source) {
  if (source.trim().isEmpty) return '';

  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final out = StringBuffer();
  var inRubric = false;
  var paragraph = <String>[];
  String? activeList;

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    final joined = paragraph.join('<br>');
    out.writeln('<p>$joined</p>');
    paragraph = [];
  }

  void flushList() {
    if (activeList == null) return;
    out.writeln('</$activeList>');
    activeList = null;
  }

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    final trimmed = line.trim();

    if (trimmed == ':::rubric') {
      flushParagraph();
      flushList();
      inRubric = true;
      out.writeln('<div class="prayer-rubric">');
      continue;
    }
    if (trimmed == ':::' && inRubric) {
      flushParagraph();
      flushList();
      inRubric = false;
      out.writeln('</div>');
      continue;
    }

    if (RegExp(r'^(?:-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed) &&
        paragraph.isEmpty) {
      flushList();
      out.writeln('<hr>');
      continue;
    }

    final heading = RegExp(r'^(#{2,6})\s+(.+)$').firstMatch(trimmed);
    if (heading != null) {
      flushParagraph();
      flushList();
      final level = heading.group(1)!.length;
      out.writeln('<h$level>${_inlineMd(heading.group(2)!)}</h$level>');
      continue;
    }

    final list = RegExp(r'^([-+*]|\d+[.)])\s+(.+)$').firstMatch(trimmed);
    if (list != null) {
      flushParagraph();
      final listType = RegExp(r'^\d').hasMatch(list.group(1)!) ? 'ol' : 'ul';
      if (activeList != listType) {
        flushList();
        activeList = listType;
        out.writeln('<$listType>');
      }
      out.writeln('<li>${_inlineMd(list.group(2)!)}</li>');
      continue;
    }

    if (trimmed.isEmpty) {
      flushParagraph();
      flushList();
      continue;
    }

    flushList();
    paragraph.add(_inlineMd(line));
  }

  flushParagraph();
  flushList();
  if (inRubric) out.writeln('</div>');
  return out.toString();
}

String _inlineMd(String input) {
  final tokens = RegExp(
    r'\\([!"#$%&\x27()*+,\-./:;<=>?@\[\]\\^_`{|}~])|\[((?:\\.|[^\]\\])+)\]\(([^\s)]+)\)',
  );
  final out = StringBuffer();
  var offset = 0;
  for (final match in tokens.allMatches(input)) {
    out.write(_inlineFormatting(input.substring(offset, match.start)));
    if (match.group(1) != null) {
      out.write(_escapeHtml(match.group(1)!));
    } else {
      final href = _escapeHtml(match.group(3)!).replaceAll('"', '&quot;');
      out.write('<a href="$href">${_inlineMd(match.group(2)!)}</a>');
    }
    offset = match.end;
  }
  out.write(_inlineFormatting(input.substring(offset)));
  return out.toString();
}

String _inlineFormatting(String input) {
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
  return s;
}

String _escapeHtml(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
