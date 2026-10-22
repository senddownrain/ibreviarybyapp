/// Builds complete hymns for each role from the four sections of the legacy
/// Common of Pastors. The stored source remains unchanged.
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
  if (has('прэзбітэр|прэзбітэра|прэзбітэру|святар|святара|святару')) return 'priest';
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
    .replaceFirst(RegExp(r'^.*?<br\s*/?>', caseSensitive: false, dotAll: true), '')
    .replaceFirst(RegExp(r'(<br\s*/?>\s*)+$', caseSensitive: false), '')
    .trim();

String _paragraph(String line) => '<p>' +
    line.replaceFirst(RegExp(r'(<br\s*/?>\s*)+$', caseSensitive: false), '').trim() +
    '</p>';

String preparePastorsHymn(String html, [String? feastName]) {
  if (!html.contains('Пра аднаго пастыра') ||
      !html.contains('Пра некалькіх') ||
      !RegExp(r'<hr\b', caseSensitive: false).hasMatch(html)) {
    return html;
  }
  final parts = html.split(RegExp(r'<hr\s*/?>', caseSensitive: false));
  if (parts.length != 4) return html;
  final groups = parts.map(_paragraphs).toList();
  final opening = groups[0];
  final middle = groups[1];
  final ending = groups[2];
  final plural = groups[3];
  if (opening.isEmpty || middle.length != 3 ||
      ending.isEmpty || plural.isEmpty) return html;
  final first = _stripRubric(opening.first);
  final middles = middle.map(_stripRubric).toList();
  final manyFirst = _stripRubric(plural.first);
  if (first.isEmpty || manyFirst.isEmpty ||
      middles.any((line) => line.isEmpty)) return html;
  final content = <String, List<String>>{
    'pope': [first, ...opening.skip(1), middles[0], ...ending],
    'bishop': [first, ...opening.skip(1), middles[1], ...ending],
    'priest': [first, ...opening.skip(1), middles[2], ...ending],
    'many': [manyFirst, ...plural.skip(1)],
  };
  final selected = pastorKindFromTitle(feastName);
  final order = selected.isEmpty
      ? _kinds
      : [selected, ..._kinds.where((kind) => kind != selected)];
  return order.map((kind) {
    final verses = content[kind]!.map(_paragraph).join('\n');
    return '<div data-alternative-title="' + _titles[kind]! +
        '" data-pastor-kind="' + kind + '">\n' + verses + '\n</div>';
  }).join('\n');
}
