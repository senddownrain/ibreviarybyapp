import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';

/// Presentation profiles audited against WEB #146, merge 6e0b708.
const devotionalOfficeProfiles = {
  'mybrev-devotion-office-for-dead-laudes': 'laudes',
  'mybrev-devotion-office-for-dead-vesper': 'vesper',
  'mybrev-devotion-blessed-virgin-mary-laudes': 'laudes',
  'mybrev-devotion-blessed-virgin-mary-vesper': 'vesper',
  'catholicby-yearcycle-100116': 'gadzinki',
};
const devotionalDeadIntentions = [
  'За аднаго памерлага',
  'За адну памерлую',
  'За некалькіх',
  'За братоў, блізкіх і дабрадзеяў',
];
const gadzinkiParts = [
  'Ютрань',
  'Першая гадзіна',
  'Трэцяя гадзіна',
  'Шостая гадзіна',
  'Дзевятая гадзіна',
  'Нешпары',
  'Напрыканцы дня',
  'Ахвяраванне Гадзінак',
];
const _officeParts = [
  'Пачатак',
  'Гімн',
  'Псальмодыя',
  'Кароткае чытанне і рэспансорый',
  '',
  'Просьбы',
  'Ойча наш',
  'Малітва',
  'Завяршэнне',
  'Іншыя варыянты частак Гадзіны',
];
final _antiphon = RegExp(
  r'^((?:[1-3]\s*)?ант\.(?:\s+да\s+песні\s+(?:Захарыі|Марыі))?:?)(\s*)([\s\S]*)$',
  caseSensitive: false,
);
final _psalmTitle = RegExp(r'^(Псальм|Песня)\s+.+$', caseSensitive: false);
final _reading = RegExp(
  r'^Кароткае\s+чытанне(?:\s+(.+))?$',
  caseSensitive: false,
);
String _unmark(String text) => text
    .trim()
    .replaceFirstMapped(
      RegExp(r'^(?:\*\*|__)([\s\S]*)(?:\*\*|__)$'),
      (m) => m[1]!,
    )
    .trim();

/// Exact source ranges stay available even for alternatives hidden by the UI.
class DevotionalBlock {
  const DevotionalBlock(
    this.kind,
    this.source,
    this.text,
    this.start,
    this.end, {
    this.level = 0,
  });
  final String kind, source, text;
  final int start, end, level;
}

class DevotionalAlternative {
  DevotionalAlternative(this.title, Iterable<DevotionalBlock> blocks)
    : blocks = List.unmodifiable(blocks);
  final String title;
  final List<DevotionalBlock> blocks;
}

class DevotionalSection {
  DevotionalSection(
    this.type,
    this.title,
    Iterable<DevotionalBlock> blocks, [
    Iterable<DevotionalAlternative> alternatives = const [],
  ]) : blocks = List.unmodifiable(blocks),
       alternatives = List.unmodifiable(alternatives);
  final String type, title;
  final List<DevotionalBlock> blocks;
  final List<DevotionalAlternative> alternatives;
}

class DevotionalChoice {
  const DevotionalChoice(this.label, this.sourceIndex);
  final String label;
  final int sourceIndex;
}

class DevotionalOfficeDocument {
  DevotionalOfficeDocument(
    this.prayerId,
    this.profile,
    this.source,
    Iterable<DevotionalBlock> blocks,
    Iterable<DevotionalSection> sections,
  ) : sourceBlocks = List.unmodifiable(blocks),
      sections = List.unmodifiable(sections);
  final String prayerId, profile, source;
  final List<DevotionalBlock> sourceBlocks;
  final List<DevotionalSection> sections;
  bool get forDead => prayerId.startsWith('mybrev-devotion-office-for-dead-');
  bool get forMary =>
      prayerId.startsWith('mybrev-devotion-blessed-virgin-mary-');

  List<DevotionalChoice> choices(DevotionalSection section) {
    if (!forMary) return const [];
    final wanted = section.type == 'intercessions'
        ? [
            (
              'Просьбы — Варыянт 2',
              profile == 'laudes'
                  ? 'Аб чысціні і нябеснай славе'
                  : 'Аб сям’і і тых, хто ў патрэбе',
            ),
          ]
        : section.type == 'prayer'
        ? [
            ('Малітва — Варыянт 2', 'Аб прабачэнні'),
            ('Малітва — Варыянт 3', 'Аб выпраўленні жыцця'),
            ('Малітва — Варыянт 4', 'Аб абароне'),
            ('Малітва — Варыянт 5', 'Аб Божай ласцы'),
          ]
        : <(String, String)>[];
    if (wanted.isEmpty) return const [];
    final options = <DevotionalChoice>[];
    for (final (title, label) in wanted) {
      final index = section.alternatives.indexWhere((a) => a.title == title);
      if (index < 0) return const [];
      options.add(DevotionalChoice(label, index + 1));
    }
    return [
      DevotionalChoice(
        section.type == 'prayer'
            ? 'Агульная'
            : profile == 'laudes'
            ? 'Аб жыцці ў Хрысце'
            : 'Аб Касцёле і збаўленні',
        0,
      ),
      ...options,
    ];
  }

