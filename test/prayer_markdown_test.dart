import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';

void main() {
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
