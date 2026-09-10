import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';

void main() {
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
