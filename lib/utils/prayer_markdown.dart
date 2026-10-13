import 'package:markdown/markdown.dart' as md;
import 'package:mybrev_flutter/utils/prayer_html.dart';

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
final _speaker = RegExp(r'^( {0,3})([КСНДЛЦVR]\.)(:)?(?=[ \t]+\S)');
final _initial = RegExp(r'^\p{Lu}\.', unicode: true);
final _name = RegExp(r'^\p{Lu}\p{Ll}+(?:\s+\p{Lu}\p{Ll}+)*$', unicode: true);

/// Contract 1.0: CommonMark, physical line breaks and explicit rubrics.
/// Recognition is confined to ordinary paragraph AST nodes. Mass opts out
/// because its role metadata is language/context dependent.
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
}) {
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    if (node is md.UnparsedContent) {
      final inlines = document.parseInline(node.textContent);
      if (recognizeSpeakers && paragraph && !excluded) {
        _markSpeakers(inlines, node.textContent.split('\n'));
      }
      nodes.replaceRange(i, i + 1, inlines);
      i += inlines.length - 1;
    } else if (node is md.Element && node.children != null) {
      _parseInlines(
        node.children!,
        document,
        recognizeSpeakers: recognizeSpeakers,
        paragraph: node.tag == 'p',
        excluded:
            excluded ||
            {'aside', 'blockquote', 'li', 'pre', 'code'}.contains(node.tag),
      );
    }
  }
}

void _markSpeakers(List<md.Node> nodes, List<String> lines) {
  var line = 0;
  var start = true;
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    if (start && node is md.Text && line < lines.length) {
      final prefix = _speaker.firstMatch(lines[line]);
      if (prefix != null) {
        final rest = lines[line].substring(prefix.end).trim();
        if (!_initial.hasMatch(rest) && !_name.hasMatch(rest)) {
          final indent = prefix.group(1)!;
          final label = '${prefix.group(2)}${prefix.group(3) ?? ''}';
          if (node.text.startsWith('$indent$label')) {
            final span = md.Element.text('span', label)
              ..attributes['class'] = 'prayer-speaker'
              ..attributes['data-role'] = prayerSpeakers[prefix.group(2)]!;
            final replacement = <md.Node>[
              if (indent.isNotEmpty) md.Text(indent),
              span,
              md.Text(node.text.substring(indent.length + label.length)),
            ];
            nodes.replaceRange(i, i + 1, replacement);
            i += replacement.length - 1;
          }
        }
      }
    }
    line += _breakCount(node);
    start = node is md.Element && node.tag == 'br';
  }
}

int _breakCount(md.Node node) {
  if (node is md.Text) return '\n'.allMatches(node.text).length;
  if (node is md.Element) {
    if (node.tag == 'br') return 1;
    return node.children?.fold<int>(0, (n, child) => n + _breakCount(child)) ??
        0;
  }
  return 0;
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
