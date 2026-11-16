import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/models/parsed_reading.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';
import 'package:mybrev_flutter/utils/liturgical_psalter.dart';

const _romanDigits = <(int, String)>[
  (1000, 'M'),
  (900, 'CM'),
  (500, 'D'),
  (400, 'CD'),
  (100, 'C'),
  (90, 'XC'),
  (50, 'L'),
  (40, 'XL'),
  (10, 'X'),
  (9, 'IX'),
  (5, 'V'),
  (4, 'IV'),
  (1, 'I'),
];

const _liturgicalPlaceLabels = <String, String>{
  'grodno': 'Гродзенская дыяцэзія',
  'hrodna': 'Гродзенская дыяцэзія',
  'pinsk': 'Пінская дыяцэзія',
  'vitebsk': 'Віцебская дыяцэзія',
  'minsk-mohilev': 'Мінска-Магілёўская архідыяцэзія',
};

String toRomanNumeral(int? value) {
  if (value == null || value < 1) return '';
  var remaining = value;
  final result = StringBuffer();
  for (final (number, numeral) in _romanDigits) {
    while (remaining >= number) {
      result.write(numeral);
      remaining -= number;
    }
  }
  return result.toString();
}

bool isChristmasOctaveDate(DateTime date) =>
    (date.month == DateTime.december && date.day >= 25) ||
    (date.month == DateTime.january && date.day == 1);

String formatLiturgicalPeriodTitle({
  required String periodType,
  required int? periodWeek,
  required int? dayOfWeek,
  required DateTime date,
  bool useArabicWeekNumber = false,
}) {
  final dayName = weekdayLabelMap[dayOfWeek] ?? '';
  final week = periodWeek == null || periodWeek < 1
      ? ''
      : useArabicWeekNumber
      ? periodWeek.toString()
      : toRomanNumeral(periodWeek);

  if (periodType == 'christmas' && isChristmasOctaveDate(date)) {
    return '$dayName у Актаве Нараджэння Пана'.trim();
  }

  if (dayOfWeek == 1 && week.isNotEmpty) {
    final title = switch (periodType) {
      'ordinary' => '$week нядзеля звычайная',
      'advent' => '$week нядзеля Адвэнту',
      'lent' => '$week нядзеля Вялікага посту',
      'easter' => '$week велікодная нядзеля',
      'christmas' => '$week нядзеля пасля Нараджэння Пана',
      _ => '',
    };
    if (title.isNotEmpty) return title;
  }

  final periodName = periodType == 'holyweek'
      ? 'Вялікі тыдзень'
      : switch (periodType) {
          'ordinary' when week.isNotEmpty => '$week звычайны тыдзень',
          'advent' when week.isNotEmpty => '$week тыдзень Адвэнту',
          'lent' when week.isNotEmpty => '$week тыдзень Вялікага посту',
          'easter' when week.isNotEmpty => '$week велікодны тыдзень',
          'christmas' when week.isNotEmpty =>
            '$week тыдзень перыяду Божага Нараджэння',
          _ => periodLabelMap[periodType] ?? '',
        };
  final inlineDay = dayName.isEmpty
      ? ''
      : '${dayName[0].toLowerCase()}${dayName.substring(1)}';
  return [periodName, inlineDay].where((part) => part.isNotEmpty).join(', ');
}

/// Uses the same period/week/weekday title as the Liturgy of the Hours for a
/// lectionary document that carries liturgical coordinates.
String liturgicalReadingPeriodTitle(ParsedReading reading, DateTime date) {
  final periodType = reading.periodType ?? '';
  if (periodType.isEmpty) return '';
  return formatLiturgicalPeriodTitle(
    periodType: periodType,
    periodWeek: reading.periodWeekNumber,
    dayOfWeek: reading.dayOfWeek,
    date: date,
    useArabicWeekNumber: true,
  );
}

