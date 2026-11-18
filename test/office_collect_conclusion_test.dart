import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/utils/office_collect_conclusion.dart';

String visible(String html) => parseFragment(html)
    .text!
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

void main() {
  const basilicasCollect =
      '<p style="text-align: justify;">'
      'Усемагутны вечны Божа, захавай Твой Касцёл пад апекаю святых '
      'апосталаў Пятра і Паўла, ад якіх ён атрымаў падставы веры; '
      'праз іх заступніцтва ўчыні, каб ён атрымліваў Твае шчодрыя '
      'ласкі аж да канца свету. Праз Пана нашага.</p>';

  test('18 November shortened Lauds collect receives complete formula', () {
    final formatted = expandOfficeCollectConclusion(basilicasCollect);
    expect(visible(formatted), endsWith(fullOfficeCollectConclusion));
    expect(formatted, contains('святых апосталаў Пятра і Паўла'));
    expect(expandOfficeCollectConclusion(formatted), formatted);
  });

  test('individual choices expand without crossing alternative boundaries', () {
    const choices = '<p>Першы тэкст. Праз Пана нашага.</p>'
        '<hr><p>Другі тэкст. Праз Пана нашага.</p>';
    final formatted = expandOfficeCollectConclusion(choices);
    final root = parseFragment(formatted);
    expect(root.querySelectorAll('p'), hasLength(2));
    for (final prayer in root.querySelectorAll('p')) {
      expect(prayer.text, endsWith(fullOfficeCollectConclusion));
    }
    expect(root.querySelectorAll('hr'), hasLength(1));
  });

  test('plain, simple HTML and inline-styled prayer conclusion', () {
    const plain = 'Прымі, Пане, малітвы. Праз Пана нашага.';
    expect(
      expandOfficeCollectConclusion(plain),
      'Прымі, Пане, малітвы. $fullOfficeCollectConclusion',
    );
    const styled = '<p><em>Прымі, Пане.</em> '
        '<span>Праз Пана нашага.</span></p>';
    expect(
      visible(expandOfficeCollectConclusion(styled)),
      endsWith(fullOfficeCollectConclusion),
    );
  });

  test('never rewrite other or already full prayers', () {
    for (final prayer in [
      '<p>Праз Хрыста, Пана нашага. Амэн.</p>',
      '<p>$fullOfficeCollectConclusion</p>',
      '<p>Цытата: Праз Пана нашага. Іншы сказ.</p>',
      '<p>Праз Пана нашага. Амэн.</p>',
      '<p>Які з Табою жыве і валадарыць. Амэн.</p>',
      '<p>Праз <span>Пана нашага.</span></p>',
    ]) {
      expect(expandOfficeCollectConclusion(prayer), prayer);
    }
  });
}
