import 'package:mybrev_flutter/models/mass_reading_sets.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/utils/readings_selection.dart';

/// One section of the reading the Readings screen renders, with the hash of
/// its full semantic content (never the HTML or the widget tree).
class ReadingViewSection {
  const ReadingViewSection({
    required this.kind,
    required this.role,
    required this.cycle,
    required this.hash,
    this.bible = '',
  });

  final String kind;
  final String role;
  final String cycle;
  final String hash;

  /// The citation printed with the section.
  final String bible;
}

/// What the Readings screen shows for a selection: the document, the set
/// and cycle, and the ordered sections (the model of the render; the widget
/// draws exactly these).
class ReadingView {
  const ReadingView({
    required this.docId,
    required this.setId,
    required this.cycle,
    required this.referenceOnly,
    required this.sections,
  });

  final String docId;

  /// Null: a legacy document read from its flat fields.
  final String? setId;
  final String cycle;
  final bool referenceOnly;
  final List<ReadingViewSection> sections;
}

/// Ordered flat (legacy) sections of a document, as the reader draws them:
/// first reading, psalm, second reading, sequence, acclamation, Gospel.
List<MassReadingSection> legacyReadingSections(ParsedReading reading) {
  final first = reading.firstReading;
  final sequence = reading.sequence;
  return [
    if (first != null) first.toSection('reading', 'reading1'),
    if (reading.psalm != null) reading.psalm!.toSection('psalm', 'psalm'),
    if (reading.reading2 != null)
      reading.reading2!.toSection('reading', 'reading2'),
    if ((sequence?.text ?? '').trim().isNotEmpty)
      sequence!.toSection('sequence', 'sequence'),
    if (reading.alleluia != null)
      reading.alleluia!.toSection('acclamation', 'alleluia'),
    if (reading.gospel != null) reading.gospel!.toSection('gospel', 'gospel'),
  ];
}

/// The view of [selection] (null: nothing selected).
ReadingView? readingViewOf(DefaultReadingsSelection selection) {
  final massSet = selection.massSet;
  if (massSet != null) {
    return ReadingView(
      docId: massSet.document.id,
      setId: massSet.set.id,
      cycle: massSet.cycle,
      referenceOnly: massSet.referenceOnly,
      sections: [
        for (final section in massSet.sections)
          ReadingViewSection(
            kind: section.kind,
            role: section.role ?? '',
            cycle: section.cycle ?? '',
            hash: section.contentHash,
            bible: section.bible ?? '',
          ),
      ],
    );
  }
  final reading = selection.reading;
  if (reading == null) return null;
  return ReadingView(
    docId: reading.id,
    setId: null,
    cycle: _cycleOf(reading),
    referenceOnly: false,
    sections: [
      for (final section in legacyReadingSections(reading))
        ReadingViewSection(
          kind: section.kind,
          role: section.role ?? '',
          cycle: '',
          hash: section.contentHash,
          bible: section.bible ?? '',
        ),
    ],
  );
}

String _cycleOf(ParsedReading reading) {
  final cycle = (reading.year ?? '').trim().toUpperCase();
  return const {'A', 'B', 'C', '1', '2'}.contains(cycle) ? cycle : '';
}

/// One line of citations of the shown reading (first reading · second
/// reading · Gospel), for the day screen's subtitle: ONLY the reading the
/// Readings screen opens for this selection, never the citations of every
/// cycle or celebration of the date. Null when the reading has none.
String? readingCitationLine(ReadingView? view) {
  if (view == null) return null;
  final citations = <String>[];
  for (final section in view.sections) {
    if (!const {'reading', 'gospel'}.contains(section.kind)) continue;
    if (section.role != 'reading1' &&
        section.role != 'reading2' &&
        section.role != 'gospel') {
      continue;
    }
    final bible = section.bible.trim();
    if (bible.isNotEmpty && !citations.contains(bible)) citations.add(bible);
  }
  return citations.isEmpty ? null : citations.join(' · ');
}
