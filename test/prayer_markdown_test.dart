import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';
import 'package:mybrev_flutter/utils/prayer_link.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:html/parser.dart' show parseFragment;

void main() {
  test('portable editor links preserve escaped labels and encoded IDs', () {
    const source =
        r'[Малітва \[вечар\] \*і\* \_ноч\_](/prayer/local_one_two%20be)';
    final link = parseFragment(
      prayerMarkdownToHtml(source),
    ).querySelector('a')!;
    expect(link.text, 'Малітва [вечар] *і* _ноч_');
    expect(link.attributes['href'], '/prayer/local_one_two%20be');
    expect(
      prayerLinkLocation(link.attributes['href']),
      '/prayers/prayer/local_one_two%20be',
    );
    expect(const Prayer(id: 'one', title: '', body: source).isMarkdown, isTrue);
  });

  test('only relative prayer reader links resolve internally', () {
    expect(
      prayerLinkLocation('/prayer/abc?lang=be#text'),
      '/prayers/prayer/abc',
    );
    expect(prayerLinkLocation('/prayers/prayer/abc'), '/prayers/prayer/abc');
    for (final href in [
      null,
      '/prayer/',
      '/prayer/add',
      '/prayer/a/edit',
      '/prayer/a%2Fb',
      '/prayer/%ZZ',
      'https://example.com/prayer/abc',
      '//example.com/prayer/abc',
      '/settings',
    ]) {
      expect(prayerLinkLocation(href), isNull, reason: '$href');
    }
  });

  test('prayer Markdown renders the formatting offered by the editor', () {
    final html = prayerMarkdownToHtml('''## Загаловак

**Тлусты** і *курсіў*.

- Першы радок
- Другі радок''');

    expect(html, contains('<h2>Загаловак</h2>'));
    expect(html, contains('<strong>Тлусты</strong>'));
    expect(html, contains('<em>курсіў</em>'));
    expect(html, contains('<ul>'));
    expect(html, contains('<li>Першы радок</li>'));
    expect(html, contains('<li>Другі радок</li>'));
  });
}
