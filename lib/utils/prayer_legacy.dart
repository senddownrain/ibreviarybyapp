import 'package:markdown/markdown.dart' as md;

// Port of MyBrev prayerLegacyFormatting.js at 0fcce378. Read-only projection;
// these rules must never be used to rewrite the stored prayer or Mass content.
const prayerDirections = {
  'Усе ўстаюць.',
  'Усе кленчаць.',
  'Усе садзяцца.',
  'Усе моляцца ў цішыні.',
  'Святар кажа:',
  'Святар гаворыць:',
  'Цэлебрант кажа:',
  'Цэлебрант гаворыць:',
  'Народ адказвае:',
  'Усе адказваюць:',
  'Кантар спявае:',
  'Дыякан кажа:',
  'Лектар чытае:',
};
const prayerRoles = {
  'К.': 'cantor',
  'С.': 'priest',
  'Н.': 'people',
  'Д.': 'deacon',
  'Л.': 'reader',
  'Ц.': 'celebrant',
  'V.': 'versicle',
  'R.': 'response',
  'У.': 'all',
  'Усе:': 'all',
  'Цэлебрант:': 'celebrant',
};
final _prefix = RegExp(
  r'^( {0,3})([КСНДЛЦУVR]\.:?|Усе:|Цэлебрант:)(?=[ \t]+\S)',
);
final _initial = RegExp(r'^\p{Lu}\.', unicode: true);
final _name = RegExp(r'^\p{Lu}\p{Ll}+(?:\s+\p{Lu}\p{Ll}+)*$', unicode: true);
final _attribution = RegExp(
  r'^\p{Lu}[\p{Ll}\p{M}-]+(?:\s+\p{Lu}[\p{Ll}\p{M}-]+)*:',
  unicode: true,
);

String? prayerPrefix(String line, {bool pairedInvocation = false}) {
  final match = _prefix.firstMatch(line);
  if (match == null) return null;
  final label = match[2]!;
  final rest = line.substring(match.end).trim();
  if (label.contains('.') &&
      (_initial.hasMatch(rest) ||
          (!pairedInvocation && _name.hasMatch(rest)))) {
    return null;
  }
  if (RegExp(r'^[КСНДЛЦУ]').hasMatch(label) &&
      _attribution.hasMatch(rest) &&
      !RegExp(r'^(?:Молімся|Памолімся):').hasMatch(rest)) {
    return null;
  }
  return label;
}

String prayerInlineText(List<md.Node> nodes) => nodes.map((n) {
  if (n is md.Element && n.tag == 'br') return '\n';
  if (n is md.Element && n.tag == 'img') return n.attributes['alt'] ?? '';
  if (n is md.Element) return prayerInlineText(n.children ?? []);
  return n.textContent;
}).join();

bool _labelMarkup(List<md.Node> nodes) => nodes.every(
  (n) =>
      n is md.Text ||
      (n is md.Element &&
          {'em', 'strong'}.contains(n.tag) &&
          _labelMarkup(n.children ?? [])),
);

class _Candidate {
  _Candidate(this.label, this.display, {this.standalone = false});
  final String label;
  final String display;
  final bool standalone;
  String get canonical => label.replaceFirst(RegExp(r'\.:$'), '.');
}

