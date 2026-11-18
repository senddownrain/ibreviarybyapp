import 'package:html/parser.dart' show parseFragment;

/// Display-only full conclusion of Lauds/Vespers collects addressed to the Father.
/// Data in the bundle and Firestore remain unchanged.
const fullOfficeCollectConclusion =
    'Праз Пана нашага Езуса Хрыста, Твайго Сына, які з Табою жыве і '
    'валадарыць у еднасці Духа Святога, Бог, праз усе вякі вечныя. Амэн.';

final _shortAtEnd = RegExp(r'Праз\s+Пана\s+нашага\.\s*$');
final _shortHtmlAtEnd = RegExp(
  r'Праз(?:\s|&nbsp;|&#0*160;|&#x0*a0;)+Пана(?:\s|&nbsp;|&#0*160;|&#x0*a0;)+нашага\.(?=(?:\s*</(?:span|font|b|strong|i|em|a)>)*\s*$)',
  caseSensitive: false,
);

/// Only expands the exact abbreviated ending at a prayer paragraph boundary.
/// Alternatives are independent; completed and other concluding formulas remain
/// exactly as stored. Safe to call repeatedly.
String expandOfficeCollectConclusion(String source) {
  if (!source.contains('Праз') || !source.contains('Пана')) return source;
  if (!source.contains('<')) {
    return source.replaceFirst(_shortAtEnd, fullOfficeCollectConclusion);
  }
  final root = parseFragment(source);
  var changed = false;
  for (final paragraph in root.querySelectorAll('p, div')) {
    if (paragraph.querySelector('p, div') != null) continue;
    final text = paragraph.text
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (!_shortAtEnd.hasMatch(text)) continue;
    final original = paragraph.innerHtml;
    final replacement = original.replaceFirst(
      _shortHtmlAtEnd,
      fullOfficeCollectConclusion,
    );
    if (replacement == original) continue;
    paragraph.innerHtml = replacement;
    changed = true;
  }
  return changed ? root.outerHtml : source;
}
