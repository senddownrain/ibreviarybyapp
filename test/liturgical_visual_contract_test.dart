import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';

void main() {
  testWidgets('document role typography follows one reader contract', (
    tester,
  ) async {
    late ReaderTheme reader;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            reader = ReaderTheme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final heading = reader.blockHeading(16);
    final rubric = reader.rubricBlock(16);
    final styles = liturgicalDocumentStyles(
      reader: reader,
      body: reader.body(16),
    );
    expect(heading.fontFamily, startsWith('CormorantGaramond'));
    expect(heading.color, reader.rubric);
    expect(rubric.fontStyle, FontStyle.normal);
    expect(rubric.fontSize, lessThan(16));
    expect(styles, contains('.office-reading-pericope-title'));
    expect(styles, contains('.liturgical-rubric'));
    final htmlRubric = styles['.liturgical-rubric']!;
    final prayerRubric = readerRubricHtmlStyle(
      reader: reader,
      body: reader.body(16),
    );
    expect(htmlRubric.color, prayerRubric.color);
    expect(htmlRubric.fontSize?.value, prayerRubric.fontSize?.value);
    expect(htmlRubric.lineHeight?.size, prayerRubric.lineHeight?.size);
    expect(htmlRubric.fontStyle, FontStyle.normal);
    expect(styles['.liturgical-reading-reference']?.color, reader.muted);
  });

  test('short reading title and reference become distinct roles', () {
    final html = normalizeOfficeHtml(
      '<p><span>КАРОТКАЕ ЧЫТАННЕ Дрг 8, 5b–6</span></p><p>Сыне мой.</p>',
    );
    final root = parseFragment(html);
    expect(root.querySelector('.liturgical-heading')?.text, 'Кароткае чытанне');
    expect(root.querySelector('.liturgical-reference')?.text, 'Дрг 8, 5b–6');
    expect(root.querySelectorAll('p').last.text, 'Сыне мой.');
  });

  test('bundled feast reading splits real legacy heading and turns', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/office_assembly_parity.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final templates = fixture['templates'] as Map<String, dynamic>;
    final apostle = templates['apostles'] as Map<String, dynamic>;
    final html = normalizeOfficeHtml(apostle['vesperR'] as String);
    final root = parseFragment(html);
    expect(root.querySelector('.liturgical-heading')?.text, 'Кароткае чытанне');
    expect(root.querySelector('.liturgical-reference')?.text, 'Эф 4, 11-13');
    expect(
      root.querySelectorAll('.responsory-turn').length,
      greaterThanOrEqualTo(4),
    );
    expect(root.text, contains('Хрыстус паставіў адных апосталамі'));
  });

  test(
    'responsory title, reference and speaker turns survive HTML and plain',
    () {
      for (final source in [
        '<p>Рэспансорый Флп 4, 12–13; 2 Кар 12, 10а</p>'
            '<p><span style="color:red">К.</span> Упадабай я слабасць * за Хрыста. '
            '<span style="color:red">Н.</span> Усё.</p>',
        'Рэспансорый Флп 4, 12–13; 2 Кар 12, 10а\n'
            'К. Упадабай я слабасць * за Хрыста. Н. Усё.',
        'Кароткі рэспансорый\nК. Першы †\nН. Другі.',
      ]) {
        final normalized = normalizeOfficeHtml(source);
        final rendered = formatLiturgicalHtml(normalized);
        final root = parseFragment(rendered);
        expect(root.querySelector('.liturgical-heading'), isNotNull);
        final turns = root.querySelectorAll('.responsory-turn');
        expect(turns, hasLength(2));
        expect(turns.first.text.trim(), startsWith('К.'));
        expect(turns.last.text.trim(), startsWith('Н.'));
        expect(root.text, anyOf(contains('Усё.'), contains('Другі.')));
        expect(rendered, contains('liturgical-rubric-inline'));
        expect(rendered, contains('psalm-marker'));
        if (source.startsWith('Рэспансорый')) {
          expect(
            root.querySelector('.liturgical-reference')?.text,
            'Флп 4, 12–13; 2 Кар 12, 10а',
          );
        }
      }
    },
  );

  test(
    'office reading thematic title is red-role and loses source emphasis',
    () {
      final html = normalizeOfficeHtml(
        '<p>Пасланне св. апостала Паўла</p><p>Флп 4, 10–23</p>'
        '<p><em>Велікадушнасць філіпянаў адносна Паўла</em></p>'
        '<p>Браты, я ўзрадаваўся.</p>',
        officeReading: true,
      );
      final root = parseFragment(html);
      final title = root.querySelector('.office-reading-pericope-title');
      expect(title?.text, 'Велікадушнасць філіпянаў адносна Паўла');
      expect(title?.querySelector('em'), isNull);
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/office_assembly_parity.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final source =
          (fixture['templates']
                  as Map<String, dynamic>)['apostles']['officeOfReadingsR1']
              as String;
      final actual = parseFragment(
        normalizeOfficeHtml(source, officeReading: true),
      );
      expect(
        actual.querySelector('.office-reading-pericope-title')?.text,
        contains('Мы наследуем Апостала'),
      );
    },
  );

  test('rubric block removes inherited source italics', () {
    final html = formatLiturgicalHtml(
      '<p class="liturgical-rubric"><span style="color:red">'
      '<em>Потым, калі прысутнічае святар.</em></span></p>',
    );
    expect(html, contains('liturgical-rubric'));
    expect(html, isNot(contains('<em>')));
    final legacy = formatLiturgicalHtml(
      '<p><span style="color:red"><em>Потым прамаўляецца благаслаўленне.</em></span></p>',
    );
    expect(legacy, contains('class="liturgical-rubric"'));
    expect(legacy, isNot(contains('<em>')));
  });

  test('psalm subtitle has a distinct metadata role', () {
    final html = formatPsalmHtml(
      '<p><span style="color:red">Псальм 63 (62), 2–9</span></p>'
      '<p><em>Той з Богам, хто адкідае ўчынкі цемры</em></p>'
      '<p>Божа, Ты Бог мой *</p>',
    );
    final root = parseFragment(html);
    expect(
      root.querySelector('.psalm-subtitle')?.text,
      'Той з Богам, хто адкідае ўчынкі цемры',
    );
    expect(root.querySelector('.psalm-marker'), isNotNull);
  });

  test('Hours use one psalm rhythm and shared canticle composition', () {
    final source = File('lib/screens/ora_screen.dart').readAsStringSync();
    expect(
      RegExp(r'_OraItem\.psalmGap\(\)').allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
    expect(source, contains('LiturgicalSpacing.psalmBlockToNext'));
    expect(source, contains('LiturgicalSpacing.antiphonToPsalm'));
    final compline = source.substring(
      source.indexOf('final antS = cf('),
      source.indexOf("final pr = cf('compPr')"),
    );
    expect(
      compline.indexOf('_OraItem.antiphon(antS'),
      lessThan(compline.indexOf('_OraItem.serviceHeader(')),
    );
    expect(
      compline.indexOf('_OraItem.serviceHeader('),
      lessThan(compline.indexOf('Песня Сімяона')),
    );
    expect(
      compline.indexOf('Песня Сімяона'),
      lessThan(compline.indexOf('_OraItem.psalm(_kNunc)')),
    );
  });
}
