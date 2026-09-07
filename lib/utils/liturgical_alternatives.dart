import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/utils/liturgical_html.dart';

const _maxTitleLength = 56;
final _alternativeMarker = RegExp(
  r'^\s*А\s*бо(?:\s+(?:інш(?:ае|ая|ыя)|яшчэ))?\s*:',
  caseSensitive: false,
);
final _categoryMarker = RegExp(
  r'^\s*(?:Пра|За|Для)\s+[^:]{1,72}\s*:',
  caseSensitive: false,
);
final _instructionMarker = RegExp(
  r'^(?:Калі\s+няма\s+ўласнай|Чытаецца\s+на\s+выбар|На\s+выбар)\b',
  caseSensitive: false,
);
final _repeatedSectionMarker = RegExp(
  r'^(?:Кароткае\s+чытанне|Гімн)\b',
  caseSensitive: false,
);
final _gospelCycleMarker = RegExp(
  r'^Год\s+([АAВBСC])\s*:',
  caseSensitive: false,
);

class LiturgicalAlternative {
  const LiturgicalAlternative({required this.title, required this.html});

  final String title;
  final String html;
}

class _RawAlternative {
  const _RawAlternative(this.html, [this.explicitTitle = '']);

  final String html;
  final String explicitTitle;
}

List<LiturgicalAlternative> getLiturgicalAlternatives(
  String html, {
  String kind = 'generic',
}) {
  final source = html.trim();
  if (source.isEmpty) return const [];

  final root = parseFragment(source);
  final structured = kind == 'gospel-antiphon'
      ? (_gospelCycleAlternatives(root) ?? _structuredAlternatives(root))
      : _structuredAlternatives(root);
  final raw = structured ?? _splitAtRules(root);
  final unique = <_RawAlternative>[];
  final seen = <String>{};
  for (final option in raw) {
    final key = _substantiveText(option.html);
    if (key.isEmpty || !seen.add(key)) continue;
    unique.add(option);
  }

  final titleCounts = <String, int>{};
  final options = <LiturgicalAlternative>[];
  for (var index = 0; index < unique.length; index++) {
    final option = unique[index];
    var title = _optionTitle(option, index, kind);
    final count = (titleCounts[title] ?? 0) + 1;
    titleCounts[title] = count;
    if (count > 1) title = _shorten('$title · $count');
    options.add(
      LiturgicalAlternative(
        title: title,
        html: removeBreakAfterAsterisk(option.html),
      ),
    );
  }
  return options.isNotEmpty
      ? options
      : [
          LiturgicalAlternative(
            title: 'Варыянт 1',
            html: removeBreakAfterAsterisk(source),
          ),
        ];
}

bool hasLiturgicalAlternatives(String html, {String kind = 'generic'}) =>
    getLiturgicalAlternatives(html, kind: kind).length > 1;

List<Node> _directNodes(DocumentFragment root) => List<Node>.from(root.nodes);

List<Element> _directElements(DocumentFragment root) =>
    root.nodes.whereType<Element>().toList();

String _nodeHtml(Node node) =>
    node is Element ? node.outerHtml : node.text ?? '';

