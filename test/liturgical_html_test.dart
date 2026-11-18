import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';

void main() {
  test('only semantic HTML section headings become uppercase', () {
    final html = formatLiturgicalHtml(
      '<p class="liturgical-heading"><span>Кароткае чытанне</span> '
      '<span class="liturgical-reading-reference">(2 Кар 13, 4)</span></p>'
      '<p>Хрыстус быў укрыжаваны праз бяссілле.</p>',
    );
    expect(html, contains('>КАРОТКАЕ ЧЫТАННЕ</span>'));
    expect(html, contains('(2 Кар 13, 4)'));
    expect(html, contains('Хрыстус быў укрыжаваны'));
    expect(html, isNot(contains('ХРЫСТУС БЫЎ УКРЫЖАВАНЫ')));
  });

  test('reading psalm verses break after stars and before verse numbers', () {
    const source =
        '2. Я цвёрда спадзяваўся на Пана, * і Ён схіліўся '
        'нада мною, і пачуў мой крык. 4. І паклаў у мае вусны новую '
        'песню, * спеў хвалы нашаму Богу.';
    expect(
      formatReadingPsalmText(source),
      '2. Я цвёрда спадзяваўся на Пана, *\nі Ён схіліўся '
      'нада мною, і пачуў мой крык.\n4. І паклаў у мае вусны новую '
      'песню, *\nспеў хвалы нашаму Богу.',
    );
    final html = formatReadingPsalmHtml('<p>$source</p>');
    expect(html, contains('*</span><br>і Ён'));
    expect(html, contains('мой крык.<br>4.'));
    expect(html, contains('*</span><br>спеў'));
  });

  test(
    'reading psalm HTML removes encoded spaces and keeps existing breaks',
    () {
      final html = formatReadingPsalmHtml(
        '<p>2. Першы <b>&ast;</b>&nbsp;&#x20;<br>другі. '
        '&#32;14. Трэці *&#x20;чацвёрты.</p>',
      );
      expect(html, contains('*</span></b><br>другі.'));
      expect(html, contains('другі.<br>14.'));
      expect(html, contains('*</span><br>чацвёрты.'));
      expect(html, isNot(contains('<br><br>')));
    },
  );

  test('numbered HTML paragraphs without cadence keep verse line breaks', () {
    final html = formatReadingPsalmHtml(
      '<p>2. Першы верш. 4.&nbsp;Другі верш.</p>',
    );
    expect(html, contains('Першы верш.<br>4.'));
  });

  group('formatPsalmHtml', () {
    test('marks cadence signs and alternating strophes', () {
      final result = formatPsalmHtml(
        '<p>Першы радок *<br>другі радок<br>'
        'Трэці радок †<br>чацвёрты радок</p>',
      );

      expect(result, contains('class="psalm-strophe"'));
      expect(result, contains('class="psalm-strophe psalm-strophe-even"'));
      expect(result, contains('<span class="psalm-marker">*</span>'));
      expect(result, contains('<span class="psalm-marker">†</span>'));
    });

    test('Psalm 50 soft break remains inside one strophe and keeps parity', () {
      const source =
          '<p>Пане, адкрый мае вусны, * і вусны мае будуць абвяшчаць хвалу.</p>'
          '<p>Бо Ты не прагнеш ахвяры, * Табе не спадабаецца.</p>'
          '<p>Ахвяра Богу – гэта скрушаны дух, * не пагарджай, Божа, '
          'пакорным<br>і прыгнечаным сэрцам.</p>'
          '<p>У сваёй дабрыні будзь ласкавы да Сіёна, * адбудуй муры.</p>';
      final result = formatPsalmHtml(source);

      expect(RegExp('class="psalm-strophe').allMatches(result), hasLength(4));
      expect(
        result,
        contains('пакорным<br>і прыгнечаным сэрцам.</p>'),
      );
      expect(RegExp('data-psalm-choir="1"').allMatches(result), hasLength(2));
      expect(RegExp('data-psalm-choir="2"').allMatches(result), hasLength(2));
      expect(
        result,
        contains('data-psalm-choir="2" class="psalm-strophe psalm-strophe-even">У сваёй'),
      );
    });

    test('soft wrap stays within stanza; later cadence creates new choir stanza', () {
      const source =
          '<p>Першы радок * другая палова<br>працяг без кадэнцыі<br>'
          'Новы радок † працяг * другая палова<br>'
          'Яшчэ адзін радок * завяршэнне.</p>';
      final result = formatPsalmHtml(source);

      expect(RegExp('class="psalm-strophe').allMatches(result), hasLength(3));
      expect(result, contains('другая палова<br>працяг без кадэнцыі'));
      expect(RegExp('data-psalm-choir="1"').allMatches(result), hasLength(2));
      expect(RegExp('data-psalm-choir="2"').allMatches(result), hasLength(1));
    });

    test('encoded cadence on the next line still begins a new strophe', () {
      const source =
          '<p>Радок * працяг<br>мяккі перанос<br>'
          'Наступны радок &#x2a; другая палова.</p>';
      final result = formatPsalmHtml(source);

      expect(RegExp('class="psalm-strophe').allMatches(result), hasLength(2));
      expect(result, contains('працяг<br>мяккі перанос'));
      expect(result, contains('data-psalm-choir="2"'));
    });

    test('prepares alternating choirs and dims only the selected choir', () {
      final formatted = formatPsalmHtml(
        '<p>Першы радок *<br>другі радок</p>'
        '<p>Трэці радок *<br>чацвёрты радок</p>',
      );

      final neutral = preparePsalmChoirHtml(formatted);
      expect(neutral, contains('href="psalm-choir:2"'));
      expect(neutral, contains('href="psalm-choir:1"'));
      expect(neutral, isNot(contains('psalm-choir-muted')));

      final firstSelected = preparePsalmChoirHtml(formatted, selectedChoir: 1);
      final firstChoirLinks = RegExp(
        'href="psalm-choir:1"',
      ).allMatches(firstSelected).length;
      expect(firstChoirLinks, greaterThan(0));
      expect(
        RegExp('psalm-choir-muted').allMatches(firstSelected),
        hasLength(firstChoirLinks),
      );
      expect(
        firstSelected,
        isNot(
          contains(
            'href="psalm-choir:2" class="psalm-choir-strophe '
            'psalm-choir-muted"',
          ),
        ),
      );
      expect(
        firstSelected,
        contains(
          'href="psalm-choir:1" class="psalm-choir-strophe '
          'psalm-choir-muted"',
        ),
      );
    });

    test('normalizes literal, named, decimal and hex cadence breaks', () {
      final result = formatPsalmHtml(
        '<p>a *<br>b &ast;<br>c &#42;<br>d &#x2a;<br>'
        'e †<br>f &dagger;<br>g &#8224;<br>h &#x2020;</p><p>i<br>j</p>',
      );

      expect(RegExp('psalm-marker').allMatches(result), hasLength(8));
      expect(result, contains('i<br>j'));
      expect(result, isNot(contains('†<br>')));
      expect(result, isNot(contains('&#x2020;<br>')));
    });

    test('keeps leading psalm metadata separate from strophes', () {
      final result = formatPsalmHtml(
        '<p style="text-align: center"><em>Псальм 62</em></p>'
        '<p>Божа, Ты Бог мой *<br>Цябе шукаю.</p>',
      );

      expect(result, contains('liturgical-subheading'));
      expect(result, contains('psalm-strophe'));
    });

    test('marks every styled paragraph in a psalm introduction as metadata', () {
      final result = formatPsalmHtml(
        '<p><span style="color: #ff0000;">Псальм 89 (88), 39–53</span></p>'
        '<p><span style="color: #ff0000;">Плач над падзеннем дому Давіда</span></p>'
        '<p><em>Узнаў моц збаўлення для нас у доме Давіда</em></p>'
        '<p><span style="color: #ff0000;">IV (39–46)</span></p>'
        '<p>Ты адкінуў і адрокся, *<br>разгневаўся на памазаніка.</p>',
      );

      expect(RegExp('liturgical-subheading').allMatches(result), hasLength(4));
      expect(RegExp('psalm-metadata').allMatches(result), hasLength(4));
      expect(result, contains('class="psalm-strophe"'));
    });
  });

  test('formatLiturgicalHtml marks stars and crosses', () {
    final result = formatLiturgicalHtml(
      '<p><span style="color:red">К.</span> Хвала Айцу * і Сыну †</p>',
    );
    expect(RegExp('psalm-marker').allMatches(result), hasLength(2));
    expect(result, contains('liturgical-rubric-inline'));
    expect(result, isNot(contains('color:red')));
    expect(result, isNot(contains('liturgical-subheading')));
  });

  test('inline red marker does not turn spoken paragraph into metadata', () {
    final result = formatLiturgicalHtml(
      '<p><span style="color:red">К.</span> Пане, пачуй нас.</p>',
    );
    expect(result, contains('liturgical-rubric-inline'));
    expect(result, isNot(contains('liturgical-subheading')));
  });

  test('fully styled leading metadata remains metadata', () {
    final result = formatLiturgicalHtml(
      '<p><span style="color:red">Усе разам</span></p><p>Асноўны тэкст</p>',
    );
    expect(result, contains('liturgical-subheading'));
  });

  test('explicit opening rubric keeps rubric typography', () {
    final result = formatLiturgicalHtml(
      '<p class="liturgical-rubric"><span style="color:red"><em>'
      'Заклік з’яўляецца пачаткам малітвы.</em></span></p>',
    );

    expect(result, contains('class="liturgical-rubric"'));
    expect(result, contains('liturgical-rubric-inline'));
    expect(result, isNot(contains('liturgical-subheading')));
  });

  test('mixed emphasis and ordinary body remains body', () {
    final result = formatLiturgicalHtml(
      '<p><em>Кароткі загаловак</em> і асноўны тэкст чытання.</p>',
    );
    expect(result, isNot(contains('liturgical-subheading')));
  });

  test('centered caption remains metadata', () {
    final result = formatLiturgicalHtml(
      '<p style="text-align:center">Песня Захарыі</p><p>Тэкст</p>',
    );
    expect(result, contains('liturgical-subheading'));
  });

  test('embedded antiphon is stripped only with matching external context', () {
    const html = '<p>Псальм</p><p>Ант. Хвала Пану</p>';
    expect(
      stripEmbeddedAntiphon(html, externalAntiphon: 'Хвала Пану'),
      '<p>Псальм</p>',
    );
    expect(stripEmbeddedAntiphon(html), html);
    expect(
      stripEmbeddedAntiphon(html, externalAntiphon: 'Іншая антыфона'),
      html,
    );
  });

  test('recognizes a structured psalm package without flattening it', () {
    const html =
        '<div data-alternative-title="Псальм 146">'
        '<p class="ora-ant">Ант. Першы</p>'
        '<div class="ora-psalm"><p>Псальм</p></div>'
        '</div>';
    expect(ownsStructuredPsalmPackage(html), isTrue);
    expect(ownsStructuredPsalmPackage('<p>Звычайны псальм</p>'), isFalse);
  });

  test('legacy reading label is removed without losing its source', () {
    const html = 'ПЕРШАЕ ЧЫТАННЕ<br>Пасланне да Габрэяў<br><p>Браты.</p>';
    final result = stripLeadingReadingHeading(html, 'Першае чытанне');
    expect(result, isNot(contains('ПЕРШАЕ ЧЫТАННЕ')));
    expect(result, contains('Пасланне да Габрэяў'));
    expect(result, contains('Браты.'));
  });

  test('encoded reading labels are removed from styled first lines', () {
    const first =
        '<p style="text-align: justify;"><span style="color: #ff0000;">'
        'Першае чытанне&#x20;<br />Кніга Прарока</span></p>';
    const second =
        '<p><span>Другое&nbsp;чытанне&#32;</span><br>'
        '<span>Ліст святога</span></p>';

    final firstResult = stripLeadingReadingHeading(first, 'Першае чытанне');
    final secondResult = stripLeadingReadingHeading(second, 'Другое чытанне');

    expect(firstResult, isNot(contains('Першае чытанне')));
    expect(firstResult, contains('Кніга Прарока'));
    expect(secondResult, isNot(contains('Другое')));
    expect(secondResult, contains('Ліст святога'));
  });

  test('reading label elsewhere in the body is preserved', () {
    const html = '<p>Уводзіны</p><p>Першае чытанне</p>';
    expect(stripLeadingReadingHeading(html, 'Першае чытанне'), html);
  });

  test('inline reference is marked only in a reading heading context', () {
    final reading = formatLiturgicalHtml(
      '<p>КАРОТКАЕ ЧЫТАННЕ (Рым 8, 1–2) Тэкст.</p>',
    );
    final prayer = formatLiturgicalHtml('<p>Малітва (усе разам).</p>');
    expect(reading, contains('liturgical-reading-reference'));
    expect(prayer, isNot(contains('liturgical-reading-reference')));
  });

  test('legacy presentation is normalized after centered role detection', () {
    final result = formatLiturgicalHtml(
      '<p style="text-align:center; margin-left:30px; font-size:10px">Назва</p>',
    );
    expect(result, contains('liturgical-subheading'));
    expect(result, isNot(contains('text-align')));
    expect(result, isNot(contains('margin-left')));
    expect(result, isNot(contains('font-size')));
  });
}
