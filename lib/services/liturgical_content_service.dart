import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';
import 'package:mybrev_flutter/utils/liturgical_psalter.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';

String _stripHtml(String value) => value
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .trim();

class DayTemplate {
  final String id;
  final String label;
  final LiturgicalDay day;

  const DayTemplate({required this.id, required this.label, required this.day});
}

class DayOption {
  final LiturgicalOptionSource source;
  final String title;
  final String? subtitle;
  final String? placeLabel;
  final LiturgicalDay? day;
  final int order;
  final bool disabled;
  final String key;
  final List<DayTemplate> templates;
  final String contextPeriodType;

  const DayOption({
    required this.source,
    required this.title,
    required this.key,
    required this.contextPeriodType,
    this.subtitle,
    this.placeLabel,
    this.day,
    this.order = 0,
    this.disabled = false,
    this.templates = const [],
  });

  String? get dayId => day?.id;
  bool get hasLiturgicalDay => day != null;
  String? get displaySubtitle {
    final value = [
      subtitle,
      placeLabel,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · ');
    return value.isEmpty ? null : value;
  }
}

class LiturgicalContentService {
  /// Assemble the date from Hive only. Network reads happen in warmup and the
  /// result becomes available atomically via cacheEpochProvider.
  List<DayOption> getContentForDate(
    DateTime date,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates,
  ) {
    final context = computeLiturgicalContext(
      date,
      opts,
      nextYearOpts,
      dynamicDates,
    );
    final feastCodes = getDynamicFeastCodesForDate(date, dynamicDates);
    final period = _resolvedPeriod(date, context);
    final exclusiveFeast = feastCodes
        .map(_normalizeFeast)
        .where((code) => code == 'holyfamily' || code == 'buptismofthelord')
        .firstOrNull;
    final fixedDateExclusive = isChristmasDateExceptionExclusion(date);
    final seasonalId = seasonalDateExceptionId(date, context.periodType);
    final seasonalRaw = seasonalId == null ? null : _dayById(seasonalId);
    final seasonal = seasonalRaw == null
        ? null
        : applySeasonalWeekdayAntiphons(
            (context.periodType == 'christmas'
                ? resolveChristmasDateAgainstPeriod(seasonalRaw, period)
                : resolveDayAgainstPeriod(
                    seasonalRaw,
                    period,
                    fillMissing: true,
                  ))!,
            context.dayOfWeek,
          );

    LiturgicalDay contextual(LiturgicalDay day) {
      final data = day.toMap()
        ..['_periodType'] = context.periodType
        ..['_periodWeekNumber'] = context.periodWeek
        ..['_dayOfWeek'] = context.dayOfWeek
        ..['_contextPeriodType'] = context.periodType
        ..['_calendarDate'] = _isoDate(date);
      return LiturgicalDay.fromMap(data);
    }

    final options = <DayOption>[];
    if (period != null &&
        exclusiveFeast == null &&
        !fixedDateExclusive &&
        seasonal == null) {
      final day = contextual(period);
      options.add(
        _option(
          source: LiturgicalOptionSource.period,
          title: _periodTitle(context, date),
          subtitle: 'Літургічны дзень',
          day: day,
          order: 1,
          context: context,
        ),
      );
    }

    for (final code in feastCodes) {
      if (exclusiveFeast != null && _normalizeFeast(code) != exclusiveFeast) {
        continue;
      }
      for (final raw in _daysByFeast(code)) {
        final day = contextual(resolveDayAgainstPeriod(raw, period)!);
        options.add(
          _option(
            source: LiturgicalOptionSource.dynamic,
            title: _dayTitle(day, date),
            subtitle: 'Свята',
            day: day,
            order: 2,
            context: context,
          ),
        );
      }
    }

    final fixed = <LiturgicalDay>[
      if (seasonal != null) contextual(seasonal),
      if (exclusiveFeast == null)
        ..._daysByDate(date)
            .where(
              (day) =>
                  day.id != seasonalId && !isSeasonalDateDocumentId(day.id),
            )
            .map(
              (day) => contextual(
                resolveDayAgainstPeriod(day, period, fillMissing: true)!,
              ),
            ),
    ];
    final fixedGroups = <String, List<LiturgicalDay>>{};
    for (final day in fixed) {
      fixedGroups.putIfAbsent(_fixedKey(day), () => []).add(day);
    }
    for (final variants in fixedGroups.values) {
      final places = mergedLiturgicalDayPlaces(variants);
      LiturgicalDay withGroupPlaces(LiturgicalDay value) {
        if (places.isEmpty) return value;
        return LiturgicalDay.fromMap(value.toMap()..['_place'] = places);
      }

      final day = withGroupPlaces(variants.first);
      final templateGroups = <String, List<LiturgicalDay>>{};
      for (final variant in variants) {
        templateGroups
            .putIfAbsent(_templateKey(variant), () => [])
            .add(variant);
      }
      final templates = templateGroups.values.map((group) {
        final templateDay = withGroupPlaces(group.first);
        return DayTemplate(
          id: templateDay.id,
          label: _templateLabel(templateDay),
          day: templateDay,
        );
      }).toList();
      options.add(
        _option(
          source: LiturgicalOptionSource.fixed,
          title: _dayTitle(day, date),
          subtitle: _rankLabel(day),
          day: day,
          order: 3,
          context: context,
          templates: templates,
        ),
      );
    }

    final deadRaw = _dayById('office-for-dead');
    if (deadRaw != null) {
      final day = contextual(resolveDayAgainstPeriod(deadRaw, period)!);
      options.add(
        _option(
          source: LiturgicalOptionSource.officeForDead,
          title: day.feastName ?? day.title ?? 'Афіцый за памерлых',
          subtitle: 'Памінальны афіцый',
          day: day,
          order: 99,
          context: context,
        ),
      );
    }

    options.sort((left, right) {
      final priority = _celebrationPriority(
        left.day,
      ).compareTo(_celebrationPriority(right.day));
      return priority != 0 ? priority : left.order.compareTo(right.order);
    });
    return options;
  }

