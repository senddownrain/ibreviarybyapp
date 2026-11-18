import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';

void main() {
  test(
    'first reading citation separates from book introduction without uppercasing it',
    () {
      final source =
          '<p>Пачатак Паслання да Галатаў <span style="color:red">1, 1–12</span></p><p>Тэкст чытання.</p>';
      final h = extractOfficeReadingReference(source);
      expect(h.reference, '1, 1–12');
      expect(
        parseFragment(h.bodyHtml).text,
        contains('Пачатак Паслання да Галатаў'),
      );
      expect(parseFragment(h.bodyHtml).text, contains('Тэкст чытання.'));
    },
  );
  test(
    'standalone Scripture reference keeps case and numbering; Patristic annotation stays in body',
    () {
      expect(
        extractOfficeReadingReference(
          '<p>1 Ян 3, 1а–2</p><p>Тэкст.</p>',
        ).reference,
        '1 Ян 3, 1а–2',
      );
      const source =
          '<p>Каментарый святога Аўгустына</p><p>(Praefatio: PL 35, 2105–2107)</p>';
      expect(extractOfficeReadingReference(source).reference, isNull);
      expect(extractOfficeReadingReference(source).bodyHtml, source);
    },
  );
  test('wrapper cannot pull a later verse out of reading content', () {
    const source =
        '<div><p>Пачатак чытання.</p><p>Тэкст <span style="color:red">3, 2</span></p></div>';
    expect(extractOfficeReadingReference(source).reference, isNull);
    expect(extractOfficeReadingReference(source).bodyHtml, source);
    const patristic = '<p>(PL 35, 2105–2107)</p><p>Тэкст.</p>';
    expect(extractOfficeReadingReference(patristic).reference, isNull);
    expect(extractOfficeReadingReference(patristic).bodyHtml, patristic);
  });
}
