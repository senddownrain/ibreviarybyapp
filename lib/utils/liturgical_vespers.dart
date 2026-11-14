import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';
import 'package:mybrev_flutter/utils/liturgical_office.dart';

/// Liturgical evening is selected by the Ordo's precedence decision, not by
/// whether tomorrow's document happens to contain `vesper1*` fields.
const firstVespersSuffixes = [
  'Hymn',
  'Ant1',
  'Ant2',
  'Ant3',
  'Ps1',
  'Ps2',
  'Ps3',
  'R',
  'AntMag',
  'Inter',
  'Pr',
];

bool _hasText(String? value) => value?.trim().isNotEmpty == true;

/// Celebration with I Vespers by right (for non-ordinary-Sunday cases):
/// explicit `vesper1*` Proper wins, then its own regular Vespers/Common.
/// The ordinary Sunday needs a *different* fallback; see below.
LiturgicalDay assembleFirstVespers(
  LiturgicalDay celebration, {
  LiturgicalDay? civilDay,
}) {
  final data = celebration.toMap();
  var own = 0;
  for (final suffix in firstVespersSuffixes) {
    final first = celebration.field('vesper1$suffix');
    if (_hasText(first)) own++;
    data['vesper$suffix'] = _hasText(first)
        ? first
        : (celebration.field('vesper$suffix') ?? '');
  }
  data['_firstVespersSource'] = own == firstVespersSuffixes.length
      ? 'vesper1'
      : own > 0
      ? 'vesper1+proper'
      : 'proper';
  if (civilDay?.periodType == 'advent' &&
      celebration.periodType == 'advent' &&
      RegExp(r'^advent-\d{2}-12$').hasMatch(civilDay!.id) &&
      _hasText(civilDay.field('vesperAntMag'))) {
    data['vesperAntMag'] = civilDay.field('vesperAntMag');
  }
  return LiturgicalDay.fromMap(data);
}

/// Ordinary Sunday II Vespers live in Sunday's `vesper*` fields.
/// I Vespers are the previous Saturday's `vesper*` (psalter of Sunday).
/// Never substitute Sunday II Vespers when `vesper1*` are blank.
LiturgicalDay assembleOrdinarySundayFirstVespers(
  LiturgicalDay sunday,
  LiturgicalDay? saturdayPsalter,
) {
  final data = sunday.toMap();
  final missing = <String>[];
  for (final suffix in firstVespersSuffixes) {
    final proper = sunday.field('vesper1$suffix');
    final psalter = saturdayPsalter?.field('vesper$suffix');
    final value = _hasText(proper)
        ? proper!
        : (_hasText(psalter) ? psalter! : '');
    data['vesper$suffix'] = value;
    if (!_hasText(value)) missing.add(suffix);
  }
  data['_firstVespersSource'] = hasFirstVespers(sunday)
      ? 'vesper1+saturday-psalter'
      : 'saturday-psalter';
  data['_missingFirstVespersFields'] = missing;
  return LiturgicalDay.fromMap(data);
}

class EveningOfficeResolution {
  const EveningOfficeResolution({
    required this.day,
    this.isFirst = false,
    this.isSecond = false,
    this.firstVespersTitle,
  });
  final LiturgicalDay day;
  final bool isFirst;
  final bool isSecond;
  final String? firstVespersTitle;
}

/// Uses the same Ordo decision as the calendar and the Hours cards.
/// `today.itemsDays` contains the current Saturday period/psalter even if
/// the date's public cards are two competing memorials with no weekday card.
EveningOfficeResolution resolveEveningOffice({
  required DateTime date,
  required LiturgicalDay selected,
  required LiturgicalDayContent today,
  required LiturgicalDayContent tomorrow,
}) {
  if (usesOwnVespers(selected)) return EveningOfficeResolution(day: selected);
  final evening = today.ordo.evening;
  if (evening.vespersType != 'first') {
    return EveningOfficeResolution(
      day: selected,
      isSecond: evening.vespersType == 'second',
    );
  }

  final legal =
      tomorrow.options
          .where((option) => option.ordo?.optionId == evening.celebrationId)
          .firstOrNull ??
      tomorrow.options
          .where((option) => option.ordo?.role == 'primary')
          .firstOrNull;
  final celebration = legal?.day;
  if (celebration == null) {
    // No legal source: do not label the current day's ordinary office as
    // tomorrow's I Vespers, or invent text.
    return EveningOfficeResolution(day: selected);
  }

  final ordinarySunday =
      date.weekday == DateTime.saturday &&
      legal?.ordo?.officeKind == 'sunday' &&
      tomorrow.ordo.period == 'ordinary';
  final periodId = periodDayDocumentId(
    today.ordo.period,
    today.ordo.week,
    today.ordo.dayOfWeek,
  );
  final resolved = ordinarySunday
      ? assembleOrdinarySundayFirstVespers(
          celebration,
          today.itemsDays[periodId],
        )
      : assembleFirstVespers(celebration, civilDay: selected);
  return EveningOfficeResolution(
    day: resolved,
    isFirst: true,
    firstVespersTitle: legal?.title,
  );
}
