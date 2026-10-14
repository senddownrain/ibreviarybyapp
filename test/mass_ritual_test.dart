import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:html/dom.dart' as dom;

import 'package:mybrev_flutter/models/mass_ritual.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';

List<String> _blockTexts(String markdown) => [
  for (final node in parseFragment(
    prayerMarkdownToHtml(markdown, recognizeSpeakers: false),
  ).nodes)
    node is dom.Element ? node.text : '',
];

void main() {
  test('Dart ritual data matches the shared JSON asset', () {
    final json =
        jsonDecode(
              File('assets/mass/order-of-mass.ritual.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(kMassRitual.schemaVersion, json['schemaVersion']);
    expect(kMassRitual.schemaVersion, 3);
    expect(kMassRitual.roles, List<String>.from(json['roles'] as List));
    final policy = json['rolePolicy'] as Map<String, dynamic>;
    expect(
      kMassRitual.rolePolicy.showSpeakerLabels,
      policy['showSpeakerLabels'],
    );
    expect(kMassRitual.rolePolicy.labelPolicy, policy['labelPolicy']);
    expect(
      kMassRitual.rolePolicy.responseRoles,
      List<String>.from(policy['responseRoles'] as List),
    );
    expect(kMassRitual.id, json['id']);
    expect(
      kMassRitual.aliases,
      Map<String, String>.from(json['aliases'] as Map),
    );
    expect(kMassRitual.primaryPrayerId, json['primaryPrayerId']);
    expect(kMassRitual.defaultLanguage, json['defaultLanguage']);
    expect(
      kMassRitual.sections.map((s) => [s.id, s.title, s.parent]).toList(),
      [
        for (final s in json['sections'] as List)
          [s['id'], s['title'], s['parent']],
      ],
    );
    final variants = json['variants'] as List;
    expect(kMassRitual.variants, hasLength(variants.length));
    for (var i = 0; i < variants.length; i++) {
      final v = variants[i] as Map<String, dynamic>;
      final d = kMassRitual.variants[i];
      expect(d.language, v['language']);
      expect(d.prayerId, v['prayerId']);
      expect(d.title, v['title']);
      expect(d.shortLabel, v['shortLabel']);
      expect(d.source, v['source']);
      expect(d.strongMarksResponses, v['strongMarksResponses'] ?? false);
      expect(
        d.bundledAsset,
        v['bundledText'] == null ? null : 'assets/mass/${v['bundledText']}',
      );
      Map<String, List<String>> lists(String key) => {
        for (final e in ((v[key] as Map?) ?? const {}).entries)
          e.key as String: List<String>.from(e.value as List),
      };
      Map<String, String> strings(String key) =>
          Map<String, String>.from((v[key] as Map?) ?? const {});
      expect(d.label, v['label']);
      expect(d.markers, lists('markers'));
      expect(d.anchors, lists('anchors'));
      expect(d.classify, lists('classify'));
      expect(d.roleMarkers, lists('roleMarkers'));
      expect(d.roleCues, lists('roleCues'));
      expect(d.speakerLabels, strings('speakerLabels'));
      expect(d.roleLabels, strings('roleLabels'));
      expect(d.callRole, v['callRole']);
      // Canonical Belarusian title first, the legacy heading as a fallback.
      for (final major in kMassRitual.majorSections) {
        expect(d.markers[major.id]!.first, major.title, reason: d.language);
      }
    }
  });

  test('exactly five canonical major sections with Belarusian names', () {
    expect(kMassRitual.majorSections.map((s) => [s.id, s.title]).toList(), [
      ['introductory-rites', 'Уступныя абрады'],
      ['liturgy-of-the-word', 'Літургія слова'],
      ['eucharistic-liturgy', 'Эўхарыстычная літургія'],
      ['communion-rite', 'Абрад Камуніі'],
      ['concluding-rites', 'Заключныя абрады'],
    ]);
    // Every other section is a subsection of one of the five.
    final majorIds = kMassRitual.majorSections.map((s) => s.id).toSet();
    for (final s in kMassRitual.sections.where((s) => !s.isMajor)) {
      expect(majorIds, contains(s.parent), reason: s.id);
    }
    expect(kMassRitual.section('offertory')!.parent, 'eucharistic-liturgy');
    expect(kMassRitual.majorPositionOf('eucharistic-prayer'), 3);
    expect(kMassRitual.majorPositionOf('dismissal'), 5);
  });

  test('former eucharist section id stays resolvable', () {
    expect(
      kMassRitual.canonicalSectionId('liturgy-of-the-eucharist'),
      'eucharistic-liturgy',
    );
    expect(
      kMassRitual.section('liturgy-of-the-eucharist')!.id,
      'eucharistic-liturgy',
    );
    expect(
      kMassRitual.resolveSectionTarget('liturgy-of-the-eucharist', [
        'eucharistic-liturgy',
      ]),
      'eucharistic-liturgy',
    );
    expect(
      kMassRitual.resolveSectionTarget('offertory', [
        'liturgy-of-the-word',
        'liturgy-of-the-eucharist',
      ]),
      'eucharistic-liturgy',
    );
  });

  test('a missing subsection lands on the nearest preceding sibling', () {
    const available = ['liturgy-of-the-word', 'first-reading', 'creed'];
    expect(
      kMassRitual.resolveSectionTarget('homily', available),
      'first-reading',
    );
    expect(kMassRitual.resolveSectionTarget('creed', available), 'creed');
    // No preceding sibling: the parent section.
    expect(
      kMassRitual.resolveSectionTarget('prayer-over-the-offerings', [
        'liturgy-of-the-word',
        'eucharistic-liturgy',
      ]),
      'eucharistic-liturgy',
    );
  });

  test('markers ending with an ellipsis match as a prefix', () {
    expect(
      massMarkerMatches('Credo in unum Deum…', 'Credo in unum Deum, Patrem'),
      isTrue,
    );
    expect(
      massMarkerMatches('Credo in unum Deum', 'Credo in unum Deum, Patrem'),
      isFalse,
    );
    expect(massMarkerMatches('Или:', '**Или**'), isTrue);
  });

  test('existing Belarusian and Latin prayers are reused as variants', () {
    expect(kMassRitual.primaryPrayerId, 'eMmCtxwyJ75ogmL5rwye');
    expect(kMassRitual.variant('be')!.prayerId, 'eMmCtxwyJ75ogmL5rwye');
    expect(
      kMassRitual.variantForPrayerId('zdro66KYVuQ9p2KbqizD')!.language,
      'la',
    );
    expect(kMassRitual.variant('en')!.prayerId, 'order-of-mass-en');
    expect(kMassRitual.variantForPrayerId('morning'), isNull);
  });

  test('language resolves from link, then stored choice, then default', () {
    expect(kMassRitual.resolveLanguage('en', 'la'), 'en');
    expect(kMassRitual.resolveLanguage(null, 'la'), 'la');
    expect(kMassRitual.resolveLanguage('xx', null), 'be');
  });

  test('English asset exposes every configured section in order', () {
    final text = File('assets/mass/order-of-mass-en.md').readAsStringSync();
    final en = kMassRitual.variant('en')!;
    final located = kMassRitual.locateSections(en, _blockTexts(text));
    expect(located.map((s) => s.sectionId).toList(), [
      for (final section in kMassRitual.sections)
        if (en.markers.containsKey(section.id) ||
            en.anchors.containsKey(section.id))
          section.id,
    ]);
    expect(located.where((s) => s.isMajor).map((s) => s.sectionId).toList(), [
      'introductory-rites',
      'liturgy-of-the-word',
      'eucharistic-liturgy',
      'communion-rite',
      'concluding-rites',
    ]);
    expect(text, contains('Deliver us, Lord, we pray…'));
  });

  test('Latin rubric markers become sections', () {
    final located = kMassRitual.locateSections(
      kMassRitual.variant('la')!,
      _blockTexts(
        'ЧИН МЕССЫ\n\n:::rubric\nВступительные обряды\n:::\n\nV. Amen.\n\n'
        ':::rubric\nЛитургия Слова\n:::\n\nR. Deo gratias.',
      ),
    );
    expect(located.map((s) => s.sectionId), [
      'introductory-rites',
      'liturgy-of-the-word',
    ]);
  });

  test('section target falls back to parent and neighbours', () {
    const latin = [
      'introductory-rites',
      'liturgy-of-the-word',
      'creed',
      'eucharistic-liturgy',
      'communion-rite',
    ];
    expect(kMassRitual.resolveSectionTarget('creed', latin), 'creed');
    expect(
      kMassRitual.resolveSectionTarget('gospel', latin),
      'liturgy-of-the-word',
    );
    expect(
      kMassRitual.resolveSectionTarget('dismissal', latin),
      'communion-rite',
    );
    expect(
      kMassRitual.resolveSectionTarget('sign-of-the-cross', ['gloria']),
      'gloria',
    );
    expect(kMassRitual.resolveSectionTarget(null, latin), isNull);
  });

  test('active section never oscillates around the reading line', () {
    final tops = [
      (sectionId: 'a', top: -300.0),
      (sectionId: 'b', top: 100.0),
      (sectionId: 'c', top: 600.0),
    ];
    expect(activeMassSectionAt(tops, 100), 'b');
    expect(activeMassSectionAt(tops, 99.9), 'a');
    expect(activeMassSectionAt([(sectionId: 'a', top: 500.0)], 100), 'a');
  });

  test('markdown horizontal rules separate alternative forms', () {
    expect(prayerMarkdownToHtml('A\n\n---\n\nB'), contains('<hr>'));
    expect(prayerMarkdownToHtml('A\n---'), isNot(contains('<hr>')));
  });
}
