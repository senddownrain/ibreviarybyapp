/// Builds complete hymns for each role from the legacy Common of Pastors. The
/// stored source remains unchanged. Two stored layouts are recognized, nothing
/// else: the base text with four `<hr>` sections, and the seasonal variants
/// (Advent/Christmas/Lent/Easter) where the same hymn is flattened into one
/// paragraph without `<hr>`. Mirrors mybrev `src/utils/pastorsHymn.js`.
const _titles = <String, String>{
  'pope': 'Пра Папу',
  'bishop': 'Пра біскупа',
  'priest': 'Пра прэзбітэра',
  'many': 'Пра некалькіх пастыраў',
};
const _kinds = ['pope', 'bishop', 'priest', 'many'];

String pastorKindFromTitle(String? title) {
  final value = (title ?? '').replaceAll(RegExp(r'<[^>]*>'), ' ').toLowerCase();
  bool has(String words) => RegExp(
    '(^|[\\s,;().])(' + words + ')(?=\$|[\\s,;().])',
    caseSensitive: false,
    unicode: true,
  ).hasMatch(value);
  if (has('пастыраў|біскупаў|папаў|прэзбітэраў|святароў')) return 'many';
  if (has('папа|папы|папу|папе|папам')) return 'pope';
  if (has('біскуп|біскупа|біскупу|біскупам')) return 'bishop';
  if (has('прэзбітэр|прэзбітэра|прэзбітэру|святар|святара|святару'))
    return 'priest';
  return '';
}

List<String> _paragraphs(String section) => section
    .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<p\b[^>]*>', caseSensitive: false), '')
    .split(RegExp(r'\n+'))
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();

String _stripRubric(String line) => line
    .replaceFirst(
      RegExp(r'^.*?<br\s*/?>', caseSensitive: false, dotAll: true),
      '',
    )
    .replaceFirst(RegExp(r'(<br\s*/?>\s*)+$', caseSensitive: false), '')
    .trim();

String _paragraph(String line) =>
    '<p>' +
    line
        .replaceFirst(RegExp(r'(<br\s*/?>\s*)+$', caseSensitive: false), '')
        .trim() +
    '</p>';

Map<String, List<String>>? _hrContent(String html) {
  if (!RegExp(r'<hr\b', caseSensitive: false).hasMatch(html)) return null;
  final parts = html.split(RegExp(r'<hr\s*/?>', caseSensitive: false));
  if (parts.length != 4) return null;
  final groups = parts.map(_paragraphs).toList();
  final opening = groups[0];
  final middle = groups[1];
  final ending = groups[2];
  final plural = groups[3];
  if (opening.isEmpty || middle.length != 3 || ending.isEmpty || plural.isEmpty)
    return null;
  final first = _stripRubric(opening.first);
  final middles = middle.map(_stripRubric).toList();
  final manyFirst = _stripRubric(plural.first);
  if (first.isEmpty || manyFirst.isEmpty || middles.any((line) => line.isEmpty))
    return null;
  return {
    'pope': [first, ...opening.skip(1), middles[0], ...ending],
    'bishop': [first, ...opening.skip(1), middles[1], ...ending],
    'priest': [first, ...opening.skip(1), middles[2], ...ending],
    'many': [manyFirst, ...plural.skip(1)],
  };
}

const _headings = [
  'Пра аднаго пастыра',
  'Пра Папу',
  'Пра біскупа',
  'Пра прэзбітэра',
  'Пра некалькіх пастыраў',
];

String _plainText(String line) => line
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Flattened seasonal layout. The headings are certain; the only inference is
/// the end of the presbyter stanza (no separator before the shared
/// conclusion): the three exclusive stanzas have the same number of lines.
Map<String, List<String>>? _flatContent(String html) {
  if (RegExp(r'<hr\b', caseSensitive: false).hasMatch(html)) return null;
  final lines = html
      .replaceAll(RegExp(r'</p>\s*<p\b[^>]*>', caseSensitive: false), '<br />')
      .replaceAll(RegExp(r'^\s*<p\b[^>]*>|</p>\s*$', caseSensitive: false), '')
      .split(RegExp(r'<br\s*/?>', caseSensitive: false))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final at = <int>[];
  for (final label in _headings) {
    final found = [
      for (var i = 0; i < lines.length; i++)
        if (_plainText(lines[i]).replaceFirst(RegExp(r'\s*:$'), '') == label)
          i,
    ];
    at.add(found.length == 1 ? found.first : -1);
  }
  for (var i = 0; i < at.length; i++) {
    if (at[i] < 0 || (i > 0 && at[i] <= at[i - 1])) return null;
  }
  if (at[0] != 0) return null;
  final opening = lines.sublist(at[0] + 1, at[1]);
  final pope = lines.sublist(at[1] + 1, at[2]);
  final bishop = lines.sublist(at[2] + 1, at[3]);
  final rest = lines.sublist(at[3] + 1, at[4]);
  final plural = lines.sublist(at[4] + 1);
  final size = pope.length;
  if (opening.isEmpty ||
      size == 0 ||
      bishop.length != size ||
      rest.length <= size ||
      plural.isEmpty)
    return null;
  String block(List<String> list) => list.join('<br />');
  final priest = rest.sublist(0, size);
  final ending = rest.sublist(size);
  return {
    'pope': [block(opening), block(pope), block(ending)],
    'bishop': [block(opening), block(bishop), block(ending)],
    'priest': [block(opening), block(priest), block(ending)],
    'many': [block(plural)],
  };
}

String preparePastorsHymn(String html, [String? feastName]) {
  if (!html.contains('Пра аднаго пастыра') || !html.contains('Пра некалькіх')) {
    return html;
  }
  final content = _flatContent(html) ?? _hrContent(html);
  if (content == null) return html;
  final selected = pastorKindFromTitle(feastName);
  final order = selected.isEmpty
      ? _kinds
      : [selected, ..._kinds.where((kind) => kind != selected)];
  final hymns = order
      .map((kind) {
        final verses = content[kind]!.map(_paragraph).join('\n');
        return '<div data-alternative-title="' +
            _titles[kind]! +
            '" data-pastor-kind="' +
            kind +
            '">\n' +
            verses +
            '\n</div>';
      })
      .join('\n');
  // An unknown title requires a manual selection, never an invented rank.
  if (selected.isNotEmpty) return hymns;
  return '<div data-alternative-title="Абярыце тып пастыра" '
          'data-pastor-kind="unspecified">'
          '<p>Абярыце адпаведны варыянт гімна паводле святога.</p>'
          '</div>\n' +
      hymns;
}
