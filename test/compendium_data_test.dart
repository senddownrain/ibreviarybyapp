import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:mybrev_flutter/models/compendium.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/services/compendium_repository.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';

/// Raw canonical map, as MyBrev exports it.
Map<String, dynamic> _rawDataset() =>
    jsonDecode(
          utf8.decode(
            GZipDecoder().decodeBytes(
              File(CompendiumRepository.assetPath).readAsBytesSync(),
            ),
          ),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

/// A newer copy of [raw], as `compendiumMeta/current` + unit documents.
(Map<String, dynamic>, List<Map<String, dynamic>>) _firestore(
  Map<String, dynamic> raw, {
  int contentVersion = 2,
  String checksum = 'remote',
}) {
  final meta = {
    ...Map<String, dynamic>.from(raw['meta'] as Map),
    'contentVersion': contentVersion,
    'checksum': checksum,
    'parts': raw['parts'],
    'importedAt': 1,
  };
  final units = [
    for (final unit in (raw['units'] as List).reversed)
      {...Map<String, dynamic>.from(unit as Map), 'importedAt': 1},
  ];
  return (_copy(meta), [for (final unit in units) _copy(unit)]);
}

class _Remote implements CompendiumRemote {
  _Remote({this.meta, this.units = const [], this.fail = false});

  Map<String, dynamic>? meta;
  List<Map<String, dynamic>> units;
  bool fail;
  int metaReads = 0;
  int unitReads = 0;

  @override
  Future<Map<String, dynamic>?> fetchMeta() async {
    metaReads++;
    if (fail) throw StateError('offline');
    return meta;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchUnits() async {
    unitReads++;
    if (fail) throw StateError('offline');
    return units;
  }
}

void main() {
  final raw = _rawDataset();

  group('canonical dataset', () {
    final dataset = CompendiumDataset.fromJson(raw);
    final index = CompendiumIndex(dataset);

    test('bundled asset is the valid canonical export', () {
      expect(validateCompendiumDataset(raw), isEmpty);
      expect(dataset.meta.schemaVersion, kCompendiumSchemaVersion);
      expect(dataset.meta.questionCount, 598);
      expect(dataset.parts.map((part) => part.id), ['p1', 'p2', 'p3', 'p4']);
      expect(dataset.units, hasLength(27));
      expect(dataset.units.map((unit) => unit.id), dataset.meta.unitIds);
      expect(
        dataset.meta.sourceUrl,
        'https://catholic.by/3/lib/documents/kasciol/3963-kampendyj-katekhizisa-katalitskaga-kastsjola',
      );
      expect(dataset.meta.copyright, hasLength(2));
      // The bundle decodes the same way off the UI isolate.
      final decoded = decodeBundledCompendium(
        File(CompendiumRepository.assetPath).readAsBytesSync(),
      );
      expect(decoded.meta.checksum, dataset.meta.checksum);
    });

    test('index: flat order, lookup by number/id and reading groups', () {
      expect(index.questions, hasLength(598));
      expect(index.questions.take(3).map((q) => q.number), [1, 2, 3]);
      expect(
        [for (final q in index.questions) q.id],
        [for (var n = 1; n <= 598; n++) 'q${'$n'.padLeft(3, '0')}'],
      );
      expect(index.getQuestion(598)!.id, 'q598');
      expect(index.getQuestion('q042')!.number, 42);
      expect(index.getQuestion('42')!.number, 42);
      expect(index.getQuestion('777'), isNull);
      expect(index.getQuestion('abc'), isNull);
      final grouped = [
        for (final group in index.groups.values)
          for (final q in group.questions) q.number,
      ]..sort();
      expect(grouped, [for (final q in index.questions) q.number]);
      expect(
        index.getGroup(index.getQuestion(252)!.groupId)!.title,
        'САКРАМЭНТ ХРОСТУ',
      );
      final firsts = [
        for (final id in index.groupOrder) index.groups[id]!.firstQuestion,
      ];
      expect(firsts, [...firsts]..sort());
      expect(index.getPart('2')!.id, 'p2');
      expect(index.partRange('p4'), (534, 598));
    });

    test('navigation: every question once, in canonical order', () {
      final navigation = index.navigation;
      expect(navigation.map((node) => node.id), ['p1', 'p2', 'p3', 'p4']);
      final ordered = [
        for (final part in navigation)
          for (final question in part.questions) question.number,
      ];
      expect(ordered, [for (final q in index.questions) q.number]);
      expect(index.partOutline('2')!.id, 'p2');
      expect(index.partOutline('p9'), isNull);
      expect(buildCompendiumPartOutline(index, 'p9'), isNull);
      expect(
        identical(index.partOutline('p1'), index.partOutline('p1')),
        isTrue,
        reason: 'built once per index',
      );
    });

    test('navigation: only real source headings are nodes', () {
      Iterable<CompendiumNavNode> walk(CompendiumNavNode node) sync* {
        yield node;
        for (final child in node.children) {
          yield* walk(child);
        }
      }

      final nodes = [for (final part in index.navigation) ...walk(part)];
      final untitled = [
        for (final group in index.groups.values)
          if (!group.hasSourceHeading) group.id,
      ];
      expect(untitled, contains('p1-s1-intro'));
      for (final node in nodes) {
        // Chapter nodes share their unit's id (`p1-s1-ch1`); only a topic
        // stands for a reading group.
        if (node.kind == CompendiumNodeKind.topic) {
          expect(untitled, isNot(contains(node.id)), reason: node.id);
        }
        expect(node.id, isNot(endsWith('-intro')), reason: node.id);
        expect(node.title, isNotEmpty, reason: node.id);
        expect(
          node.title,
          isNot(startsWith('Пытан')),
          reason: 'a question range is never a heading (${node.id})',
        );
        if (node.kind == CompendiumNodeKind.topic) {
          expect(node.group!.hasSourceHeading, isTrue);
          expect(node.children, isEmpty);
          expect(node.directQuestions, isEmpty);
        } else {
          expect(node.label, isNotNull, reason: node.id);
        }
      }
      final topics = nodes.where(
        (node) => node.kind == CompendiumNodeKind.topic,
      );
      expect(
        topics.map((node) => node.id).toSet(),
        {
          for (final group in index.groups.values)
            if (group.hasSourceHeading) group.id,
        },
        reason: 'every named topic stays visible',
      );
    });

    test('navigation: question 1 is a direct child of section p1-s1', () {
      final part = index.partOutline('p1')!;
      expect(part.label, 'ЧАСТКА ПЕРШАЯ');
      expect(part.title, 'ВЫЗНАННЕ ВЕРЫ');
      expect(part.directQuestions, isEmpty);
      final section = part.children.first;
      expect(section.id, 'p1-s1');
      expect(section.kind, CompendiumNodeKind.section);
      expect(section.label, 'РАЗДЗЕЛ ПЕРШЫ');
      expect(section.title, '«ВЕРУ» — «ВЕРЫМ»');
      expect(section.directQuestions.map((q) => q.number), [1]);
      expect(
        section.directQuestions.single.question,
        'Які Божы намер адносна чалавека?',
      );

      // РАЗДЗЕЛ and ГЛАВА stay distinct levels.
      expect(section.children.map((node) => node.kind).toSet(), {
        CompendiumNodeKind.chapter,
      });
      expect(section.children.map((node) => node.label), [
        'ГЛАВА ПЕРШАЯ',
        'ГЛАВА ДРУГАЯ',
        'ГЛАВА ТРЭЦЯЯ',
      ]);
      final chapter = section.children.first;
      expect(chapter.id, 'p1-s1-ch1');
      expect(chapter.title, 'ЧАЛАВЕК — «СВЯТЫНЯ» БОГА');
      expect(chapter.directQuestions.map((q) => q.number), [2, 3, 4, 5]);
      expect(chapter.children, isEmpty);

      // A real named topic keeps its title; the range is metadata.
      final revelation = section.children[1].children.first;
      expect(revelation.kind, CompendiumNodeKind.topic);
      expect(revelation.title, 'БОЖАЕ АБ’ЯЎЛЕННЕ');
      expect(revelation.rangeLabel, 'Пытанні 6–10');
    });

    test('navigation: lead-in questions precede named topics', () {
      final chapter = index
          .partOutline('p1')!
          .children[1]
          .children
          .firstWhere((node) => node.id == 'p1-s2-ch2');
      expect(chapter.directQuestions.map((q) => q.number), [79, 80]);
      expect(chapter.children.first.firstQuestion, 81);

      // A section without chapters holds its named topics directly.
      final lordsPrayer = index.partOutline('p4')!.children[1];
      expect(lordsPrayer.label, 'РАЗДЗЕЛ ДРУГІ');
      expect(lordsPrayer.directQuestions, isEmpty);
      expect(lordsPrayer.children.first.kind, CompendiumNodeKind.topic);
      expect(lordsPrayer.children.first.title, 'ОЙЧА НАШ');

      // A source heading above several topics is kept as the topic heading.
      final celebration = index
          .partOutline('p2')!
          .children
          .first
          .children[1]
          .children
          .first;
      expect(celebration.title, 'Хто цэлебруе?');
      expect(celebration.heading, 'ЦЭЛЕБРАЦЫЯ ЛIТУРГII КАСЦЁЛА');
    });

    test('ПАДРАЗДЗЕЛ labels use masculine ordinals from the number', () {
      expect(
        [
          for (var number = 1; number <= 10; number++) number,
        ].map(compendiumSubsectionLabel),
        [
          'ПАДРАЗДЗЕЛ ПЕРШЫ',
          'ПАДРАЗДЗЕЛ ДРУГІ',
          'ПАДРАЗДЗЕЛ ТРЭЦІ',
          'ПАДРАЗДЗЕЛ ЧАЦВЁРТЫ',
          'ПАДРАЗДЗЕЛ ПЯТЫ',
          'ПАДРАЗДЗЕЛ ШОСТЫ',
          'ПАДРАЗДЗЕЛ СЁМЫ',
          'ПАДРАЗДЗЕЛ ВОСЬМЫ',
          'ПАДРАЗДЗЕЛ ДЗЯВЯТЫ',
          'ПАДРАЗДЗЕЛ ДЗЯСЯТЫ',
        ],
      );
      expect(compendiumSubsectionLabel(11), 'ПАДРАЗДЗЕЛ 11');
      expect(compendiumSubsectionLabel(null), 'ПАДРАЗДЗЕЛ');
      expect(compendiumSubsectionLabel(0), 'ПАДРАЗДЗЕЛ');

      // The source label stays faithful; only the display label changes.
      final chapter = index.getNode('p1-s1-ch1')!;
      expect(chapter.label, 'ГЛАВА ПЕРШАЯ');
      expect(chapter.displayLabel, 'ПАДРАЗДЗЕЛ ПЕРШЫ');
      expect(index.getNode('p2-s2-ch4')!.displayLabel, 'ПАДРАЗДЗЕЛ ЧАЦВЁРТЫ');
      expect(index.getNode('p1-s1')!.displayLabel, 'РАЗДЗЕЛ ПЕРШЫ');
      expect(index.getNode('p1')!.displayLabel, 'ЧАСТКА ПЕРШАЯ');
      expect(index.getNode('p1-s1-ch2-t1')!.displayLabel, isNull);
      expect(
        index.units.map((unit) => unit.chapterLabel).whereType<String>(),
        everyElement(startsWith('ГЛАВА ')),
        reason: 'canonical data is not rewritten',
      );
    });

    test('audit: every node is addressable and owns its questions once', () {
      final nodes = [for (final part in index.navigation) ...part.descendants];
      expect(nodes.map((node) => node.id).toSet(), hasLength(nodes.length));
      final counts = <CompendiumNodeKind, int>{};
      final owned = <int>[];
      for (final node in nodes) {
        counts[node.kind] = (counts[node.kind] ?? 0) + 1;
        expect(identical(index.getNode(node.id), node), isTrue);
        expect(node.questions, isNotEmpty, reason: node.id);
        final label = node.displayLabel ?? '';
        expect(label, isNot(contains('ГЛАВА')), reason: node.id);
        switch (node.kind) {
          case CompendiumNodeKind.part:
            expect(node.parent, isNull);
            expect(label, startsWith('ЧАСТКА '));
            expect(node.directQuestions, isEmpty, reason: node.id);
            expect(
              node.children.map((child) => child.kind).toSet(),
              {CompendiumNodeKind.section},
              reason: 'a part screen lists sections only',
            );
            expect(node.contextTrail, isEmpty);
          case CompendiumNodeKind.section:
            expect(node.parent!.kind, CompendiumNodeKind.part);
            expect(label, startsWith('РАЗДЗЕЛ '));
            expect(node.contextTrail, [node.parent!.label]);
          case CompendiumNodeKind.chapter:
            expect(node.parent!.kind, CompendiumNodeKind.section);
            expect(label, compendiumSubsectionLabel(node.number));
            expect(label, matches(RegExp(r'^ПАДРАЗДЗЕЛ \S+[ЫІ]$')));
            expect(
              node.children.map((child) => child.kind).toSet().difference({
                CompendiumNodeKind.topic,
              }),
              isEmpty,
              reason: 'a subsection holds questions and topics only',
            );
            expect(node.contextTrail, [
              node.parent!.parent!.label,
              node.parent!.title,
            ]);
          case CompendiumNodeKind.topic:
            expect(node.parent!.isStructural, isTrue);
            expect(node.isStructural, isFalse);
        }
        for (final child in node.children) {
          expect(identical(child.parent, node), isTrue, reason: child.id);
        }
        // Direct questions precede the children, in canonical order.
        if (node.directQuestions.isNotEmpty && node.children.isNotEmpty) {
          expect(
            node.directQuestions.last.number,
            lessThan(node.children.first.firstQuestion),
            reason: node.id,
          );
        }
        final own = node.group?.questions ?? node.directQuestions;
        for (final question in own) {
          owned.add(question.number);
          expect(identical(index.ownerOf(question), node), isTrue);
        }
      }
      expect(counts, {
        CompendiumNodeKind.part: 4,
        CompendiumNodeKind.section: 8,
        CompendiumNodeKind.chapter: 20,
        CompendiumNodeKind.topic: 70,
      });
      expect(owned, [for (var number = 1; number <= 598; number++) number]);
      expect(index.getNode('p1-s1-intro'), isNull);
      expect(index.getNode(null), isNull);
    });

    test('audit: direct questions of sections and subsections', () {
      final direct = {
        for (final part in index.navigation)
          for (final node in part.descendants)
            if (node.isStructural && node.directQuestions.isNotEmpty)
              node.id: [
                node.directQuestions.first.number,
                node.directQuestions.last.number,
              ],
      };
      expect(direct, {
        'p1-s1': [1, 1],
        'p1-s1-ch1': [2, 5],
        'p1-s2-ch2': [79, 80],
        'p2-s1': [218, 220],
        'p2-s2-ch1': [251, 251],
        'p2-s2-ch2': [295, 295],
        'p2-s2-ch3': [321, 321],
        'p3-s1': [357, 357],
        'p3-s2': [434, 441],
        'p4-s1': [534, 534],
        'p4-s1-ch1': [535, 535],
        'p4-s1-ch2': [557, 557],
        'p4-s1-ch3': [567, 568],
      });
      // A section without chapters holds named topics only.
      final lordsPrayer = index.getNode('p4-s2')!;
      expect(lordsPrayer.children.map((node) => node.kind).toSet(), {
        CompendiumNodeKind.topic,
      });
      // A section with its own named topic before its subsections.
      expect(index.getNode('p2-s2')!.children.map((node) => node.id), [
        'p2-s2-intro-t1',
        'p2-s2-ch1',
        'p2-s2-ch2',
        'p2-s2-ch3',
        'p2-s2-ch4',
      ]);
      expect(index.getNode('p1-s1')!.rangeLabel, 'Пытанні 1–32');
      expect(index.getNode('p1-s1-ch1')!.rangeLabel, 'Пытанні 2–5');
      expect(index.getNode('p1-s1-ch1')!.leadCitations, hasLength(1));
      // Subtopic headings stay inside a topic, never a navigation level.
      final church = index.getNode('p1-s2-ch3-t2')!;
      expect(church.children, isEmpty);
      expect(
        church.questions
            .map((q) => q.subtopicTitle)
            .whereType<String>()
            .toSet(),
        hasLength(6),
      );
    });

    test('untitled lead-ins are reading chunks, not headings', () {
      final intro = index.getGroup('p1-s1-intro')!;
      expect(intro.hasSourceHeading, isFalse);
      expect(compendiumGroupQuestionRedirect(intro), 1);
      expect(
        compendiumGroupQuestionRedirect(index.getGroup('p1-s1-ch1')!),
        isNull,
        reason: 'several questions stay a reading page',
      );
      expect(
        compendiumGroupQuestionRedirect(index.getGroup('p2-s2-intro-t1')!),
        isNull,
        reason: 'a named one-question topic is a real heading',
      );
      expect(groupContextTrail(intro), ['ЧАСТКА ПЕРШАЯ', '«ВЕРУ» — «ВЕРЫМ»']);
      expect(questionContextTrail(index.getQuestion(1)!), [
        'ЧАСТКА ПЕРШАЯ',
        '«ВЕРУ» — «ВЕРЫМ»',
      ]);
      expect(questionContextTrail(index.getQuestion(7)!), [
        'ЧАСТКА ПЕРШАЯ',
        '«ВЕРУ» — «ВЕРЫМ»',
        'БОГ ВЫХОДЗІЦЬ НАСУСТРАЧ ЧАЛАВЕКУ',
        'БОЖАЕ АБ’ЯЎЛЕННЕ',
      ]);
    });

    test('answer paragraphs keep source text and emphasis', () {
      final question = index.getQuestion(445)!;
      final paragraphs = answerParagraphs(question);
      expect(
        paragraphs.map((runs) => runs.map((run) => run.text).join()).join('\n'),
        question.answer.replaceAll(RegExp(r'\n+'), '\n'),
      );
      expect(paragraphs[1].first.style, CompendiumEmphasisStyle.italic);
      expect(formatCccRefs(['50-53', '68']), '50–53, 68');
      expect(romanNumeral(4), 'IV');
    });

    test('context trails use visible Belarusian titles only', () {
      final question = index.getQuestion(252)!;
      final trail = questionContextTrail(question);
      expect(trail.first, 'ЧАСТКА ДРУГАЯ');
      expect(trail.last, 'САКРАМЭНТ ХРОСТУ');
      expect(groupContextTrail(index.groupOf(question)!), trail);
    });
  });

  group('validation', () {
    test('rejects incomplete or inconsistent datasets', () {
      expect(validateCompendiumDataset(null), isNotEmpty);
      final missingUnit = _copy(raw)
        ..['units'] = (raw['units'] as List).skip(1).toList();
      expect(validateCompendiumDataset(missingUnit), isNotEmpty);
      final schema = _copy(raw);
      (schema['meta'] as Map)['schemaVersion'] = 2;
      expect(
        validateCompendiumDataset(schema).first,
        contains('schemaVersion'),
      );
      final gap = _copy(raw);
      (((gap['units'] as List)[3] as Map)['questions'] as List).removeAt(1);
      expect(validateCompendiumDataset(gap), isNotEmpty);
      final refs = _copy(raw);
      ((((refs['units'] as List)[0] as Map)['questions'] as List)[0]
          as Map)['cccRefs'] = [
        'Мц 5, 3',
      ];
      expect(
        validateCompendiumDataset(refs),
        contains('Question 1: invalid cccRefs.'),
      );
      final source = _copy(raw);
      (source['meta'] as Map).remove('sourceUrl');
      expect(
        validateCompendiumDataset(source),
        contains('Source attribution is missing.'),
      );
    });

    test('Firestore documents reassemble into the canonical dataset', () {
      final (meta, units) = _firestore(
        raw,
        contentVersion: (raw['meta'] as Map)['contentVersion'] as int,
        checksum: (raw['meta'] as Map)['checksum'] as String,
      );
      expect(jsonEncode(compendiumFromDocuments(meta, units)), jsonEncode(raw));
    });

    test('only a strictly newer version with the same schema wins', () {
      final bundled = Map<String, dynamic>.from(raw['meta'] as Map);
      expect(isNewerCompendium({...bundled}, bundled), isFalse);
      expect(
        isNewerCompendium({...bundled, 'contentVersion': 2}, bundled),
        isTrue,
      );
      expect(
        isNewerCompendium({
          ...bundled,
          'contentVersion': 2,
          'schemaVersion': 99,
        }, bundled),
        isFalse,
      );
      expect(
        isNewerCompendium({...bundled, 'contentVersion': '2'}, bundled),
        isFalse,
      );
    });
  });

  group('offline storage and sync', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('compendium-');
      await HiveService.init(path: directory.path);
      CompendiumRepository.resetMemo();
    });
    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    CompendiumSync sync(_Remote remote) =>
        CompendiumSync(remote: remote, bundledVersion: () async => 1);

    test('the compendium box opens at startup but stays empty', () {
      expect(Hive.isBoxOpen(CompendiumRepository.boxName), isTrue);
      expect(Hive.box(CompendiumRepository.boxName), isEmpty);
      expect(CompendiumRepository.readStored(), isNull);
    });

    test('nothing newer: one meta read, no units, nothing stored', () async {
      final (meta, units) = _firestore(raw, contentVersion: 1);
      final remote = _Remote(meta: meta, units: units);
      expect(await sync(remote).run(), CompendiumSyncOutcome.upToDate);
      expect(remote.metaReads, 1);
      expect(remote.unitReads, 0);
      expect(Hive.box(CompendiumRepository.boxName), isEmpty);
      expect(
        await sync(_Remote()).run(),
        CompendiumSyncOutcome.upToDate,
        reason: 'Firestore without a Compendium keeps the bundle',
      );
    });

    test('newer valid data is stored, read back and preferred', () async {
      final (meta, units) = _firestore(raw);
      final remote = _Remote(meta: meta, units: units);
      expect(await sync(remote).run(), CompendiumSyncOutcome.updated);
      final box = Hive.box(CompendiumRepository.boxName);
      expect(box.length, 28, reason: '27 units + meta');
      final stored = CompendiumRepository.readStored()!;
      expect(stored.meta.contentVersion, 2);
      expect(stored.meta.checksum, 'remote');
      expect(stored.units, hasLength(27));
      final bundled = CompendiumDataset.fromJson(raw);
      expect(identical(selectCompendium(bundled, stored), stored), isTrue);
      // A second refresh sees the stored version and downloads nothing.
      remote.unitReads = 0;
      expect(await sync(remote).run(), CompendiumSyncOutcome.upToDate);
      expect(remote.unitReads, 0);
      // A later app update with a newer bundle wins over the older copy.
      final newerBundle = CompendiumDataset.fromJson(
        _copy(raw)
          ..['meta'] = {
            ...Map<String, dynamic>.from(raw['meta'] as Map),
            'contentVersion': 3,
          },
      );
      expect(
        identical(selectCompendium(newerBundle, stored), newerBundle),
        isTrue,
      );
    });

    test('invalid remote data is rejected and old data is kept', () async {
      final (meta, units) = _firestore(raw);
      await sync(_Remote(meta: meta, units: units)).run();
      final (newer, newerUnits) = _firestore(raw, contentVersion: 3);
      final remote = _Remote(meta: newer, units: newerUnits.skip(1).toList());
      await expectLater(
        sync(remote).run(),
        throwsA(isA<CompendiumSyncException>()),
      );
      expect(CompendiumRepository.readStored()!.meta.contentVersion, 2);
    });

    test('a failed refresh keeps the current content', () async {
      final (meta, units) = _firestore(raw);
      await sync(_Remote(meta: meta, units: units)).run();
      await expectLater(sync(_Remote(fail: true)).run(), throwsStateError);
      expect(CompendiumRepository.readStored()!.meta.contentVersion, 2);
    });

    test('an interrupted write is never read as a mixed dataset', () async {
      final (meta, units) = _firestore(raw);
      await sync(_Remote(meta: meta, units: units)).run();
      final box = Hive.box(CompendiumRepository.boxName);
      final unit = Map<String, dynamic>.from(box.get('p1-s1-ch1') as Map);
      await box.put('p1-s1-ch1', {
        ...unit,
        CompendiumRepository.versionField: 3,
      });
      CompendiumRepository.resetMemo();
      expect(CompendiumRepository.readStored(), isNull);
    });

    test('cancellation before the download leaves storage untouched', () async {
      final (meta, units) = _firestore(raw);
      final remote = _Remote(meta: meta, units: units);
      expect(
        await sync(remote).run(shouldCancel: () => true),
        CompendiumSyncOutcome.cancelled,
      );
      expect(Hive.box(CompendiumRepository.boxName), isEmpty);
    });

    test(
      'dataset provider: bundle, newer copy, or copy when bundle fails',
      () async {
        final bundled = CompendiumDataset.fromJson(raw);
        final (meta, units) = _firestore(raw);
        await sync(_Remote(meta: meta, units: units)).run();
        final stored = CompendiumRepository.readStored()!;
        for (final (seed, expected) in [
          (() async => bundled, stored),
          (() async => throw StateError('asset'), stored),
        ]) {
          final container = ProviderContainer(
            overrides: [
              compendiumBundledProvider.overrideWith((ref) => seed()),
            ],
          );
          addTearDown(container.dispose);
          await container
              .read(compendiumBundledProvider.future)
              .then((_) {}, onError: (_) {});
          final value = container.read(compendiumDatasetProvider);
          expect(identical(value.requireValue, expected), isTrue);
          expect(
            container.read(compendiumIndexProvider).requireValue.questions,
            hasLength(598),
          );
        }
        final empty = ProviderContainer(
          overrides: [
            compendiumBundledProvider.overrideWith((ref) async => bundled),
            compendiumStoredProvider.overrideWithValue(null),
          ],
        );
        addTearDown(empty.dispose);
        await empty.read(compendiumBundledProvider.future);
        expect(
          identical(
            empty.read(compendiumDatasetProvider).requireValue,
            bundled,
          ),
          isTrue,
        );
      },
    );
  });
}
