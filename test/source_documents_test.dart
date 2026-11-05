import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/source_documents.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/services/bible_seed_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRegistry registry;
  setUpAll(() async => registry = await SourceRegistry.load());

  test(
    'all imported bytes and Bible corpora match the pinned Web lock',
    () async {
      final lock =
          jsonDecode(
                File('docs/sources/web-import-lock.json').readAsStringSync(),
              )
              as Map;
      expect(lock['commit'], 'f185657e88436eb8c6adb0f666b6e50bed416b40');
      expect(lock['files'], hasLength(4));
      expect(lock['bibleCorpora'], hasLength(2));
      for (final file in [...lock['files'], ...lock['bibleCorpora']]) {
        final data = await rootBundle.load(file['flutter'] as String);
        expect(
          sha256
              .convert(
                data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
              )
              .toString(),
          file['sha256'],
          reason: file['flutter'] as String,
        );
      }
    },
  );

  test('six IDs, exact bibliography and nullable rights remain intact', () {
    expect(registry.entries.map((e) => e.id).toSet(), {
      'bible-nt-kkbb-2017',
      'bible-charniauski-2017',
      'bible-ru-synodal',
      'lectionary-kkbb-2002-2005',
      'liturgy-hours-2012-2020',
      'compendium-kkbb-2010',
    });
    expect(registry.groups.map((g) => g.title), [
      'Святое Пісанне',
      'Чытанні',
      'Літургія гадзінаў',
      'Кампендый ККК',
    ]);
    expect(registry.groups.expand((g) => g.entries).map((e) => e.edition), [
      '«Новы Запавет» (Мінск, 2017)',
      '«Біблія. Кнігі Святога Пісання» (2017)',
      '',
      '«Лекцыянарый» (Мінск, 2002-2005)',
      'Літургія гадзінаў (Мінск, 2012-2020)',
      'Катэхізіс Каталіцкага Касцёла. Кампендый (Мінск, 2010)',
    ]);
    expect(registry.entry('bible-nt-kkbb-2017').notices, [
      '© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2017',
    ]);
    expect(registry.entry('lectionary-kkbb-2002-2005').notices, [
      '© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2002-2005',
    ]);
    expect(registry.entry('compendium-kkbb-2010').notices, [
      '© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2010',
      '© Libreria Editrice Vaticana, 2005',
    ]);
    for (final id in [
      'bible-charniauski-2017',
      'bible-ru-synodal',
      'liturgy-hours-2012-2020',
    ]) {
      expect(registry.entry(id).raw['rightsholder'], isNull);
      expect(registry.entry(id).notices, isEmpty);
    }
    for (final entry in registry.entries) {
      expect(entry.raw['verification']['evidence'], isNotEmpty);
      expect(entry.raw['digitalPermission']['status'], 'requires_verification');
    }
  });

  test(
    'four complete decrees reconstruct their original text and metadata',
    () async {
      final data = await HoursDecrees.load();
      expect(data.documents, hasLength(4));
      final metadata =
          registry.entry('liturgy-hours-2012-2020').raw['decrees'] as List;
      expect(data.documents.map((d) => d.number), [
        '32/P/12',
        '70/P/13',
        '62/P/15',
        '04/P/20',
      ]);
      expect(data.documents.map((d) => d.raw['date']), [
        '2012-06-29',
        '2013-08-15',
        '2015-08-06',
        '2020-02-02',
      ]);
      String normalized(String s) => s.replaceAll(RegExp(r'\s+'), '');
      for (final document in data.documents.indexed) {
        final d = document.$2;
        final m = metadata[document.$1] as Map;
        expect(d.raw['volume'], m['volume']);
        expect(d.number, m['number']);
        expect(d.raw['date'], m['date']);
        expect(d.raw['sourceUrl'], m['sourceUrl']);
        expect(m['documentPath'], '$hoursDecreesRoute#${d.id}');
        expect(d.lines('paragraphs'), hasLength(3));
        final rendered = [
          ...d.lines('issuer'),
          '№ ${d.number}',
          d.heading,
          ...d.lines('paragraphs'),
          ...d.lines('dateLines'),
          ...d.lines('signature'),
        ].join('\n');
        expect(normalized(rendered), normalized(d.raw['fullText'] as String));
      }
      expect(
        data.documents.last.lines('paragraphs').first,
        contains('Nr 15/P/19'),
      );
      expect(metadata.last['approval']['number'], '15/P/19');
    },
  );

  test(
    'calendar preserves every page, month, empty date and semantic run',
    () async {
      final data = await ProperCalendarDocument.load();
      expect(data.pages.map((p) => p.number), List.generate(13, (i) => i + 1));
      expect(data.months, hasLength(12));
      expect(data.rows, hasLength(495));
      expect(data.rows.where((r) => r.date != null), hasLength(365));
      expect(
        data.rows.where((r) => r.date != null && r.runs.isEmpty),
        hasLength(153),
      );
      expect(data.rows.where((r) => r.indent), hasLength(100));
      final semanticRuns = data.rows.expand((r) => [...r.runs, ...r.rank]);
      expect(semanticRuns.where((r) => r.small), hasLength(193));
      expect(semanticRuns.where((r) => r.italic), hasLength(133));
      expect(semanticRuns.where((r) => r.tone == 'red'), hasLength(194));
      expect(semanticRuns.where((r) => r.tone == 'magenta'), hasLength(3));
      final datesPerMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      for (var m = 1; m <= 12; m++) {
        expect(
          data.rows
              .where((r) => r.month == m && r.date != null)
              .map((r) => r.date),
          List.generate(datesPerMonth[m - 1], (i) => i + 1),
        );
      }
      final original =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/legal/proper-calendar.json',
                ),
              )
              as Map;
      for (final page in data.pages.indexed) {
        final originalRows = original['pages'][page.$1]['rows'] as List;
        for (final row in page.$2.rows.indexed) {
          final r = row.$2;
          final expected = originalRows[row.$1] as Map;
          expect(r.kind, expected['kind']);
          expect(r.text, expected['text']);
          expect(r.indent, expected['indent'] ?? false);
          expect(r.dateTone, expected['dateTone']);
          for (final field in ['runs', 'rank']) {
            final runs = field == 'runs' ? r.runs : r.rank;
            expect([
              for (final run in runs)
                {
                  'text': run.text,
                  'tone': run.tone,
                  'italic': run.italic,
                  'small': run.small,
                  'bold': run.bold,
                },
            ], expected[field] ?? []);
          }
        }
      }
      final intro = data.introRuns.map((r) => r.text).join();
      expect(
        intro,
        data.rows
            .where((r) => r.kind == 'intro')
            .map((r) => r.runs.map((s) => s.text).join())
            .join(' '),
      );
      for (final protocol in [
        '2366/96/L',
        '2270/96/L',
        '796/03/L',
        '417/12/L',
        '371/00/L',
        '209/23',
      ]) {
        expect(intro, contains(protocol));
      }
      final november = data.rows
          .where((r) => r.month == 11)
          .expand((r) => r.runs)
          .map((r) => r.text)
          .join();
      expect(november, contains('(Маці Божай Вастрабрамскай)'));
      expect(november, contains('У Віцебскай дыяцэзіі:'));
    },
  );

  test(
    'registry translation IDs match the audited bundled testaments',
    () async {
      for (final lang in ['bel', 'ru']) {
        BibleRepository.setData(lang, await BibleSeedLoader.load(lang: lang));
        final books = BibleRepository.getBooks(lang);
        expect(books, hasLength(73));
        expect(books.where((b) => !b.isNewTestament), hasLength(46));
        expect(books.where((b) => b.isNewTestament), hasLength(27));
      }
      expect(registry.bibleId('bel', false), 'bible-charniauski-2017');
      expect(registry.bibleId('bel', true), 'bible-nt-kkbb-2017');
      expect(registry.bibleId('ru', false), 'bible-ru-synodal');
      expect(registry.bibleId('ru', true), 'bible-ru-synodal');
      expect(
        bibleAttribution(versionId: 'bel', isNewTestament: true),
        'Новы Запавет · ККББ, 2017',
      );
      expect(
        BibleRepository.getChapter('bel', 'mt', 1)[17].text,
        contains('з Юзафам'),
      );
      expect(
        BibleRepository.getChapter('bel', 'gn', 1).first.text,
        'Спачатку стварыў Бог неба і зямлю.',
      );
      expect(
        BibleRepository.getChapter('ru', 'gn', 1).first.text,
        'В начале сотворил Бог небо и землю.',
      );
    },
  );
}
