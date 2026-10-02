import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

import 'package:mybrev_flutter/models/mass_ritual.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/utils/mass_semantics.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';

// Mirrors MyBrev's tests/mass-content-v4.test.mjs: the adapter must give the
// same block types, roles and labels for the texts as they are in Firestore
// today ("before") and as the V4 migration leaves them ("after").

MassSemanticDocument _build(String language, String markdown) =>
    buildMassDocument(
      prayerMarkdownToHtml(markdown),
      kMassRitual.variant(language)!,
    );

dom.DocumentFragment _fragment(MassSemanticDocument doc) =>
    parseFragment(doc.chunks.map((c) => c.html).join());

List<String> _textsOf(MassSemanticDocument doc, String className) => [
  for (final e in _fragment(doc).querySelectorAll('.$className'))
    e.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
];

/// `type:role:label` of every block.
List<String> _shape(MassSemanticDocument doc) => [
  for (final b in doc.blocks)
    '${b.type}:${b.role ?? ''}:${b.speakerLabel ?? ''}',
];

String _compact(MassSemanticDocument doc) =>
    doc.blocks.map((b) => b.text).join().replaceAll(RegExp(r'\s+'), '');

MassBlock _find(MassSemanticDocument doc, String start) =>
    doc.blocks.firstWhere((b) => b.text.startsWith(start));

/// The block whose text is [call] and the one after it.
List<String> _dialogue(MassSemanticDocument doc, String call) {
  final index = doc.blocks.indexWhere((b) => b.text == call);
  return [
    for (final b in doc.blocks.sublist(index, index + 2))
      '${b.type}:${b.role}:${b.speakerLabel}',
  ];
}

const _majorIds = [
  'introductory-rites',
  'liturgy-of-the-word',
  'eucharistic-liturgy',
  'communion-rite',
  'concluding-rites',
];
const _majorTitles = [
  'Уступныя абрады',
  'Літургія слова',
  'Эўхарыстычная літургія',
  'Абрад Камуніі',
  'Заключныя абрады',
];
const _formerEnglishMajors = [
  'The Introductory Rites',
  'The Liturgy of the Word',
  'The Liturgy of the Eucharist',
  'The Communion Rite',
  'The Concluding Rites',
];

// Excerpts of the Firestore texts before the V4 migration, original markup.
const _beBefore = '''
### Уступныя абрады

:::rubric
Святар гаворыць:
:::

У імя Айца і Сына, і Духа Святога.

:::rubric
Народ адказвае:
:::

Амэн.

**Чын пакаяння**

:::rubric
Пасля гэтага гаворыцца Пане, змілуйся над намі:
:::

С.: Пане, змілуйся над намі.
Н.: Пане, змілуйся над намі.

**Хвала на вышынях Богу**

:::rubric
Затым, калі прадпісана, спяваецца ці прамаўляецца гімн:
:::

Хвала на вышынях Богу, а на зямлі супакой людзям добрай волі.

:::rubric
Усе разам са святаром пэўны час ціха моляцца.Потым святар, развёўшы рукі, гаворыць малітву дня (калекту), на заканчэнне якой народ адказвае:
:::

Амэн.

### **Літургія слова**

:::rubric
Потым спяваецца
:::

 Аллелюя

:::rubric
альбо іншы спеў, прадпісаны ў рубрыках, у залежнасці ад патрабаванняў літургічнага перыяду.
:::

### Эўхарыстычная літургія

II эўхарыстычная малітва

:::rubric
бярэ хлеб, трымае яго крыху ўзнятым над  алтаром і працягвае:
:::

**узяў хлеб і, падзяку Табе складаючы,
ламаў і раздаваў сваім вучням, кажучы:**

### Абрад Камуніі

:::rubric
Альбо:
:::

### Абрад заканчэння

Цэлебрант: Пан з вамі.
Усе:І з духам тваім.

Няхай благаславіць вас Бог усемагутны, Айцец і Сын,**X**і Дух Святы.''';

