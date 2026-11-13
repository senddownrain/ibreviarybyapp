import 'package:mybrev_flutter/models/day.dart';

const _solemnities = {
  'solemnitas',
  'solemnity',
  'урачыстасць',
  'ўрачыстасць',
  'торжество',
};
const _feasts = {'festum', 'feast', 'свята', 'праздник'};
const _memorials = {
  'memoria',
  'memoria-ad-libitum',
  'memorial',
  'memoria-optional',
  'успамін',
};

String _rank(LiturgicalDay? day) =>
    (day?.rank ?? day?.field('_feastType') ?? '').trim().toLowerCase();

bool usesSundayCompletorium(LiturgicalDay? day) =>
    day?.field('_kind') == 'office-for-dead' ||
    _solemnities.contains(_rank(day));

String completoriumId(
  String periodType,
  int dayOfWeek, [
  LiturgicalDay? selectedDay,
]) {
  final period = periodType == 'holyweek' ? 'lent' : periodType.trim();
  final day = usesSundayCompletorium(selectedDay) ? 1 : dayOfWeek;
  if (period.isEmpty || day < 1 || day > 7) return '';
  return '$period-d$day';
}

bool isSolemnity(LiturgicalDay? day) => _solemnities.contains(_rank(day));

bool usesOwnVespers(LiturgicalDay? day) =>
    day?.field('_kind') == 'office-for-dead';

bool hasFirstVespers(LiturgicalDay day) => const [
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
].any((suffix) => (day.field('vesper1$suffix') ?? '').trim().isNotEmpty);

bool hasFirstVespersRank(LiturgicalDay day) =>
    _solemnities.contains(_rank(day)) || _feasts.contains(_rank(day));

LiturgicalDay? normalizeFirstVespers(LiturgicalDay day) {
  if (!hasFirstVespers(day)) return null;
  final data = day.toMap();
  for (final suffix in const [
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
  ]) {
    data['vesper$suffix'] = data['vesper1$suffix'] ?? '';
  }
  return LiturgicalDay.fromMap(data);
}

/// Web assembleFirstVespers: fill each absent I-Vespers field from the
/// celebration's own Vespers. The Advent O antiphon belongs to tonight.
LiturgicalDay assembleFirstVespers(
  LiturgicalDay tomorrow, {
  LiturgicalDay? civilDay,
}) {
  final data = tomorrow.toMap();
  var own = 0;
  const suffixes = [
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
  for (final suffix in suffixes) {
    final first = tomorrow.field('vesper1$suffix') ?? '';
    if (first.trim().isNotEmpty) own++;
    data['vesper$suffix'] = first.trim().isNotEmpty
        ? first
        : tomorrow.field('vesper$suffix') ?? '';
  }
  data['_firstVespersSource'] = own == suffixes.length
      ? 'vesper1'
      : own > 0
      ? 'vesper1+proper'
      : 'proper';
  if (civilDay?.periodType == 'advent' &&
      tomorrow.periodType == 'advent' &&
      RegExp(r'^advent-\d{2}-12$').hasMatch(civilDay!.id) &&
      (civilDay.field('vesperAntMag') ?? '').trim().isNotEmpty) {
    data['vesperAntMag'] = civilDay.field('vesperAntMag');
  }
  return LiturgicalDay.fromMap(data);
}

bool shouldShowTeDeum(LiturgicalDay? day) {
  if (day == null || day.field('_kind') == 'office-for-dead') return false;
  final period = (day.periodType ?? '').toLowerCase();
  final week = day.periodWeekNumber ?? -1;
  final dow = day.dayOfWeek ?? -1;
  final feast = (day.feast ?? '').toLowerCase().replaceFirst('feast-', '');
  if ((period == 'holyweek' && dow >= 5) || feast == 'palmsunday') return false;
  final rank = _rank(day);
  if (_memorials.contains(rank)) return false;
  if (_solemnities.contains(rank) || _feasts.contains(rank)) return true;
  if ((period == 'christmas' && week == 1) ||
      (period == 'easter' && week == 1)) {
    return true;
  }
  return dow == 1 && period != 'lent' && period != 'holyweek';
}
