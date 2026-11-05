import 'package:mybrev_flutter/models/day.dart';

const _identityFields = <String>{
  'id',
  '_date',
  '_feast',
  '_feastName',
  '_rank',
  '_place',
  '_templates',
  '_currentVersion',
  '_periodType',
  '_periodWeekNumber',
  '_dayOfWeek',
  '_fromDayFields',
};

const _daytimeSuffixes = <String>[
  'Hymn',
  'Ant1',
  'Ant2',
  'Ant3',
  'Ps1',
  'Ps2',
  'Ps3',
  'R',
  'Pr',
];

bool isFromDayReference(dynamic value) {
  final normalized = (value?.toString() ?? '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'^\[|\]$'), '')
      .trim();
  return normalized == 'from-day';
}

bool _missing(dynamic value) =>
    value == null || (value is String && value.trim().isEmpty);

String periodDayDocumentId(String periodType, int week, int day) {
  final period = periodType.trim();
  if (period.isEmpty || week < 0 || day < 1 || day > 7) return '';
  return '$period-w$week-d$day';
}

String periodPsalterDayDocumentId(String periodType, int week, int day) {
  if (week < 1) return '';
  return periodDayDocumentId(periodType, (week - 1) % 4 + 1, day);
}

String ordinaryPsalterDayDocumentId(int week, int day) {
  if (week < 1 || day < 1 || day > 7) return '';
  final psalterWeek = (week - 1) % 4 + 1;
  final sourceWeek = psalterWeek == 1 && day == 1 ? 5 : psalterWeek;
  return periodDayDocumentId('ordinary', sourceWeek, day);
}

bool isSeasonalDateDocumentId(String? id) =>
    RegExp(r'^(?:advent|christmas)-\d{2}-\d{2}$').hasMatch(id ?? '');

String _ddmm(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';

bool isChristmasDateExceptionExclusion(DateTime date) => const {
  '25.12',
  '26.12',
  '27.12',
  '28.12',
  '01.01',
  '06.01',
}.contains(_ddmm(date));

bool isSeasonalDateException(DateTime date, [String? periodType]) {
  final advent = date.month == 12 && date.day >= 17 && date.day <= 24;
  final christmas =
      (date.month == 12 && date.day >= 25) ||
      (date.month == 1 && date.day <= 12);
  return (advent && (periodType == null || periodType == 'advent')) ||
      (christmas &&
          (periodType == null || periodType == 'christmas') &&
          !isChristmasDateExceptionExclusion(date));
}

String? seasonalDateExceptionId(DateTime date, [String? periodType]) {
  if (!isSeasonalDateException(date, periodType)) return null;
  final prefix = date.month == 12 && date.day <= 24 ? 'advent' : 'christmas';
  return '$prefix-${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}';
}

Set<String> _singleAntiphonExclusions(Map<String, dynamic> day) {
  final excluded = <String>{};
  final prefixes = <String>{};
  for (final field in day.keys) {
    final match = RegExp(r'^(.*)Ant[123]$').firstMatch(field);
    if (match != null) prefixes.add(match.group(1)!);
  }
  for (final prefix in prefixes) {
    final first = day['${prefix}Ant1'];
    final second = day['${prefix}Ant2'];
    final third = day['${prefix}Ant3'];
    bool absent(dynamic value) => _missing(value) || isFromDayReference(value);
    if (!absent(first) && absent(second) && absent(third)) {
      excluded.addAll(['${prefix}Ant2', '${prefix}Ant3']);
    }
  }
  if (excluded.containsAll(['sext1Ant2', 'sext1Ant3'])) {
    for (final hour in [2, 3]) {
      final fields = [1, 2, 3].map((i) => 'sext${hour}Ant$i').toList();
      if (fields.every(
        (field) => _missing(day[field]) || isFromDayReference(day[field]),
      )) {
        excluded.addAll(fields);
      }
    }
  }
  return excluded;
}

LiturgicalDay? resolveDayAgainstPeriod(
  LiturgicalDay? day,
  LiturgicalDay? periodDay, {
  bool fillMissing = false,
  bool fillMissingDaytime = false,
}) {
  if (day == null && periodDay == null) return null;
  final dayData = day?.toMap() ?? <String, dynamic>{};
  final periodData = periodDay?.toMap() ?? <String, dynamic>{};
  final resolved = <String, dynamic>{...periodData, ...dayData};
  final fromFields = <String>{};
  final explicit = dayData['_fromDayFields'];
  if (explicit is List) fromFields.addAll(explicit.map((e) => e.toString()));
  for (final entry in dayData.entries) {
    if (isFromDayReference(entry.value)) fromFields.add(entry.key);
  }
  // A stale inheritance list must not erase a supplied feast Proper. Remove
  // it here as well as from the assembled result, which may be resolved again.
  if (fillMissingDaytime) {
    fromFields.removeWhere(
      (field) =>
          _isDaytimeField(field) &&
          !_missing(dayData[field]) &&
          !isFromDayReference(dayData[field]),
    );
  }
  final exclusions = fillMissing || fillMissingDaytime
      ? _singleAntiphonExclusions(
          dayData,
        ).where((field) => fillMissing || _isDaytimeField(field)).toSet()
      : const <String>{};
  final keys = <String>{...periodData.keys, ...dayData.keys, ...fromFields};
  for (final field in keys) {
    final value = dayData[field];
    if (exclusions.contains(field)) {
      resolved[field] = '';
      fromFields.remove(field);
    } else if (fromFields.contains(field)) {
      final fallback = _identityFields.contains(field) ? '' : periodData[field];
      resolved[field] = isFromDayReference(fallback) ? '' : fallback ?? '';
    } else if (!_identityFields.contains(field) &&
        (fillMissing || (fillMissingDaytime && _isDaytimeField(field))) &&
        _missing(value)) {
      // Sext/None can share a supplied Terce field. Leave that fallback to
      // daytimeHourField instead of masking it with weekday content.
      final shared = fillMissingDaytime && !fillMissing
          ? RegExp(r'^sext[23](.+)$').firstMatch(field)
          : null;
      final fromTerce = shared == null
          ? null
          : dayData['sext1${shared.group(1)}'];
      final useProperTerce =
          !_missing(fromTerce) && !isFromDayReference(fromTerce);
      final suffix = RegExp(r'^sext[123](.+)$').firstMatch(field)?.group(1);
      if (fillMissingDaytime && !fillMissing && suffix == 'R') {
        // Feast readings are proper; missing source content needs correction.
        resolved[field] = '';
        continue;
      }
      if (fillMissingDaytime && !fillMissing && suffix == 'Pr') {
        final collect = dayData['laudesPr'];
        resolved[field] =
            !useProperTerce &&
                !_missing(collect) &&
                !isFromDayReference(collect)
            ? collect
            : '';
        continue;
      }
      final fallback = useProperTerce ? '' : periodData[field];
      resolved[field] = isFromDayReference(fallback) ? '' : fallback ?? '';
    }
  }
  for (final field in resolved.keys.toList()) {
    if (isFromDayReference(resolved[field])) resolved[field] = '';
  }
  if (fromFields.isEmpty) {
    resolved.remove('_fromDayFields');
  } else {
    resolved['_fromDayFields'] = fromFields.toList();
  }
  return LiturgicalDay.fromMap(resolved);
}

bool _isDaytimeField(String field) {
  final match = RegExp(r'^sext[123](.+)$').firstMatch(field);
  return match != null && _daytimeSuffixes.contains(match.group(1));
}

/// Movable feasts use the current day's daytime psalter. Solemnities retain
/// their existing resolution; this mode never fills gaps in the other Hours.
LiturgicalDay resolveMovableFeastAgainstPeriod(
  LiturgicalDay day,
  LiturgicalDay? periodDay,
  String feastCode,
) {
  final declaredRank = (day.rank ?? '').trim();
  final rank =
      (declaredRank.isEmpty ? day.field('_feastType') ?? '' : declaredRank)
          .trim()
          .toLowerCase();
  final isFeast =
      const {'festum', 'feast'}.contains(rank) ||
      (rank.isEmpty &&
          feastCode.replaceFirst(RegExp(r'^feast-'), '') ==
              'christthehighpriest');
  return resolveDayAgainstPeriod(day, periodDay, fillMissingDaytime: isFeast)!;
}

LiturgicalDay? resolveChristmasDateAgainstPeriod(
  LiturgicalDay? dateDay,
  LiturgicalDay? periodDay,
) {
  if (periodDay?.id == 'christmas-w2-d1') {
    return resolveDayAgainstPeriod(periodDay, dateDay, fillMissing: true);
  }
  return resolveDayAgainstPeriod(dateDay, periodDay, fillMissing: true);
}

LiturgicalDay? resolvePeriodDayAgainstPsalter(
  LiturgicalDay? day,
  LiturgicalDay? psalterDay,
) {
  if (day == null || psalterDay == null) return day;
  final resolved = day.toMap();
  for (final hour in [1, 2, 3]) {
    for (final suffix in _daytimeSuffixes) {
      final field = 'sext$hour$suffix';
      if (!_missing(resolved[field]) && !isFromDayReference(resolved[field])) {
        continue;
      }
      final fallback = psalterDay.data[field];
      resolved[field] = _missing(fallback) || isFromDayReference(fallback)
          ? ''
          : fallback;
    }
  }
  return LiturgicalDay.fromMap(resolved);
}

bool hasMissingDaytimeFields(LiturgicalDay day) {
  for (final hour in [1, 2, 3]) {
    for (final suffix in _daytimeSuffixes) {
      final value = day.data['sext$hour$suffix'];
      if (_missing(value) || isFromDayReference(value)) return true;
    }
  }
  return false;
}

String daytimeHourField(LiturgicalDay day, int hour, String suffix) {
  // An hour with one own antiphon must not borrow Ant2/Ant3 from Terce.
  if ((suffix == 'Ant2' || suffix == 'Ant3') &&
      _singleAntiphonExclusions(day.data).contains('sext$hour$suffix')) {
    return '';
  }
  final value = day.data['sext$hour$suffix'];
  if (!_missing(value) && !isFromDayReference(value)) {
    return value.toString().trim();
  }
  final fallback = day.data['sext1$suffix'];
  return _missing(fallback) || isFromDayReference(fallback)
      ? ''
      : fallback.toString().trim();
}

LiturgicalDay applySeasonalWeekdayAntiphons(LiturgicalDay day, int dayOfWeek) {
  const weekdayFields = {
    1: 'sunday',
    2: 'monday',
    3: 'tuesday',
    4: 'wednesday',
    5: 'thursday',
    6: 'friday',
    7: 'saturday',
  };
  final html = day.field(weekdayFields[dayOfWeek] ?? '') ?? '';
  final antiphons = RegExp(
    r'<p(?:\s[^>]*)?>[\s\S]*?<\/p>',
    caseSensitive: false,
  ).allMatches(html).take(3).map((match) => match.group(0)!).toList();
  if (antiphons.length < 3) return day;
  final data = day.toMap();
  for (final office in ['laudes', 'vesper']) {
    for (var i = 0; i < 3; i++) {
      data['${office}Ant${i + 1}'] = antiphons[i];
    }
  }
  return LiturgicalDay.fromMap(data);
}
