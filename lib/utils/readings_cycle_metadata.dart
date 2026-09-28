/// One quiet line of cycle and manual-selection context for the reader header.
String? readingsCycleMetadata({
  required String? cycle,
  required bool manualGroup,
  required bool manualCycle,
}) {
  assert(!manualCycle || cycle != null);
  if (manualGroup && manualCycle) return 'Набор і цыкл $cycle · зменены';
  if (manualGroup) return 'Набор чытанняў · зменены';
  if (manualCycle) return 'Цыкл $cycle · зменены';
  return cycle == null ? null : 'Цыкл $cycle';
}
