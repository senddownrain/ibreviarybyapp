import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/models/year_options.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/engine.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/ordo/season.dart';
import 'package:mybrev_flutter/services/days_index.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
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

/// One legal assembly of an option (a Common, «З дня», the document).
class DayTemplate {
  final String id;
  final String label;
  final LiturgicalDay day;

  /// `current-day` or a Common template id (sparse Propers).
  final String? choice;

  /// Other ids that open this assembly (former per-template copies,
  /// diocesan copies of the same text).
  final List<String> dayIds;

  const DayTemplate({
    required this.id,
    required this.label,
    required this.day,
    this.choice,
    this.dayIds = const [],
  });

  bool answers(String dayId) => id == dayId || dayIds.contains(dayId);
}

/// Where the Office of a fixed celebration came from.
abstract final class ProperSource {
  static const properTexts = 'liturgicalProperTexts';
  static const legacyDays = 'legacy-days';
  static const none = 'none';
}

/// One legal Office of the date: a card on the Hours root.
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

  /// The engine's descriptor of this option (null: the votive Office for
  /// the Dead offered besides the legal options).
  final OrdoOptionDescriptor? ordo;

  /// `liturgicalProperTexts`, `legacy-days` or `none` (fixed celebrations).
  final String? properSource;

  /// The celebration has no own document: assembled from Common / the day.
  final bool missingProper;

  /// Selected dioceses that have this option (Settings with several).
  final List<String> dioceses;

  /// Diocesan badges (empty when every selected diocese has it).
  final List<String> badges;

  /// The diocese the option is opened in.
  final String? contextDiocese;

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
    this.ordo,
    this.properSource,
    this.missingProper = false,
    this.dioceses = const [],
    this.badges = const [],
    this.contextDiocese,
  });

  String? get dayId => day?.id;
  bool get hasLiturgicalDay => day != null;

  /// Canonical identity: the engine option id (or `office-for-dead`).
  String get optionId => ordo?.optionId ?? key;

  String? get displaySubtitle {
    final value = [
      subtitle,
      placeLabel,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · ');
    return value.isEmpty ? null : value;
  }

  bool ownsDayId(String dayId) =>
      this.dayId == dayId || templates.any((item) => item.answers(dayId));

  DayOption copyWith({
    String? key,
    LiturgicalDay? day,
    List<String>? dioceses,
    List<String>? badges,
    String? contextDiocese,
  }) => DayOption(
    source: source,
    title: title,
    key: key ?? this.key,
    contextPeriodType: contextPeriodType,
    subtitle: subtitle,
    placeLabel: placeLabel,
    day: day ?? this.day,
    order: order,
    disabled: disabled,
    templates: templates,
    ordo: ordo,
    properSource: properSource,
    missingProper: missingProper,
    dioceses: dioceses ?? this.dioceses,
    badges: badges ?? this.badges,
    contextDiocese: contextDiocese ?? this.contextDiocese,
  );
}

/// A legal option the device has no Office for (reported, never hidden
/// silently: the Ordo still shows the celebration).
class UnavailableOption {
  const UnavailableOption(this.id, this.title, {this.assembled = false});
  final String id;
  final String title;

  /// Assembled anyway (Common / the day) — only its own document is missing.
  final bool assembled;
}

/// Everything the Hours show for one date and one diocese.
class LiturgicalDayContent {
  const LiturgicalDayContent({
    required this.ordo,
    required this.options,
    required this.unavailable,
    required this.itemsDays,
  });

  final OrdoDay ordo;
  final List<DayOption> options;
  final List<UnavailableOption> unavailable;

  /// Every document of the date addressable by a route id (legacy links).
  final Map<String, LiturgicalDay> itemsDays;

  DayOption? optionOwning(String dayId) =>
      options.where((option) => option.ownsDayId(dayId)).firstOrNull;

  /// The document a route id opens: the option's resolved assembly first,
  /// then any document of the date.
  LiturgicalDay? dayById(String dayId) {
    for (final option in options) {
      for (final template in option.templates) {
        if (template.answers(dayId)) {
          return template.id == dayId
              ? template.day
              : LiturgicalDay.fromMap({...template.day.toMap(), 'id': dayId});
        }
      }
      if (option.dayId == dayId) return option.day;
    }
    return itemsDays[dayId];
  }
}

const kCurrentDayLabel = 'З дня';

const _templateLabels = {
  'apostles': 'Апосталы',
  'blessed-virgin-mary': 'Пра Найсвяцейшую Панну Марыю',
  'church-dedication': 'Пра пасвячэнне касцёла',
  'doctors-of-church': 'Пра доктараў касцёла',
  'educators': 'Пра выхавацеляў',
  'current-day': kCurrentDayLabel,
  'holy-men': 'Пра святых мужчынаў',
  'holy-women': 'Пра святых жанчынаў',
  'martyr-one': 'Пра аднаго мучаніка',
  'martyrs-many': 'Пра некалькіх мучанікаў',
  'office-for-dead': 'За памерлых',
  'pastors': 'Пра пастыраў',
  'religious': 'Пра законнікаў',
  'virgins': 'Пра паннаў',
  'works-of-mercy': 'Пра справы міласэрнасці',
};

/// Label of a Common (`pastors` → «Пра пастыраў»).
String dayTemplateLabel(String? value) {
  final key = (value ?? '').trim().toLowerCase();
  return _templateLabels[key] ?? ((value ?? '').isEmpty ? 'Асноўны' : value!);
}

