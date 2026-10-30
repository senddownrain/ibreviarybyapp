import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/utils/liturgical_alternatives.dart';

void main() {
  group('getLiturgicalAlternatives', () {
    test('a hymn stanza «Для …» ending a later line with a colon is verse', () {
      final stanza =
          '<p>Для адданых слугаў Божых<br>Хай гучыць хвала й падзяка:<br>Трэці радок</p>';
      final options = getLiturgicalAlternatives(
        '<p>Пра аднаго святога:<br>Першы радок</p>'
        '<p>Пра некалькіх святых:<br>Другі радок</p>$stanza',
        kind: 'hymn',
      );
      expect(options, hasLength(2));
      expect(options.last.html, contains('Для адданых слугаў Божых'));

      final headings = getLiturgicalAlternatives(
        '<p>Пра адну панну:<br>Першы радок</p>'
        '<p>Для адданых слугаў:<br>Трэці радок</p>',
        kind: 'hymn',
      );
      expect(headings, hasLength(2));
    });

    test('splits legacy hr-delimited alternatives and derives titles', () {
      final options = getLiturgicalAlternatives(
        '<p><span style="color:red">Пра біскупа:</span></p>'
        '<p>Першая малітва.</p><hr>'
        '<p><span style="color:red">Або:</span></p>'
        '<p>Другая малітва.</p>',
        kind: 'prayer',
      );

      expect(options, hasLength(2));
      expect(options.first.title, 'Пра біскупа');
      expect(options.last.title, 'Варыянт 2');
      expect(options.first.html, contains('Першая малітва'));
      expect(options.last.html, contains('Другая малітва'));
    });

    test('combines shared content, structured option and suffix', () {
      final options = getLiturgicalAlternatives(
        '<p>Агульны пачатак.</p>'
        '<div data-alternative-title="Першы"><p>Тэкст 1.</p></div>'
        '<div data-alternative-title="Другі"><p>Тэкст 2.</p></div>'
        '<div data-alternative-suffix><p>Амэн.</p></div>',
      );

      expect(options, hasLength(2));
      expect(options.map((option) => option.title), ['Першы', 'Другі']);
      expect(options.first.html, contains('Агульны пачатак'));
      expect(options.first.html, contains('Тэкст 1'));
      expect(options.first.html, contains('Амэн'));
      expect(options.last.html, isNot(contains('Тэкст 1')));
    });

    test('recognizes gospel-antiphon cycles', () {
      final options = getLiturgicalAlternatives(
        '<p>Год A: Антыфона A.<br>Год B: Антыфона B.<br>'
        'Год C: Антыфона C.</p>',
        kind: 'gospel-antiphon',
      );

      expect(options, hasLength(3));
      expect(options.map((option) => option.title), [
        'Год A',
        'Год B',
        'Год C',
      ]);
      expect(options.first.html, contains('Антыфона A.'));
      expect(options.first.html, isNot(contains('Год A:')));
    });

    test('keeps antiphon text outside a paragraph after a cycle marker', () {
      final options = getLiturgicalAlternatives(
        '<p><span style="color:red">Год А:</span></p>'
        'Антыфона нядзелі.'
        '<p><span style="color:red">Год В:</span></p>'
        'Другая антыфона.',
        kind: 'gospel-antiphon',
      );

      expect(options, hasLength(2));
      expect(options.first.html, contains('Антыфона нядзелі.'));
      expect(options.last.html, contains('Другая антыфона.'));
      expect(options.first.html, isNot(contains('Год А:')));
    });

    test('keeps Psalm 26:7-14 whole when verse 8 begins with “Пра ...:”', () {
      final psalm = [
        '<p>II (7-14)</p>',
        '<p>Пачуй, Пане, мой голас, калі я клічу, * змілуйся нада мною і адкажы мне.</p>',
        '<p>Пра Цябе кажа маё сэрца: † «Шукай Ягонага аблічча!» * Буду шукаць Твайго аблічча, Пане.</p>',
        '<p>Не хавай ад мяне свайго твару.</p>',
      ].join();
      final options = getLiturgicalAlternatives(psalm, kind: 'psalm');

      expect(options, hasLength(1));
      expect(hasLiturgicalAlternatives(psalm, kind: 'psalm'), isFalse);
      expect(options.single.html, contains('Пачуй, Пане, мой голас'));
      expect(options.single.html, contains('Пра Цябе кажа маё сэрца:'));
      expect(options.single.html, contains('Не хавай ад мяне'));
    });

    test('still permits explicit hr-delimited psalm alternatives', () {
      final options = getLiturgicalAlternatives(
        '<p>Псальм 1.</p><hr><p>Або:</p><p>Іншы псальм.</p>',
        kind: 'psalm',
      );
      expect(options, hasLength(2));
    });

    test('does not split narrative “У тыя дні” as a category', () {
      final options = getLiturgicalAlternatives(
        '<p>У тыя дні: Езус сказаў вучням.</p><p>Працяг чытання.</p>',
        kind: 'reading',
      );

      expect(options, hasLength(1));
    });
  });

  test('formatIntercessions adds semantic prayer classes', () {
    final html = formatIntercessions(
      '<p>Будзем маліцца:</p>'
      '<p><em>Пане, выслухай нас.</em></p>'
      '<p>За Касцёл,</p><p>– Пане, выслухай нас.</p>',
    );

    expect(html, contains('intercessions__intro'));
    expect(html, contains('intercessions__refrain'));
    expect(html, contains('intercessions__petition'));
    expect(html, contains('intercessions__response'));
    expect(html, contains('intercessions__marker'));
    expect(html.replaceAll(RegExp(r'<[^>]+>'), ''), contains('– Пане'));
  });
}
