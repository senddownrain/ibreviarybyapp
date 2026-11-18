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
  final antiphon = (parseFragment(selectedAntiphonHtml).text ?? '').replaceFirst(
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
    final parent = current.parentNode;
    if (parent == null) return psalmHtml;
    for (final sibling in parent.nodes.take(parent.nodes.indexOf(current)).toList()) {
      sibling.remove();
    }
    current = parent;
  }
  // Retain † at the beginning of the remaining half-verse (even if the
  // original cadence was *). Only this marker is exempt from line breaking.
  marker.innerHtml = '†';
  marker.classes.add('psalm-opening-flexa');

  // Keep the dagger attached to its first word, across inline wrappers.
  dom.Node cursor = marker;
  while (!identical(cursor, paragraph)) {
    final parent = cursor.parentNode;
    if (parent == null) break;
    final nextIndex = parent.nodes.indexOf(cursor) + 1;
    if (nextIndex < parent.nodes.length) {
      final next = parent.nodes[nextIndex];
      if (next is dom.Text) {
        next.data = next.data.replaceFirst(RegExp(r'^[\\s\\u00a0]*'), '\\u00a0');
      } else {
        parent.nodes.insert(nextIndex, dom.Text('\\u00a0'));
      }
      break;
    }
    cursor = parent;
  }

  // Remove empty prefix wrappers without rewriting any surviving word.
  _trimLeading(paragraph);
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
    final parent = current.parentNode;
    if (parent == null) return '';
    result = parent.nodes
        .take(parent.nodes.indexOf(current))
        .map((node) => node.text ?? '')
        .join() + result;
    current = parent;
  }
  return result;
}

void _trimLeading(dom.Node node) {
  while (node.nodes.isNotEmpty) {
    final child = node.nodes.first;
    if (child is dom.Text) {
      child.data = child.data.replaceFirst(RegExp(r'^\s+'), '');
      if (child.data.isEmpty) {
        child.remove();
        continue;
      }
      return;
    }
    if (child is dom.Element) {
      _trimLeading(child);
      if (child.text.trim().isEmpty) {
        child.remove();
        continue;
      }
    }
    return;
  }
}

String addOpeningAntiphonFlexa(String html) {
  if (html.isEmpty) return html;
  final root = parseFragment(html);
  final paragraphs = root.querySelectorAll('p');
  final dom.Node target = paragraphs.isEmpty ? root : paragraphs.last;
  if ((target.text ?? '').trimRight().endsWith('†')) return html;
  if ((target.text ?? '').trim().isEmpty) return html;
  target.nodes.add(dom.Text(' '));
  target.nodes.add(
    dom.Element.tag('span')
      ..classes.add('psalm-antiphon-flexa')
      ..nodes.add(dom.Text('†')),
  );
  return root.outerHtml;
}