// The same excerpts as the V4 migration writes them.
const _beAfter = '''
## Уступныя абрады

:::rubric
Святар гаворыць:
:::

У імя Айца і Сына, і Духа Святога.

:::rubric
Народ адказвае:
:::

Амэн.

### Чын пакаяння

:::rubric
Пасля гэтага гаворыцца Пане, змілуйся над намі:
:::

С. Пане, змілуйся над намі.
Н. Пане, змілуйся над намі.

### Хвала на вышынях Богу

:::rubric
Затым, калі прадпісана, спяваецца ці прамаўляецца гімн:
:::

Хвала на вышынях Богу, а на зямлі супакой людзям добрай волі.

:::rubric
Усе разам са святаром пэўны час ціха моляцца. Потым святар, развёўшы рукі, гаворыць малітву дня (калекту), на заканчэнне якой народ адказвае:
:::

Амэн.

## Літургія слова

:::rubric
Потым спяваецца
:::

Аллелюя

:::rubric
альбо іншы спеў, прадпісаны ў рубрыках, у залежнасці ад патрабаванняў літургічнага перыяду.
:::

## Эўхарыстычная літургія

### II эўхарыстычная малітва

:::rubric
бярэ хлеб, трымае яго крыху ўзнятым над алтаром і працягвае:
:::

**узяў хлеб і, падзяку Табе складаючы,
ламаў і раздаваў сваім вучням, кажучы:**

## Абрад Камуніі

:::rubric
Альбо:
:::

## Заключныя абрады

Цэлебрант: Пан з вамі.
Усе: І з духам тваім.

Няхай благаславіць вас Бог усемагутны, Айцец і Сын, **X** і Дух Святы.''';

const _laBefore = '''
ЧИН МЕССЫ НА ЛАТИНСКОМ ЯЗЫКЕ

:::rubric
Вступительные обряды
:::

V. In nomine Patris, et Filii, et Spiritus Sancti.

R. Amen.

V. Gratia Domini nostri Iesu Christi, et caritas Dei, et communicatio Sancti Spiritus sit cum omnibus vobis.

Или:

V. Dominus vobiscum.

R. Et cum spiritu tuo.

V. Kyrie eleison.

R. Kyrie eleison.

Gloria in excelsis Deo et in terra pax hominibus bonae voluntatis.

:::rubric
Литургия Слова
:::

После чтения:

V. Verbum Domini.

R. Deo gratias.

V.

:::rubric
(После чтения)
:::

 Verbum Domini.

R. Laus tibi, Christe.

:::rubric
Исповедание веры
:::

Credo in unum Deum, Patrem omnipotentem.

:::rubric
Евхаристическая Литургия
:::

:::rubric
Вторая Евхаристическая молитва
:::

V. Vere dignum et iustum est, aequum et salutare, nos tibi, sancte Pater, semper et ubique gratias agere.

Et ideo cum Angelis et omnibus Sanctis gloriam tuam praedicamus, una voce dicentes:

R. Sanctus, Sanctus, Sanctus Dominus Deus Sabaoth.

:::rubric
Обряд причащения
:::

:::rubric
Заключительный обряд
:::

V. Ite, missa est.

R. Deo gratias.''';

const _laAfter = '''
#### ЧИН МЕССЫ НА ЛАТИНСКОМ ЯЗЫКЕ

## Уступныя абрады

V. In nomine Patris, et Filii, et Spiritus Sancti.

R. Amen.

V. Gratia Domini nostri Iesu Christi, et caritas Dei, et communicatio Sancti Spiritus sit cum omnibus vobis.

:::rubric
Или:
:::

V. Dominus vobiscum.

R. Et cum spiritu tuo.

V. Kyrie eleison.

R. Kyrie eleison.

Gloria in excelsis Deo et in terra pax hominibus bonae voluntatis.

## Літургія слова

:::rubric
После чтения:
:::

V. Verbum Domini.

R. Deo gratias.

:::rubric
(После чтения)
:::

V. Verbum Domini.

R. Laus tibi, Christe.

### Исповедание веры

Credo in unum Deum, Patrem omnipotentem.

## Эўхарыстычная літургія

### Вторая Евхаристическая молитва

V. Vere dignum et iustum est, aequum et salutare, nos tibi, sancte Pater, semper et ubique gratias agere.

Et ideo cum Angelis et omnibus Sanctis gloriam tuam praedicamus, una voce dicentes:

R. Sanctus, Sanctus, Sanctus Dominus Deus Sabaoth.

## Абрад Камуніі

## Заключныя абрады

V. Ite, missa est.

R. Deo gratias.''';

