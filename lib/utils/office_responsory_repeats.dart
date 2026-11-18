import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

/// Expands only verifiable repeats from the SAME responsory for display.
/// This must not touch Firestore, the offline bundle, or adjacent alternatives.
final _words = RegExp(r"[\p{L}\p{N}]+(?:[’'ʼ][\p{L}\p{N}]+)*", unicode: true);
final _speaker = RegExp(r'^\s*([КН])\.\s*', unicode: true);

String _visible(dom.Element? element) => (element?.text ?? '')
    .replaceAll('\u00a0', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
String _role(dom.Element? element) =>
    _speaker.firstMatch(_visible(element))?.group(1) ?? '';
String _body(dom.Element? element) =>
    _visible(element).replaceFirst(_speaker, '');
List<RegExpMatch> _tokens(String value) => _words.allMatches(value).toList();

// Belarusian Ў/ў at the start of the source continuation is written У/у
// when it starts a standalone reply. The rest of the line is compared verbatim.
String _comparable(String word, int index) {
  final lower = word.toLowerCase();
  return index == 0 ? lower.replaceFirst(RegExp(r'^ў'), 'у') : lower;
}

dom.Text? _lastText(dom.Node node) {
  if (node is dom.Text && node.data.trim().isNotEmpty) return node;
  for (final child in node.nodes.reversed) {
    final result = _lastText(child);
    if (result != null) return result;
  }
  return null;
}

bool _expand(dom.Element target, String expected) {
  if (_role(target) != 'Н') return false;
  final actual = _tokens(_body(target));
  final wanted = _tokens(expected);
  if (actual.isEmpty || actual.length >= wanted.length) return false;
  for (var index = 0; index < actual.length; index++) {
    if (_comparable(actual[index].group(0)!, index) !=
        _comparable(wanted[index].group(0)!, index)) {
      return false;
    }
  }
  final suffix = expected.substring(wanted[actual.length - 1].end);
  if (!RegExp(r'^\s').hasMatch(suffix) ||
      !RegExp(r'\p{L}', unicode: true).hasMatch(suffix)) {
    return false;
  }
  // Preserve the answer's original case (У, not ў) and inline markup.
  // Remove only abbreviation-ending punctuation and append attested words.
  final last = _lastText(target);
  if (last != null) {
    last.data = last.data.replaceFirst(RegExp(r'[.!?…]+(?=\s*$)'), '');
  }
  target.nodes.add(dom.Text(suffix));
  return true;
}

bool _turn(dom.Element? item, String speaker) =>
    item != null &&
    const {'p', 'div'}.contains(item.localName) &&
    item.querySelector('p, div') == null &&
    _role(item) == speaker;

({String text, dom.Element? next})? _tail(dom.Element opening) {
  final content = _body(opening);
  if ('*'.allMatches(content).length != 1) return null;
  final suffix = content.substring(content.indexOf('*') + 1).trim();
  if (suffix.isNotEmpty) {
    return (text: suffix, next: opening.nextElementSibling);
  }
  // A few older sources put the continuation after '*' in a separate p.
  final sibling = opening.nextElementSibling;
  final line = _visible(sibling);
  if (sibling == null ||
      !const {'p', 'div'}.contains(sibling.localName) ||
      sibling.querySelector('p, div') != null ||
      _role(sibling).isNotEmpty ||
      RegExp(r'^(Рэспансорый|Кароткі|Першае|Другое|Або)', caseSensitive: false)
          .hasMatch(line) ||
      line.isEmpty) {
    return null;
  }
  return (text: line, next: sibling.nextElementSibling);
}

/// Called after alternatives are selected/office HTML is normalized.
/// No cross-sibling, cross-variant or unverified editorial substitutions.
String expandOfficeResponsoryRepeats(String source) {
  final fragment = parseFragment(source);
  var changed = false;
  final blocks = fragment.querySelectorAll('p, div')
      .where((node) => node.querySelector('p, div') == null)
      .toList();
  for (final opening in blocks) {
    if (_role(opening) == 'Н') {
      final tail = _tail(opening);
      if (tail == null) continue;
      final verse = tail.next;
      final repeated = verse?.nextElementSibling;
      if (_turn(verse, 'К') &&
          _turn(repeated, 'Н') &&
          identical(verse!.parentNode, opening.parentNode) &&
          identical(repeated!.parentNode, opening.parentNode)) {
        changed = _expand(repeated, tail.text) || changed;
      }
    } else if (_role(opening) == 'К') {
      final tail = _tail(opening);
      if (tail == null) continue;
      final first = tail.next;
      final verse = first?.nextElementSibling;
      final second = verse?.nextElementSibling;
      final doxology = second?.nextElementSibling;
      final last = doxology?.nextElementSibling;
      final replies = [first, verse, second, doxology, last];
      if (replies.any((item) => item == null ||
          !identical(item.parentNode, opening.parentNode)) ||
          !_turn(first, 'Н') || !_turn(verse, 'К') ||
          !_turn(second, 'Н') || !_turn(doxology, 'К') ||
          !_turn(last, 'Н') || !_body(doxology).startsWith('Хвала Айцу')) {
        continue;
      }
      final full = _body(opening);
      changed = _expand(first!, full) || changed;
      changed = _expand(second!, tail.text) || changed;
      changed = _expand(last!, full) || changed;
    }
  }
  return changed ? fragment.outerHtml : source;
}
