import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

// Same conservative semantic opt-in as MyBrev PR #202. This transient DOM is
// only for rendering; cached documents and their inline nodes are not rewritten.
const _excluded =
    'h1,h2,h3,h4,h5,h6,aside,blockquote,ul,ol,li,table,pre,figure,nav,button,a,'
    '.prayer-rubric,.prayer-source,.reading-rubric,.reading-acclamation,.section-ref,'
    '.psalm-strophe,.psalm-verse-text,.alleluia-verse,.liturgical-rubric,.liturgical-heading,'
    '.liturgical-service-heading,.liturgical-reference,.liturgical-reading-reference,'
    '.liturgical-subheading,.psalm-metadata,.psalm-subtitle,.office-reading-pericope-title,'
    '.mass-rubric,.mass-comment,.mass-posture,.mass-alternative,.mass-response,'
    '.mass-major,.mass-subsection,.mass-minor-heading,.mass-acclamation,.mass-invocation,.mass-option,'
    '.devotional-office,[data-liturgical-heading],[data-liturgical-subheading],'
    '[data-liturgical-reference],[data-psalm-strophe],[data-reader-structure]';
const _structured =
    'br,.prayer-speaker,.mass-role,.mass-speaker,[data-office-speaker],.passion__role';

String prepareReaderProseHtml(String html) {
  final fragment = parseFragment(html);
  final excluded = fragment.querySelectorAll(_excluded).toSet();
  for (final paragraph in fragment.querySelectorAll('p')) {
    paragraph.classes.remove('reader-prose');
    bool insideExcluded(dom.Element element) =>
        excluded.contains(element) ||
        (element.parent != null && insideExcluded(element.parent!));
    if (insideExcluded(paragraph) ||
        paragraph.querySelector(_structured) != null) {
      continue;
    }
    final children = paragraph.nodes
        .where((node) => node is! dom.Text || node.text.trim().isNotEmpty)
        .toList();
    if (children.length == 1 &&
        children.single is dom.Element &&
        {
          'em',
          'i',
          'strong',
          'b',
          'a',
        }.contains((children.single as dom.Element).localName)) {
      continue;
    }
    if (paragraph.querySelector('[style*="color"],font[color]') != null ||
        RegExp(
          r'text-align\s*:\s*(?:center|right)',
          caseSensitive: false,
        ).hasMatch(paragraph.attributes['style'] ?? '') ||
        RegExp(
          r'^(?:\d+\s*)?Ант\.|^[КСНДЛЦVR]\.|^(?:Рэфрэн|ККК)\s',
          caseSensitive: false,
        ).hasMatch(paragraph.text.trim())) {
      continue;
    }
    if (paragraph.text.trim().isNotEmpty) paragraph.classes.add('reader-prose');
  }
  return fragment.nodes
      .map((node) => node is dom.Element ? node.outerHtml : node.text)
      .join();
}
