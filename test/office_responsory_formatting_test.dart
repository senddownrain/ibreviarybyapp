import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';

void main() {
  const reference = 'пар. 2 Кар 1, 3–5';
  for (final (name, source) in [
    ('paragraph', '<p>Рэспансорый $reference</p><p>Н. Адказ.</p>'),
    (
      'inline spans',
      '<p><b><span>Рэспансорый</span></b> <i>$reference</i><br>Н. Адказ.</p>',
    ),
    (
      'inside reading',
      '<p>Слова <em>чытання</em>.<br><br><span style="color:red">Рэспансорый $reference</span><br>Н. Адказ.</p>',
    ),
    ('div', '<div>Рэспансорый $reference<br>Н. Адказ.</div>'),
    ('heading tag', '<h3>Рэспансорый $reference</h3><p>Н. Адказ.</p>'),
    ('inline root', '<span>Рэспансорый $reference</span><br>Н. Адказ.'),
    ('reference on next line', '<p>Рэспансорый<br>$reference<br>Н. Адказ.</p>'),
    (
      'separate reference',
      '<p>Рэспансорый</p><p>$reference</p><p>Н. Адказ.</p>',
    ),
    ('plain text', 'Рэспансорый $reference\nН. Адказ.'),
  ]) {
    test('responsory heading is uppercase, reference retains case: $name', () {
      final html = formatLiturgicalHtml(
        normalizeOfficeHtml(source, officeReading: true),
      );
      final root = parseFragment(html);
      expect(root.querySelector('.liturgical-heading')!.text, 'РЭСПАНСОРЫЙ');
      expect(root.querySelector('.liturgical-reference')!.text, reference);
      expect(root.querySelector('.responsory-turn')!.text, 'Н. Адказ.');
      if (name == 'inside reading') {
        expect(root.querySelector('em')!.text, 'чытання');
        expect(root.nodes.first.text, 'Слова чытання.');
      }
    });
  }

  test('normalized responsory roles do not become small leading metadata', () {
    final root = parseFragment(
      formatLiturgicalHtml(
        normalizeOfficeHtml(
          '<p><span style="color:red">КАРОТКІ РЭСПАНСОРЫЙ</span></p>'
          '<p><span style="color:red"><b>К. Адказ *</b></span></p>'
          '<p><br></p><p>Н. Паўтор.</p><p>* Працяг.</p>',
        ),
      ),
    );
    expect(root.querySelectorAll('.responsory-turn'), hasLength(3));
    expect(
      root.querySelectorAll('.responsory-turn.liturgical-subheading'),
      isEmpty,
    );
    expect(
      root.querySelectorAll('p').any((p) => p.text.trim().isEmpty),
      isFalse,
    );
    expect(
      root.querySelectorAll('.psalm-marker').every((m) => m.text == '*'),
      isTrue,
    );
    expect(root.text, contains('К. Адказ *Н. Паўтор.* Працяг.'));
  });

  for (final size in [16.0, 24.0]) {
    testWidgets('adjacent turns add no paragraph gap at body size $size', (
      tester,
    ) async {
      await tester.pumpWidget(
        ReaderTypographyScope(
          useSystemFonts: true,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final reader = ReaderTheme.of(context);
                  final styles = liturgicalDocumentStyles(
                    reader: reader,
                    body: reader.body(size),
                  );
                  return Column(
                    children: [
                      LiturgicalResponsoryBlock(
                        key: const Key('turns'),
                        html:
                            '<p class="responsory-turn">К. Адказ *</p><p class="responsory-turn">Н. Паўтор.</p>',
                        style: styles,
                      ),
                      LiturgicalResponsoryBlock(
                        key: const Key('lines'),
                        html:
                            '<p class="responsory-turn">К. Адказ *<br>Н. Паўтор.</p>',
                        style: styles,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('turns'))).height,
        lessThanOrEqualTo(
          tester.getSize(find.byKey(const Key('lines'))).height + 1,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
