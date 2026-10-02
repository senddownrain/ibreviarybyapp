import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';

import 'support/compendium_fixture.dart';

void main() {
  final index = CompendiumIndex(readBundledCompendium());

  test(
    'all four cached streams contain exactly the canonical 598 questions',
    () {
      final all = <int>[];
      for (final part in index.parts) {
        final outline = index.partReadingOutline(part.id)!;
        expect(
          identical(outline, index.partReadingOutline('${part.number}')),
          isTrue,
        );
        final numbers = [
          for (final item in outline.items)
            if (item.question case final question?) question.number,
        ];
        expect(numbers, [
          for (final question in index.questions)
            if (question.partId == part.id) question.number,
        ]);
        expect(
          outline.items.map((item) => item.id).toSet(),
          hasLength(outline.items.length),
        );
        expect(
          outline.items.where((item) => item.id.endsWith('-intro')),
          isEmpty,
        );
        all.addAll(numbers);
      }
      expect(all, List.generate(598, (i) => i + 1));
    },
  );

  test('Part I starts with section, q1, subsection, citation, q2–5, topic', () {
    final items = index.partReadingOutline('p1')!.items;
    final ids = items.map((item) => item.id).toList();
    expect(ids.take(3), ['p1-s1', 'q001', 'p1-s1-ch1']);
    expect(items[0].kind, CompendiumPartItemKind.sectionHeading);
    expect(items[2].label, 'ПАДРАЗДЗЕЛ ПЕРШЫ');
    expect(items[3].kind, CompendiumPartItemKind.leadCitations);
    expect(items[3].citations, isNotEmpty);
    expect(ids.sublist(4, 8), ['q002', 'q003', 'q004', 'q005']);
    expect(ids.indexOf('p1-s1-ch2-t1'), lessThan(ids.indexOf('q006')));
    expect(ids.indexOf('q079'), lessThan(ids.indexOf('q080')));
    expect(ids.indexOf('p1-s2'), lessThan(ids.indexOf('q079')));
    expect(ids[ids.indexOf('q080') + 1], 'p1-s2-ch2-t1');
    expect(ids[ids.indexOf('q059') - 1], 'q059-subtopic');
    expect(ids[ids.indexOf('q147') - 1], 'q147-subtopic');
  });

  test('edge placements and inline headings match source order', () {
    final p2 = index.partReadingOutline('p2')!;
    final p3 = index.partReadingOutline('p3')!;
    final p4 = index.partReadingOutline('p4')!;
    for (final (outline, numbers) in [
      (index.partReadingOutline('p1')!, [1, 2, 5, 79, 80]),
      (p2, [218, 219, 220, 250, 251, 295, 321]),
      (p3, [357, 434, 435, 436, 437, 438, 439, 440, 441]),
      (p4, [534, 535, 557, 567, 568]),
    ]) {
      final ids = outline.items.map((item) => item.id).toList();
      final positions = [
        for (final n in numbers)
          ids.indexOf('q${n.toString().padLeft(3, '0')}'),
      ];
      expect(positions, everyElement(greaterThanOrEqualTo(0)));
      expect(positions, orderedEquals([...positions]..sort()));
    }
    expect(p2.targetIndices['p2-s2'], lessThan(p2.targetIndices['q250']!));
    expect(p2.targetIndices['q250'], lessThan(p2.targetIndices['p2-s2-ch1']!));
    expect(p2.items[p2.targetIndices['q220']! + 1].id, 'p2-s1-ch1');
    expect(p2.items[p2.targetIndices['q250']! - 1].id, 'p2-s2-intro-t1');
    expect(
      p2.targetIndices['p2-s1-ch2-t1-parent'],
      lessThan(p2.targetIndices['p2-s1-ch2-t1']!),
    );
    expect(p4.targetIndices['p4-s2'], isNotNull);
    expect(
      p4.items[p4.targetIndices['p4-s2']! + 1].kind,
      CompendiumPartItemKind.topicHeading,
    );
    expect(
      index.partReadingOutlines.values
          .expand((part) => part.items)
          .where((item) => item.kind == CompendiumPartItemKind.subtopicHeading),
      isNotEmpty,
    );
    expect(
      p3.items.where(
        (item) => item.kind == CompendiumPartItemKind.topicHeading,
      ),
      isNotEmpty,
    );
  });
}