// MyBrev V4.1 replaces only these whole service lines in the V4 Latin text.
// Keep _laAfter as the older cached fixture for the transition period.
final _laV41 = _laAfter
    .replaceAll(
      'ЧИН МЕССЫ НА ЛАТИНСКОМ ЯЗЫКЕ',
      'ПАРАДАК СВЯТОЙ ІМШЫ НА ЛАЦІНСКАЙ МОВЕ',
    )
    .replaceAll('Исповедание веры', 'Вызнанне веры')
    .replaceAll('Вторая Евхаристическая молитва', 'II эўхарыстычная малітва')
    .replaceAll('Или:', 'Альбо:')
    .replaceAll('После чтения:', 'Пасля чытання:')
    .replaceAll('(После чтения)', '(Пасля чытання)');

// Block shapes produced by MyBrev's adapter for the excerpts above.
const _beShape = [
  'majorSection::',
  'rubric::',
  'spoken::',
  'rubric::',
  'response:people:',
  'subsection::',
  'rubric::',
  'spoken:priest:С.',
  'response:people:Н.',
  'subsection::',
  'rubric::',
  'response:all:',
  'rubric::',
  'response:people:',
  'majorSection::',
  'rubric::',
  'majorSection::',
  'subsection::',
  'rubric::',
  'spoken::',
  'majorSection::',
  'alternative::',
  'majorSection::',
  'spoken:celebrant:С.',
  'response:all:Н.',
  'spoken::',
];

const _laShape = [
  'heading::',
  'majorSection::',
  'spoken:priest:V.',
  'response:people:R.',
  'spoken:priest:',
  'alternative::',
  'spoken:priest:V.',
  'response:people:R.',
  'spoken:priest:V.',
  'response:people:R.',
  'response:all:',
  'majorSection::',
  'rubric::',
  'spoken:priest:V.',
  'response:people:R.',
  'rubric::',
  'spoken:priest:V.',
  'response:people:R.',
  'subsection::',
  'response:all:',
  'majorSection::',
  'subsection::',
  'spoken:priest:',
  'spoken::',
  'response:people:',
  'majorSection::',
  'majorSection::',
  'spoken:priest:V.',
  'response:people:R.',
];

