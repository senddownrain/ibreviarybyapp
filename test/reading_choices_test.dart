// D-1 (Flutter port of web #164): the reader offers each legal reading of an Office
// field as a choice instead of one glued block and shows the volume's
// «Выбіраюцца найбольш адпаведныя тэксты …» sentence as a note.
//
// Expectations are typed from the volumes (WEB tests/reading-choices.test.mjs:
// I 4359-4360, II 4806-4807, III 5617-5633), not produced by the generator; the
// parity test compares hashes with the WEB output (scripts/build_reading_choices_parity.mjs).
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_alternatives.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/utils/reading_choice.dart';
import 'package:mybrev_flutter/widgets/alternative_text.dart';

const _works = [
  '«Гамілія да кнігі Дзеяў Апосталаў» св. Яна Хрызастома, біскупа',
  'Казанне св. Аўгустына, біскупа',
];
const _pius = 'Прамова папы Пія ХІІ, скіраваная да маладых сужэнстваў';
const _seasons = ['advent', 'christmas', 'lent', 'easter'];

String _plain(String html) => html
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _words(String html) =>
    (parseFragment(html).text ?? '').replaceAll(RegExp(r'\s+'), '');

String _hash(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 16);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Map<String, Map<String, dynamic>> templates;
  late Map<String, Map<String, dynamic>> propers;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('reading-choices-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
    templates = HiveService.templates();
    final collection = HiveService.content.collection('liturgicalProperTexts');
    propers = {
      for (final key in collection.keys)
        if (collection.get(key) case final Map raw)
          '$key': Map<String, dynamic>.from(raw),
    };
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  String field(String id, String name, [String? season]) {
    final doc = templates[id]!;
    final source = season == null
        ? doc
        : (doc['_seasonalVariants'] as Map)[season] as Map;
    return source[name] as String;
  }

  group('choices equal the volumes', () {
    test(
      'holy-women R2 in Advent, Christmas, Lent, Easter: note + two readings of holy men',
      () {
        const pages = {
          'advent': '1275-1277',
          'christmas': '1275-1277',
          'lent': '1787-1791',
          'easter': '1787-1791',
        };
        pages.forEach((season, page) {
          final choices = getReadingChoices(
            field('holy-women', 'officeOfReadingsR2', season),
          );
          expect(choices.notes, hasLength(1), reason: season);
          expect(
            _plain(choices.notes.single.html),
            matches(
              RegExp(
                '^Выбіраюцца найбольш адпаведныя тэксты .* святых мужчын, с\\. $page\\.\$',
              ),
            ),
            reason: season,
          );
          expect(choices.options.map((o) => o.title), _works, reason: season);
          for (final option in choices.options) {
            expect(
              _plain(option.html),
              isNot(matches(RegExp('Выбіраюцца|Пія ХІІ|Discorsi'))),
              reason: season,
            );
          }
          expect(
            _plain(choices.options[0].html),
            contains('Святло хрысціяніна не можа быць схавана'),
          );
          expect(
            _plain(choices.options[1].html),
            contains('Паўсюднае пакліканне да святасці'),
          );
        });
      },
    );

    test(
      'holy-women R2 in Ordinary Time (volume III): the two holy-men texts, then Pius XII',
      () {
        final choices = getReadingChoices(
          field('holy-women', 'officeOfReadingsR2'),
        );
        expect(choices.notes, hasLength(1));
        expect(_plain(choices.notes.single.html), endsWith('с. 1584-1587.'));
        expect(choices.options.map((o) => o.title), [..._works, _pius]);
        expect(
          _plain(choices.options[2].html),
          contains('Жонка – сонца сям’і'),
        );
      },
    );

    test('Pius XII is never offered as a seasonal variant of volumes I/II', () {
      for (final season in _seasons) {
        for (final name in ['officeOfReadingsR1', 'officeOfReadingsR2']) {
          final text = _plain(field('holy-women', name, season));
          expect(text, isNot(contains('Пія ХІІ')), reason: '$season $name');
        }
      }
    });

    test(
      'holy-women R1: note, holy-men first readings of the same volume, then the two for a married saint',
      () {
        const menCount = {
          null: 3,
          'advent': 3,
          'christmas': 3,
          'lent': 2,
          'easter': 2,
        };
        for (final season in [null, ..._seasons]) {
          final choices = getReadingChoices(
            field('holy-women', 'officeOfReadingsR1', season),
          );
          expect(choices.notes, hasLength(1), reason: '$season');
          expect(
            choices.options,
            hasLength(menCount[season]! + 2),
            reason: '$season',
          );
          final own = choices.options.sublist(choices.options.length - 2);
          expect(
            own[0].title,
            matches(RegExp(r'^Кніга Прыпавесцяў(?: Саламона)? 31, 10-31$')),
            reason: '$season',
          );
          expect(
            own[1].title,
            'Першае пасланне св. апостала Пятра 3, 1-6. 8-17',
            reason: '$season',
          );
          expect(
            _plain(own[0].html),
            isNot(contains('Першае пасланне св. апостала Пятра')),
            reason: '$season: two readings glued',
          );
          final men = getReadingChoices(
            field('holy-men', 'officeOfReadingsR1', season),
          );
          expect(
            choices.options.take(menCount[season]!).map((o) => o.title),
            men.options.map((o) => o.title),
            reason: '$season: holy-men readings unchanged',
          );
        }
      },
    );

    test('holy-men R2 offers exactly the two volume texts in every period', () {
      for (final season in _seasons) {
        expect(
          getReadingChoices(
            field('holy-men', 'officeOfReadingsR2', season),
          ).options.map((o) => o.title),
          _works,
          reason: season,
        );
      }
    });

    test(
      'no choice is invented or lost: choices and notes are the stored text, word for word',
      () {
        final stored = [
          field('holy-women', 'officeOfReadingsR1'),
          field('holy-women', 'officeOfReadingsR2'),
          for (final s in _seasons) ...[
            field('holy-women', 'officeOfReadingsR1', s),
            field('holy-women', 'officeOfReadingsR2', s),
          ],
          field('holy-men', 'officeOfReadingsR1'),
          field('holy-men', 'officeOfReadingsR2'),
        ];
        for (final html in stored) {
          final choices = getReadingChoices(html);
          expect(
            _words(
              [
                ...choices.notes,
                ...choices.options,
              ].map((o) => o.html).join(' '),
            ),
            _words(html.replaceAll(RegExp(r'<hr\s*/?>'), ' ')),
          );
        }
      },
    );

    test(
      'a single legal reading gets no choice; a text that is only a reference stays readable',
      () {
        expect(
          getReadingChoices('<p>Кніга Рут 1, 1-5</p>').options,
          hasLength(1),
        );
        const only =
            '<p>Выбіраюцца найбольш адпаведныя тэксты з Агульных тэкстаў пра святых мужчын, с. 1.</p>';
        final choices = getReadingChoices(only);
        expect(choices.notes, isEmpty);
        expect(choices.options, hasLength(1));
        expect(_plain(choices.options.single.html), startsWith('Выбіраюцца'));
      },
    );

    test(
      'other kinds keep their behaviour: the new rules are for office readings only',
      () {
        const sample =
            '<p>Выбіраюцца найбольш адпаведныя тэксты.</p><hr /><p>Кніга Рут 1, 1-5</p>';
        expect(
          getLiturgicalAlternatives(
            sample,
            kind: 'reading',
          ).every((o) => !o.reference),
          isTrue,
        );
        expect(
          getLiturgicalAlternatives(
            '<p>Гімн раз</p><hr /><p>Або: Гімн два</p>',
            kind: 'hymn',
          ),
          hasLength(2),
        );
      },
    );

    test(
      'a Proper reading has priority: its own text is not replaced by the Common choices',
      () {
        // the Proper celebration carries its own readings; the choice parser only splits the text it is given
        final proper = propers.values.firstWhere(
          (doc) => (doc['officeOfReadingsR2'] as String? ?? '').isNotEmpty,
        );
        final text = proper['officeOfReadingsR2'] as String;
        final choices = getReadingChoices(text);
        expect(
          _words(
            [...choices.notes, ...choices.options].map((o) => o.html).join(' '),
          ),
          _words(text.replaceAll(RegExp(r'<hr\s*/?>'), ' ')),
        );
      },
    );
  });

  test(
    'parity: every office-reading field equals the Web output (titles, words, notes)',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/reading_choices_parity.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final mismatches = <String>[];
      var withChoice = 0;
      final cases = (fixture['cases'] as List).cast<List>();
      for (final item in cases) {
        final parts = (item[0] as String).split(':');
        final collection = parts[0];
        final id = parts[1];
        final key = parts.sublist(2);
        final doc = (collection == 'liturgicalTemplates'
            ? templates
            : propers)[id];
        expect(doc, isNotNull, reason: '${item[0]} is missing from the bundle');
        final html = key.length == 1
            ? doc![key[0]] as String
            : (((doc!['_seasonalVariants'] as Map)[key[0]]) as Map)[key[1]]
                  as String;
        final label = key.last.endsWith('R1')
            ? 'Першае чытанне'
            : 'Другое чытанне';
        final choices = getReadingChoices(
          stripLeadingReadingHeading(html, label),
        );
        if (choices.options.length > 1) withChoice++;
        final actual = {
          'notes': choices.notes.map((n) => _hash(_words(n.html))).toList(),
          'options': [
            for (final o in choices.options)
              [_hash(o.title), _hash(_words(o.html))],
          ],
        };
        final expected = {
          'notes': (item[1] as List).cast<String>(),
          'options': [
            for (final o in item[2] as List) (o as List).cast<String>(),
          ],
        };
        if (jsonEncode(actual) != jsonEncode(expected)) {
          mismatches.add(item[0] as String);
        }
      }
      expect(cases.length, greaterThan(300));
      expect(withChoice, fixture['choices']);
      expect(mismatches, isEmpty, reason: mismatches.take(8).join('\n'));
    },
  );

  group('remembering the pick (session only)', () {
    test('per field, day, Office option and diocese; any change resets', () {
      final store = ReadingChoiceStore();
      final day = readingChoiceContext(
        '2026-12-04',
        'grodno-cathedral-dedication',
        'grodno',
      );
      expect(store.get('officeOfReadingsR2', day, 3), 0);
      store.set('officeOfReadingsR2', day, 1);
      expect(store.get('officeOfReadingsR2', day, 3), 1);
      expect(
        store.get('officeOfReadingsR1', day, 3),
        0,
        reason: 'another field',
      );
      expect(
        store.get(
          'officeOfReadingsR2',
          readingChoiceContext(
            '2026-12-05',
            'grodno-cathedral-dedication',
            'grodno',
          ),
          3,
        ),
        0,
        reason: 'another day',
      );
      expect(
        store.get(
          'officeOfReadingsR2',
          readingChoiceContext('2026-12-04', 'other-option', 'grodno'),
          3,
        ),
        0,
        reason: 'Proper <-> Common',
      );
      expect(
        store.get(
          'officeOfReadingsR2',
          readingChoiceContext(
            '2026-12-04',
            'grodno-cathedral-dedication',
            'minsk',
          ),
          3,
        ),
        0,
        reason: 'another diocese',
      );
      expect(
        store.get('officeOfReadingsR2', day, 1),
        0,
        reason: 'fewer readings than the stored index',
      );
      store.set(
        'officeOfReadingsR2',
        readingChoiceContext('2026-12-05', 'x'),
        2,
      );
      expect(
        store.get('officeOfReadingsR2', day, 3),
        0,
        reason: 'a write elsewhere replaces the entry',
      );
    });
  });

  group('AlternativeText with office readings', () {
    Future<void> pump(
      WidgetTester tester,
      String html,
      ReadingChoiceSlot slot, {
      double scale = 1,
      Brightness brightness = Brightness.light,
      Size size = const Size(390, 844),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: SingleChildScrollView(
                child: AlternativeText(
                  text: html,
                  kind: 'office-reading',
                  label: 'Выбар чытання',
                  choice: slot,
                  contentBuilder: (_, value) => Text(_plain(value)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> pick(WidgetTester tester, int index) async {
      await tester.tap(find.byKey(const Key('alternative-picker-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('alternative-option-$index')));
      await tester.pumpAndSettle();
    }

    late String advent;
    late String ordinary;
    late ReadingChoiceStore store;
    ReadingChoiceSlot slot(
      String context, [
      String name = 'officeOfReadingsR2',
    ]) => ReadingChoiceSlot(field: name, context: context, store: store);

    setUp(() {
      advent = field('holy-women', 'officeOfReadingsR2', 'advent');
      ordinary = field('holy-women', 'officeOfReadingsR2');
      store = ReadingChoiceStore();
    });

    testWidgets(
      'D1-F1: pick B and see one complete B with its title; no other readings',
      (tester) async {
        await pump(tester, advent, slot('2026-12-04|a|'));
        expect(
          find.byKey(const Key('reading-reference-note-0')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Выбіраюцца найбольш адпаведныя'),
          findsOneWidget,
        );
        expect(find.text('Чытанне · 1 з 2'), findsOneWidget);
        expect(find.textContaining('Святло хрысціяніна'), findsOneWidget);
        await pick(tester, 1);
        expect(find.text('Чытанне · 2 з 2'), findsOneWidget);
        expect(
          find.textContaining('Паўсюднае пакліканне да святасці'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Святло хрысціяніна'),
          findsNothing,
          reason: 'A is not glued to B',
        );
        expect(find.textContaining('Пія ХІІ'), findsNothing);
        expect(
          find.byKey(const Key('reading-reference-note-0')),
          findsOneWidget,
          reason: 'the rubric stays above the choice',
        );
      },
    );

    testWidgets(
      'no picker when only one legal reading is left (volume III, married saint only after the note)',
      (tester) async {
        const single =
            '<p>Выбіраюцца найбольш адпаведныя тэксты з Агульных тэкстаў пра святых мужчын, с. 1.</p><hr />'
            '<p>Кніга Рут 1, 1-5</p>';
        await pump(tester, single, slot('d|a|'));
        expect(
          find.byKey(const Key('alternative-picker-trigger')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('reading-reference-note-0')),
          findsOneWidget,
        );
        expect(find.textContaining('Кніга Рут'), findsOneWidget);
      },
    );

    testWidgets(
      'Pius XII is a choice only in the volume that prints it (III)',
      (tester) async {
        await pump(tester, ordinary, slot('d|a|'));
        expect(find.text('Чытанне · 1 з 3'), findsOneWidget);
        await tester.tap(find.byKey(const Key('alternative-picker-trigger')));
        await tester.pumpAndSettle();
        expect(find.text(_pius), findsOneWidget);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        await pump(tester, advent, slot('d2|a|'));
        await tester.tap(find.byKey(const Key('alternative-picker-trigger')));
        await tester.pumpAndSettle();
        expect(find.text(_pius), findsNothing);
      },
    );

    testWidgets(
      'D1-F2: B survives leaving the reader and coming back; Back keeps the screen working',
      (tester) async {
        final context = slot('2026-12-04|a|');
        final navigator = GlobalKey<NavigatorState>();
        Widget page() => Scaffold(
          body: SingleChildScrollView(
            child: AlternativeText(
              text: advent,
              kind: 'office-reading',
              choice: context,
              contentBuilder: (_, value) => Text(_plain(value)),
            ),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: Builder(
              builder: (c) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(
                    c,
                  ).push(MaterialPageRoute<void>(builder: (_) => page())),
                  child: const Text('Час чытанняў'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Час чытанняў'));
        await tester.pumpAndSettle();
        await pick(tester, 1);
        expect(find.textContaining('Паўсюднае пакліканне'), findsOneWidget);
        // another hour (Morning) and Back
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('Час чытанняў'), findsOneWidget);
        await tester.tap(find.text('Час чытанняў'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Паўсюднае пакліканне'),
          findsOneWidget,
          reason: 'B is remembered in the same context',
        );
        expect(find.textContaining('Святло хрысціяніна'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'D1-F3: another day, season, diocese or Proper does not inherit B',
      (tester) async {
        await pump(tester, advent, slot('2026-12-04|a|grodno'));
        await pick(tester, 1);
        expect(find.textContaining('Паўсюднае пакліканне'), findsOneWidget);
        for (final other in [
          '2026-12-05|a|grodno',
          '2026-12-04|proper|grodno',
          '2026-12-04|a|minsk',
        ]) {
          await pump(tester, advent, slot(other));
          expect(
            find.textContaining('Святло хрысціяніна'),
            findsOneWidget,
            reason: other,
          );
          expect(find.text('Чытанне · 1 з 2'), findsOneWidget, reason: other);
        }
        // another field of the same Office does not inherit it either
        await pump(
          tester,
          advent,
          slot('2026-12-04|a|grodno', 'officeOfReadingsR1'),
        );
        expect(find.textContaining('Святло хрысціяніна'), findsOneWidget);
        // the original context still has B (no other write happened)
        await pump(tester, advent, slot('2026-12-04|a|grodno'));
        expect(find.textContaining('Паўсюднае пакліканне'), findsOneWidget);
      },
    );

    testWidgets(
      'D1-F3: a stored index larger than the new choice count falls back to the first reading',
      (tester) async {
        store.set('officeOfReadingsR2', 'c', 2);
        await pump(tester, advent, slot('c'));
        expect(find.text('Чытанне · 1 з 2'), findsOneWidget);
      },
    );

    testWidgets(
      'D1-F5: 320 px, 180 % text, dark theme: readable, labelled, no overflow',
      (tester) async {
        await pump(
          tester,
          ordinary,
          slot('d|a|'),
          scale: 1.8,
          brightness: Brightness.dark,
          size: const Size(320, 640),
        );
        expect(tester.takeException(), isNull);
        final handle = tester.ensureSemantics();
        expect(find.bySemanticsLabel('Выбар чытання'), findsOneWidget);
        final value = tester
            .getSemantics(find.bySemanticsLabel('Выбар чытання'))
            .value;
        expect(value, contains('Чытанне · 1 з 3'));
        expect(value, contains(_works[0]));
        await tester.tap(find.byKey(const Key('alternative-picker-trigger')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // the sheet scrolls: every legal reading is reachable
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('alternative-option-2')),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        expect(
          find.byKey(const ValueKey('alternative-option-2')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );
  });
}
