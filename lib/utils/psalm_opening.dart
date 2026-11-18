import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

/// A display-only rule: the full opening half-verse may be suppressed when
/// the selected antiphon is word-for-word identical. Source HTML is unchanged.
String omitEchoedPsalmOpening(String psalmHtml, String? selectedAntiphonHtml) {
  if (selectedAntiphonHtml == null || selectedAntiphonHtml.isEmpty) {
    return psalmHtml;
  }
  final root = parseFragment(psalmHtml);
  final paragraph = root.querySelector('p.psalm-strophe');
  final marker = paragraph?.querySelector('.psalm-marker');
  if (paragraph == null || marker == null ||
      (marker.text.trim() != '†' && marker.text.trim() != '*')) {
    return psalmHtml;
  }
  final antiphon = parseFragment(selectedAntiphonHtml).text.replaceFirst(
    RegExp(r'^\s*(?:[1-9]\s*)?ант\.\s*', caseSensitive: false), '',
  );
  final prefix = _textBefore(paragraph, marker).replaceFirst(
    RegExp(r'^\s*\d+[.)]\s*'), '',
  );
  if (_words(antiphon).isEmpty || _words(antiphon) != _words(prefix)) {
    return psalmHtml;
  }

  dom.Node current = marker;
  while (!identical(current, paragraph)) {
    final parent = current.parent;
    if (parent == null) return psalmHtml;
    for (final sibling in parent.nodes.take(parent.nodes.indexOf(current)).toList()) {
      sibling.remove();
    }
    current = parent;
  }
  marker.remove();

  // Only presentation whitespace is removed. Never rewrite a surviving word
  // or its inline formatting.
  dom.Node? leading = paragraph.nodes.isEmpty ? null : paragraph.nodes.first;
  while (leading is dom.Element && leading.nodes.isNotEmpty) {
    leading = leading.nodes.first;
  }
  if (leading is dom.Text) {
    leading.data = leading.data.replaceFirst(RegExp(r'^\s+'), '');
  }
  if (_words(paragraph.text).isEmpty) {
    if (root.querySelectorAll('p.psalm-strophe').length <= 1) return psalmHtml;
    paragraph.remove();
  }
  return root.outerHtml;
}

String _words(String text) => text
    .replaceAll(RegExp(r'[\s.,;:!?…“”«»()\[\]†*]+'), ' ')
    .trim()
    .toLowerCase();

String _textBefore(dom.Element paragraph, dom.Element marker) {
  dom.Node current = marker;
  var result = '';
  while (!identical(current, paragraph)) {
    final parent = current.parent;
    if (parent == null) return '';
    result = parent.nodes
        .take(parent.nodes.indexOf(current))
        .map((node) => node.text ?? '')
        .join() + result;
    current = parent;
  }
  return result;
}