  DayOption _option({
    required LiturgicalOptionSource source,
    required String title,
    required String subtitle,
    required LiturgicalDay day,
    required int order,
    required LiturgicalContext context,
    List<DayTemplate>? templates,
  }) => DayOption(
    source: source,
    title: _stripHtml(title),
    subtitle: subtitle,
    placeLabel: liturgicalDayPlaceLabel(day),
    day: day,
    key: '${source.name}-${day.id}',
    order: order,
    templates:
        templates ?? [DayTemplate(id: day.id, label: 'Асноўны', day: day)],
    contextPeriodType: context.periodType,
  );

  LiturgicalDay? _resolvedPeriod(DateTime date, LiturgicalContext context) {
    var day = _dayById(
      periodDayDocumentId(
        context.periodType,
        context.periodWeek,
        context.dayOfWeek,
      ),
    );
    day ??= _allDays().where((candidate) {
      final noFeast = (candidate.feast ?? '').trim().isEmpty;
      return noFeast &&
          candidate.periodType == context.periodType &&
          candidate.periodWeekNumber == context.periodWeek &&
          candidate.dayOfWeek == context.dayOfWeek;
    }).firstOrNull;
    if (day == null && context.periodType == 'christmas') {
      final psalterWeek = calculatePsalterWeek(
        date: date,
        periodType: context.periodType,
        periodWeek: context.periodWeek,
      );
      if (psalterWeek != null) {
        day = _dayById(
          periodDayDocumentId('advent', psalterWeek, context.dayOfWeek),
        );
      }
    }
    if (day == null) return null;
    var resolved = resolveDayAgainstPeriod(day, null)!;
    if (context.periodType == 'christmas') return resolved;
    if (context.periodType != 'advent' && !hasMissingDaytimeFields(resolved)) {
      return resolved;
    }
    final fallbackId = context.periodType == 'ordinary'
        ? periodPsalterDayDocumentId(
            context.periodType,
            context.periodWeek,
            context.dayOfWeek,
          )
        : ordinaryPsalterDayDocumentId(context.periodWeek, context.dayOfWeek);
    final fallback = _dayById(fallbackId);
    if (fallback == null || fallback.id == resolved.id) return resolved;
    resolved = context.periodType == 'advent'
        ? resolveDayAgainstPeriod(resolved, fallback, fillMissing: true)!
        : resolvePeriodDayAgainstPsalter(resolved, fallback)!;
    return resolved;
  }

