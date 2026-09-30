import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

import 'package:mybrev_flutter/models/mass_ritual.dart';
import 'package:mybrev_flutter/utils/mass_semantics.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';

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

String _flat(String html) =>
    parseFragment(html).text!.replaceAll(RegExp(r'\s+'), '');

// Excerpts in the formats of the synced sources (structure only matters).
const _belarusian = '''
### Уступныя абрады

:::rubric
Святар гаворыць:
:::

У імя Айца і Сына, і Духа Святога.

:::rubric
Народ адказвае:
:::

Амэн.

:::rubric
Затым святар вітае народ, гаворачы:
:::

Ласка Пана нашага.

:::rubric
Альбо:
:::

Пан з вамі.

**Чын пакаяння**

:::rubric
Пасля гэтага гаворыцца Пане, змілуйся над намі:
:::

С.: Пане, змілуйся над намі.
Н.: Пане, змілуйся над намі.

### **Літургія слова**

:::rubric
Потым спяваецца
:::

 Аллелюя

:::rubric
альбо іншы спеў.
:::

**Вызнанне веры**

:::rubric
Пасля гаміліі спяваецца ці прамаўляецца сімвал веры:
:::

Веру ў адзінага Бога.

:::rubric
Ад наступных словаў і да словаў
:::

 стаўся чалавекам

:::rubric
усе схіляюцца.
:::

І ўцелавіўся ад Духа Святога.

### Эўхарыстычная літургія

II эўхарыстычная малітва

:::rubric
Святар з разведзенымі рукамі дадае:
:::

Падзякуем Пану Богу нашаму.

:::rubric
Калі ламанне хлеба працягваецца, заканчваецца ён словамі
:::

 адары нас супакоем

:::rubric
.Затым святар ціха гаворыць:
:::

Пане Езу Хрыстэ.

### Абрад заканчэння

Цэлебрант: Пан з вамі.
Усе:І з духам тваім.
''';

const _latin = '''
ЧИН МЕССЫ НА ЛАТИНСКОМ ЯЗЫКЕ

:::rubric
Вступительные обряды
:::

V. Gratia Domini nostri Iesu Christi.

Или:

V. Dominus vobiscum.

R. Et cum spiritu tuo.

:::rubric
Литургия Слова
:::

После чтения:

V. Verbum Domini.

V.

:::rubric
(После чтения)
:::

 Verbum Domini.

R. Laus tibi, Christe.
''';

const _english = '''
## The Liturgy of the Word

### First Reading

:::rubric
all sit
:::

The word of the Lord.
**Thanks be to God.**

### The Creed

#### The Niceno-Constantinopolitan Creed

**I believe in one God,**
**the Father almighty,**

---

:::rubric
Or:
:::

**When we eat this Bread**
''';

