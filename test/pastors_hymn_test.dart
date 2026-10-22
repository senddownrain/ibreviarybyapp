import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/utils/liturgical_alternatives.dart';
import 'package:mybrev_flutter/utils/pastors_hymn.dart';

const legacy =
    '<p><span>Пра аднаго пастыра:</span><br />Пачатак гімна.<br />Другі радок.<br /><hr />'
    '<span>Пра Папу:</span><br />Пятровую аўчарню.</p>'
    '<p><span>Пра біскупа:</span><br />Святаром быў для народу.</p>'
    '<p><span>Пра прэзбітэра:</span><br />Ён настаўнікам быў слаўным.<br /><hr />'
    'Агульнае заканчэнне.</p><p>Слава Богу. Амэн.</p><hr />'
    '<p><span>Пра некалькіх пастыраў:</span><br />Святары Найвышэйшага Бога.</p>'
    '<p>Шмат пастыраў. Амэн.</p>';

void main() {
  test('complete hymns have only one middle stanza and the shared ending', () {
    final options = getLiturgicalAlternatives(
      preparePastorsHymn(legacy), kind: 'hymn',
    );
    expect(options.map((o) => o.title), [
      'Пра Папу', 'Пра біскупа', 'Пра прэзбітэра',
      'Пра некалькіх пастыраў',
    ]);
    for (var i = 0; i < options.length; i++) {
      final html = options[i].html;
      expect('<p>'.allMatches(html).length, i == 3 ? 2 : 4);
      expect(html.contains('<hr'), isFalse);
      expect(html.contains('Пра Папу:'), isFalse);
      if (i < 3) {
        expect(html.contains('Пачатак гімна.'), isTrue);
        expect(html.contains('Агульнае заканчэнне.'), isTrue);
        expect(html.contains('Святары Найвышэйшага Бога.'), isFalse);
      } else {
        expect(html.contains('Пачатак гімна.'), isFalse);
      }
    }
    expect(options[0].html.contains('Пятровую аўчарню.'), isTrue);
    expect(options[0].html.contains('Святаром быў для народу.'), isFalse);
    expect(options[1].html.contains('Святаром быў для народу.'), isTrue);
    expect(options[1].html.contains('Ён настаўнікам быў слаўным.'), isFalse);
    expect(options[2].html.contains('Ён настаўнікам быў слаўным.'), isTrue);
  });

  test('default option follows unambiguous rank in feast title', () {
    final cases = <String, String>{
      'Св. Яна Паўла ІІ, папы': 'Пра Папу',
      'Св. Марціна, біскупа': 'Пра біскупа',
      'Св. Яна Марыі, прэзбітэра': 'Пра прэзбітэра',
      'Святых пастыраў': 'Пра некалькіх пастыраў',
    };
    for (final entry in cases.entries) {
      final options = getLiturgicalAlternatives(
        preparePastorsHymn(legacy, entry.key), kind: 'hymn',
      );
      expect(options.first.title, entry.value);
    }
    expect(pastorKindFromTitle('Св. Яна Паўла ІІ'), isEmpty);
    expect(preparePastorsHymn('<p>Звычайны гімн</p>', 'папы'),
        '<p>Звычайны гімн</p>');
  });
}
