import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/utils/office_responsory_repeats.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';

List<String> replies(String html) => parseFragment(html)
    .querySelectorAll('p')
    .map((p) => p.text.replaceAll(RegExp(r'\s+'), ' ').trim())
    .toList();

void main() {
  test('actual Office screenshots show full repeated responses', () {
    const first = '<p>Рэспансорый</p>'
        '<p><span>Н.</span> Перш, чым убачыш * Жыві паводле веры, каб змог убачыць.</p>'
        '<p>К. Вера.</p><p>Н. Жыві.</p>';
    const second = '<p>Н. Я ўратую іх * І развесяліцца сэрца іхняе ў Пану.</p>'
        '<p>К. Пан.</p><p>Н. І развесяліцца.</p>';
    final firstResult = normalizeOfficeHtml(first, officeReading: true);
    final secondResult = normalizeOfficeHtml(second, officeReading: true);
    expect(replies(firstResult).last, 'Н. Жыві паводле веры, каб змог убачыць.');
    expect(replies(secondResult).last, 'Н. І развесяліцца сэрца іхняе ў Пану.');
  });
  test('initial ў in asterisk repeat matches capital У, not inner occurrences', () {
    const source = '<p>Н. Пачакай * ў жыцці ў Пану будзем разам.</p>'
        '<p>К. Верш.</p><p>Н. У жыцці.</p>';
    final result = expandOfficeResponsoryRepeats(source);
    expect(replies(result).last, 'Н. У жыцці ў Пану будзем разам.');
    expect(expandOfficeResponsoryRepeats(result), result);
  });
  test('keeps separate variants and cannot invent mismatched completion', () {
    const source = '<div data-alternative-title="А">'
        '<p>Н. Першы * Жыві паводле веры.</p><p>К. Верш.</p><p>Н. Жыві.</p>'
        '</div><hr><div data-alternative-title="Б">'
        '<p>Н. Другі * Іншы хвост.</p><p>К. Верш.</p><p>Н. Жыві.</p>'
        '</div>';
    final out = expandOfficeResponsoryRepeats(source);
    final blocks = parseFragment(out).querySelectorAll('[data-alternative-title]');
    expect(replies(blocks.first.outerHtml).last, 'Н. Жыві паводле веры.');
    expect(replies(blocks.last.outerHtml).last, 'Н. Жыві.');
  });
  test('ambiguous, already full, absent star and rule boundary are unchanged', () {
    for (final source in [
      '<p>Н. Адказ.</p><p>К. Верш.</p><p>Н. Адказ.</p>',
      '<p>Н. Адказ * Жыві паводле веры.</p><p>К. Верш.</p><p>Н. Іншае.</p>',
      '<p>Н. Адказ * Жыві паводле веры.</p><p>К. Верш.</p><p>Н. Жыві паводле веры.</p>',
      '<p>Н. Адказ * Жыві паводле веры.</p><hr><p>К. Верш.</p><p>Н. Жыві.</p>',
    ]) {
      expect(expandOfficeResponsoryRepeats(source), source);
    }
  });
  test('short response expands repeated text without changing doxology', () {
    const source = '<p>К. Мой Бог – мая дапамога, * я на Яго спадзяюся.</p>'
        '<p>Н. Мой Бог.</p><p>К. Прыстанішча маё.</p><p>Н. Я на.</p>'
        '<p>К. Хвала Айцу і Сыну.</p><p>Н. Мой Бог.</p>';
    final out = replies(expandOfficeResponsoryRepeats(source));
    expect(out[1], 'Н. Мой Бог – мая дапамога, * я на Яго спадзяюся.');
    expect(out[3], 'Н. Я на Яго спадзяюся.');
    expect(out[4], 'К. Хвала Айцу і Сыну.');
  });
}