  Iterable<LiturgicalDay> _allDays() sync* {
    for (final key in HiveService.daysBox.keys) {
      final raw = HiveService.daysBox.get(key);
      if (raw is Map) {
        yield LiturgicalDay.fromMap(Map<String, dynamic>.from(raw));
      }
    }
  }

  LiturgicalDay? _dayById(String id) {
    if (id.isEmpty) return null;
    final raw = HiveService.daysBox.get(id);
    return raw is Map
        ? LiturgicalDay.fromMap(Map<String, dynamic>.from(raw))
        : null;
  }

  List<LiturgicalDay> _daysByFeast(String code) {
    final variants = {_normalizeFeast(code), 'feast-${_normalizeFeast(code)}'};
    return _allDays().where((day) => variants.contains(day.feast)).toList();
  }

  List<LiturgicalDay> _daysByDate(DateTime date) {
    final variants = {
      '${date.day}.${date.month}',
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}',
    };
    return _allDays().where((day) => variants.contains(day.date)).toList();
  }
}

String _periodTitle(LiturgicalContext context, DateTime date) =>
    formatLiturgicalPeriodTitle(
      periodType: context.periodType,
      periodWeek: context.periodWeek,
      dayOfWeek: context.dayOfWeek,
      date: date,
    );

String _dayTitle(LiturgicalDay day, DateTime date) =>
    liturgicalDayDisplayTitle(day, date);

String _rankLabel(LiturgicalDay day) {
  final rank = day.rank ?? day.field('_feastType') ?? '';
  return feastTypeLabelMap[rank] ?? 'Літургічны дзень';
}

int _celebrationPriority(LiturgicalDay? day) {
  final rank = (day?.rank ?? day?.field('_feastType') ?? '').toLowerCase();
  if (const {
    'solemnitas',
    'solemnity',
    'урачыстасць',
    'ўрачыстасць',
  }.contains(rank)) {
    return 0;
  }
  if (const {'festum', 'feast', 'свята'}.contains(rank)) return 1;
  return 2;
}

String _normalizeFeast(String value) =>
    value.replaceFirst(RegExp(r'^feast-'), '');

String _isoDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _fixedKey(LiturgicalDay day) => [
  day.date ?? '',
  (day.feastName ?? day.title ?? '').trim().toLowerCase(),
  (day.rank ?? day.field('_feastType') ?? '').trim().toLowerCase(),
].join('|');

String _templateKey(LiturgicalDay day) {
  final current = (day.field('_currentVersion') ?? '').trim();
  if (current.isNotEmpty) return 'template:$current';
  final raw = day.data['_templates'];
  if (raw is List) {
    final values =
        raw
            .map((item) => item.toString().trim())
            .where((v) => v.isNotEmpty)
            .toList()
          ..sort();
    if (values.length == 1) return 'template:${values.first}';
    if (values.isNotEmpty) return 'templates:${values.join('|')}';
  }
  return 'document:${day.id}';
}

String _templateLabel(LiturgicalDay day) {
  final raw = day.data['_templates'];
  final key = (day.field('_currentVersion') ?? '').trim().isNotEmpty
      ? day.field('_currentVersion')!.trim()
      : raw is List && raw.length == 1
      ? raw.first.toString()
      : day.id.split('--').last;
  return const {
        'apostles': 'Апосталы',
        'blessed-virgin-mary': 'Пра Найсвяцейшую Панну Марыю',
        'church-dedication': 'Пра пасвячэнне касцёла',
        'doctors-of-church': 'Пра доктараў Касцёла',
        'educators': 'Пра выхавацеляў',
        'holy-men': 'Пра святых мужчынаў',
        'holy-women': 'Пра святых жанчынаў',
        'martyr-one': 'Пра аднаго мучаніка',
        'martyrs-many': 'Пра некалькіх мучанікаў',
        'pastors': 'Пра пастыраў',
        'religious': 'Пра законнікаў',
        'virgins': 'Пра паннаў',
        'works-of-mercy': 'Пра справы міласэрнасці',
      }[key] ??
      (key.isEmpty ? 'Асноўны' : key);
}
