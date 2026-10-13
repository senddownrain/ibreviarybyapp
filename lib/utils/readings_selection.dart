import 'package:mybrev_flutter/models/mass_reading_sets.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/utils/reading_content.dart';
import 'package:mybrev_flutter/utils/reading_groups.dart';

/// The active Mass reading set of the selected celebration: the canonical
/// document, its sets, the chosen set and the cycle (shared base + the
/// cycle-specific sections).
class MassSetSelection {
  const MassSetSelection({
    required this.document,
    required this.sets,
    required this.set,
    required this.automaticSetId,
    required this.cycles,
    required this.cycle,
    required this.automaticCycle,
  });

  final ParsedReading document;
  final List<MassReadingSet> sets;
  final MassReadingSet set;

  /// The default set of the document (`defaultSetId`).
  final String automaticSetId;

  /// Cycles A/B/C the set distinguishes (empty when it has none).
  final List<String> cycles;

  /// The shown cycle ('' when the set has no cycle-specific sections).
  final String cycle;

  /// The cycle of the date (from the app's liturgical-year cycle).
  final String automaticCycle;

  bool get referenceOnly => set.referenceOnly;

  /// Ordered sections to render.
  List<MassReadingSection> get sections => set.sectionsForCycle(cycle);
}

/// The Readings selection policy of the screen (port of mybrev
/// `resolveReadingsScreen`).
///
/// Group: the user's choice, else the celebration chosen in the calendar
/// (`optionId`, the group of the readings that option's lookups named), else
/// the group linked to the Hours day id, else the default group (an
/// evening/vigil Mass before the morning one, otherwise the first).
/// Documents with sets decide inside their sets (`defaultSetId`); the cycle
/// is the one of the date when the document has it, else the first.
///
/// Audit 2026-10-13 (docs/flutter-lectionary-audit.md): the remaining
/// «first item» fallbacks (`groups.first`, `cycles.first`,
/// `documents.first`) are the web's own and agree with it on all 20 717
/// legal Mass options 2025–2035 × 4 dioceses; the failing cases found
/// (Sundays opening the seasonal date document through the Hours day id,
/// documents of other dioceses, a wrong Sunday cycle on 27.11.2033) were
/// lookup / cycle defects fixed upstream of this function, not fallbacks.
class DefaultReadingsSelection {
  const DefaultReadingsSelection({
    required this.groups,
    required this.activeGroupKey,
    required this.documents,
    required this.automaticCycle,
    required this.reading,
    this.cycles = const [],
    this.massSet,
  });

  final List<ReadingCelebrationGroup> groups;
  final String? activeGroupKey;
  final List<ParsedReading> documents;
  final String automaticCycle;
  final ParsedReading? reading;

  /// Cycles the reader can switch between (of the set, or of the group).
  final List<String> cycles;

  /// The structured Mass reading set shown (documents with `massReadings`).
  final MassSetSelection? massSet;
}

/// Documents of a date as the Readings screen shows them: a legacy document
/// covered by a canonical document that is also present is hidden (mybrev
/// `collapseCoveredDocuments`).
List<ParsedReading> collapseCoveredReadings(List<ParsedReading> readings) {
  final canonical = {
    for (final reading in readings)
      if (reading.hasMassReadingSets) reading.id,
  };
  return [
    for (final reading in readings)
      if (!canonical.contains(reading.massReadingsRef?.doc)) reading,
  ];
}

/// Variants of a legacy document celebrated in the evening (mybrev
/// `EVENING_VARIANTS`).
const kEveningReadingVariants = {
  'christmas-vigil',
  'pentecost-vigil',
  'evening-mass',
};

bool _isEveningGroup(ReadingCelebrationGroup group) =>
    group.documents.any((document) {
      final variant = (document.variant ?? '').toLowerCase();
      final set = document.massReadingsRef?.set;
      return kEveningReadingVariants.contains(variant) ||
          set == 'vigil' ||
          set == 'evening';
    });

