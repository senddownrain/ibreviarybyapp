// Ports Web daysResult/adventVespers runtime source selection. The immutable
// bundle remains intact; reviewed old values alone receive the Web bridge.
import 'package:mybrev_flutter/generated/approved_office_sources.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';

LiturgicalDay? applyReviewedAdventVespers(LiturgicalDay? day) {
  if (day == null) return null;
  final fields = (approvedOfficeSources['advent'] as Map)['documents'][day.id];
  if (fields is! Map) return day;
  final data = day.toMap();
  for (final entry in fields.entries) {
    final correction = entry.value as Map;
    if (data[entry.key] != correction['before']) continue;
    data[entry.key as String] = correction['value'];
    if (data['_fromDayFields'] case final List refs) {
      data['_fromDayFields'] = refs.where((f) => f != entry.key).toList();
    }
  }
  return LiturgicalDay.fromMap(data);
}

LiturgicalDay? resolveAdventDateAgainstPeriod(
  LiturgicalDay? dateDay,
  LiturgicalDay? periodDay,
  int dow,
) {
  final resolved = resolveDayAgainstPeriod(
    dateDay,
    periodDay,
    fillMissing: true,
  );
  if (resolved == null) return null;
  final data = resolved.toMap();
  // Sunday IV of Advent on 17–24 December: «Верш, чытанні і рэспансорыі
  // бяруцца з бягучага дня» — the verse and both readings (with responsories)
  // belong to the calendar date, everything else to the Sunday.
  final fourthSunday = dow == 1 && periodDay?.id == 'advent-w4-d1';
  const datedReadingFields = [
    'officeOfReadingsVers',
    'officeOfReadingsR1',
    'officeOfReadingsR2',
  ];
  for (final field
      in (approvedOfficeSources['fields'] as List).cast<String>()) {
    if (fourthSunday && datedReadingFields.contains(field)) {
      final dated = dateDay?.field(field);
      if (dated != null &&
          dated.trim().isNotEmpty &&
          !isFromDayReference(dated)) {
        data[field] = dated;
        continue;
      }
    }
    final dateProper = ['laudesAntBen', 'vesperAntMag'].contains(field);
    if ((dow == 1 && !dateProper) ||
        ['vesperPs1', 'vesperPs2', 'vesperPs3'].contains(field)) {
      data[field] = periodDay?.data[field] ?? '';
    }
  }
  data.remove('_fromDayFields');
  final day = LiturgicalDay.fromMap(data);
  return dow == 1
      ? day
      : applySeasonalWeekdayAntiphons(day, dow, ownDay: dateDay);
}
