import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/services/priest_access_policy.dart';
import 'package:mybrev_flutter/utils/devotional_office.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Prayer> prayers;
  setUpAll(() async {
    final collection = decodeContentCollection(
      (await rootBundle.load(
        'assets/content/prayers.json.gz',
      )).buffer.asUint8List(),
    );
    final categories = decodeContentCollection(
      (await rootBundle.load(
        'assets/content/prayerCategories.json.gz',
      )).buffer.asUint8List(),
    );
    final policy = PriestAccessPolicy(categories.docs);
    prayers = {
      for (final id in devotionalOfficeProfiles.keys)
        id: Prayer.fromMap(collection.docs[id]!, id),
    };
    for (final id in prayers.keys) {
      expect(
        policy.prayerRestricted(collection.docs[id]!),
        isFalse,
        reason: id,
      );
    }
  });
  for (final id in devotionalOfficeProfiles.keys) {
    test(
      '$id: strict profile, exact source ranges and all hidden alternatives retained',
      () {
        final prayer = prayers[id]!;
        final before = prayer.toMap();
        final doc = parseDevotionalOffice(prayer)!;
        expect(doc.profile, devotionalOfficeProfiles[id]);
        expect(doc.source, prayer.displayText);
        final lines = prayer.displayText.split('\n');
        final covered = <int>[];
        for (final b in doc.sourceBlocks) {
          expect(b.source, lines.sublist(b.start, b.end).join('\n'));
          covered.addAll(List.generate(b.end - b.start, (i) => b.start + i));
        }
        expect(covered.toSet().length, covered.length);
        expect(
          [
            for (var i = 0; i < lines.length; i++)
              if (lines[i].trim().isNotEmpty) i,
          ].every(covered.contains),
          isTrue,
        );
        final retained = [
          for (final s in doc.sections) ...s.blocks,
          for (final s in doc.sections)
            for (final a in s.alternatives) ...a.blocks,
        ];
        expect(retained.length, doc.sourceBlocks.length);
        expect(retained.toSet(), doc.sourceBlocks.toSet());
        expect(parseDevotionalOffice(prayer.copyWith(id: 'ordinary')), isNull);
        expect(
          parseDevotionalOffice(
            prayer.copyWith(
              body: prayer.displayText.replaceFirst('## ', '### '),
            ),
          ),
          isNull,
        );
        expect(
          parseDevotionalOffice(
            prayer.copyWith(body: '```\n${prayer.displayText}\n```'),
          ),
          isNull,
        );
        if (doc.profile == 'gadzinki') {
          expect(doc.sections.map((s) => s.title), gadzinkiParts);
          expect(doc.sections.expand((s) => doc.choices(s)), isEmpty);
          expect(
            doc.sections
                .expand((s) => devotionalDisplayItems(s, s.blocks))
                .where((i) => i.kind == 'heading' && i.text == 'Гімн'),
            hasLength(7),
          );
        } else {
          final psalmody = doc.sections.firstWhere((s) => s.type == 'psalmody');
          final items = devotionalDisplayItems(psalmody, psalmody.blocks);
          expect(items.where((b) => b.kind == 'psalmBody'), hasLength(3));
          expect(items.where((b) => b.kind == 'antiphon'), hasLength(6));
          final reading = doc.sections.firstWhere((s) => s.type == 'reading');
          final readingItems = devotionalDisplayItems(reading, reading.blocks);
          expect(
            readingItems
                .where((b) => b.kind == 'readingTitle')
                .single
                .reference,
            isNotEmpty,
          );
          final response = readingItems.singleWhere(
            (b) => b.kind == 'responsoryBody',
          );
          final html = parseFragment(
            devotionalSpeakerHtml(response.source, responsory: true),
          );
          expect(html.querySelectorAll('.prayer-speaker'), hasLength(6));
          expect(html.querySelectorAll('p'), hasLength(1));
          expect(html.querySelectorAll('br'), hasLength(5));
          String plain(String source) => parseFragment(
            prayerMarkdownToHtml(source),
          ).text!.replaceAll(RegExp(r'\s+'), ' ').trim();
          expect(
            html.text!.replaceAll(RegExp(r'\s+'), ' ').trim(),
            plain(response.source),
          );
          if (doc.forMary) {
            if (doc.profile == 'laudes') {
              expect(items.where((b) => b.kind == 'psalmMeta'), hasLength(6));
            }
            expect(
              doc.sections
                  .where((s) => doc.choices(s).isNotEmpty)
                  .map((s) => s.type),
              ['intercessions', 'prayer'],
            );
            expect(
              doc.choices(
                doc.sections.firstWhere((s) => s.type == 'intercessions'),
              ),
              hasLength(2),
            );
            final section = doc.sections.firstWhere((s) => s.type == 'prayer');
            expect(doc.choices(section), hasLength(5));
            for (var i = 1; i < 5; i++) {
              expect(
                doc
                    .selectedBlocks(section, choice: i)
                    .skip(1)
                    .map((b) => b.source),
                section.alternatives[i - 1].blocks
                    .skip(1)
                    .where((b) => !{'Або:', 'Або іншыя:'}.contains(b.text))
                    .map((b) => b.source),
              );
            }
          }
        }
        expect(prayer.toMap(), before);
      },
    );
  }
  for (final id in devotionalOfficeProfiles.keys.where(
    (id) => id.contains('for-dead'),
  )) {
    test(
      '$id: four intentions synchronously choose exact source hymn and prayer',
      () {
        final doc = parseDevotionalOffice(prayers[id]!)!;
        final hymn = doc.sections.firstWhere((s) => s.type == 'hymn');
        final prayer = doc.sections.firstWhere((s) => s.type == 'prayer');
        expect(doc.selectedBlocks(hymn), isEmpty);
        expect(doc.selectedBlocks(prayer), isEmpty);
        for (var i = 0; i < 4; i++) {
          final h = doc.selectedBlocks(hymn, intention: i);
          final p = doc.selectedBlocks(prayer, intention: i);
          final expectedH = i == 0
              ? hymn.blocks
              : hymn.alternatives
                    .singleWhere(
                      (a) =>
                          a.title ==
                          (i == 1
                              ? 'Гімн — За адну памерлую'
                              : 'Гімн — За некалькіх'),
                    )
                    .blocks;
          final expectedP = i < 2
              ? prayer.blocks
              : prayer.alternatives
                    .singleWhere(
                      (a) =>
                          a.title == 'Малітва — ${devotionalDeadIntentions[i]}',
                    )
                    .blocks;
          expect(h.last.source, expectedH.last.source);
          expect(p.last.source, expectedP.last.source);
          expect(
            [...h, ...p].where(
              (b) =>
                  b.kind == 'text' &&
                  b.source.trim().startsWith('За ') &&
                  b.source.trim().endsWith(':'),
            ),
            isEmpty,
          );
          if (i < 2) expect(p.last.source, contains('N.'));
          if (i == 2) expect(p.last.source, contains('(N. і N.)'));
        }
      },
    );
  }
  test(
    'office labels stay red-ready, compact and safe, including no-space legacy replies',
    () {
      final html = parseFragment(
        devotionalSpeakerHtml(
          '**Кантар:** Тэкст.\n**Н.:** Адказ.\n**К:** Слова.\n**Молiмся:** Малітва.\nС. Слова.',
        ),
      );
      expect(html.querySelectorAll('.prayer-speaker').map((e) => e.text), [
        'Кантар:',
        'Н.:',
        'К:',
        'Молiмся:',
        'С.',
      ]);
      final compact = parseFragment(
        devotionalSpeakerHtml(
          'К.Тэкст. Н.Адказ. К.Хвала. Н.Амэн.',
          responsory: true,
        ),
      );
      expect(compact.querySelectorAll('.prayer-speaker'), hasLength(4));
      expect(compact.querySelectorAll('br'), hasLength(3));
      final unsafe = parseFragment(
        devotionalSpeakerHtml(
          '<script>alert(1)</script>\n[link](javascript:evil())',
        ),
      );
      expect(
        unsafe.querySelectorAll(
          'script, iframe, [onclick], [href^="javascript:"]',
        ),
        isEmpty,
      );
    },
  );
}