/// Default group without an explicit choice: an evening/vigil Mass of the
/// date (24.12, Holy Thursday, Pentecost Saturday) before the morning one
/// (mybrev `preferredReadingGroup`). Documents with sets decide inside
/// their sets.
ReadingCelebrationGroup? preferredReadingGroup(
  List<ReadingCelebrationGroup> groups,
) {
  if (groups.length > 1) {
    final evening = groups.where(_isEveningGroup).firstOrNull;
    if (evening != null) return evening;
  }
  return groups.firstOrNull;
}

DefaultReadingsSelection resolveDefaultReadings({
  required List<ParsedReading> readings,
  required String sundayCycle,
  required String weekdayCycle,
  String? dayId,
  String? optionId,
  String? groupKey,
  String? manualCycle,
  String? requestedSetId,
  Map<String, String> setChoices = const {},
  bool groupByCelebration = true,
}) {
  // A legacy document linked to the day may be covered by a canonical one:
  // the canonical document stands for it.
  final linkedIds = <String>{};
  if (dayId != null && dayId.isNotEmpty) {
    for (final reading in readings) {
      if (reading.dayId == dayId || reading.dayIds.contains(dayId)) {
        linkedIds.add(reading.massReadingsRef?.doc ?? reading.id);
      }
    }
  }
  final visible = collapseCoveredReadings(readings);
  var groups = groupByCelebration
      ? groupReadings(visible)
      : <ReadingCelebrationGroup>[];
  final withContent = groups
      .where((group) => group.documents.any(readingHasVisibleContent))
      .toList();
  if (withContent.isNotEmpty) groups = withContent;

  final linked = linkedIds.isEmpty
      ? null
      : groups
            .where(
              (group) => group.documents.any(
                (reading) => linkedIds.contains(reading.id),
              ),
            )
            .firstOrNull;

  ReadingCelebrationGroup? selected;
  if (groupKey != null) {
    selected = groups.where((group) => group.key == groupKey).firstOrNull;
  }
  // The celebration chosen in the calendar (mybrev `?option=`): the group
  // of the readings its lookups named. It outranks a link by the Hours day
  // id: the seasonal date document of a Sunday (`advent-21-12`) is linked
  // to the Hours day of the Sunday but is not its lectionary (the period
  // document `advent-w4-d1--A` is).
  final ofOption = optionId == null || optionId.isEmpty
      ? null
      : groups
            .where(
              (group) => group.documents.any(
                (reading) => reading.ordoOptionId == optionId,
              ),
            )
            .firstOrNull;
  selected ??= ofOption ?? linked ?? preferredReadingGroup(groups);
  final documents = selected?.documents ?? visible;

  final setDocument = documents
      .where((reading) => reading.hasMassReadingSets)
      .firstOrNull;
  if (setDocument != null) {
    final massReadings = setDocument.massReadings!;
    final set = massReadings.select(
      setChoices[setDocument.id] ?? requestedSetId,
    );
    final cycles = set.cycles;
    final automaticCycle = cycles.contains(sundayCycle)
        ? sundayCycle
        : (cycles.firstOrNull ?? '');
    final requested = normalizeReadingCycle(manualCycle);
    final cycle = cycles.contains(requested) ? requested : automaticCycle;
    return DefaultReadingsSelection(
      groups: groups,
      activeGroupKey: selected?.key,
      documents: documents,
      automaticCycle: automaticCycle,
      reading: setDocument,
      cycles: cycles,
      massSet: MassSetSelection(
        document: setDocument,
        sets: massReadings.sets,
        set: set,
        automaticSetId: massReadings.defaultSetId,
        cycles: cycles,
        cycle: cycle,
        automaticCycle: automaticCycle,
      ),
    );
  }

  final cycles = availableCyclesForGroup(documents);
  final automaticCycle = cycles.any(const {'A', 'B', 'C'}.contains)
      ? sundayCycle
      : weekdayCycle;
  final requestedCycle = normalizeReadingCycle(manualCycle).isNotEmpty
      ? normalizeReadingCycle(manualCycle)
      : automaticCycle;

  final reading =
      pickReadingForCycle(documents, requestedCycle) ??
      documents.where(readingHasVisibleContent).firstOrNull ??
      documents.firstOrNull;
  return DefaultReadingsSelection(
    groups: groups,
    activeGroupKey: selected?.key,
    documents: documents,
    automaticCycle: automaticCycle,
    reading: reading,
    cycles: cycles,
  );
}