String liturgicalDayDisplayTitle(LiturgicalDay day, DateTime date) {
  final periodType = day.periodType ?? day.field('_periodType') ?? '';
  final periodWeek =
      day.periodWeekNumber ??
      int.tryParse(day.field('_periodWeekNumber') ?? '');
  final dayOfWeek =
      day.dayOfWeek ?? int.tryParse(day.field('_dayOfWeek') ?? '');
  final hasCelebration =
      (day.feast ?? '').trim().isNotEmpty ||
      (day.rank ?? '').trim().isNotEmpty ||
      (day.field('_feastType') ?? '').trim().isNotEmpty;
  final isOfficeForDead =
      day.field('_kind') == 'office-for-dead' || day.id == 'office-for-dead';
  if (isOfficeForDead) {
    return day.feastName ?? day.title ?? 'Афіцый за памерлых';
  }
  if (day.feast == 'feast-christking' ||
      day.field('_celebrationId') == 'christ-king' ||
      day.id == 'feast-christking') {
    return 'Пана нашага Езуса Хрыста, Валадара Сусвету';
  }

  final periodTitle = formatLiturgicalPeriodTitle(
    periodType: periodType,
    periodWeek: periodWeek,
    dayOfWeek: dayOfWeek,
    date: date,
  );
  final isChristmasDateDay =
      periodType == 'christmas' &&
      (isSeasonalDateDocumentId(day.id) || !hasCelebration);
  if ((periodType.isNotEmpty && !hasCelebration) || isChristmasDateDay) {
    return periodTitle;
  }
  return day.feastName ?? day.title ?? periodTitle;
}

String liturgicalDayPeriodLabel(LiturgicalDay day) {
  if (day.field('_kind') == 'office-for-dead' || day.id == 'office-for-dead') {
    return 'Афіцый за памерлых';
  }
  return periodLabelMap[day.periodType ?? day.field('_periodType')] ??
      'Літургічны дзень';
}

String liturgicalDayRankLabel(LiturgicalDay day) {
  if (day.field('_kind') == 'office-for-dead' || day.id == 'office-for-dead') {
    return '';
  }
  final rank =
      day.field('_celebrationRank') ??
      day.rank ??
      day.field('_feastType') ??
      '';
  return feastTypeLabelMap[rank] ?? rank;
}

List<String> liturgicalDayPlaces(LiturgicalDay day) {
  final raw = day.data['_place'];
  final values = raw is Iterable && raw is! String ? raw : [raw];
  final places = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final rawPlace = (value?.toString() ?? '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final place = _liturgicalPlaceLabels[rawPlace.toLowerCase()] ?? rawPlace;
    if (place.isEmpty || !seen.add(place.toLowerCase())) continue;
    places.add(place);
  }
  return places;
}

String liturgicalDayPlaceLabel(LiturgicalDay day) =>
    liturgicalDayPlaces(day).join(', ');

List<String> mergedLiturgicalDayPlaces(Iterable<LiturgicalDay> days) {
  final places = <String>[];
  final seen = <String>{};
  for (final day in days) {
    for (final place in liturgicalDayPlaces(day)) {
      if (seen.add(place.toLowerCase())) places.add(place);
    }
  }
  return places;
}

String liturgicalDayPsalterLabel(LiturgicalDay day, DateTime date) {
  // Proper festal psalmody is not the seasonal four-week psalter.
  final rank =
      day.field('_celebrationRank') ??
      day.rank ??
      day.field('_feastType') ??
      '';
  if (const {'solemnitas', 'festum', 'solemnity', 'feast'}.contains(rank) ||
      day.field('_kind') == 'office-for-dead' ||
      day.id == 'office-for-dead') {
    return '';
  }
  final periodType = day.periodType ?? day.field('_periodType') ?? '';
  final periodWeek =
      day.periodWeekNumber ??
      int.tryParse(day.field('_periodWeekNumber') ?? '');
  if (periodType.isEmpty || periodWeek == null) return '';
  final week = calculatePsalterWeek(
    date: date,
    periodType: periodType,
    periodWeek: periodWeek,
  );
  final numeral = toRomanNumeral(week);
  return numeral.isEmpty ? '' : '$numeral тыдзень Псалтыра';
}
