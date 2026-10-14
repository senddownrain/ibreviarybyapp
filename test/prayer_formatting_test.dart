import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/utils/prayer_html.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';

void main() {
  test('all contract labels, colons, indentation and breaks preserve text', () {
    for (final entry in prayerSpeakers.entries) {
      final source =
          '  ${entry.key}:\tПан з вамі.\n${entry.key} І з духам тваім.';
      final doc = parseFragment(prayerMarkdownToHtml(source));
      final labels = doc.querySelectorAll('.prayer-speaker');
      expect(labels.map((e) => e.text), ['${entry.key}:', entry.key]);
      expect(
        labels.map((e) => e.attributes['data-role']),
        everyElement(entry.value),
      );
      expect(doc.querySelectorAll('br'), hasLength(1));
      expect(
        doc.querySelector('p')!.innerHtml,
        contains('</span>\tПан з вамі.<br>'),
      );
    }
  });

  test('semantic exclusions protect names and structured content', () {
    final source = [
      'С. Я. Купала',
      'К. Купала',
      'С. Купала Янка',
      'Тэкст: Н. І з духам тваім.',
      'Народ моліцца.',
      'C. Пан з вамі.',
      'K. Пан з вамі.',
      'H. І з духам тваім.',
      'N. Name',
      'P. Dominus vobiscum.',
      'с. пан з вамі.',
      '[С. Пан з вамі.](/prayer/id)',
      '`Н. І з духам тваім.`',
      '# С. Пан з вамі.',
      ':::rubric\nС. Пан з вамі.\n:::',
      '```md\nК. Пане, пачуй нас.\n```',
      '    Н. І з духам тваім.',
      '- Н. І з духам тваім.',
      r'\С. Пан з вамі.',
      'С. ',
      'С.Пан з вамі.',
    ].join('\n\n');
    expect(
      parseFragment(
        prayerMarkdownToHtml(source),
      ).querySelectorAll('.prayer-speaker'),
      isEmpty,
    );
  });

  test(
    'links, nested emphasis, reference links, headings and lists use AST',
    () {
      const source =
          '# Загаловак\n\nН. _Молімся._ [Іншая **малітва**](/prayer/id)\n'
          'К. **Пане, _пачуй_ нас.**\n\n- першы\n  - укладзены\n\n'
          '3. трэці\n\n[Спасылка][ref]\n\n[ref]: /prayer/test-id';
      final doc = parseFragment(prayerMarkdownToHtml(source));
      expect(doc.querySelector('h1')!.text, 'Загаловак');
      expect(doc.querySelectorAll('.prayer-speaker'), hasLength(2));
      expect(doc.querySelectorAll('a').map((e) => e.attributes['href']), [
        '/prayer/id',
        '/prayer/test-id',
      ]);
      expect(doc.querySelector('strong em')!.text, 'пачуй');
      expect(doc.querySelector('ul ul'), isNotNull);
      expect(doc.querySelector('ol')!.attributes['start'], '3');
    },
  );

  test('rubrics and real quotes render structurally without mutating source', () {
    const source =
        'К. Пане, адкрый вусны мае.\nН. І вусны мае будуць абвяшчаць хвалу Тваю.\n\n'
        'С.: Пан з вамі.\nН.: І з духам тваім.\n\n:::rubric\nУсе ўстаюць.\n:::\n\n'
        '> Гэта сапраўдная цытата.\n\n[Іншая малітва](/prayer/test-id)';
    final prayer = Prayer.fromMap({
      'text': source,
      'textFormat': 'mybrev-markdown',
    }, 'fixture');
    final doc = parseFragment(prayerMarkdownToHtml(prayer.displayText));
    expect(doc.querySelectorAll('.prayer-speaker'), hasLength(4));
    expect(
      doc.querySelector('aside.prayer-rubric')!.text.trim(),
      'Усе ўстаюць.',
    );
    expect(
      doc.querySelector('blockquote')!.text.trim(),
      'Гэта сапраўдная цытата.',
    );
    expect(doc.outerHtml, isNot(contains('&gt;')));
    expect(prayer.toMap()['text'], source);
    expect(prayer.displayText, contains('> Гэта'));
    // A mistaken import is still a quote, with semantic speaker styling inside
    // it. Only an author can decide whether the source marker should be removed.
    expect(
      parseFragment(
        prayerMarkdownToHtml('> Н. І з духам тваім.'),
      ).querySelectorAll('blockquote .prayer-speaker').map((e) => e.text),
      ['Н.'],
    );
    expect(
      parseFragment(prayerMarkdownToHtml(r'\> Н. І з духам тваім.')).text,
      contains('> Н.'),
    );
  });

  test(
    'quoted dialogue labels preserve blockquote and source for all roles',
    () {
      for (final entry in prayerSpeakers.entries) {
        final source = '> Гэта цытата.\n> ${entry.key}: І з духам тваім.';
        final prayer = Prayer(
          id: 'quote',
          title: '',
          body: source,
          textFormat: 'mybrev-markdown',
        );
        final doc = parseFragment(prayerMarkdownToHtml(prayer.displayText));
        final quote = doc.querySelector('blockquote')!;
        final label = quote.querySelector('.prayer-speaker')!;
        expect(label.text, '${entry.key}:');
        expect(label.attributes['data-role'], entry.value);
        expect(label.parent!.localName, 'p');
        expect(quote.querySelectorAll('.prayer-speaker'), hasLength(1));
        expect(quote.innerHtml, contains('</span> І з духам тваім.'));
        expect(quote.querySelectorAll('br'), hasLength(1));
        expect(prayer.toMap()['text'], source);
        expect(doc.outerHtml, isNot(contains('&gt;')));
      }
      final exact = parseFragment(
        prayerMarkdownToHtml('> Н. І з духам тваім.'),
      );
      expect(exact.querySelector('blockquote .prayer-speaker')!.text, 'Н.');
      expect(
        exact.querySelector('blockquote')!.text.trim(),
        'Н. І з духам тваім.',
      );
    },
  );

  test(
    'quoted narrative, names, initials, explicit formatting and code stay excluded',
    () {
      final source = [
        '> С. Я. Купала',
        '> К. Купала',
        '> Тэкст: Н. І з духам тваім.',
        '> C. Пан з вамі.',
        '> N. Name',
        '> **Н.** І з духам тваім.',
        '> `Н. І з духам тваім.`',
        '> [Н. І з духам тваім.](/prayer/id)',
        '> # Н. І з духам тваім.',
        '> - Н. І з духам тваім.',
        '> ```md\n> Н. І з духам тваім.\n> ```',
        '>     Н. І з духам тваім.',
        '> :::rubric\n> Н. І з духам тваім.\n> :::',
      ].join('\n\n');
      expect(
        parseFragment(
          prayerMarkdownToHtml(source),
        ).querySelectorAll('.prayer-speaker'),
        isEmpty,
      );
      final nested = parseFragment(
        prayerMarkdownToHtml('> > Н. І з духам тваім.'),
      );
      expect(
        nested.querySelector('blockquote blockquote .prayer-speaker')!.text,
        'Н.',
      );
    },
  );

  test('unclosed rubric stays visible, fenced directives remain code', () {
    final doc = parseFragment(prayerMarkdownToHtml(':::rubric\nУсе ўстаюць.'));
    expect(doc.querySelector('aside'), isNull);
    expect(doc.text, contains(':::rubric'));
    final code = parseFragment(
      prayerMarkdownToHtml('```\n:::rubric\nН. Amen.\n:::\n```'),
    );
    expect(code.querySelector('aside'), isNull);
    expect(code.querySelector('code')!.text, contains(':::rubric'));
  });

  test('long multilingual litany retains responses and authored words', () {
    final lines = List.generate(400, (i) => 'Н. Змілуйся над намі. $i');
    final doc = parseFragment(
      prayerMarkdownToHtml(
        '${lines.join('\n')}\nV. Ora pro nobis.\nR. Pray for us.',
      ),
    );
    expect(doc.querySelectorAll('.prayer-speaker'), hasLength(402));
    expect(doc.querySelectorAll('br'), hasLength(401));
    expect(doc.text, contains('Змілуйся над намі. 399'));
  });

  test('Markdown HTML is escaped and malicious URIs cannot be rendered', () {
    final doc = parseFragment(
      prayerMarkdownToHtml(
        '<script>alert(1)</script>\n<img src=x onerror=alert(1)>\n'
        '[bad](javascript:alert(1)) [data](data:text/html,bad) [file](file:///secret) [protocol](//evil.test)\n'
        '[encoded](javascript&#58;alert) [safe](/prayer/test-id)',
      ),
    );
    expect(doc.querySelectorAll('script, img'), isEmpty);
    expect(doc.text, contains('<script>alert(1)</script>'));
    expect(doc.querySelectorAll('a[href]').map((e) => e.attributes['href']), [
      '/prayer/test-id',
    ]);
  });

  test('legacy HTML keeps presentation but drops active tags and attributes', () {
    final doc = parseFragment(
      sanitizePrayerHtml(
        '<p style="color:red;text-align:center;background-image:url(https://evil)" onclick="evil()">'
        '<strong>Молімся.</strong><br><a href="java&#10;script:evil()">Словы</a>'
        '<a href="/prayer/id">Іншая</a><img src="https://evil" alt="Вобраз">'
        '<script>evil()</script><iframe src="https://evil"></iframe></p>',
      ),
    );
    expect(doc.querySelector('strong')!.text, 'Молімся.');
    expect(
      doc.querySelector('p')!.attributes['style'],
      'color:red;text-align:center',
    );
    expect(doc.querySelectorAll('script, iframe, img, [onclick]'), isEmpty);
    expect(doc.querySelectorAll('a[href]'), hasLength(1));
    expect(doc.text, contains('Вобраз'));
  });

  test('Mass opts out of generic role semantics', () {
    final html = prayerMarkdownToHtml(
      'С. Пан з вамі.\nН. І з духам тваім.',
      recognizeSpeakers: false,
    );
    expect(html, isNot(contains('prayer-speaker')));
    expect(parseFragment(html).querySelectorAll('br'), hasLength(1));
  });

  test(
    'unmarked plain text, quotes and emphasis use Markdown; legacy uses HTML',
    () {
      for (final source in [
        'Н. Амэн.',
        '> Цытата.',
        '*Молімся.*',
        '- Тэкст',
        'x < 3',
      ]) {
        expect(Prayer(id: 'id', title: '', body: source).isMarkdown, isTrue);
      }
      expect(
        const Prayer(id: 'id', title: '', body: '<p>Амэн.</p>').isMarkdown,
        isFalse,
      );
      expect(
        const Prayer(
          id: 'id',
          title: '',
          body: '<p>Амэн.</p>',
          textFormat: 'mybrev-markdown',
        ).isMarkdown,
        isTrue,
      );
      final localized = Prayer.fromMap({
        'textVersions': {'be': 'Н. Амэн.', 'la': 'R. Amen.'},
      }, 'id');
      expect(localized.displayText, 'Н. Амэн.');
    },
  );
}