  List<DevotionalBlock> selectedBlocks(
    DevotionalSection section, {
    int? intention,
    int choice = 0,
  }) {
    if (forDead && {'hymn', 'prayer'}.contains(section.type)) {
      if (intention == null ||
          intention < 0 ||
          intention >= devotionalDeadIntentions.length) {
        return const [];
      }
      final title = section.type == 'hymn'
          ? switch (intention) {
              1 => 'Гімн — За адну памерлую',
              2 || 3 => 'Гімн — За некалькіх',
              _ => null,
            }
          : switch (intention) {
              2 => 'Малітва — За некалькіх',
              3 => 'Малітва — За братоў, блізкіх і дабрадзеяў',
              _ => null,
            };
      final option = title == null
          ? -1
          : section.alternatives.indexWhere((a) => a.title == title);
      if (title != null && option < 0) return const [];
      final blocks = option < 0
          ? section.blocks
          : [
              section.blocks.first,
              ...section.alternatives[option].blocks.skip(1),
            ];
      final label = section.type == 'hymn'
          ? (title?.substring('Гімн — '.length) ?? 'За аднаго памерлага')
          : (title?.substring('Малітва — '.length) ??
                'За аднаго памерлага або адну памерлую — 1');
      // Remove only the observed, single-line editorial label in its exact slot.
      final labelIndex = section.type == 'hymn' ? blocks.length - 2 : 1;
      return [
        for (var i = 0; i < blocks.length; i++)
          if (!(i == labelIndex &&
              blocks[i].kind == 'text' &&
              blocks[i].source.trim() == '$label:' &&
              blocks[i].end - blocks[i].start == 1))
            blocks[i],
      ];
    }
    final options = choices(section);
    final selected = choice >= 0 && choice < options.length
        ? options[choice].sourceIndex
        : 0;
    if (selected == 0) return section.blocks;
    return [
      section.blocks.first,
      ...section.alternatives[selected - 1].blocks
          .skip(1)
          .where(
            (b) => !RegExp(
              r'^(?:Або|Або іншыя):$',
              caseSensitive: false,
            ).hasMatch(b.text.trim()),
          ),
    ];
  }
}

String _kind(String text) {
  final plain = _unmark(text);
  if (_antiphon.hasMatch(plain)) return 'antiphon';
  if (_psalmTitle.hasMatch(plain)) return 'psalmTitle';
  if (_reading.hasMatch(plain) && plain != 'Кароткае чытанне і рэспансорый') {
    return 'readingTitle';
  }
  if (plain.toLowerCase() == 'кароткі рэспансорый') return 'responseTitle';
  return 'text';
}

/// Line-preserving blocks for the audited Markdown dialect. Fenced code and
/// rubric bodies are opaque: apparent headings inside them never select a reader.
List<DevotionalBlock> devotionalSourceBlocks(String source) {
  final lines = source.replaceAll(RegExp(r'\r\n?'), '\n').split('\n');
  final blocks = <DevotionalBlock>[];
  var i = 0;
  while (i < lines.length) {
    if (lines[i].trim().isEmpty) {
      i++;
      continue;
    }
    final start = i;
    final row = lines[i].trim();
    if (row == ':::rubric' || row.startsWith('```') || row.startsWith('~~~')) {
      final close = row == ':::rubric' ? ':::' : row.substring(0, 3);
      i++;
      while (i < lines.length && !lines[i].trim().startsWith(close)) {
        i++;
      }
      if (i < lines.length) i++;
      final raw = lines.sublist(start, i).join('\n');
      blocks.add(
        DevotionalBlock(
          row == ':::rubric' ? 'rubric' : 'text',
          raw,
          raw,
          start,
          i,
        ),
      );
      continue;
    }
    final heading = RegExp(r'^(#{1,6})\s+(.+?)\s*#*\s*$').firstMatch(row);
    if (heading != null) {
      i++;
      final title = _unmark(heading[2]!);
      blocks.add(
        DevotionalBlock(
          'heading',
          lines[start],
          title,
          start,
          i,
          level: heading[1]!.length,
        ),
      );
      continue;
    }
    if (RegExp(r'^(?:---+|\*\*\*+|___+)\s*$').hasMatch(row)) {
      i++;
      blocks.add(DevotionalBlock('separator', lines[start], row, start, i));
      continue;
    }
    final kind = _kind(lines[i]);
    i++;
    if (kind == 'text') {
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !RegExp(r'^(?:#{1,6}\s|:::|```|~~~)').hasMatch(lines[i].trim()) &&
          _kind(lines[i]) == 'text') {
        i++;
      }
    }
    final raw = lines.sublist(start, i).join('\n');
    blocks.add(DevotionalBlock(kind, raw, raw, start, i));
  }
  return blocks;
}