void main() {
  group('Belarusian', () {
    final doc = _build('be', _belarusian);

    test('section markers become major and subsection headings', () {
      expect(_textsOf(doc, MassBlockClass.major), [
        'Уступныя абрады',
        'Літургія слова',
        'Эўхарыстычная літургія',
        'Абрад заканчэння',
      ]);
      expect(_textsOf(doc, MassBlockClass.subsection), [
        'Чын пакаяння',
        'Вызнанне веры',
        'II эўхарыстычная малітва',
      ]);
      expect(
        _fragment(doc).querySelectorAll('h2.${MassBlockClass.major}'),
        hasLength(4),
      );
    });

    test('responses follow the people cues, not every line', () {
      expect(_textsOf(doc, MassBlockClass.response), [
        'Амэн.',
        'Пане, змілуйся над намі.',
        'Веру ў адзінага Бога.',
        'І ўцелавіўся ад Духа Святога.',
        'І з духам тваім.',
      ]);
      expect(
        _textsOf(doc, MassBlockClass.spoken),
        containsAll([
          'У імя Айца і Сына, і Духа Святога.',
          'Падзякуем Пану Богу нашаму.',
          'Ласка Пана нашага.',
          'Пан з вамі.',
          'Пане Езу Хрыстэ.',
        ]),
      );
    });

    test('source role abbreviations become role labels', () {
      final roles = _fragment(
        doc,
      ).querySelectorAll('.${MassBlockClass.roleLabel}');
      expect(
        [for (final r in roles) '${r.text}=${r.attributes['data-role']}'],
        ['С.:=celebrant', 'Н.:=people', 'Цэлебрант:=celebrant', 'Усе:=all'],
      );
    });

    test('a rubric split around a quoted phrase is one rubric', () {
      expect(_textsOf(doc, MassBlockClass.cited), [
        'Аллелюя',
        'стаўся чалавекам',
        'адары нас супакоем',
      ]);
      expect(
        _textsOf(doc, MassBlockClass.rubric),
        containsAll([
          'Потым спяваецца Аллелюя альбо іншы спеў.',
          'Ад наступных словаў і да словаў стаўся чалавекам усе схіляюцца.',
          'Калі ламанне хлеба працягваецца, заканчваецца ён словамі '
              'адары нас супакоем. Затым святар ціха гаворыць:',
        ]),
      );
    });

    test('alternatives use the alternative label', () {
      expect(_textsOf(doc, MassBlockClass.alternative), ['Альбо:']);
    });
  });

  group('Latin', () {
    final doc = _build('la', _latin);

    test('V./R. are role labels and R. lines are responses', () {
      expect(_textsOf(doc, MassBlockClass.response), [
        'R. Et cum spiritu tuo.',
        'R. Laus tibi, Christe.',
      ]);
      expect(
        _textsOf(doc, MassBlockClass.spoken),
        contains('V. (После чтения) Verbum Domini.'),
      );
      expect(_textsOf(doc, MassBlockClass.inlineRubric), ['(После чтения)']);
    });

    test('rubric-marked sections become major headings', () {
      expect(_textsOf(doc, MassBlockClass.major), [
        'Вступительные обряды',
        'Литургия Слова',
      ]);
    });

    test('Cyrillic plain directions are rubrics or alternatives', () {
      expect(_textsOf(doc, MassBlockClass.alternative), ['Или:']);
      expect(_textsOf(doc, MassBlockClass.rubric), ['После чтения:']);
      // The document title before the first section is left alone.
      expect(
        _textsOf(doc, MassBlockClass.spoken),
        contains('ЧИН МЕССЫ НА ЛАТИНСКОМ ЯЗЫКЕ'),
      );
    });
  });

  group('English', () {
    final doc = _build('en', _english);

    test('bold people parts are split from the leader as responses', () {
      expect(_textsOf(doc, MassBlockClass.spoken), ['The word of the Lord.']);
      expect(_textsOf(doc, MassBlockClass.response), [
        'Thanks be to God.',
        // <br> between the two lines
        'I believe in one God,the Father almighty,',
        'When we eat this Bread',
      ]);
    });

    test('posture, alternatives and minor headings', () {
      expect(_textsOf(doc, MassBlockClass.posture), ['all sit']);
      expect(_textsOf(doc, MassBlockClass.alternative), ['Or:']);
      expect(_textsOf(doc, MassBlockClass.minorHeading), [
        'The Niceno-Constantinopolitan Creed',
      ]);
    });
  });

  test('normalization never changes the wording', () {
    final assetText = File(
      'assets/mass/order-of-mass-en.md',
    ).readAsStringSync();
    for (final (language, markdown) in [
      ('be', _belarusian),
      ('la', _latin),
      ('en', _english),
      ('en', assetText),
    ]) {
      final html = prayerMarkdownToHtml(markdown);
      final doc = buildMassDocument(html, kMassRitual.variant(language)!);
      expect(
        _flat(doc.chunks.map((c) => c.html).join()),
        _flat(html),
        reason: language,
      );
    }
  });

  group('normalized content', () {
    const majors = [
      'Уступныя абрады',
      'Літургія слова',
      'Эўхарыстычная літургія',
      'Абрад Камуніі',
      'Заключныя абрады',
    ];
    const ids = [
      'introductory-rites',
      'liturgy-of-the-word',
      'eucharistic-liturgy',
      'communion-rite',
      'concluding-rites',
    ];

    test('canonical Belarusian major headings are located in any language', () {
      for (final (language, line) in [
        ('be', 'С. Пан з вамі.'),
        ('la', 'V. Dominus vobiscum.'),
        ('en', 'P. The Lord be with you.'),
      ]) {
        final doc = _build(
          language,
          [for (final title in majors) '## $title\n\n$line'].join('\n\n'),
        );
        expect(doc.sections.map((s) => s.sectionId), ids, reason: language);
        expect(_textsOf(doc, MassBlockClass.major), majors, reason: language);
      }
    });

    test('normalized speaker prefixes are role labels in every language', () {
      List<String> roles(String language, String markdown) => [
        for (final r in _fragment(
          _build(language, markdown),
        ).querySelectorAll('.${MassBlockClass.roleLabel}'))
          '${r.text}=${r.attributes['data-role']}',
      ];
      expect(
        roles(
          'be',
          '## Уступныя абрады\n\nС. Пан з вамі.\nН. І з духам тваім.',
        ),
        ['С.=celebrant', 'Н.=people'],
      );
      expect(
        roles(
          'la',
          '## Уступныя абрады\n\nV. Dominus vobiscum.\nR. Et cum spiritu tuo.',
        ),
        ['V.=celebrant', 'R.=people'],
      );
      final english =
          '## Уступныя абрады\n\nP. The Lord be with you.\n**R. And with your spirit.**';
      expect(roles('en', english), ['P.=celebrant', 'R.=people']);
      // The response keeps its semantic class and its wording.
      expect(_textsOf(_build('en', english), MassBlockClass.response), [
        'And with your spirit.',
      ]);
    });

    test('ordinary words starting with a role letter are not labels', () {
      final doc = _build(
        'be',
        '## Уступныя абрады\n\nСвятар гаворыць.\n\nНа зямлі супакой.',
      );
      expect(
        _fragment(doc).querySelectorAll('.${MassBlockClass.roleLabel}'),
        isEmpty,
      );
    });
  });

  test('chunks start at every located section', () {
    final doc = _build('be', _belarusian);
    expect(
      doc.chunks
          .where((c) => c.section != null)
          .map((c) => c.section!.sectionId),
      doc.sections.map((s) => s.sectionId),
    );
  });

  test('markdown bold may span the lines of one paragraph', () {
    expect(
      prayerMarkdownToHtml('**узяў хлеб,\nламаў:**'),
      contains('<strong>узяў хлеб,<br>ламаў:</strong>'),
    );
  });
}
