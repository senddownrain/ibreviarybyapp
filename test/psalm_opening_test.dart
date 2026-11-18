import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/utils/psalm_opening.dart';

void main() {
  test('only an exact opening antiphon echo is hidden', () {
    final prepared = formatPsalmHtml(
      '<p>Псальм 10</p>'
      '<p><b>Слава нашаму Пану <em>†</em> далей паём *</b> вечна.</p>'
      '<p>Наступная страфа * заўсёды.</p>',
    );
    final result = omitEchoedPsalmOpening(
      prepared,
      '<p><span>1 ант.</span> Слава нашаму Пану.</p>',
    );
    final root = parseFragment(result);
    final verses = root.querySelectorAll('.psalm-strophe');
    expect(verses, hasLength(2));
    expect(verses.first.text.trim().startsWith('далей паём'), isTrue);
    expect(verses.first.text, isNot(contains('Слава нашаму Пану')));
    expect(verses.last.text, contains('Наступная страфа'));
    expect(verses.first.querySelector('b'), isNotNull);
  });

  test('partial, different or missing antiphon retains entire original', () {
    final prepared = formatPsalmHtml(
      '<p>Слава нашаму Пану † далей паём * вечна.</p>',
    );
    for (final ant in <String?>[
      'Ант. Слава нашаму',
      'Ант. Пану слава',
      '',
      null,
    ]) {
      expect(omitEchoedPsalmOpening(prepared, ant), prepared);
    }
  });

  test('exact antiphon through * retains continuation and next stanza', () {
    final prepared = formatPsalmHtml(
      '<p>Божа наш * благаслаўляем Цябе.</p>'
      '<p>Хвала Айцу * Амэн.</p>',
    );
    final result = omitEchoedPsalmOpening(prepared, 'Ант. Божа наш');
    final text = parseFragment(result).text;
    expect(text, contains('благаслаўляем Цябе'));
    expect(text, contains('Хвала Айцу'));
    expect(text, isNot(contains('Божа наш')));
  });

  test('† begins the continuation, while * ends its preceding line', () {
    final html = formatPsalmHtml('<p>Першае † другое * трэцяе.</p>');
    for (final mode in [
      PsalmodyMode.leftBreak,
      PsalmodyMode.leftBreakIndent,
    ]) {
      final result = preparePsalmChoirHtml(html, mode: mode);
      final lines = parseFragment(result).querySelectorAll('.psalm-line');
      expect(lines.length, 3);
      expect(lines[0].text, isNot(contains('†')));
      expect(lines[1].text.trim().startsWith('†'), isTrue);
      expect(lines[1].text, contains('*'));
      expect(lines[2].text.trim(), 'трэцяе.');
    }
  });
}
