import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/utils/prayer_markdown.dart';
import 'package:mybrev_flutter/utils/prayer_legacy_html.dart';

void main() {
  final oracle =
      jsonDecode(
            File('test/support/prayer_11_web_oracle.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  test('oracle is pinned to the approved web commit', () {
    expect(oracle['webCommit'], '0fcce378d6dd4b6f3d67a35fb45e44f49c5da4af');
  });
  for (final entry in oracle['cases'] as List) {
    final fixture = entry as Map<String, dynamic>;
    test('web 1.1: ${fixture['name']}', () {
      final source = fixture['source'] as String;
      final html = prayerMarkdownToHtml(
        fixture['format'] == 'html'
            ? prayerLegacyHtmlToMarkdown(source)
            : source,
      );
      Map<String, Object> summarize(String renderedHtml) {
        final doc = parseFragment(renderedHtml);
        String clean(String text) =>
            text.replaceAll(RegExp(r'\s+'), ' ').trim();
        return {
          'text': clean(doc.text ?? ''),
          'speakers': doc
              .querySelectorAll('.prayer-speaker')
              .map((n) => [n.text, n.attributes['data-role']])
              .toList(),
          'rubrics': doc
              .querySelectorAll('.prayer-rubric')
              .map((n) => clean(n.text))
              .toList(),
          'emphasis': doc
              .querySelectorAll('em, strong')
              .map((n) => [n.localName, clean(n.text)])
              .toList(),
          'links': doc
              .querySelectorAll('a')
              .map(
                (n) => [
                  clean(n.text),
                  n.attributes['href'] ?? '',
                  n.attributes['title'] ?? '',
                ],
              )
              .toList(),
          'headings': doc
              .querySelectorAll('h1,h2,h3,h4,h5,h6')
              .map((n) => [n.localName, clean(n.text)])
              .toList(),
          'quotes': doc.querySelectorAll('blockquote').length,
          'breaks': doc.querySelectorAll('br').length,
          'code': doc.querySelectorAll('code').map((n) => n.text).toList(),
        };
      }

      expect(
        summarize(html),
        summarize(fixture['expectedHtml'] as String),
        reason:
            'Source: $source\nFlutter: $html\nWeb: ${fixture['expectedHtml']}',
      );
    });
  }
}
