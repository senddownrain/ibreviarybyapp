import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/utils/reading_content.dart';
import 'package:mybrev_flutter/utils/reading_groups.dart';

/// The existing production Readings selection policy, centralized for the
/// Stage 4 reader UI. This intentionally preserves the current ordering and
/// first-item fallbacks; it is not a new liturgical precedence resolver.
/// TODO(readings-resolver): audit these fallbacks against the normative
/// lectionary rules in a dedicated migration.
class DefaultReadingsSelection {
  const DefaultReadingsSelection({
    required this.groups,
    required this.activeGroupKey,
    required this.documents,
    required this.automaticCycle,
    required this.reading,
  });

  final List<ReadingCelebrationGroup> groups;
  final String? activeGroupKey;
  final List<ParsedReading> documents;
  final String automaticCycle;
  final ParsedReading? reading;
}

DefaultReadingsSelection resolveDefaultReadings({
  required List<ParsedReading> readings,
  required String sundayCycle,
  required String weekdayCycle,
  String? dayId,
  String? groupKey,
  String? manualCycle,
  bool groupByCelebration = true,
}) {
  var groups = groupByCelebration
      ? groupReadings(readings)
      : <ReadingCelebrationGroup>[];
  final withContent = groups
      .where((group) => group.documents.any(readingHasVisibleContent))
      .toList();
  if (withContent.isNotEmpty) groups = withContent;

  ReadingCelebrationGroup? linked;
  if (dayId != null && dayId.isNotEmpty) {
    linked = groups.where((group) {
      return group.documents.any(
        (reading) => reading.dayId == dayId || reading.dayIds.contains(dayId),
      );
    }).firstOrNull;
  }

  ReadingCelebrationGroup? selected;
  if (groupKey != null) {
    selected = groups.where((group) => group.key == groupKey).firstOrNull;
  }
  selected ??= linked ?? groups.firstOrNull;
  final documents = selected?.documents ?? readings;
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
  );
}
