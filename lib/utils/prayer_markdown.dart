import 'package:markdown/markdown.dart' as md;
import 'package:mybrev_flutter/utils/prayer_html.dart';
import 'package:mybrev_flutter/utils/prayer_legacy.dart';

const prayerSpeakers = {
  'К.': 'cantor',
  'С.': 'priest',
  'Н.': 'people',
  'Д.': 'deacon',
  'Л.': 'reader',
  'Ц.': 'celebrant',
  'V.': 'versicle',
  'R.': 'response',
};

/// CommonMark prayer reader, MyBrev interpretation contract 1.1. All legacy
/// projection is in memory. Quotes admit only bare abbreviated labels; Mass
/// opts out of the generic compatibility rules entirely.
String prayerMarkdownToHtml(String source, {bool recognizeSpeakers = true}) {
  if (source.trim().isEmpty) return '';
  final document = md.Document(
    extensionSet: md.ExtensionSet.none,
    withDefaultBlockSyntaxes: false,
    blockSyntaxes: [
      _RubricSyntax(),
      const md.EmptyBlockSyntax(),
      const md.FencedCodeBlockSyntax(),
      const md.SetextHeaderSyntax(),
      const md.HeaderSyntax(),
      const md.CodeBlockSyntax(),
      const md.BlockquoteSyntax(),
      const md.HorizontalRuleSyntax(),
      const md.UnorderedListSyntax(),
      const md.OrderedListSyntax(),
      const md.LinkReferenceDefinitionSyntax(),
      const md.ParagraphSyntax(),
    ],
    inlineSyntaxes: [_ReadingBreakSyntax()],
  );
  // Keep physical lines until eligibility is decided; collect references before
  // parsing inlines. Raw HTML block/inline syntaxes are deliberately disabled.
  final nodes = md.BlockParser(
    source
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .split('\n')
        .map(md.Line.new)
        .toList(),
    document,
  ).parseLines();
  _parseInlines(nodes, document, recognizeSpeakers: recognizeSpeakers);
  return sanitizePrayerHtml(md.renderToHtml(nodes));
}

void _parseInlines(
  List<md.Node> nodes,
  md.Document document, {
  required bool recognizeSpeakers,
  bool paragraph = false,
  bool excluded = false,
  bool quoted = false,
}) {
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    if (node is md.UnparsedContent) {
      var source = node.textContent;
      Map<int, String>? labels;
      if (recognizeSpeakers && paragraph && !excluded && !quoted) {
        final projection = projectPrayerParagraph(source, document);
        source = projection.source;
        labels = projection.labels;
      }
      final inlines = document.parseInline(source);
      if (recognizeSpeakers && paragraph && !excluded) {
        _markSpeakers(inlines, source.split('\n'), labels: labels);
      }
      nodes.replaceRange(i, i + 1, inlines);
      i += inlines.length - 1;
    } else if (node is md.Element && node.children != null) {
      if (recognizeSpeakers &&
          !excluded &&
          !quoted &&
          node.tag == 'p' &&
          node.children!.length == 1 &&
          node.children!.first is md.UnparsedContent) {
        final source = node.children!.first.textContent;
        if (!source.contains('\n') &&
            prayerDirections.contains(
              prayerInlineText(document.parseInline(source)).trim(),
            )) {
          nodes[i] = md.Element('aside', [node])
            ..attributes['class'] = 'prayer-rubric';
          _parseInlines(node.children!, document, recognizeSpeakers: false);
          continue;
        }
      }
      _parseInlines(
        node.children!,
        document,
        recognizeSpeakers: recognizeSpeakers,
        paragraph: node.tag == 'p',
        excluded: excluded || {'aside', 'li', 'pre', 'code'}.contains(node.tag),
        quoted: quoted || node.tag == 'blockquote',
      );
    }
  }
}

void _markSpeakers(
  List<md.Node> nodes,
  List<String> lines, {
  Map<int, String>? labels,
}) {
  var line = 0;
  var start = true;
  // Match the web's flat inline token stream. Opening/closing emphasis disables
  // a prefix at that position, but a physical break inside emphasis starts a
  // new reply. Author formatting remains on the words surrounding the label.
  void visit(List<md.Node> children) {
    for (var i = 0; i < children.length; i++) {
      final node = children[i];
      if (start && node is md.Text && line < lines.length) {
        final label = labels != null ? labels[line] : prayerPrefix(lines[line]);
        if (label != null &&
            (labels != null || RegExp(r'^[КСНДЛЦVR]\.').hasMatch(label))) {
          final indent = RegExp(r'^ {0,3}').firstMatch(lines[line])![0]!;
          if (node.text.startsWith('$indent$label')) {
            final span = md.Element.text('span', label)
              ..attributes['class'] = 'prayer-speaker'
              ..attributes['data-role'] =
                  prayerRoles[label.replaceFirst(RegExp(r'\.:$'), '.')]!;
            final replacement = <md.Node>[
              if (indent.isNotEmpty) md.Text(indent),
              span,
              md.Text(node.text.substring(indent.length + label.length)),
            ];
            children.replaceRange(i, i + 1, replacement);
            i += replacement.length - 1;
          }
        }
      }
      if (node is md.Element && node.tag == 'br') {
        line++;
        start = true;
      } else {
        start = false;
        if (node is md.Element && {'em', 'strong', 'a'}.contains(node.tag)) {
          visit(node.children ?? []);
          start = false;
        }
      }
    }
  }

  visit(nodes);
}

class _ReadingBreakSyntax extends md.InlineSyntax {
  _ReadingBreakSyntax() : super(r'(?:\\| {2,})?\n');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.empty('br'));
    return true;
  }
}

class _RubricSyntax extends md.BlockSyntax {
  // Cache once per block parser, including nested quote/list parsers, to avoid
  // quadratic lookahead when an imported source contains many unclosed fences.
  final _closed = Expando<Map<md.Line, bool>>();
  @override
  RegExp get pattern => RegExp(r'^ {0,3}:::rubric\s*$');
  @override
  bool canParse(md.BlockParser parser) {
    if (!super.canParse(parser)) return false;
    var closed = _closed[parser];
    if (closed == null) {
      closed = <md.Line, bool>{};
      var found = false;
      for (final line in parser.lines.reversed) {
        closed[line] = found;
        if (line.content.trim() == ':::') found = true;
      }
      _closed[parser] = closed;
    }
    return closed[parser.current] ?? false;
  }

  @override
  md.Node parse(md.BlockParser parser) {
    parser.advance();
    final lines = <md.Line>[];
    while (!parser.isDone && parser.current.content.trim() != ':::') {
      lines.add(parser.current);
      parser.advance();
    }
    if (!parser.isDone) parser.advance();
    return md.Element(
      'aside',
      md.BlockParser(lines, parser.document).parseLines(),
    )..attributes['class'] = 'prayer-rubric';
  }
}
