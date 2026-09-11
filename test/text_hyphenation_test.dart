import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/utils/text_hyphenation.dart';

void main() {
  test('adds optional Russian-pattern hyphenation to Belarusian text', () {
    final result = hyphenateReaderText('благаслаўленне');

    expect(result, contains(softHyphen));
    expect(result.replaceAll(softHyphen, ''), 'благаслаўленне');
  });

  test('hyphenates visible HTML without changing markup or entities', () {
    const source = '<p class="prayer">благословение&nbsp;милосердие</p>';
    final result = hyphenateReaderHtml(source);

    expect(result, startsWith('<p class="prayer">'));
    expect(result, contains('&nbsp;'));
    expect(result, endsWith('</p>'));
    expect(result, contains(softHyphen));
    expect(result.replaceAll(softHyphen, ''), source);
  });

  test('does not add the same soft hyphens twice', () {
    final once = hyphenateReaderText('благословение');

    expect(hyphenateReaderText(once), once);
  });
}