const _placeLabels = {
  'grodno': 'Гродзенская дыяцэзія',
  'vitebsk': 'Віцебская дыяцэзія',
  'pinsk': 'Пінская дыяцэзія',
  'minsk-mohilev': 'Мінска-Магілёўская архідыяцэзія',
};

const kRankLabels = {
  'solemnitas': 'Урачыстасць',
  'festum': 'Свята',
  'memoria': 'Успамін',
  'memoria-ad-libitum': 'Неабавязковы ўспамін',
  'commemoratio-defunctorum': 'Успамін усіх памерлых вернікаў',
  'solemnity': 'Урачыстасць',
  'feast': 'Свята',
  'memorial': 'Успамін',
};

class LiturgicalContentService {
  /// The Hours of [date] for one diocese, built from the engine's legal
  /// options (port of mybrev `fetchContentForDate` + `buildOrdoDayOptions`):
  /// PRIMARY + LEGAL ALTERNATIVES are the only cards; Propers come from
  /// `liturgicalProperTexts`, legacy fixed `days` are a fallback.
  LiturgicalDayContent contentForDate(
    DateTime date, {
    String diocese = kDefaultDiocese,
    OrdoEngine? engine,
  }) {
    final ordo = (engine ?? OrdoRuntime.engine).resolve(
      isoOf(date),
      diocese: diocese,
    );
    return _build(date, ordo);
  }

  /// Day options of [date] (legacy entry point: the arguments of the former
  /// computed context are ignored — the engine is the only truth).
  List<DayOption> getContentForDate(
    DateTime date,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates, {
    String diocese = kDefaultDiocese,
  }) => contentForDate(date, diocese: diocese).options;

  /// The selected day of a route resolved from the device. Returns null
  /// while the content is still being decoded at launch.
  LiturgicalDay? resolveDayLocal(
    DateTime date,
    String dayId,
    YearOptions? opts,
    YearOptions? nextYearOpts,
    DynamicDates? dynamicDates, {
    String diocese = kDefaultDiocese,
  }) {
    if (!HiveService.content.isLoaded('days')) return null;
    final content = contentForDate(date, diocese: diocese);
    final day = content.dayById(dayId) ?? _legacyDay(date, dayId, content);
    if (day == null) return null;
    final data = day.toMap()
      ..['_periodType'] = content.ordo.period
      ..['_periodWeekNumber'] = content.ordo.week
      ..['_dayOfWeek'] = content.ordo.dayOfWeek
      ..['_calendarDate'] = isoOf(date)
      ..['_contextPeriodType'] = content.ordo.period;
    return LiturgicalDay.fromMap(data);
  }

  /// A document id the legal options do not name (an old link to a former
  /// per-template copy): resolved against the day as before.
  LiturgicalDay? _legacyDay(
    DateTime date,
    String dayId,
    LiturgicalDayContent content,
  ) {
    final raw = _dayById(dayId) ?? _properById(dayId);
    if (raw == null) return null;
    final period = _findDayByPeriod(
      date,
      content.ordo.period,
      content.ordo.week,
      content.ordo.dayOfWeek,
    );
    if (raw.date != null && raw.date!.isNotEmpty) {
      return resolveDayAgainstPeriod(raw, period, fillMissing: true);
    }
    return resolveDayAgainstPeriod(raw, period);
  }

  // ── documents of a date (port of fetchDaysForDate / assembleDaysResult) ──

  LiturgicalDayContent _build(DateTime date, OrdoDay ordo) {
    final civilKey = fixedDateKey(ordo.date);
    final feastCodes = {
      for (final option in ordo.options) ?option.feastCode,
    }.toList();
    final extraFixedDates = {
      for (final option in [...ordo.options, ...ordo.commemorations])
        if (option.daysRef?['_date'] case final String value
            when value != civilKey)
          value,
    }.toList();
    final result = _daysResult(date, ordo, feastCodes, extraFixedDates);
    final templates = HiveService.content.isLoaded('liturgicalTemplates')
        ? HiveService.templates()
        : const <String, Map<String, dynamic>>{};
    return _buildOptions(date, ordo, result, templates);
  }

