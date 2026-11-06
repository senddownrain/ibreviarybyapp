import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';

void main() {
  test('semantic choir overrides visual parity class', () {
    const source =
        '<p class="psalm-strophe psalm-strophe-even" data-psalm-choir="1">A * B</p>';
    for (final mode in PsalmodyMode.values) {
      final root = parseFragment(
        preparePsalmChoirHtml(
          markLiturgicalCadenceSigns(source),
          mode: mode,
          selectedChoir: 1,
        ),
      );
      expect(
        root
            .querySelectorAll('a')
            .every(
              (a) =>
                  a.attributes['href'] == 'psalm-choir:1' &&
                  a.classes.contains('psalm-choir-muted'),
            ),
        isTrue,
      );
    }
  });
  for (final name in [
    'Ютрань',
    'Нешпары',
    'Гадзіна чытанняў',
    'Камплета',
    'Benedictus',
    'Magnificat',
    'Nunc dimittis',
  ]) {
    for (final mode in PsalmodyMode.values) {
      test(
        '$name ${mode.name}: one continuous strophe or non-nested continuations',
        () {
          // Already structured content: several verses and a nested source br
          // belong to ONE strophe; the second strophe is semantic choir 2.
          final source =
              '<h3>$name</h3><p class="ora-ant">Ант. Тэкст<br>антыфоны</p>'
              '<p class="psalm-strophe" data-psalm-choir="1">'
              '1. <b>Пачатак <em>†</em> працяг<br>верша *</b> '
              '<i>канец</i><br>2. <strong>Яшчэ † словы *</strong> завяршэнне.</p>'
              '<p class="psalm-strophe psalm-strophe-even" data-psalm-choir="2">'
              '3. Доўгая страфа * ${List.filled(30, 'слова').join(' ')} † Амэн.</p>'
              '<p class="liturgical-rubric">Рубрыка<br>без зменаў.</p>';
          final marked = markLiturgicalCadenceSigns(source);
          final output = preparePsalmChoirHtml(
            marked,
            mode: mode,
            selectedChoir: 2,
          );
          final root = parseFragment(output);
          final strophes = root.querySelectorAll('.psalm-strophe');
          expect(strophes, hasLength(2));
          final before = parseFragment(marked);
          String words(String html) => parseFragment(
            html.replaceAll(RegExp(r'<br\s*/?>'), ' '),
          ).text!.replaceAll(RegExp(r'\s+'), ' ').trim();
          expect(words(output), words(marked));
          expect(
            root.querySelector('.ora-ant')!.outerHtml,
            before.querySelector('.ora-ant')!.outerHtml,
          );
          expect(
            root.querySelector('.liturgical-rubric')!.outerHtml,
            before.querySelector('.liturgical-rubric')!.outerHtml,
          );
          expect(strophes.first.querySelector('b em'), isNotNull);
          expect(strophes.first.querySelector('i')!.text, 'канец');
          expect(root.querySelectorAll('.psalm-choir-muted'), isNotEmpty);
          expect(
            root
                .querySelectorAll('.psalm-choir-muted')
                .every((a) => a.attributes['href'] == 'psalm-choir:2'),
            isTrue,
          );
          for (final strophe in strophes) {
            if (mode == PsalmodyMode.alternatingStanzas) {
              expect(strophe.querySelector('br'), isNull);
              expect(strophe.querySelector('.psalm-line'), isNull);
              expect(strophe.querySelector('.psalm-continuation'), isNull);
            } else {
              expect(strophe.querySelectorAll('.psalm-line'), isNotEmpty);
              expect(
                strophe.querySelector(
                  '.psalm-continuation .psalm-continuation',
                ),
                isNull,
              );
            }
          }
          expect(root.querySelectorAll('.psalm-marker'), hasLength(6));
        },
      );
    }
  }
}
