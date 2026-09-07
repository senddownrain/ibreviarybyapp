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
  });
}