  _DaysResult _daysResult(
    DateTime date,
    OrdoDay ordo,
    List<String> feastCodes,
    List<String> extraFixedDates,
  ) {
    final period = ordo.period;
    final week = ordo.week;
    final dayOfWeek = ordo.dayOfWeek;
    final exclusive = feastCodes
        .map(_normalizeFeast)
        .where((code) => code == 'holyfamily' || code == 'buptismofthelord')
        .firstOrNull;
    final exclusiveFixedDate = isChristmasDateExceptionExclusion(date);

    var periodDay = _findDayByPeriod(date, period, week, dayOfWeek);
    if (periodDay == null && period == 'christmas') {
      final psalterWeek = calculatePsalterWeek(
        date: date,
        periodType: 'christmas',
        periodWeek: week,
      );
      if (psalterWeek != null && psalterWeek > 0) {
        periodDay = _findDayByPeriod(date, 'advent', psalterWeek, dayOfWeek);
      }
    }
    final variants = _fixedDateVariants(date);
    final fixedDocs = exclusive == null
        ? _daysByDate(variants)
        : const <LiturgicalDay>[];
    final seasonalId = period == 'advent' || period == 'christmas'
        ? seasonalDateExceptionId(date, period) ?? _seasonalDateDocumentId(date)
        : null;
    final seasonalDay = exclusive != null || seasonalId == null
        ? null
        : _dayById(seasonalId);
    final extraFixedDocs = extraFixedDates.isEmpty
        ? const <LiturgicalDay>[]
        : _daysByDate(extraFixedDates);
    final officeForDead = _dayById('office-for-dead');
    final properDocs = exclusive == null
        ? _propersByDate({...variants, ...extraFixedDates})
        : const <LiturgicalDay>[];

    LiturgicalDay? withContext(
      LiturgicalDay? day, {
      String? periodType,
      int? periodWeek,
    }) {
      if (day == null) return null;
      return LiturgicalDay.fromMap({
        ...day.toMap(),
        '_periodType': periodType ?? period,
        '_periodWeekNumber': periodWeek ?? week,
        '_dayOfWeek': dayOfWeek,
      });
    }

    final resolvedPeriodDay = withContext(
      resolveDayAgainstPeriod(periodDay, null),
    );
    final hasSeasonalException =
        isSeasonalDateException(date, period) && seasonalDay != null;
    final seasonalDateDay =
        seasonalDay != null && !hasSeasonalException && exclusive == null
        ? withContext(
            resolveChristmasDateAgainstPeriod(seasonalDay, resolvedPeriodDay),
            periodType: 'christmas',
            periodWeek: week,
          )
        : null;
    final seasonalPeriodType = date.month == 12 && date.day <= 24
        ? 'advent'
        : 'christmas';
    final seasonal = hasSeasonalException
        ? applySeasonalWeekdayAntiphons(
            withContext(
              period == 'christmas'
                  ? resolveChristmasDateAgainstPeriod(
                      seasonalDay,
                      resolvedPeriodDay,
                    )
                  : resolveDayAgainstPeriod(
                      seasonalDay,
                      resolvedPeriodDay,
                      fillMissing: true,
                    ),
              periodType: seasonalPeriodType,
              periodWeek: week,
            )!,
            dayOfWeek,
          )
        : null;
    LiturgicalDay resolveFixed(LiturgicalDay item) => withContext(
      isSparseDay(item)
          ? item
          : resolveDayAgainstPeriod(item, resolvedPeriodDay, fillMissing: true),
    )!;
    final resolvedFixed = [
      ?seasonal,
      for (final item in fixedDocs)
        if (item.id != seasonalDay?.id && !isSeasonalDateDocumentId(item.id))
          resolveFixed(item),
    ];
    final rawDynamicDays = <String, List<LiturgicalDay>>{
      for (final code in feastCodes)
        if (exclusive == null || _normalizeFeast(code) == exclusive)
          code: _daysByFeast(code),
    };
    final dynamicDays = <String, List<LiturgicalDay>>{
      for (final entry in rawDynamicDays.entries)
        entry.key: [
            for (final item in entry.value)
              withContext(
                resolveMovableFeastAgainstPeriod(item, resolvedPeriodDay, entry.key),
              )!,
          ],
    };
    return _DaysResult(
      properDays: [
        for (final item in properDocs)
          if (isSparseDay(item)) withContext(item)!,
      ],
      extraFixedDays: [
        for (final item in extraFixedDocs)
          if (!isSeasonalDateDocumentId(item.id)) resolveFixed(item),
      ],
      periodDays:
          exclusive != null || exclusiveFixedDate || hasSeasonalException
          ? const []
          : [?resolvedPeriodDay],
      periodFallback: resolvedPeriodDay,
      fixedDateDays: exclusive == null ? resolvedFixed : const [],
      dynamicDaysByFeast: dynamicDays,
      rawDynamicDaysByFeast: rawDynamicDays,
      seasonalException: exclusive == null ? seasonal : null,
      seasonalDateDay: seasonalDateDay,
      officeForDead: officeForDead == null
          ? null
          : withContext(
              resolveDayAgainstPeriod(officeForDead, resolvedPeriodDay),
            ),
    );
  }

  LiturgicalDay? _findDayByPeriod(
    DateTime date,
    String period,
    int week,
    int dayOfWeek,
  ) {
    final day =
        _dayById(periodDayDocumentId(period, week, dayOfWeek)) ??
        _dayById(DaysIndex.idByPeriod(period, week, dayOfWeek) ?? '');
    if (day == null) return null;
    final resolved = resolveDayAgainstPeriod(day, null)!;
    if (period == 'christmas') return resolved;
    if (period != 'advent' && !hasMissingDaytimeFields(resolved)) {
      return resolved;
    }
    final fallbackId = period == 'ordinary'
        ? periodPsalterDayDocumentId(period, week, dayOfWeek)
        : ordinaryPsalterDayDocumentId(week, dayOfWeek);
    if (fallbackId.isEmpty || fallbackId == resolved.id) return resolved;
    final fallback = _dayById(fallbackId);
    if (fallback == null) return resolved;
    return period == 'advent'
        ? resolveDayAgainstPeriod(resolved, fallback, fillMissing: true)
        : resolvePeriodDayAgainstPsalter(resolved, fallback);
  }

  // ── options (port of buildOrdoDayOptions) ─────────────────────────────

