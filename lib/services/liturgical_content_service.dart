import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/services/days_index.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';
import 'package:mybrev_flutter/utils/liturgical_psalter.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';
import 'package:mybrev_flutter/utils/office_assembly.dart';

/// Option titles are one-line labels: `<br>` and line breaks in the source
/// title become plain spaces so the list wraps naturally.
String _stripHtml(String value) => value
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
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

    final dated = exclusiveFeast == null
        ? _daysByDate(date)
              .where(
                (day) =>
                    day.id != seasonalId && !isSeasonalDateDocumentId(day.id),
              )
              .toList()
        : <LiturgicalDay>[];
    // A sparse document replaces its former per-template copies.
    final sparseDocs = dated.where(isSparseDay).toList();
    final replaced = {for (final doc in sparseDocs) ..._legacyIdsOf(doc)};
    final fixed = <LiturgicalDay>[
      if (seasonal != null) contextual(seasonal),
      ...dated
          .where((day) => !isSparseDay(day) && !replaced.contains(day.id))
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

    for (final doc in sparseDocs) {
      final choices = assemblyChoices(doc.toMap(), officeKindOfRank(doc.rank));
      final variants = [
        for (final (index, choice) in choices.indexed)
          DayTemplate(
            id: assemblyDayId(doc.id, choice, isDefault: index == 0),
            label: choice == kCurrentDayChoice
                ? 'З дня'
                : _templateLabel(
                    LiturgicalDay.fromMap({
                      'id': doc.id,
                      '_currentVersion': choice,
                    }),
                  ),
            day: contextual(
              assembleSparseDay(date, doc, period, choice: choice).copyWithId(
                assemblyDayId(doc.id, choice, isDefault: index == 0),
              ),
            ),
          ),
      ];
      options.add(
        _option(
          source: LiturgicalOptionSource.fixed,
          title: _dayTitle(variants.first.day, date),
          subtitle: _rankLabel(variants.first.day),
          day: variants.first.day,
          order: 3,
          context: context,
          templates: variants,
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

  /// The selected day resolved against its period / psalter day from the
  /// device only — the synchronous counterpart of
  /// `LiturgicalDayService.resolveDayForDate`. Returns null when the date is
  /// not completely cached, so the caller falls back to the network path.
  LiturgicalDay? resolveDayLocal(
    DateTime date,
    String dayId,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates,
  ) {
    if (!HiveService.isDateCached('days', date)) return null;
    var selected = _dayById(dayId);
    String? choice;
    if (selected == null || selected.data['_obsolete'] == true) {
      final parsed = parseAssemblyDayId(dayId);
      final base = parsed == null ? null : _dayById(parsed.$1);
      if (!isSparseDay(base)) return null;
      selected = base;
      choice = parsed!.$2;
    }
    final context = computeLiturgicalContext(
      date,
      opts,
      nextYearOpts,
      dynamicDates,
    );
    final period = _resolvedPeriod(date, context);
    final seasonalId = seasonalDateExceptionId(date, context.periodType);
    LiturgicalDay? resolved;
    if (isSparseDay(selected)) {
      resolved = assembleSparseDay(
        date,
        selected!,
        period,
        choice: choice,
      ).copyWithId(dayId);
    } else if (seasonalId == dayId) {
      resolved = context.periodType == 'christmas'
          ? resolveChristmasDateAgainstPeriod(selected, period)
          : resolveDayAgainstPeriod(selected, period, fillMissing: true);
      resolved = applySeasonalWeekdayAntiphons(resolved!, context.dayOfWeek);
    } else if (selected!.date != null && selected.date!.isNotEmpty) {
      resolved = resolveDayAgainstPeriod(selected, period, fillMissing: true);
    } else {
      resolved = resolveDayAgainstPeriod(selected, period);
    }
    final data = resolved!.toMap()
      ..['_periodType'] = context.periodType
      ..['_periodWeekNumber'] = context.periodWeek
      ..['_dayOfWeek'] = context.dayOfWeek
      ..['_calendarDate'] = _isoDate(date)
      ..['_contextPeriodType'] = context.periodType;
    return LiturgicalDay.fromMap(data);
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
    day ??= _dayById(
      DaysIndex.idByPeriod(
            context.periodType,
            context.periodWeek,
            context.dayOfWeek,
          ) ??
          '',
    );
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

  LiturgicalDay? _dayById(String id) {
    if (id.isEmpty) return null;
    final raw = HiveService.daysBox.get(id);
    return raw is Map
        ? LiturgicalDay.fromMap(Map<String, dynamic>.from(raw))
        : null;
  }

  List<LiturgicalDay> _daysByFeast(String code) {
    final variants = {_normalizeFeast(code), 'feast-${_normalizeFeast(code)}'};
    return _daysByIds(DaysIndex.idsByFeast(variants));
  }

  List<LiturgicalDay> _daysByDate(DateTime date) {
    final variants = {
      '${date.day}.${date.month}',
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}',
    };
    return _daysByIds(DaysIndex.idsByDate(variants));
  }

  // Only the documents the index names are deserialized.
  List<LiturgicalDay> _daysByIds(Iterable<String> ids) => [
    for (final id in {...ids}) ?_dayById(id),
  ];
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

List<String> _legacyIdsOf(LiturgicalDay day) {
  final raw = day.data['_legacyIds'];
  return raw is List ? raw.map((id) => id.toString()).toList() : const [];
}

/// A sparse feast document assembled for [date] (Commons from the device,
/// the current day as [period]). Missing Commons fall back to the day.
LiturgicalDay assembleSparseDay(
  DateTime date,
  LiturgicalDay doc,
  LiturgicalDay? period, {
  String? choice,
}) {
  final assembly = assembleOffice(
    proper: {...doc.toMap(), 'id': doc.id},
    currentDay: period?.toMap() ?? const {},
    templates: HiveService.isCacheReady ? HiveService.templates() : const {},
    isSunday: date.weekday == DateTime.sunday,
    choice: choice,
  );
  return LiturgicalDay.fromMap({...assembly.data, 'id': doc.id});
}

extension on LiturgicalDay {
  LiturgicalDay copyWithId(String id) =>
      LiturgicalDay.fromMap({...toMap(), 'id': id});
}