String _textOf(String value) => (parseFragment(value).text ?? '')
    .replaceAll(RegExp(r'&nbsp;|&#x0*20;', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _isMarkerText(String text) =>
    _alternativeMarker.hasMatch(text) ||
    _categoryMarker.hasMatch(text) ||
    _instructionMarker.hasMatch(text);

bool _isAlternativeBoundary(Element element) =>
    element.localName == 'p' && _isMarkerText(_textOf(element.outerHtml));

List<_RawAlternative> _splitAtRules(DocumentFragment root) {
  final nodes = _directNodes(root);
  final hasRule = nodes.any(
    (node) => node is Element && node.localName == 'hr',
  );
  final repeated = <String, int>{};
  if (!hasRule) {
    for (final node in nodes.whereType<Element>()) {
      if (node.localName != 'p') continue;
      final marker = _repeatedSectionMarker.firstMatch(_textOf(node.outerHtml));
      final key = marker?.group(0)?.toLowerCase();
      if (key != null) repeated[key] = (repeated[key] ?? 0) + 1;
    }
  }

  final groups = <List<String>>[[]];
  for (final node in nodes) {
    if (node is Element && node.localName == 'hr') {
      if (groups.last.isNotEmpty) groups.add([]);
      continue;
    }
    String marker = '';
    if (node is Element && node.localName == 'p') {
      marker =
          _repeatedSectionMarker
              .firstMatch(_textOf(node.outerHtml))
              ?.group(0)
              ?.toLowerCase() ??
          '';
    }
    final startsNew =
        !hasRule &&
        groups.last.isNotEmpty &&
        ((node is Element && _isAlternativeBoundary(node)) ||
            (marker.isNotEmpty && (repeated[marker] ?? 0) > 1));
    if (startsNew) groups.add([]);
    groups.last.add(_nodeHtml(node));
  }
  return groups
      .map((group) => group.join('\n').trim())
      .where((value) => value.isNotEmpty)
      .map(_RawAlternative.new)
      .toList();
}

List<_RawAlternative>? _structuredAlternatives(DocumentFragment root) {
  final elements = _directElements(root);
  final blocks = elements
      .where(
        (element) => element.attributes.containsKey('data-alternative-title'),
      )
      .toList();
  if (blocks.length < 2) return null;
  final suffixes = elements
      .where(
        (element) => element.attributes.containsKey('data-alternative-suffix'),
      )
      .toList();
  final excluded = <Node>{...blocks, ...suffixes};
  final shared = root.nodes
      .where((node) => !excluded.contains(node))
      .map(_nodeHtml)
      .join('\n')
      .trim();
  final suffix = suffixes.map((element) => element.innerHtml.trim()).join('\n');
  return blocks
      .map(
        (block) => _RawAlternative(
          [
            shared,
            block.innerHtml.trim(),
            suffix,
          ].where((part) => part.isNotEmpty).join('\n'),
          block.attributes['data-alternative-title'] ?? '',
        ),
      )
      .toList();
}

List<_RawAlternative>? _gospelCycleAlternatives(DocumentFragment root) {
  final shared = <String>[];
  final options = <({String title, List<String> parts})>[];
  ({String title, List<String> parts})? current;
  for (final element in _directElements(root)) {
    if (element.localName != 'p') {
      (current?.parts ?? shared).add(element.outerHtml);
      continue;
    }
    final attributes = element.attributes.entries
        .map((entry) => '${entry.key}="${entry.value}"')
        .join(' ');
    final prefix = attributes.isEmpty ? '' : ' $attributes';
    final lines = element.innerHtml
        .split(RegExp(r'<br\s*/?>', caseSensitive: false))
        .where((line) => _textOf(line).isNotEmpty);
    for (final line in lines) {
      final match = _gospelCycleMarker.firstMatch(_textOf(line));
      final lineHtml = '<p$prefix>${line.trim()}</p>';
      if (match != null) {
        current = (
          title: 'Год ${match.group(1)!.toUpperCase()}',
          parts: <String>[lineHtml],
        );
        options.add(current);
      } else {
        (current?.parts ?? shared).add(lineHtml);
      }
    }
  }
  if (options.length < 2) return null;
  final common = shared.join('\n');
  return options
      .map(
        (option) => _RawAlternative(
          [common, ...option.parts].where((part) => part.isNotEmpty).join('\n'),
          option.title,
        ),
      )
      .toList();
}

String _substantiveText(String html) {
  final root = parseFragment(html);
  final paragraphs = root.querySelectorAll('p');
  final texts = (paragraphs.isEmpty ? <Node>[root] : paragraphs)
      .map((node) => _textOf(_nodeHtml(node)))
      .map(
        (text) => text
            .replaceFirst(_alternativeMarker, '')
            .replaceFirst(_categoryMarker, '')
            .replaceFirst(
              RegExp(
                r'^(?:Калі\s+няма\s+ўласнай|Чытаецца\s+на\s+выбар|На\s+выбар)[^:]{0,160}:\s*',
                caseSensitive: false,
              ),
              '',
            )
            .replaceFirst(RegExp(r'^\d{1,2}[.)]\s*'), '')
            .trim(),
      )
      .where((text) => text.isNotEmpty);
  return texts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

String _shorten(String value, [int maxLength = _maxTitleLength]) {
  final text = value
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceFirst(RegExp(r'\s*[:.;,–—-]+$'), '');
  if (text.length <= maxLength) return text;
  final length = maxLength - 1;
  final slice = text.substring(0, length + 1);
  final boundary = slice.lastIndexOf(' ');
  return '${slice.substring(0, boundary > 28 ? boundary : length).trim()}…';
}

List<String> _paragraphTexts(String html) {
  final root = parseFragment(html);
  final paragraphs = root.querySelectorAll('p');
  return (paragraphs.isEmpty ? <Node>[root] : paragraphs)
      .map((node) => _textOf(_nodeHtml(node)))
      .where((text) => text.isNotEmpty)
      .toList();
}

String _categoryTitle(List<String> paragraphs) {
  for (final paragraph in paragraphs.take(3)) {
    final match = _categoryMarker.firstMatch(paragraph);
    if (match != null) {
      return _shorten(match.group(0)!.replaceFirst(RegExp(r'\s*:\s*$'), ''));
    }
  }
  return '';
}

String _firstVerseLine(String html) {
  final lines = html.replaceAll(
    RegExp(r'<br\s*/?>', caseSensitive: false),
    '\n',
  );
  for (final line in lines.split('\n')) {
    final text = _textOf(line);
    if (text.isNotEmpty &&
        !RegExp(
          r'^(?:Гімн|А\s*бо|Пра\s+[^:]+):?$',
          caseSensitive: false,
        ).hasMatch(text)) {
      return text;
    }
  }
  return '';
}

String _readingTitle(List<String> paragraphs) {
  for (final paragraph in paragraphs.take(4)) {
    final match = RegExp(
      r'Кароткае\s+чытанне\s+(.{1,42})$',
      caseSensitive: false,
    ).firstMatch(paragraph);
    if (match != null) return _shorten(match.group(1)!);
  }
  for (final paragraph in paragraphs.take(4)) {
    if (RegExp(r'\d').hasMatch(paragraph) &&
        RegExp(r'(?:пар\.|[А-ЯЁІЎ][а-яёіў]{0,5})\s*\d').hasMatch(paragraph)) {
      return _shorten(
        paragraph.replaceFirst(
          RegExp(r'^(?:Першае|Другое)\s+чытанне\s*', caseSensitive: false),
          '',
        ),
      );
    }
  }
  return '';
}

String _optionTitle(_RawAlternative option, int index, String kind) {
  if (option.explicitTitle.isNotEmpty) return _shorten(option.explicitTitle);
  final paragraphs = _paragraphTexts(option.html);
  final category = _categoryTitle(paragraphs);
  if (category.isNotEmpty) return category;
  if (kind == 'reading') {
    final reading = _readingTitle(paragraphs);
    if (reading.isNotEmpty) return reading;
  }
  if (kind == 'hymn' || kind == 'marian-antiphon') {
    final line = _firstVerseLine(option.html);
    if (line.isNotEmpty) return _shorten(line);
  }
  if (kind == 'prayer' || paragraphs.any(_instructionMarker.hasMatch)) {
    return 'Варыянт ${index + 1}';
  }
  for (final text in paragraphs) {
    if (!_isMarkerText(text) &&
        !RegExp(
          r'^(?:Гімн|Кароткае чытанне)$',
          caseSensitive: false,
        ).hasMatch(text) &&
        text.length <= _maxTitleLength) {
      return _shorten(text);
    }
  }
  return 'Варыянт ${index + 1}';
}

String formatIntercessions(String html) {
  final root = parseFragment(html);
  final normalized = <String>[];
  for (final node in root.nodes) {
    if (node is! Element ||
        node.localName != 'p' ||
        !node.innerHtml.contains(RegExp(r'<br\s*/?>', caseSensitive: false))) {
      normalized.add(_nodeHtml(node));
      continue;
    }
    final attrs = node.attributes.entries
        .map((entry) => '${entry.key}="${entry.value}"')
        .join(' ');
    final prefix = attrs.isEmpty ? '' : ' $attrs';
    for (final line in node.innerHtml.split(
      RegExp(r'<br\s*/?>', caseSensitive: false),
    )) {
      if (_textOf(line).isNotEmpty) normalized.add('<p$prefix>$line</p>');
    }
  }
  final parsed = parseFragment(normalized.join('\n'));
  final paragraphs = parsed.querySelectorAll('p');
  if (paragraphs.isEmpty) return html;

  var refrain = paragraphs.indexWhere(
    (paragraph) =>
        paragraphs.indexOf(paragraph) < 3 &&
        paragraph.querySelector('em') != null,
  );
  if (refrain < 0) {
    for (var index = 1; index < paragraphs.length && index <= 3; index++) {
      final previous = _textOf(paragraphs[index - 1].outerHtml);
      final current = _textOf(paragraphs[index].outerHtml);
      if (previous.endsWith(':') &&
          current.isNotEmpty &&
          current.length <= 120) {
        refrain = index;
        break;
      }
    }
  }
  final anchor = refrain >= 0 ? refrain : (paragraphs.length > 1 ? 1 : 0);
  final intro = anchor > 0 ? anchor - 1 : 0;
  final refrainText = _textOf(paragraphs[anchor].outerHtml);
  var separateLine = 0;
  for (var index = 0; index < paragraphs.length; index++) {
    final paragraph = paragraphs[index];
    final text = _textOf(paragraph.outerHtml);
    if (index == intro) paragraph.classes.add('intercessions__intro');
    if (index == anchor) paragraph.classes.add('intercessions__refrain');
    if (index <= anchor) continue;
    if (RegExp(r'^Ойча\s+наш\.?$', caseSensitive: false).hasMatch(text)) {
      paragraph.classes.add('intercessions__conclusion');
    } else if (text == refrainText) {
      paragraph.classes.addAll([
        'intercessions__refrain',
        'intercessions__refrain--repeat',
      ]);
    } else {
      separateLine += 1;
      paragraph.classes.add(
        separateLine.isOdd
            ? 'intercessions__petition'
            : 'intercessions__response',
      );
    }
  }
  return parsed.nodes.map(_nodeHtml).join();
}