  LiturgicalDayContent _buildOptions(
    DateTime date,
    OrdoDay ordo,
    _DaysResult result,
    Map<String, Map<String, dynamic>> templates,
  ) {
    final properDocs = result.properDays;
    final fixedDocs = [
      ...result.fixedDateDays,
      ...result.extraFixedDays,
    ].where((doc) => !isSeasonalDateDocumentId(doc.id)).toList();
    final temporalDoc =
        result.seasonalException ??
        result.periodDays.firstOrNull ??
        result.periodFallback;
    final currentDay =
        result.seasonalException ??
        result.seasonalDateDay ??
        result.periodFallback ??
        result.periodDays.firstOrNull;
    final options = <DayOption>[];
    final unavailable = <UnavailableOption>[];
    final period = ordo.period;

    DayOption option({
      required String key,
      required LiturgicalOptionSource source,
      required String title,
      required String subtitle,
      required LiturgicalDay day,
      required List<DayTemplate> templates,
      required int order,
      required OrdoOptionDescriptor ordo,
      String? properSource,
      bool missingProper = false,
    }) {
      final stamped = _stamp(day, ordo);
      return DayOption(
        source: source,
        title: _stripHtml(title),
        subtitle: subtitle,
        placeLabel: liturgicalDayPlaceLabel(stamped),
        day: stamped,
        key: key,
        order: order,
        templates: [
          for (final template in templates)
            DayTemplate(
              id: template.id,
              label: template.label,
              day: _stamp(template.day, ordo),
              choice: template.choice,
              dayIds: template.dayIds,
            ),
        ],
        contextPeriodType: period,
        ordo: ordo,
        properSource: properSource,
        missingProper: missingProper,
      );
    }

    List<DayTemplate> assembled(LiturgicalDay proper, OrdoOption candidate) {
      final office = ordo.office(candidate.id);
      final context = {
        '_periodType': currentDay?.periodType,
        '_periodWeekNumber': currentDay?.periodWeekNumber,
        '_dayOfWeek': currentDay?.dayOfWeek,
      };
      final properData = proper.toMap();
      final choices = assemblyChoices(
        properData,
        office?.officeKind ?? 'memorial',
        office: office,
      );
      return [
        for (final (index, choice) in choices.indexed)
          () {
            final assembly = assembleOffice(
              proper: properData,
              currentDay: currentDay?.toMap() ?? const {},
              templates: templates,
              isSunday: date.weekday == DateTime.sunday,
              choice: choice,
              office: office,
              season: computeSeason(isoOf(date)),
            );
            final choiceId = assemblyDayId(proper.id, choice, isDefault: false);
            final id = index == 0 ? proper.id : choiceId;
            return DayTemplate(
              id: id,
              label: choice == kCurrentDayChoice
                  ? kCurrentDayLabel
                  : dayTemplateLabel(choice),
              choice: choice,
              dayIds: index == 0 ? [choiceId] : const [],
              day: LiturgicalDay.fromMap({
                ...context,
                ...assembly.data,
                'id': id,
                if (assembly.missing.isNotEmpty)
                  '_missingFields': assembly.missing,
              }),
            );
          }(),
      ];
    }

    // Legal Offices of the Hours (`officeOptions`: the Sunday on All Souls
    // Sunday, §11.1).
    for (final candidate in ordo.officeOptions) {
      final descriptor = optionDescriptor(ordo, candidate);

      if (candidate.isTemporal) {
        if (temporalDoc == null) {
          unavailable.add(UnavailableOption(candidate.id, candidate.title));
          continue;
        }
        final seasonal = isSeasonalDateDocumentId(temporalDoc.id);
        options.add(
          option(
            key: '${seasonal ? 'fixed' : 'period'}-${temporalDoc.id}',
            source: seasonal
                ? LiturgicalOptionSource.fixed
                : LiturgicalOptionSource.period,
            title: _dayTitle(temporalDoc, date),
            subtitle: seasonal
                ? _fixedSubtitle(temporalDoc.rank, temporalDoc, 1)
                : 'Літургічны дзень',
            day: temporalDoc,
            templates: [
              DayTemplate(
                id: temporalDoc.id,
                label: 'Перыяд',
                day: temporalDoc,
              ),
            ],
            order: 1,
            ordo: descriptor,
          ),
        );
        continue;
      }

      if (candidate.kind == 'dynamic' || candidate.feastCode != null) {
        var docs = _dynamicDocuments(candidate, result);
        if (docs.isEmpty && candidate.temporal && temporalDoc != null) {
          docs = [temporalDoc];
        }
        // Like fixed memorials, movable memorials are assembled from their
        // unmodified Propers. The old resolved dynamic map already contains
        // weekday fields and must not masquerade as the celebration's Proper.
        // The Marian Common is explicitly established for Immaculate Heart,
        // including offline bundles created before the calendar definition fix.
        final effectiveTemplates = candidate.templates.isNotEmpty
            ? candidate.templates
            : candidate.id == 'immaculate-heart'
                ? const ['blessed-virgin-mary']
                : const <String>[];
        if (!candidate.temporal &&
            const {'memorial', 'optional-memorial'}.contains(candidate.officeKind) &&
            effectiveTemplates.isNotEmpty &&
            currentDay != null) {
          final rawDocs = _dynamicDocuments(candidate, result, raw: true);
          final raw = rawDocs.where(isSparseDay).firstOrNull ??
              rawDocs.firstOrNull;
          final base = raw?.toMap() ?? _scaffoldOf(candidate).toMap();
          final proper = LiturgicalDay.fromMap({
            ...base,
            if (raw == null) 'id': candidate.feastCode ?? candidate.id,
            '_feast': base['_feast'] ?? candidate.feastCode,
            '_feastName': base['_feastName'] ?? candidate.title,
            '_celebrationId': base['_celebrationId'] ?? candidate.id,
            '_templates': (base['_templates'] is List &&
                    (base['_templates'] as List).isNotEmpty)
                ? base['_templates']
                : effectiveTemplates,
            '_defaultTemplate': base['_defaultTemplate'] ??
                candidate.defaultTemplate ?? effectiveTemplates.first,
          });
          final variants = assembled(proper, candidate);
          if (raw == null) {
            unavailable.add(
              UnavailableOption(candidate.id, candidate.title, assembled: true),
            );
          }
          options.add(
            option(
              key: 'dynamic-${candidate.id}',
              source: LiturgicalOptionSource.dynamic,
              title: candidate.title,
              subtitle: [
                _fixedSubtitle(candidate.rank, proper, variants.length),
                _contentHint(proper),
              ].where((part) => part.isNotEmpty).join(' · '),
              day: variants.first.day,
              templates: [
                for (final (i, variant) in variants.indexed)
                  DayTemplate(
                    id: variant.id,
                    label: variant.label,
                    day: variant.day,
                    choice: variant.choice,
                    dayIds: [
                      ...variant.dayIds,
                      if (i == 0 && raw == null) candidate.id,
                    ],
                  ),
              ],
              order: 2,
              ordo: descriptor,
              properSource: raw == null
                  ? ProperSource.none
                  : ProperSource.legacyDays,
              missingProper: raw == null,
            ),
          );
          continue;
        }
        if (docs.isEmpty &&
            !candidate.temporal &&
            candidate.templates.isNotEmpty &&
            currentDay != null) {
          unavailable.add(
            UnavailableOption(candidate.id, candidate.title, assembled: true),
          );
          final proper = _scaffoldOf(candidate);
          final variants = assembled(proper, candidate);
          options.add(
            option(
              key: 'dynamic-${candidate.id}',
              source: LiturgicalOptionSource.dynamic,
              title: candidate.title,
              subtitle: [
                _fixedSubtitle(candidate.rank, null, variants.length),
                _contentHint(proper),
              ].where((part) => part.isNotEmpty).join(' · '),
              day: variants.first.day,
              templates: variants,
              order: 2,
              ordo: descriptor,
              properSource: ProperSource.none,
              missingProper: true,
            ),
          );
          continue;
        }
        if (docs.isEmpty) {
          unavailable.add(UnavailableOption(candidate.id, candidate.title));
          continue;
        }
        options.add(
          option(
            key: 'dynamic-${docs.first.id}',
            source: LiturgicalOptionSource.dynamic,
            title: _dayTitle(docs.first, date),
            subtitle: 'Свята',
            day: docs.first,
            templates: [
              for (final doc in docs)
                DayTemplate(id: doc.id, label: _templateLabel(doc), day: doc),
            ],
            order: 2,
            ordo: descriptor,
          ),
        );
        continue;
      }

      // Proper: `liturgicalProperTexts` first; fixed `days` documents only
      // when the celebration is not published there (transitional).
      final claimed = _claimedDayIds(ordo, candidate.id);
      List<LiturgicalDay> select(List<LiturgicalDay> list) =>
          candidate.daysRef?['source'] == 'fixed'
          ? _selectFixedDocuments(candidate, list, ordo.diocese, claimed)
          : const [];
      var docs = select(properDocs);
      String? properSource = docs.isNotEmpty ? ProperSource.properTexts : null;
      if (docs.isEmpty) {
        docs = select(fixedDocs);
        if (docs.isNotEmpty) properSource = ProperSource.legacyDays;
      }
      if (docs.isEmpty &&
          candidate.rankKind == 'all-souls' &&
          result.officeForDead != null) {
        docs = [result.officeForDead!];
        properSource = ProperSource.legacyDays;
      }

      final sparse = docs.where(isSparseDay).firstOrNull;
      if (sparse != null || docs.isEmpty) {
        final needsCommon = candidate.daysRef?['source'] == 'template';
        if (currentDay == null ||
            (needsCommon &&
                !templates.containsKey(candidate.daysRef?['template']))) {
          unavailable.add(UnavailableOption(candidate.id, candidate.title));
          continue;
        }
        if (sparse == null) {
          unavailable.add(
            UnavailableOption(candidate.id, candidate.title, assembled: true),
          );
        }
        final proper = sparse ?? _scaffoldOf(candidate);
        final variants = assembled(proper, candidate);
        options.add(
          option(
            key: 'fixed-${candidate.id}',
            source: LiturgicalOptionSource.fixed,
            title: candidate.title.isNotEmpty
                ? candidate.title
                : _dayTitle(variants.first.day, date),
            subtitle: [
              _fixedSubtitle(candidate.rank, proper, variants.length),
              _contentHint(proper),
            ].where((part) => part.isNotEmpty).join(' · '),
            day: variants.first.day,
            templates: variants,
            order: 3,
            ordo: descriptor,
            properSource: sparse != null ? properSource : ProperSource.none,
            missingProper: sparse == null,
          ),
        );
        continue;
      }
      final groups = _groupFixed([
        for (final doc in docs) _resolveLegacyPlaceholders(doc, templates),
      ], ordo.diocese);
      final day = groups.$1;
      options.add(
        option(
          key: 'fixed-${candidate.id}',
          source: docs.first.field('_kind') == 'office-for-dead'
              ? LiturgicalOptionSource.officeForDead
              : LiturgicalOptionSource.fixed,
          title: _dayTitle(day, date).isNotEmpty
              ? _dayTitle(day, date)
              : candidate.title,
          subtitle: _fixedSubtitle(day.rank, day, groups.$2.length),
          day: day,
          templates: groups.$2,
          order: 3,
          ordo: descriptor,
          properSource: properSource,
        ),
      );
    }

    final dead = result.officeForDead;
    final deadUsed = options.any((item) => item.day?.id == dead?.id);
    if (dead != null && !deadUsed && _allowsOfficeForDead(ordo)) {
      options.add(
        DayOption(
          key: 'office-for-dead',
          source: LiturgicalOptionSource.officeForDead,
          title: dead.feastName ?? dead.title ?? 'Афіцый за памерлых',
          subtitle: 'Памінальны афіцый',
          day: dead,
          templates: [
            DayTemplate(id: dead.id, label: 'Афіцый за памерлых', day: dead),
          ],
          order: 99,
          contextPeriodType: period,
        ),
      );
    }

    final itemsDays = <String, LiturgicalDay>{
      for (final day in [
        ...result.periodDays,
        ...result.fixedDateDays,
        ...result.extraFixedDays,
        for (final list in result.dynamicDaysByFeast.values) ...list,
        ?result.periodFallback,
        ?result.officeForDead,
      ])
        day.id: day,
    };
    return LiturgicalDayContent(
      ordo: ordo,
      options: options,
      unavailable: unavailable,
      itemsDays: itemsDays,
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────

  /// One colour for the card, its Office pages and its readings: the Ordo's.
  LiturgicalDay _stamp(LiturgicalDay day, OrdoOptionDescriptor ordo) =>
      LiturgicalDay.fromMap({
        ...day.toMap(),
        '_vestmentColor': ordo.color,
        if (ordo.category.isNotEmpty) '_celebrationCategory': ordo.category,
        if (ordo.rank.isNotEmpty) '_celebrationRank': ordo.rank,
        '_ordoOptionId': ordo.optionId,
        '_ordoOfficeKind': ordo.officeKind,
        '_contextPeriodType': ordo.date.isEmpty ? null : day.periodType,
      });

  List<LiturgicalDay> _dynamicDocuments(
    OrdoOption option,
    _DaysResult result, {
    bool raw = false,
  }) {
    final code = _normalizeFeast(option.feastCode ?? '');
    final entries = raw
        ? result.rawDynamicDaysByFeast.entries
        : result.dynamicDaysByFeast.entries;
    for (final entry in entries) {
      if (_normalizeFeast(entry.key) == code && entry.value.isNotEmpty) {
        return entry.value;
      }
    }
    return const [];
  }

  /// Identity-only document of a celebration that has no document yet.
  LiturgicalDay _scaffoldOf(OrdoOption option) {
    final date = '${option.daysRef?['_date'] ?? ''}';
    final dayIds = (option.daysRef?['dayIds'] as List?) ?? const [];
    final templates = option.templates;
    return LiturgicalDay.fromMap({
      'id': dayIds.isNotEmpty
          ? '${dayIds.first}'
          : [
              if (date.isNotEmpty) date.replaceAll('.', '-'),
              option.id,
            ].join('-'),
      '_schema': kSparseDaySchema,
      '_scaffold': true,
      '_celebrationId': option.id,
      if (date.isNotEmpty) '_date': date,
      '_rank': option.rank,
      '_place': ?option.dioceseId,
      '_feastName': option.title,
      '_templates': templates,
      '_defaultTemplate': ?option.defaultTemplate,
      '_contentStatus':
          option.contentStatus ??
          {'hours': templates.isNotEmpty ? 'common-only' : 'day-fallback'},
    });
  }

  String _contentHint(LiturgicalDay proper) {
    final status = (proper.data['_contentStatus'] as Map?)?['hours'];
    if (status == 'common-only') return 'агульныя тэксты';
    if (status == 'day-fallback') return 'тэксты дня';
    return '';
  }

  String _fixedSubtitle(String? rank, LiturgicalDay? day, int count) {
    final chunks = <String>[
      if ((rank ?? '').isNotEmpty) kRankLabels[rank] ?? rank!,
      if (day != null)
        for (final place in _placesOf(day)) _placeLabels[place] ?? place,
      if (count > 1) '$count варыянты',
    ];
    return chunks.isEmpty ? 'Літургічны дзень' : chunks.join(' · ');
  }

  bool _allowsOfficeForDead(OrdoDay ordo) {
    // All Souls on a Sunday: the Hours are of the Sunday (§11.1).
    if (ordo.isSplit) return false;
    final primary = ordo.primary;
    if (primary.rankKind == 'all-souls') return true;
    return primary.isTemporal && primary.precedence == 13;
  }

  Set<String> _claimedDayIds(OrdoDay ordo, String exceptId) => {
    for (final candidate in ordo.candidates)
      if (candidate['id'] != exceptId)
        for (final ref in [
          candidate['daysRef'],
          ...?(candidate['fallbackDaysRefs'] as List?),
        ])
          if (ref is Map) ...?(ref['dayIds'] as List?)?.map((id) => '$id'),
  };

  /// Documents that carry a fixed celebration option: the diocese's own
  /// (`daysRef.dayIds`), then the universal ones (`fallbackDaysRefs`), then
  /// a date + title match. Documents of other dioceses are never returned.
  List<LiturgicalDay> _selectFixedDocuments(
    OrdoOption option,
    List<LiturgicalDay> all,
    String diocese,
    Set<String> claimed,
  ) {
    final docs = all.where((doc) => doc.data['_obsolete'] != true).toList();
    List<LiturgicalDay> preferSparse(List<LiturgicalDay> list) =>
        list.any(isSparseDay) ? [list.firstWhere(isSparseDay)] : list;
    List<LiturgicalDay> byIds(Object? ids) {
      if (ids is! List) return const [];
      final wanted = ids.map((id) => '$id').toSet();
      return preferSparse(
        docs.where((doc) => wanted.contains(doc.id)).toList(),
      );
    }

    final ref = option.daysRef ?? const <String, dynamic>{};
    final own = byIds(ref['dayIds']);
    if (own.isNotEmpty) return own;
    for (final fallback in option.fallbackDaysRefs) {
      final found = byIds(fallback['dayIds']);
      if (found.isNotEmpty) return found;
    }
    final sameDate = docs.where((doc) {
      if (doc.date != ref['_date'] || claimed.contains(doc.id)) return false;
      final places = _placesOf(doc);
      return places.isEmpty || places.contains(diocese);
    });
    final scored = [
      for (final doc in sameDate)
        (
          doc,
          readingTitleSimilarity(
            doc.feastName ?? doc.field('_title') ?? '',
            option.title,
          ),
        ),
    ].where((item) => item.$2 >= 0.6).toList();
    if (scored.isEmpty) return const [];
    stableSort(scored, (a, b) => b.$2.compareTo(a.$2));
    final best = scored.first.$2;
    final matches = [
      for (final item in scored)
        if (item.$2 >= best - 0.001) item.$1,
    ];
    final diocesan = matches
        .where((doc) => _placesOf(doc).contains(diocese))
        .toList();
    return diocesan.isNotEmpty ? diocesan : matches;
  }

  /// One celebration's legacy documents → its card day and one template per
  /// actual Common (diocesan copies stay addressable through `dayIds`).
  (LiturgicalDay, List<DayTemplate>) _groupFixed(
    List<LiturgicalDay> docs,
    String diocese,
  ) {
    final ordered = [...docs];
    stableSort(
      ordered,
      (a, b) => (_placesOf(b).contains(diocese) ? 1 : 0).compareTo(
        _placesOf(a).contains(diocese) ? 1 : 0,
      ),
    );
    final groups = <String, List<LiturgicalDay>>{};
    for (final day in ordered) {
      groups.putIfAbsent(_fixedKey(day), () => []).add(day);
    }
    final first = groups.values.first;
    final templates = <DayTemplate>[];
    for (final variants in groups.values) {
      final byTemplate = <String, List<LiturgicalDay>>{};
      for (final variant in variants) {
        byTemplate.putIfAbsent(_templateKey(variant), () => []).add(variant);
      }
      for (final group in byTemplate.values) {
        final day = _withMergedPlaces(group.first, group);
        templates.add(
          DayTemplate(
            id: day.id,
            label: _templateLabel(day),
            day: day,
            dayIds: [
              for (final item in group)
                if (item.id != day.id) item.id,
            ],
          ),
        );
      }
    }
    return (_withMergedPlaces(first.first, first), templates);
  }

  LiturgicalDay _withMergedPlaces(
    LiturgicalDay day,
    List<LiturgicalDay> group,
  ) {
    final places = {for (final item in group) ..._placesOf(item)}.toList()
      ..sort();
    final data = day.toMap();
    if (places.length == 1) {
      data['_place'] = places.first;
    } else if (places.length > 1) {
      data['_place'] = places;
    } else {
      data.remove('_place');
    }
    return LiturgicalDay.fromMap(data);
  }

  /// Materialized documents that predate sparse assembly stored
  /// «з нядзелі І тыдня» in a text field: the published `sunday-week-1`
  /// template replaces the instruction (never rendered raw).
  LiturgicalDay _resolveLegacyPlaceholders(
    LiturgicalDay day,
    Map<String, Map<String, dynamic>> templates,
  ) {
    if (isSparseDay(day)) return day;
    final sunday = templates[kSundayWeek1Template];
    if (sunday == null) return day;
    Map<String, dynamic>? resolved;
    for (final field in kOfficeFieldSlots.keys) {
      if (!_isSundayWeekOneMarker(day.data[field])) continue;
      final replacement = sunday[field];
      if (replacement == null ||
          (replacement is String && replacement.trim().isEmpty)) {
        continue;
      }
      resolved ??= day.toMap();
      resolved[field] = replacement;
    }
    return resolved == null ? day : LiturgicalDay.fromMap(resolved);
  }

  LiturgicalDay? _dayById(String id) {
    if (id.isEmpty) return null;
    final raw = HiveService.daysBox.get(id);
    return raw is Map
        ? LiturgicalDay.fromMap({...Map<String, dynamic>.from(raw), 'id': id})
        : null;
  }

  LiturgicalDay? _properById(String id) {
    final collection = HiveService.content.collection('liturgicalProperTexts');
    final raw = collection.get(id);
    return raw is Map
        ? LiturgicalDay.fromMap({...Map<String, dynamic>.from(raw), 'id': id})
        : null;
  }

  List<LiturgicalDay> _daysByFeast(String code) {
    final variants = {_normalizeFeast(code), 'feast-${_normalizeFeast(code)}'};
    return _daysByIds(DaysIndex.idsByFeast(variants));
  }

  List<LiturgicalDay> _daysByDate(Iterable<String> keys) =>
      _daysByIds(DaysIndex.idsByDate(keys));

  List<LiturgicalDay> _propersByDate(Set<String> keys) => [
    for (final id in ProperTextsIndex.idsByDate(keys)) ?_properById(id),
  ];

  // Only the documents the index names are deserialized.
  List<LiturgicalDay> _daysByIds(Iterable<String> ids) => [
    for (final id in {...ids}) ?_dayById(id),
  ];
}

class _DaysResult {
  const _DaysResult({
    required this.properDays,
    required this.extraFixedDays,
    required this.periodDays,
    required this.periodFallback,
    required this.fixedDateDays,
    required this.dynamicDaysByFeast,
    required this.rawDynamicDaysByFeast,
    required this.seasonalException,
    required this.seasonalDateDay,
    required this.officeForDead,
  });

  final List<LiturgicalDay> properDays;
  final List<LiturgicalDay> extraFixedDays;
  final List<LiturgicalDay> periodDays;
  final LiturgicalDay? periodFallback;
  final List<LiturgicalDay> fixedDateDays;
  final Map<String, List<LiturgicalDay>> dynamicDaysByFeast;
  final Map<String, List<LiturgicalDay>> rawDynamicDaysByFeast;
  final LiturgicalDay? seasonalException;
  final LiturgicalDay? seasonalDateDay;
  final LiturgicalDay? officeForDead;
}

/// `liturgicalProperTexts` by `_date` (rebuilt after any change).
class ProperTextsIndex {
  ProperTextsIndex._();
  static int _builtAt = -1;
  static final Map<String, List<String>> _byDate = {};

  static List<String> idsByDate(Iterable<String> keys) {
    final collection = HiveService.content.collection('liturgicalProperTexts');
    if (_builtAt != collection.changeCount) {
      _byDate.clear();
      for (final key in collection.keys) {
        final raw = collection.get(key);
        if (raw is! Map || raw['_obsolete'] == true) continue;
        final date = raw['_date']?.toString();
        if (date != null && date.isNotEmpty) {
          (_byDate[date] ??= []).add(key);
        }
      }
      _builtAt = collection.changeCount;
    }
    return [for (final key in keys) ...?_byDate[key]];
  }
}

List<String> _fixedDateVariants(DateTime date) => {
  '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}',
  '${date.day}.${date.month}',
}.toList();

String? _seasonalDateDocumentId(DateTime date) {
  final inWindow =
      (date.month == 12 && date.day >= 17) ||
      (date.month == 1 && date.day <= 12);
  if (!inWindow) return null;
  final prefix = date.month == 12 && date.day <= 24 ? 'advent' : 'christmas';
  return '$prefix-${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}';
}

List<String> _placesOf(LiturgicalDay day) {
  final raw = day.data['_place'];
  final values = raw is List ? raw : [raw];
  return [
    for (final value in values)
      if (value != null && '$value'.trim().isNotEmpty) '$value'.trim(),
  ];
}

const _sundayWeekOneMarkers = {
  'from-first-week',
  'з нядзелі і тыдня',
  'з нядзелі i тыдня',
};

bool _isSundayWeekOneMarker(Object? value) {
  final raw = value is List && value.length == 1 ? value.first : value;
  if (raw is! String) return false;
  return _sundayWeekOneMarkers.contains(
    raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase(),
  );
}

/// Normalized title of a celebration / reading (port of mybrev
/// `normalizeReadingTitle`).
String normalizeCelebrationTitle(String? value) => (value ?? '')
    .toLowerCase()
    .replaceFirst(RegExp(r'^\d{1,2}\s+[\p{L}.]+\s*[—–-]\s*', unicode: true), '')
    .replaceAll(
      RegExp(r'(?:^|[\s,])год\s+[abcавс](?=\s|,|$)', unicode: true),
      ' ',
    )
    .replaceAll(
      RegExp(
        r'(?:^|[\s,])(?:урачыстасць|свята|успамін)(?=[\s,]|$)',
        unicode: true,
      ),
      ' ',
    )
    .replaceAll(
      RegExp(r'юзаф\p{L}*\s+(?:работнік|рамеснік)\p{L}*', unicode: true),
      'юзаф рамеснік',
    )
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

Set<String> _titleStems(String value) => {
  for (final token in normalizeCelebrationTitle(value).split(' '))
    if (token.length >= 3 && token != 'св')
      token.length > 6 ? token.substring(0, 6) : token,
};

/// Dice similarity of two titles' stems (mybrev `readingTitleSimilarity`).
double readingTitleSimilarity(String left, String right) {
  final a = _titleStems(left);
  final b = _titleStems(right);
  if (a.isEmpty || b.isEmpty) return 0;
  final intersection = a.where(b.contains).length;
  return 2 * intersection / (a.length + b.length);
}

String _dayTitle(LiturgicalDay day, DateTime date) =>
    liturgicalDayDisplayTitle(day, date);

String _normalizeFeast(String value) =>
    value.replaceFirst(RegExp(r'^feast-'), '');

String _fixedKey(LiturgicalDay day) => [
  day.date ?? '',
  (day.feastName ?? day.field('_title') ?? '').trim().toLowerCase(),
  (day.rank ?? day.field('_feastType') ?? '').trim().toLowerCase(),
].join('|');

String _templateKey(LiturgicalDay day) {
  final current = (day.field('_currentVersion') ?? '').trim();
  if (current.isNotEmpty) return 'template:$current';
  final raw = day.data['_templates'];
  if (raw is List) {
    final values = {
      for (final item in raw)
        if ('$item'.trim().isNotEmpty) '$item'.trim(),
    }.toList()..sort();
    if (values.length == 1) return 'template:${values.first}';
    if (values.isNotEmpty) return 'templates:${values.join('|')}';
  }
  return 'document:${day.id}';
}

String _templateLabel(LiturgicalDay day) {
  final raw = day.data['_templates'];
  final current = (day.field('_currentVersion') ?? '').trim();
  final key = current.isNotEmpty
      ? current
      : raw is List && raw.length == 1
      ? '${raw.first}'
      : day.id.split('--').last;
  return dayTemplateLabel(key.isEmpty ? 'default' : key);
}

/// A sparse feast document assembled for [date] (Commons from the device,
/// the current day as [period]) — tests and diagnostics; the Hours use
/// [LiturgicalContentService.contentForDate].
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
    season: computeSeason(isoOf(date)),
  );
  return LiturgicalDay.fromMap({...assembly.data, 'id': doc.id});
}
