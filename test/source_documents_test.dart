import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/constants/legal_links.dart';
import 'package:mybrev_flutter/models/source_documents.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/services/bible_seed_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRegistry registry;
  setUpAll(() async => registry = await SourceRegistry.load());

  test(
    'registry and unchanged Bible corpora match their pinned import lock',
    () async {
      final lock =
          jsonDecode(
                File('docs/sources/web-import-lock.json').readAsStringSync(),
              )
              as Map;
      expect(lock['commit'], '33577e1fb265b02160a5e6d94cfc83a8df15b9a3');
      expect(lock['files'], hasLength(1));
      expect(lock['files'][0]['flutter'], 'assets/legal/sources.json');
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
        );
      }
    },
  );

  test(
    'six stable entries follow Web rights corrections and preserve provenance',
    () {
      expect(registry.entries, hasLength(6));
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
        '«Літургія гадзінаў» (Мінск, 2012–2020)',
        'Катэхізіс Каталіцкага Касцёла. Кампендый (Мінск, 2010)',
      ]);
      final hours = registry.entry('liturgy-hours-2012-2020');
      expect(
        hours.raw['rightsholder'],
        'Канферэнцыя Каталіцкіх Біскупаў Беларусі',
      );
      expect(hours.notices, ['© Канферэнцыя Каталіцкіх Біскупаў Беларусі']);
      expect(hours.raw['decrees'], hasLength(4));
      final compendium = registry.entry('compendium-kkbb-2010');
      expect(compendium.notices, [
        '© Канферэнцыя Каталіцкіх Біскупаў Беларусі, 2010',
      ]);
      expect(
        compendium.raw['auditNotices'][0]['text'],
        '© Copyright 2005 — Libreria Editrice Vaticana',
      );
      expect(
        compendium.raw['auditNotices'][0]['sourceDocument'],
        contains('compendium-source/'),
      );
      for (final entry in registry.entries) {
        expect(entry.raw['verification']['evidence'], isNotEmpty);
        expect(entry.raw['digitalSources'], isNotEmpty);
      }
      for (final id in ['bible-charniauski-2017', 'bible-ru-synodal']) {
        expect(registry.entry(id).raw['rightsholder'], isNull);
        expect(registry.entry(id).notices, isEmpty);
      }
    },
  );

  test(
    'only the registry ships in the legal asset bundle; no document fallback',
    () async {
      final assets = (await AssetManifest.loadFromAssetBundle(
        rootBundle,
      )).listAssets();
      expect(assets.where((p) => p.startsWith('assets/legal/')), [
        'assets/legal/sources.json',
      ]);
      for (final name in [
        'liturgy-hours-decrees.json',
        'proper-calendar.json',
        'proper-calendar.pdf',
      ]) {
        expect(assets.where((p) => p.endsWith('/$name')), isEmpty);
        expect(File('assets/legal/$name').existsSync(), isFalse);
      }
    },
  );

  test(
    'three distinct canonical HTTPS documents share the privacy Web origin',
    () {
      expect(kPrivacyPolicyUrl, 'https://ibreviaryby.web.app/privacy');
      expect(kSourceDocumentLinks.map((d) => d.url), [
        'https://ibreviaryby.web.app/documents/liturgy-hours-decrees',
        'https://ibreviaryby.web.app/documents/liturgy-hours-introduction',
        'https://ibreviaryby.web.app/documents/proper-calendar',
      ]);
      expect(kSourceDocumentLinks.map((d) => d.label), [
        'Дэкрэты Літургіі гадзінаў',
        'Агульныя ўводзіны да Літургіі гадзінаў',
        'Уласны каляндар дыяцэзій на Беларусі',
      ]);
      for (final link in kSourceDocumentLinks) {
        final uri = Uri.parse(link.url);
        expect(uri.scheme, 'https');
        expect(uri.host, 'ibreviaryby.web.app');
        expect(uri.query, isEmpty);
        expect(uri.fragment, isEmpty);
      }
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
