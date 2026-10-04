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
    final pieces = extractShortReadingHeader(html)!;
    expect(pieces.title, 'Кароткае чытанне');
    expect(pieces.reference, 'Дрг 8, 5b–6');
    expect(parseFragment(pieces.bodyHtml).text, 'Сыне мой.');
  });

  for (final width in [360.0, 390.0]) {
    testWidgets('short reading header fits $width px and scaled text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
                child: const LiturgicalHeadingReferenceRow(
                  title: 'Кароткае чытанне',
                  reference: '1 Кар 12, 12–31; Эф 4, 11–13',
                  bodySize: 24,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Кароткае чытанне'), findsOneWidget);
      expect(find.text('1 Кар 12, 12–31; Эф 4, 11–13'), findsOneWidget);
    });
  }

  testWidgets('short reading reference sits right on one line when it fits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: LiturgicalHeadingReferenceRow(
              title: 'Кароткае чытанне',
              reference: 'Ер 6, 16',
              bodySize: 16,
            ),
          ),
        ),
      ),
    );
    final title = tester.getTopLeft(find.text('Кароткае чытанне'));
    final reference = tester.getTopLeft(find.text('Ер 6, 16'));
    expect((title.dy - reference.dy).abs(), lessThan(6));
    expect(reference.dx, greaterThan(title.dx + 100));
    expect(tester.takeException(), isNull);
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

  test('leading psalm subtitles recognize nested and styled italics only', () {
    for (final subtitle in [
      '<em>Гэты псальм аддае хвалу</em>',
      '<i>Гэты псальм аддае хвалу</i>',
      '<span><em>Гэты псальм аддае хвалу</em></span>',
      '<span style="font-style: italic">Гэты псальм аддае хвалу</span>',
    ]) {
      final root = parseFragment(
        formatPsalmHtml(
          '<p style="text-align:center">Псальм 92 (91)</p>'
          '<p style="text-align:center">Хвала Богу Стварыцелю</p>'
          '<p>$subtitle</p><p>Добра ёсць дзякаваць Пану.</p>'
          '<p><em>Курсіў у целе псалма</em></p>',
        ),
      );
      expect(
        root.querySelector('.psalm-subtitle')?.text,
        'Гэты псальм аддае хвалу',
      );
      expect(root.querySelectorAll('.psalm-subtitle'), hasLength(1));
      expect(root.querySelectorAll('.psalm-metadata'), hasLength(3));
    }
    final paragraphItalic = parseFragment(
      formatPsalmHtml(
        '<p>Псальм 92 (91)</p>'
        '<p style="font-style: italic">Псальм усхваляе Пана</p>'
        '<p>Добра ёсць дзякаваць Пану.</p>',
      ),
    );
    expect(
      paragraphItalic.querySelector('.psalm-subtitle')?.text,
      'Псальм усхваляе Пана',
    );
  });

  test('structured psalm package keeps antiphons outside psalm metadata', () {
    final root = parseFragment(
      formatPsalmHtml(
        '<p class="ora-ant"><span style="color:red">Ант.</span> Прыйдзіце.</p>'
        '<div class="ora-psalm">'
        '<p style="text-align:center">Псальм 92 (91)</p>'
        '<p><span><em>Гэты псальм аддае хвалу</em></span></p>'
        '<p>Добра ёсць дзякаваць Пану *</p></div>'
        '<p class="ora-ant">Ант. Прыйдзіце.</p>',
      ),
    );
    expect(root.querySelectorAll('.ora-ant'), hasLength(2));
    expect(root.querySelector('.ora-ant.psalm-metadata'), isNull);
    expect(
      root.querySelector('.ora-psalm .psalm-subtitle')?.text,
      'Гэты псальм аддае хвалу',
    );
    expect(root.querySelector('.ora-psalm .psalm-marker')?.text, '*');
  });

  test('responsory turns keep nested emphasis across lost spaces', () {
    for (final source in [
      '<p>К. Першы <em>вылучаны</em> тэкст *Н. Другі адказ.</p>',
      '<p><span style="color:red">К.</span> Першы <em>вылучаны</em> тэкст *'
          '<span style="color:red">Н.</span> Другі адказ.</p>',
      '<p><span>К.</span> Першы <em>вылучаны</em> тэкст *<br>'
          '<span>Н.</span> Другі адказ.</p>',
    ]) {
      final root = parseFragment(
        formatLiturgicalHtml(normalizeOfficeHtml(source)),
      );
      final turns = root.querySelectorAll('.responsory-turn');
      expect(turns, hasLength(2));
      expect(turns.first.querySelector('em')?.text, 'вылучаны');
      expect(turns.first.querySelector('.psalm-marker')?.text, '*');
      expect(turns.last.text.trim(), startsWith('Н.'));
      expect(turns.last.querySelector('.liturgical-rubric-inline')?.text, 'Н.');
      expect(root.text, contains('Другі адказ.'));
    }
  });

  test('Hours use one psalm rhythm and shared canticle composition', () {
    final source = File('lib/screens/ora_screen.dart').readAsStringSync();
    expect(
      RegExp(r'_OraItem\.psalmGap\(').allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
    expect(source, contains('psalmBlockSpacerAfter'));
    expect(
      psalmBlockSpacerAfter(antiphon: true) + LiturgicalSpacing.antiphonToPsalm,
      psalmBlockSpacerAfter(antiphon: false) + LiturgicalSpacing.paragraphAfter,
    );
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