String _sectionType(String title) => switch (title) {
  'Пачатак' => 'intro',
  'Гімн' => 'hymn',
  'Псальмодыя' => 'psalmody',
  'Кароткае чытанне і рэспансорый' => 'reading',
  'Просьбы' => 'intercessions',
  'Ойча наш' => 'ourFather',
  'Малітва' => 'prayer',
  'Завяршэнне' => 'ending',
  'Іншыя варыянты частак Гадзіны' => 'alternatives',
  _ => 'canticle',
};
String? _alternativeType(String title) => switch (title.split(' — ').first) {
  'Гімн' => 'hymn',
  'Трэці псальм' => 'psalmody',
  'Чытанне і рэспансорый' => 'reading',
  'Антыфона да песні Захарыі' || 'Антыфона да песні Марыі' => 'canticle',
  'Просьбы' => 'intercessions',
  'Малітва' => 'prayer',
  _ => null,
};

/// Strict allowlist AND observed structure. Future/malformed content falls back
/// to PrayerContent, retaining the ordinary safe Markdown behavior.
DevotionalOfficeDocument? parseDevotionalOffice(Prayer prayer) {
  final profile = devotionalOfficeProfiles[prayer.id];
  if (profile == null || !prayer.isMarkdown) return null;
  final source = prayer.displayText;
  final blocks = devotionalSourceBlocks(source);
  final headings = blocks.where((b) => b.level == 2).toList();
  final expected = profile == 'gadzinki' ? gadzinkiParts : _officeParts;
  if (headings.length != expected.length) return null;
  for (var i = 0; i < expected.length; i++) {
    if (profile != 'gadzinki' && i == 4) {
      final name = profile == 'laudes' ? 'Захарыі' : 'Марыі';
      final ref = profile == 'laudes' ? '68[–-]79' : '46[–-]55';
      if (!RegExp(
        '^Песня $name \\(Лк 1, $ref\\)\$',
      ).hasMatch(headings[i].text)) {
        return null;
      }
    } else if (headings[i].text != expected[i]) {
      return null;
    }
  }
  final sections = <DevotionalSection>[];
  var current = <DevotionalBlock>[];
  String title = '', type = 'intro';
  void flush() {
    if (current.isNotEmpty) {
      sections.add(DevotionalSection(type, title, current));
    }
  }

  for (final block in blocks) {
    if (block.level == 2) {
      flush();
      current = [];
      title = block.text;
      type = profile == 'gadzinki' ? 'gadzinkiPart' : _sectionType(title);
    }
    current.add(block);
  }
  flush();
  if (profile != 'gadzinki') {
    final psalmody = sections.firstWhere((s) => s.type == 'psalmody');
    if (psalmody.blocks.where((b) => b.kind == 'psalmTitle').length != 3 ||
        psalmody.blocks.where((b) => b.kind == 'antiphon').length != 6) {
      return null;
    }
    final sourceSection = sections.last;
    final options = <DevotionalAlternative>[];
    var option = <DevotionalBlock>[];
    final unattached = <DevotionalBlock>[];
    void flushOption() {
      if (option.isNotEmpty) {
        options.add(DevotionalAlternative(option.first.text, option));
      }
    }

    for (final b in sourceSection.blocks.skip(1)) {
      if (b.level == 3) {
        flushOption();
        option = [b];
      } else if (option.isNotEmpty) {
        option.add(b);
      } else {
        unattached.add(b);
      }
    }
    flushOption();
    for (var i = 0; i < sections.length - 1; i++) {
      final s = sections[i];
      sections[i] = DevotionalSection(
        s.type,
        s.title,
        s.blocks,
        options.where((a) => _alternativeType(a.title) == s.type),
      );
    }
    sections[sections.length -
        1] = DevotionalSection('alternatives', sourceSection.title, [
      sourceSection.blocks.first,
      ...unattached,
      for (final a in options.where((a) => _alternativeType(a.title) == null))
        ...a.blocks,
    ]);
  }
  return DevotionalOfficeDocument(prayer.id, profile, source, blocks, sections);
}

