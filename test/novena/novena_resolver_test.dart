import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/novena/novena_definition.dart';

import 'support.dart';

const _fixtures = [
  'DVCz2NZEvgNdVFmQJaJB',
  'Wf9vo99Lt2z0VV1pucz5',
  'catholicby-yearcycle-100111',
  'cn_05b28c5bea797880',
  'cn_71fcef6576ae8b20',
  'cn_c7dd05c2dd25b78d',
  'cn_ef21171d9c54b47a',
  'oP3C3W6wnw5Iga5d6aln',
];

void main() {
  test('every contract fixture is covered', () {
    final files = [
      for (final file in Directory('test/novena/fixtures').listSync())
        file.uri.pathSegments.last.replaceAll('.json', ''),
    ]..remove('definitions_ready');
    expect(files..sort(), [..._fixtures]..sort());
  });

  for (final id in _fixtures) {
    test('resolver parity: $id', () {
      final data = fixture(id);
      final definition = NovenaDefinition.tryParse(data['definition'] as Map)!;
      final prayers = fixturePrayers(data);
      final expected = data['expected'] as List?;
      if (expected == null) {
        // Blocked by the generator: a draft, never offered by the app.
        expect(data['blockers'], isNotEmpty);
        expect(definition.isPublished, isFalse);
        return;
      }
      for (final day in expected) {
        expect([
          for (final block in definition.resolveDay(
            (day as Map)['day'] as int,
            prayers,
          ))
            block.toMap(),
        ], day['blocks']);
      }
      expect(definition.resolveAll(prayers), hasLength(9));
    });
  }

  test('all ready definitions assemble from the bundled public prayers', () {
    final prayers = bundledPrayers();
    final ready = readyDefinitions();
    expect(ready, hasLength(42));
    final unsupported = [
      for (final data in ready)
        if (NovenaDefinition.tryParse(data)!.resolveAll(prayers) == null)
          data['novenaId'],
    ];
    expect(unsupported, isEmpty);
  });

  test('a missing or closed prayer makes the whole novena unsupported', () {
    final data = fixture('cn_05b28c5bea797880');
    final definition = NovenaDefinition.tryParse(data['definition'] as Map)!;
    final prayers = fixturePrayers(data);
    final linked = prayers.keys.firstWhere((id) => id != definition.novenaId);

    expect(definition.resolveAll({...prayers}..remove(linked)), isNull);
    final closed = prayers[linked]!;
    expect(
      definition.resolveAll({
        ...prayers,
        linked: NovenaPrayer(
          id: closed.id,
          title: closed.title,
          text: closed.text,
          priestOnly: true,
        ),
      }),
      isNull,
    );
    expect(
      () => definition.resolveDay(1, {...prayers}..remove(linked)),
      throwsA(isA<NovenaResolveError>()),
    );
  });

  test('section ends at the next heading of the same or a higher level', () {
    const text =
        '## A\r\none\r\n### B\r\ntwo\r\n**Молімся:** x\r\n## C\r\n**D**\r\n'
        'three\r\n## A\r\nfour';
    expect(
      novenaSectionText(text, '## A'),
      '## A\none\n### B\ntwo\n**Молімся:** x',
    );
    expect(novenaSectionText(text, '**D**'), '**D**\nthree');
    expect(novenaSectionText(text, '## A', 2), '## A\nfour');
    expect(novenaSectionText(text, '## Z'), isNull);
  });

  test('only a published, enabled definition is offered', () {
    final data = fixture('cn_05b28c5bea797880')['definition'] as Map;
    NovenaDefinition parse(Map change) =>
        NovenaDefinition.tryParse({...data, ...change})!;
    expect(parse({}).isPublished, isFalse);
    expect(parse({'status': 'published'}).isPublished, isFalse);
    expect(
      parse({'status': 'published', 'trackerEnabled': true}).isPublished,
      isTrue,
    );
    expect(NovenaDefinition.tryParse({'novenaId': 'x'}), isNull);
    expect(NovenaDefinition.tryParse({...data, 'template': 'x'}), isNotNull);
    expect(
      NovenaDefinition.tryParse({
        ...data,
        'template': [1],
      }),
      isNull,
    );
    expect(
      parse({
        'schemaVersion': 2,
      }).resolveAll(fixturePrayers(fixture('cn_05b28c5bea797880'))),
      isNull,
    );
  });
}