void main() {
  final english = File('assets/mass/order-of-mass-en.md').readAsStringSync();
  // The bundled English text as it was before V4 (English major headings).
  var englishBefore = english;
  for (var i = 0; i < _majorTitles.length; i++) {
    englishBefore = englishBefore.replaceFirst(
      '## ${_majorTitles[i]}',
      '## ${_formerEnglishMajors[i]}',
    );
  }
  final before = {'be': _beBefore, 'la': _laBefore, 'en': englishBefore};
  final after = {'be': _beAfter, 'la': _laAfter, 'en': english};

  test(
    'five canonical Belarusian majors in every language, before and after',
    () {
      expect(englishBefore, isNot(english));
      for (final texts in [before, after]) {
        for (final language in ['be', 'la', 'en']) {
          final doc = _build(language, texts[language]!);
          final majors = doc.blocks
              .where((b) => b.type == MassBlockType.majorSection)
              .toList();
          expect(majors.map((b) => b.sectionId), _majorIds, reason: language);
          expect(majors.map((b) => b.text), _majorTitles, reason: language);
          expect(
            doc.sections.where((s) => s.isMajor).map((s) => s.sectionId),
            _majorIds,
            reason: language,
          );
          expect(_textsOf(doc, MassBlockClass.major), _majorTitles);
          expect(
            _fragment(doc).querySelectorAll('h2.${MassBlockClass.major}'),
            hasLength(5),
          );
        }
      }
      // The former headings are never shown.
      String html(String language) =>
          _build(language, before[language]!).chunks.map((c) => c.html).join();
      expect(html('be'), isNot(contains('Абрад заканчэння')));
      expect(
        html('la'),
        isNot(
          contains(
            RegExp(
              'Вступительные|Литургия Слова|Евхаристическая Литургия|'
              'Обряд причащения|Заключительный',
            ),
          ),
        ),
      );
      expect(html('en'), isNot(contains('The Introductory Rites<')));
      expect(html('en'), isNot(contains('The Concluding Rites<')));
    },
  );

  test('block types, roles and labels match MyBrev, before and after', () {
    expect(_shape(_build('be', _beBefore)), _beShape);
    expect(_shape(_build('be', _beAfter)), _beShape);
    expect(_shape(_build('la', _laBefore)), _laShape);
    expect(_shape(_build('la', _laAfter)), _laShape);
    expect(_shape(_build('en', englishBefore)), _shape(_build('en', english)));
  });

  test('old cached and V4.1 Latin service text have the same semantics', () {
    final old = _laAfter
        .replaceFirst(
          '## Літургія слова',
          ':::rubric\n(молитва из Миссала)\n:::\n\n## Літургія слова',
        )
        .replaceFirst(
          '### Исповедание веры',
          ':::rubric\nЕвангелие:\n:::\n\n### Исповедание веры',
        );
    final migrated = _laV41
        .replaceFirst(
          '## Літургія слова',
          ':::rubric\n(малітва з Імшала)\n:::\n\n## Літургія слова',
        )
        .replaceFirst(
          '### Вызнанне веры',
          ':::rubric\nЕвангелле:\n:::\n\n### Вызнанне веры',
        );
    final oldDoc = _build('la', old);
    final newDoc = _build('la', migrated);
    expect(_shape(newDoc), _shape(oldDoc));
    expect(
      newDoc.sections.map((s) => s.sectionId),
      oldDoc.sections.map((s) => s.sectionId),
    );
    for (final (phrase, type, sectionId) in [
      ('ПАРАДАК СВЯТОЙ ІМШЫ НА ЛАЦІНСКАЙ МОВЕ', MassBlockType.heading, null),
      ('Вызнанне веры', MassBlockType.subsection, 'creed'),
      (
        'II эўхарыстычная малітва',
        MassBlockType.subsection,
        'eucharistic-prayer',
      ),
      ('Пасля чытання:', MassBlockType.rubric, 'first-reading'),
      ('Евангелле:', MassBlockType.rubric, 'gospel'),
      ('Альбо:', MassBlockType.alternative, null),
    ]) {
      final block = _find(newDoc, phrase);
      expect(block.type, type, reason: phrase);
      expect(block.sectionId, sectionId, reason: phrase);
    }
    expect(_find(newDoc, '(Пасля чытання)').type, MassBlockType.rubric);
    expect(_find(newDoc, '(малітва з Імшала)').type, MassBlockType.rubric);
    expect(_dialogue(newDoc, 'Kyrie eleison.'), [
      'spoken:priest:V.',
      'response:people:R.',
    ]);
    final rendered = newDoc.chunks.map((c) => c.html).join();
    for (final oldPhrase in [
      'ЧИН МЕССЫ НА ЛАТИНСКОМ ЯЗЫКЕ',
      'Исповедание веры',
      'Вторая Евхаристическая молитва',
      'Или:',
      'После чтения:',
      '(После чтения)',
      'Евангелие:',
      '(молитва из Миссала)',
    ]) {
      expect(rendered, isNot(contains(oldPhrase)), reason: oldPhrase);
    }
  });

  test('the migration changes no wording in the rendered blocks', () {
    for (final language in ['be', 'la', 'en']) {
      expect(
        _compact(_build(language, after[language]!)),
        _compact(_build(language, before[language]!)),
        reason: language,
      );
    }
  });

  test('the reader pipeline (liturgical formatting) gives the same blocks', () {
    for (final texts in [before, after]) {
      for (final language in ['be', 'la', 'en']) {
        final formatted = buildMassDocument(
          formatLiturgicalHtml(prayerMarkdownToHtml(texts[language]!)),
          kMassRitual.variant(language)!,
        );
        expect(
          _shape(formatted),
          _shape(_build(language, texts[language]!)),
          reason: language,
        );
      }
    }
  });

  test('dialogue roles and labels mean the same in all three languages', () {
    final be = _build('be', _beAfter);
    final la = _build('la', _laAfter);
    final en = _build('en', english);
    expect(_dialogue(be, 'Пане, змілуйся над намі.'), [
      'spoken:priest:С.',
      'response:people:Н.',
    ]);
    expect(_dialogue(la, 'Kyrie eleison.'), [
      'spoken:priest:V.',
      'response:people:R.',
    ]);
    expect(_dialogue(en, 'The Lord be with you.'), [
      'spoken:priest:P.',
      'response:people:R.',
    ]);
    expect(_dialogue(be, 'Пан з вамі.'), [
      'spoken:celebrant:С.',
      'response:all:Н.',
    ]);
    // The `reader` role.
    expect(_dialogue(en, 'The word of the Lord.'), [
      'spoken:reader:L.',
      'response:people:R.',
    ]);
    // Same result from the pre-migration `С.:` / `Н.:` syntax.
    expect(_dialogue(_build('be', _beBefore), 'Пане, змілуйся над намі.'), [
      'spoken:priest:С.',
      'response:people:Н.',
    ]);
  });

  test('speaker prefixes are metadata; labels come from roleLabels', () {
    for (final (language, text, prefix) in [
      ('be', _beBefore, 'С.:'),
      ('be', _beAfter, 'С.'),
      ('la', _laBefore, 'V.'),
    ]) {
      final doc = _build(language, text);
      final call = doc.blocks.firstWhere((b) => b.sourceLabel == prefix);
      expect(call.text, isNot(startsWith(prefix)), reason: language);
      expect(call.role, 'priest');
    }
    final doc = _build('be', _beBefore);
    final labels = _fragment(
      doc,
    ).querySelectorAll('.${MassBlockClass.roleLabel}');
    // Rendered once, from the ritual metadata, without the legacy colon.
    expect(labels.map((e) => e.text), ['С.', 'Н.', 'С.', 'Н.']);
    expect(labels.map((e) => e.parent!.attributes['data-role']), [
      'priest',
      'people',
      'celebrant',
      'all',
    ]);
    expect(
      _textsOf(doc, MassBlockClass.response),
      contains('Н. І з духам тваім.'),
    );
  });

  test('labels stay off long prayers, hymns and rubric-led lines', () {
    final be = _build('be', _beAfter);
    final la = _build('la', _laAfter);
    final en = _build('en', english);

    final preface = _find(la, 'Vere dignum');
    expect(
      [preface.type, preface.role, preface.speakerLabel],
      ['spoken', 'priest', null],
    );
    expect(_find(la, 'Sanctus, Sanctus').speakerLabel, isNull);
    expect(_find(la, 'Gratia Domini').speakerLabel, isNull);
    // Hymns are said by all in every language and never labelled.
    for (final (doc, start) in [
      (be, 'Хвала на вышынях Богу, а'),
      (la, 'Gloria in excelsis'),
      (en, 'Glory to God'),
    ]) {
      final gloria = _find(doc, start);
      expect(gloria.type, MassBlockType.response, reason: start);
      expect(gloria.speakerLabel, isNull, reason: start);
    }
    // roleMarkers.
    expect(_find(la, 'Credo in unum').role, 'all');
    // A rubric cue already names the speaker: a role, but no label.
    final amen = _find(be, 'Амэн.');
    expect(
      [amen.type, amen.role, amen.speakerLabel],
      ['response', 'people', null],
    );
    // Consecutive stanzas of one prayer are not a dialogue.
    final stanzas = en.blocks
        .where(
          (b) =>
              b.type == MassBlockType.response &&
              RegExp(r'^We praise you|^For you alone').hasMatch(b.text),
        )
        .toList();
    expect(stanzas, hasLength(2));
    for (final block in en.blocks) {
      if (stanzas.contains(block) ||
          !{
            MassBlockType.spoken,
            MassBlockType.response,
          }.contains(block.type)) {
        expect(block.speakerLabel, isNull, reason: block.text);
      }
    }
  });

  test('the label policy is ritual metadata', () {
    expect(kMassRitual.rolePolicy.showSpeakerLabels, isTrue);
    expect(kMassRitual.rolePolicy.labelPolicy, 'dialogue');
    const expected = {
      'be': ['С.', 'Н.'],
      'la': ['V.', 'R.'],
      'en': ['P.', 'R.'],
    };
    for (final variant in kMassRitual.variants) {
      expect(
        variant.roleLabels.keys.toSet(),
        kMassRitual.roles.toSet(),
        reason: variant.language,
      );
      expect([
        variant.roleLabels['priest'],
        variant.roleLabels['people'],
      ], expected[variant.language]);
      for (final role in variant.roleMarkers.keys) {
        expect(kMassRitual.roles, contains(role));
      }
    }
    // No label is hard-coded in the adapter.
    expect(
      File('lib/utils/mass_semantics.dart').readAsStringSync(),
      isNot(contains(RegExp('[\'"](?:С\\.|Н\\.|V\\.|R\\.|P\\.)[\'"]'))),
    );
  });

  test('a rubric split around a quoted phrase is one rubric', () {
    for (final text in [_beBefore, _beAfter]) {
      final doc = _build('be', text);
      expect(_textsOf(doc, MassBlockClass.cited), ['Аллелюя']);
      expect(
        _textsOf(doc, MassBlockClass.rubric),
        contains(
          'Потым спяваецца Аллелюя альбо іншы спеў, прадпісаны ў рубрыках, '
          'у залежнасці ад патрабаванняў літургічнага перыяду.',
        ),
      );
    }
    // Glued sentences of the current text get their space (whitespace only).
    expect(
      _textsOf(_build('be', _beBefore), MassBlockClass.rubric),
      contains(
        startsWith('Усе разам са святаром пэўны час ціха моляцца. Потым'),
      ),
    );
  });

  test('Latin: a bare prefix gives its role to the line after the rubric', () {
    final doc = _build('la', _laBefore);
    final index = doc.blocks.indexWhere((b) => b.text == '(После чтения)');
    expect(doc.blocks[index].type, MassBlockType.rubric);
    final next = doc.blocks[index + 1];
    expect(
      [next.text, next.role, next.speakerLabel],
      ['Verbum Domini.', 'priest', 'V.'],
    );
    expect(_textsOf(doc, MassBlockClass.alternative), ['Или:']);
    expect(_textsOf(doc, MassBlockClass.minorHeading), [
      'ЧИН МЕССЫ НА ЛАТИНСКОМ ЯЗЫКЕ',
    ]);
    expect(_textsOf(doc, MassBlockClass.subsection), [
      'Исповедание веры',
      'Вторая Евхаристическая молитва',
    ]);
  });

  test('English: bold people parts, comments, posture and alternatives', () {
    final doc = _build('en', english);
    expect(
      doc.blocks.map((b) => b.type).toSet(),
      containsAll([
        MassBlockType.comment,
        MassBlockType.posture,
        MassBlockType.alternative,
        MassBlockType.subsection,
      ]),
    );
    final amen = doc.blocks.firstWhere((b) => b.text == 'Amen.');
    expect([amen.type, amen.role], ['response', 'people']);
    // The bold wrapper only encoded the role; the response class carries it.
    final response = _fragment(
      doc,
    ).querySelector('.${MassBlockClass.response}')!;
    expect(response.querySelector('strong'), isNull);
    expect(_textsOf(doc, MassBlockClass.posture), isNotEmpty);
    expect(_textsOf(doc, MassBlockClass.comment), hasLength(4));
    expect(_textsOf(doc, MassBlockClass.alternative).toSet(), {'Or:'});
  });

  test('words that merely start with a role letter are not prefixes', () {
    final doc = _build(
      'be',
      '## Уступныя абрады\n\nСвятар гаворыць.\n\nНа зямлі супакой.',
    );
    expect(doc.blocks.map((b) => b.sourceLabel), everyElement(isNull));
    expect(
      _fragment(doc).querySelectorAll('.${MassBlockClass.roleLabel}'),
      isEmpty,
    );
  });

  test('chunks start at every located section', () {
    for (final (language, text) in [('be', _beAfter), ('en', english)]) {
      final doc = _build(language, text);
      expect(
        doc.chunks
            .where((c) => c.section != null)
            .map((c) => c.section!.sectionId),
        doc.sections.map((s) => s.sectionId),
      );
    }
  });

  test('markdown bold may span the lines of one paragraph', () {
    expect(
      prayerMarkdownToHtml('**узяў хлеб,\nламаў:**'),
      contains('<strong>узяў хлеб,<br>ламаў:</strong>'),
    );
    final doc = _build('be', _beAfter);
    expect(
      _fragment(doc).querySelector('.${MassBlockClass.spoken} strong')!.text,
      startsWith('узяў хлеб і, падзяку Табе складаючы,'),
    );
  });
}