_Candidate? _legacyLine(
  String line,
  String paragraph,
  md.Document document, {
  bool pairedInvocation = false,
}) {
  final named = RegExp(
    r'^([*_]{0,6})[КСНДЛЦ]\.[ \t]+\p{Lu}[\p{Ll}\p{M}-]+(?:[ \t]+\p{Lu}[\p{Ll}\p{M}-]+)*:\1(?:\s|$)',
    unicode: true,
  );
  if (named.hasMatch(line) &&
      !RegExp(r'^[*_]*[КСНДЛЦ]\.[ \t]+(?:Молімся|Памолімся):').hasMatch(line)) {
    return null;
  }
  final label = RegExp(
    r'^( {0,3})([*_]{0,6})([КСНДЛЦУVR]\.:?|Усе:|Цэлебрант:)([*_]{0,6})(:)?(?=[ \t]+|$)',
  ).firstMatch(line);
  if (label != null && !(label[3]!.endsWith(':') && label[5] != null)) {
    final visible = '${label[3]}${label[5] ?? ''}';
    final raw = label[0]!.substring(label[1]!.length);
    final parsed = document.parseInline(raw);
    if (_labelMarkup(parsed) && prayerInlineText(parsed) == visible) {
      final body = line.substring(label.end).trimLeft();
      if (body.isNotEmpty &&
          prayerPrefix('$visible $body', pairedInvocation: pairedInvocation) ==
              null) {
        return null;
      }
      return _Candidate(
        visible,
        '${label[1]}$visible${line.substring(label.end)}',
        standalone: body.isEmpty,
      );
    }
  }
  final whole = RegExp(
    r'^( {0,3})(\*\*|__|\*|_)([КСНДЛЦУVR]\.:?|Усе:|Цэлебрант:)([ \t]+)(.+)\2[ \t]*$',
  ).firstMatch(line);
  if (whole == null && paragraph.contains('\n')) {
    final partial = RegExp(
      r'^( {0,3})(\*\*|__|\*|_)([КСНДЛЦУVR]\.:?|Усе:|Цэлебрант:)([ \t]+)(\S.*)$',
    ).firstMatch(line);
    final parsed =
        partial == null || !paragraph.trimLeft().startsWith(line.trimLeft())
        ? <md.Node>[]
        : document
              .parseInline(paragraph)
              .where((n) => n is! md.Text || n.textContent.isNotEmpty)
              .toList();
    if (partial != null &&
        paragraph.trimLeft().startsWith(line.trimLeft()) &&
        paragraph.trimRight().endsWith(partial[2]!) &&
        RegExp(r'[.!?;:,…]$').hasMatch(
          paragraph.trimRight().substring(
            0,
            paragraph.trimRight().length - partial[2]!.length,
          ),
        ) &&
        parsed.isNotEmpty &&
        parsed.first is md.Element &&
        {'em', 'strong'}.contains((parsed.first as md.Element).tag) &&
        parsed.last is md.Element &&
        {'em', 'strong'}.contains((parsed.last as md.Element).tag) &&
        prayerPrefix('${partial[3]} ${partial[5]}') != null) {
      return _Candidate(
        partial[3]!,
        '${partial[1]}${partial[3]}${partial[4]}${partial[2]}${partial[5]}',
      );
    }
  }
  if (whole == null ||
      !RegExp(r'[.!?;:,…]$').hasMatch(whole[5]!) ||
      prayerPrefix('${whole[3]} ${whole[5]}') == null) {
    return null;
  }
  final parsed = document
      .parseInline(line)
      .where((n) => n is! md.Text || n.textContent.isNotEmpty)
      .toList();
  if (parsed.isEmpty ||
      parsed.first is! md.Element ||
      !{'em', 'strong'}.contains((parsed.first as md.Element).tag)) {
    return null;
  }
  return _Candidate(
    whole[3]!,
    '${whole[1]}${whole[3]}${whole[4]}${whole[2]}${whole[5]}${whole[2]}',
  );
}

/// Eligible paragraphs only: callers exclude quote/list/rubric/code containers.
({String source, Map<int, String> labels}) projectPrayerParagraph(
  String source,
  md.Document document,
) {
  final lines = source.split('\n');
  final candidates = [
    for (var i = 0; i < lines.length; i++)
      _legacyLine(
        lines[i],
        source,
        document,
        pairedInvocation:
            RegExp(r'^ {0,3}Л\.[ \t]').hasMatch(lines[i]) &&
            i + 1 < lines.length &&
            prayerRoles[prayerPrefix(
                  lines[i + 1],
                )?.replaceFirst(RegExp(r'\.:$'), '.')] ==
                'all',
      ),
  ];
  final labels = <int, String>{};
  final projected = [...lines];
  for (var i = 0; i < candidates.length; i++) {
    final speaker = candidates[i];
    if (speaker == null) continue;
    if (speaker.standalone) {
      final body = i + 1 < lines.length ? lines[i + 1] : '';
      final neighbour = candidates.asMap().entries.any(
        (entry) =>
            entry.key != i &&
            entry.value != null &&
            entry.value!.canonical != speaker.canonical &&
            (entry.key - i).abs() <= 8,
      );
      final ordinary =
          body.isNotEmpty &&
          !RegExp(r'^\s*(?:[>#`~]|:::|[-+*]\s|\d+[.)]\s)').hasMatch(body) &&
          _legacyLine(body, '', document) == null;
      if (!neighbour ||
          !ordinary ||
          prayerPrefix('${speaker.label} $body') == null) {
        continue;
      }
    }
    labels[i] = speaker.label;
    projected[i] = speaker.display;
  }
  return (source: projected.join('\n'), labels: labels);
}