/// Display groups retain their original blocks; psalm strophes share one choir
/// renderer, and the two metadata lines never enter the alternating body.
class DevotionalItem {
  DevotionalItem(
    this.kind,
    Iterable<DevotionalBlock> blocks, {
    this.reference = '',
  }) : blocks = List.unmodifiable(blocks);
  final String kind, reference;
  final List<DevotionalBlock> blocks;
  String get source => blocks.map((b) => b.source).join('\n\n');
  String get text => blocks.first.text;
}

List<DevotionalItem> devotionalDisplayItems(
  DevotionalSection section,
  List<DevotionalBlock> blocks,
) {
  final items = <DevotionalItem>[];
  final psalm = {'psalmody', 'canticle'}.contains(section.type);
  var inWork = section.type == 'canticle', responsory = false, metadata = 0;
  bool cadence(DevotionalBlock b) => RegExp(r'[*†]').hasMatch(b.source);
  bool italic(DevotionalBlock b) =>
      RegExp(r'^_[\s\S]+_$').hasMatch(b.source.trim());
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    if (b.level == 2 || b.level == 1) continue;
    var kind = b.kind;
    var reference = '';
    if (psalm) {
      if (kind == 'antiphon') inWork = false;
      if (kind == 'psalmTitle') {
        inWork = true;
        final tail = blocks.skip(i + 1).take(3).toList();
        if (tail.length >= 2 && tail[0].kind == 'text' && !cadence(tail[0])) {
          if (italic(tail[0]) && tail[1].kind == 'text' && cadence(tail[1])) {
            metadata = 1;
          } else if (tail.length == 3 &&
              tail[1].kind == 'text' &&
              italic(tail[1]) &&
              tail[2].kind == 'text' &&
              cadence(tail[2])) {
            metadata = 2;
          }
        }
      } else if (metadata > 0 && kind == 'text') {
        kind = 'psalmMeta';
        metadata--;
      } else if (kind == 'text' && (inWork || section.type == 'canticle')) {
        kind = 'psalmBody';
      }
    } else {
      if (kind == 'readingTitle') {
        reference = _reading.firstMatch(_unmark(b.text))?[1] ?? '';
        responsory = false;
      }
      if (kind == 'responseTitle') responsory = true;
      if (responsory && kind == 'text') kind = 'responsoryBody';
      if (b.level > 0) responsory = false;
    }
    if ({'psalmBody', 'responsoryBody'}.contains(kind) &&
        items.isNotEmpty &&
        items.last.kind == kind) {
      final previous = items.removeLast();
      items.add(DevotionalItem(kind, [...previous.blocks, b]));
    } else {
      items.add(DevotionalItem(kind, [b], reference: reference));
    }
  }
  return items;
}

/// Safe Markdown first; then mark only line-initial speaker labels. No source
/// HTML or arbitrary attributes can enter this presentation transformation.
String devotionalSpeakerHtml(String source, {bool responsory = false}) {
  if (responsory) {
    source = source.replaceAllMapped(
      RegExp(r'(^|\s)((?:\*\*|__)?[КН]\.(?::)?(?:\*\*|__)?)'),
      (m) => '${m[1]}\n${m[2]}',
    );
    source = source
        .trim()
        .split(RegExp(r'\n\s*\n|\n'))
        .where((l) => l.trim().isNotEmpty)
        .join('\n');
  }
  final root = parseFragment(
    prayerMarkdownToHtml(source, recognizeSpeakers: false),
  );
  final prefix = RegExp(
    r'^(\s*)(Кантар:|Мол[іi]мся:|[КНС](?:\.:|\.|:))',
    caseSensitive: false,
  );
  for (final paragraph in root.querySelectorAll('p')) {
    var start = true;
    for (final node in paragraph.nodes.toList()) {
      if (node is dom.Element && node.localName == 'br') {
        start = true;
        continue;
      }
      if (!start) continue;
      final value = node is dom.Text
          ? node.text
          : node is dom.Element && node.localName == 'strong'
          ? node.text
          : '';
      if (value.trim().isEmpty) continue;
      final match = prefix.firstMatch(value);
      if (match != null) {
        final label = dom.Element.tag('span')
          ..classes.add('prayer-speaker')
          ..text = match[2]!;
        final tail = value.substring(match.end);
        final index = paragraph.nodes.indexOf(node);
        final bold = node is dom.Element && node.localName == 'strong';
        node.replaceWith(label);
        if (tail.isNotEmpty) {
          paragraph.nodes.insert(
            index + 1,
            bold ? (dom.Element.tag('strong')..text = tail) : dom.Text(tail),
          );
        }
        if (match[1]!.isNotEmpty) {
          paragraph.nodes.insert(index, dom.Text(match[1]!));
        }
      }
      start = false;
    }
  }
  return root.outerHtml;
}
