import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/utils/liturgical_alternatives.dart';

void main() {
  group('getLiturgicalAlternatives', () {
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
  });
}
