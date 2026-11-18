/// MyBrev Ordo engine — the Dart port of mybrev `src/utils/ordo/index.js`
/// and `runtime.js`. Pure: no Hive, Firestore or Flutter.
///
/// ```text
/// date
/// → season / period / week / psalter week
/// → temporal candidate
/// → universal → Belarus → diocese layers → year overrides → transfers
/// → precedence → PRIMARY · LEGAL ALTERNATIVES · COMMEMORATIONS · SUPPRESSED
/// → Office and Readings descriptors (→ Ordo notes, on request)
/// ```
///
/// One diocese per call; several dioceses are united in the presentation
/// layer (`lib/ordo/union.dart`).
library;

import 'package:mybrev_flutter/ordo/candidates.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/ordo/display.dart';
import 'package:mybrev_flutter/ordo/memorial_readings.dart';
import 'package:mybrev_flutter/ordo/notes.dart';
import 'package:mybrev_flutter/ordo/office.dart';
import 'package:mybrev_flutter/ordo/readings_plan.dart';
import 'package:mybrev_flutter/ordo/season.dart';
import 'package:mybrev_flutter/ordo/year_plan.dart';

/// Typed view of a resolved candidate (primary, alternative, commemoration
/// or suppressed).
extension type OrdoOption(Json data) {
  String get id => '${data['id']}';
  // The installed offline bundle may still carry the older nominative label.
  // Match the approved canonical calendar title without changing the feast ID.
  String get title => id == 'holy-family'
      ? kHolyFamilyGenitiveTitle
      : '${data['title'] ?? ''}';
  String get kind => '${data['kind'] ?? ''}';
  String get rank => '${data['rank'] ?? ''}';
  String get rankKind => '${data['rankKind'] ?? ''}';
  String get officeKind => '${data['officeKind'] ?? ''}';
  String get role => '${data['role'] ?? ''}';
  String get category => '${data['category'] ?? ''}';
  String get layer => '${data['layer'] ?? ''}';
  String get color => '${data['color'] ?? ''}';
  List<String> get colorAlternatives => [
    ...?(data['colorAlternatives'] as List?)?.map((e) => '$e'),
  ];
  int get precedence => (data['precedence'] as num?)?.toInt() ?? 13;
  bool get isTemporal => data['kind'] == 'temporal';
  bool get temporal => data['temporal'] == true;
  String? get dioceseId => data['dioceseId'] as String?;
  String? get feastCode => data['feastCode'] as String?;
  String? get transferredFrom => data['transferredFrom'] as String?;
  String? get transferredTo => data['transferredTo'] as String?;
  String? get movedFrom => data['movedFrom'] as String?;
  String? get demotedFrom => data['demotedFrom'] as String?;

  /// A temporary product decision, source-dependent (Christ the High
  /// Priest meeting another feast, §11.4).
  bool get provisional => data['provisional'] == true;

  /// The Office source of a split day (the Sunday on All Souls Sunday).
  bool get officeOnly => data['officeOnly'] == true;

  /// `rank-not-source-confirmed`: an impeded diocesan solemnity kept
  /// without transfer.
  String? get transferBlocked => data['transferBlocked'] as String?;

  /// Provenance of the stored transfer override that placed the option
  /// (`{id?, source, status, computedDate}`).
  Json? get transferOverride =>
      (data['transferOverride'] as Map?)?.cast<String, dynamic>();
  String? get reason => data['reason'] as String?;
  String? get readingsReference => data['readingsReference'] as String?;
  List<String> get templates => [
    ...?(data['templates'] as List?)?.map((e) => '$e'),
  ];
  String? get defaultTemplate => data['defaultTemplate'] as String?;
  Json? get daysRef => (data['daysRef'] as Map?)?.cast<String, dynamic>();
  Json? get readingsRef =>
      (data['readingsRef'] as Map?)?.cast<String, dynamic>();
  List<Json> get fallbackDaysRefs => [
    ...?(data['fallbackDaysRefs'] as List?)?.map(
      (e) => (e as Map).cast<String, dynamic>(),
    ),
  ];
  Json? get contentStatus =>
      (data['contentStatus'] as Map?)?.cast<String, dynamic>();
  bool get isSuppressed => role == 'suppressed';
}

/// Where one side of the day comes from (port of `sources.office` /
/// `sources.mass` of the web `ResolvedLiturgicalDay`).
class OrdoSource {
  const OrdoSource({
    required this.optionId,
    required this.celebrationId,
    required this.kind,
    required this.officeKind,
    required this.title,
  });

  factory OrdoSource.of(OrdoOption option) => OrdoSource(
    optionId: option.id,
    celebrationId: option.isTemporal ? null : option.id,
    kind: option.kind,
    officeKind: option.officeKind,
    title: option.title,
  );

  final String optionId;

  /// Null for the temporal day.
  final String? celebrationId;
  final String kind;
  final String officeKind;
  final String title;
}

/// Office (Liturgy of the Hours) and Mass (Mass texts and readings)
/// sources of a date. They are the same option except where a rule splits
/// them: All Souls on a Sunday (§11.1) — Office of the Sunday, Mass and
/// readings of All Souls.
class OrdoSources {
  const OrdoSources({
    required this.office,
    required this.mass,
    required this.split,
  });
  final OrdoSource office;
  final OrdoSource mass;
  final bool split;
}

/// One Mass of a celebration with several Masses (All Souls: three reading
/// sets of the one celebration, `all-souls-mass-1…3`). The reading sets
/// themselves come from the readings model.
class OrdoMassVariant {
  const OrdoMassVariant(this.id, this.ordinal);
  final String id;
  final int ordinal;
}

const _allSoulsMasses = [1, 2, 3];

/// One civil date resolved for one diocese.
class OrdoDay {
  OrdoDay._({
    required this.season,
    required this.diocese,
    required this.candidates,
    required this.primary,
    required this.officePrimary,
    required this.alternatives,
    required this.commemorations,
    required this.suppressed,
    required this.appliedRules,
    required this.transfers,
    required this.evening,
    required this.firstVespersCelebratedOnEve,
  });

  final Season season;
  final String diocese;
  final List<Json> candidates;

  /// The primary celebration: Mass, readings, colour, title of the day.
  final OrdoOption primary;

  /// The Office (Hours) source: [primary], except on a split day (All Souls
  /// on a Sunday: the Sunday, `officeOnly`).
  final OrdoOption officePrimary;
  final List<OrdoOption> alternatives;
  final List<OrdoOption> commemorations;
  final List<OrdoOption> suppressed;
  final List<Json> appliedRules;
  final List<TransferRecord> transfers;
  final OrdoEvening evening;
  final bool firstVespersCelebratedOnEve;

  String get date => season.date;
  String get period => season.period;
  String get periodPhase => season.periodPhase;
  int get week => season.periodWeek;
  int get dayOfWeek => season.dayOfWeek;
  int? get psalterWeek => season.psalterWeek;
  ReadingCycle get readingCycle => season.readingCycle;
  String get color => primary.color;
  List<String> get colorAlternatives => primary.colorAlternatives;

  /// PRIMARY + LEGAL ALTERNATIVES (Mass / readings / calendar options).
  List<OrdoOption> get options => [primary, ...alternatives];

  /// Office and Mass may come from different sources on one date (§11.1).
  bool get isSplit => officePrimary.id != primary.id;

  /// Legal Offices of the Liturgy of the Hours: [options], or only the
  /// Sunday on a split day. The Hours iterate these, never [options].
  List<OrdoOption> get officeOptions => isSplit ? [officePrimary] : options;

  /// Office / Mass sources of the day. The readings side reads
  /// `sources.mass` (= [primary]); the Hours read `sources.office`.
  OrdoSources get sources => OrdoSources(
    office: OrdoSource.of(officePrimary),
    mass: OrdoSource.of(primary),
    split: isSplit,
  );

  /// A legal option (Mass side) or legal Office by id.
  OrdoOption? option(String? id) =>
      options.where((option) => option.id == id).firstOrNull ??
      officeOptions.where((option) => option.id == id).firstOrNull;

  /// Several Masses of the primary celebration (All Souls: three reading
  /// sets, also when 2 November is a Sunday); empty otherwise. Mirrors
  /// web `readingResolution.primary.variants` with
  /// `variantsKind: 'reading-sets'`.
  List<OrdoMassVariant> get massVariants => primary.officeKind == 'all-souls'
      ? [
          for (final ordinal in _allSoulsMasses)
            OrdoMassVariant('all-souls-mass-$ordinal', ordinal),
        ]
      : const [];

  OrdoOption get temporal => OrdoOption(
    candidates.firstWhere((candidate) => candidate['kind'] == 'temporal'),
  );

  final Map<String, OfficeDescriptor> _office = {};

  /// Office descriptor of a legal Office (null for an unknown id; on a
  /// split day only the Sunday has one, as on the web).
  OfficeDescriptor? office(String optionId) {
    final option = officeOptions
        .where((option) => option.id == optionId)
        .firstOrNull;
    if (option == null) return null;
    return _office.putIfAbsent(
      optionId,
      () => buildOfficeDescriptor(option.data, season),
    );
  }

  /// Readings plan of every legal option (engine order).
  List<OptionReadingsPlan> get readingsPlan => [
    for (final option in options) _readingsPlanOf(option),
  ];

  OptionReadingsPlan _readingsPlanOf(OrdoOption option) {
    final lookup = readingsLookupOf(
      option.data,
      temporal.data,
      season,
      diocese: diocese,
    );
    final rule = memorialReadingsRule(option.id, option.officeKind, diocese);
    return OptionReadingsPlan(
      optionId: option.id,
      title: option.title,
      role: option.role,
      kind: option.kind,
      officeKind: option.officeKind,
      lookup: lookup,
      defaultPurpose: rule?.defaultPurpose ?? lookup.firstOrNull?.purpose ?? '',
      option: option.data,
      readingsReference: option.readingsReference,
      readingsStatus: option.contentStatus?['readings'] as String?,
    );
  }

  /// Vestment colours of the legal options, primary first (no duplicates;
  /// suppressed celebrations never colour a date).
  List<String> get legalColors {
    final colors = <String>[];
    for (final option in options) {
      final color = option.color.isEmpty ? this.color : option.color;
      if (!colors.contains(color)) colors.add(color);
    }
    return colors;
  }

  NoteDayView get noteView => NoteDayView(
    date: date,
    period: period,
    periodPhase: periodPhase,
    week: week,
    dayOfWeek: dayOfWeek,
    primary: primary.data,
    alternatives: [for (final item in alternatives) item.data],
    commemorations: [for (final item in commemorations) item.data],
    suppressed: [for (final item in suppressed) item.data],
  );
}

/// What the Hours of a legal option read instead of ad-hoc rank checks
/// (port of `optionDescriptor`).
class OrdoOptionDescriptor {
  const OrdoOptionDescriptor({
    required this.date,
    required this.diocese,
    required this.optionId,
    required this.role,
    required this.title,
    required this.rank,
    required this.kind,
    required this.officeKind,
    required this.color,
    required this.category,
    required this.teDeum,
    required this.compline,
    required this.complineDay,
    required this.complineChoice,
    required this.complineSolemnityPrayer,
    required this.firstVespersByRight,
    required this.vespersType,
    required this.commemorations,
    this.colorAlternatives = const [],
    this.contentStatus,
  });

  final String date;
  final String diocese;
  final String optionId;
  final String role;
  final String title;
  final String rank;
  final String kind;
  final String officeKind;
  final String color;
  final List<String> colorAlternatives;
  final String category;
  final bool teDeum;
  final String compline;
  final int complineDay;
  final bool complineChoice;
  final bool complineSolemnityPrayer;
  final bool firstVespersByRight;
  final String vespersType;
  final List<OrdoOption> commemorations;
  final Json? contentStatus;

  String? get celebrationId => kind == 'temporal' ? null : optionId;
}

OrdoOptionDescriptor optionDescriptor(OrdoDay day, OrdoOption option) {
  final office = day.office(option.id);
  final tomorrowWins = day.evening.vespersType == 'first';
  final complineChoice = day.period == 'easter' && day.periodPhase == 'octave';
  final compline = complineChoice
      ? 'sunday-after-first-or-second-vespers'
      : tomorrowWins
      ? day.evening.compline
      : (office?.compline ?? 'current-weekday');
  final complineSolemnityPrayer =
      !complineChoice &&
      (option.officeKind == 'triduum' ||
          (tomorrowWins
              ? day.evening.complineSolemnityPrayer
              : option.officeKind == 'solemnity' && day.dayOfWeek != 1));
  return OrdoOptionDescriptor(
    date: day.date,
    diocese: day.diocese,
    optionId: option.id,
    role: option.role,
    title: option.title,
    rank: option.rank,
    kind: option.kind,
    officeKind: option.officeKind,
    color: option.color.isEmpty ? day.color : option.color,
    colorAlternatives: option.colorAlternatives,
    category: option.category,
    teDeum: office?.teDeum ?? false,
    compline: compline,
    complineDay: complineWeekday(compline, day.dayOfWeek),
    complineChoice: complineChoice,
    complineSolemnityPrayer: complineSolemnityPrayer,
    firstVespersByRight: office?.firstVespersByRight ?? false,
    vespersType: tomorrowWins
        ? 'first'
        : (option.role == 'primary' ? day.evening.vespersType : 'of-the-day'),
    commemorations: option.role == 'primary' ? day.commemorations : const [],
    contentStatus: option.contentStatus,
  );
}

class _Core {
  const _Core(this.plan, this.season, this.candidates, this.display);
  final YearPlan plan;
  final Season season;
  final List<Json> candidates;
  final DisplayResult display;
}

/// The engine of one publication of the calendar definitions (+ notes).
class OrdoEngine {
  OrdoEngine(
    this.definitions, {
    Iterable<Json> notes = const [],
    this.ignoreTransferOverrides = false,
  }) : _notes = notes.toList();

  final OrdoDefinitions definitions;

  /// The pure transfer algorithm: stored transfer overrides (materialized
  /// auto transfers and their manual corrections) are not used.
  final bool ignoreTransferOverrides;
  final List<Json> _notes;

  final Map<String, YearPlan> _plans = {};
  final Map<String, _Core> _cores = {};
  final Map<String, OrdoDay> _days = {};
  static const _planCacheLimit = 24;
  static const _dayCacheLimit = 400;

  bool get hasNotes => _notes.isNotEmpty;

  YearPlan plan(int year, String diocese) {
    final dioceseId = normalizeDioceseId(diocese);
    final key = '$year|$dioceseId';
    final cached = _plans.remove(key);
    if (cached != null) return _plans[key] = cached;
    final built = buildYearPlan(
      year,
      definitions,
      diocese: dioceseId,
      ignoreTransferOverrides: ignoreTransferOverrides,
    );
    _plans[key] = built;
    if (_plans.length > _planCacheLimit) _plans.remove(_plans.keys.first);
    return built;
  }

  _Core _core(String iso, String diocese) {
    final key = '$iso|$diocese';
    final cached = _cores[key];
    if (cached != null) return cached;
    final plan = this.plan(parseIso(iso).year, diocese);
    final (season, candidates) = collectCandidates(iso, plan);
    final core = _Core(
      plan,
      season,
      candidates,
      resolveDisplay(candidates, season),
    );
    _cores[key] = core;
    if (_cores.length > _dayCacheLimit * 3) _cores.remove(_cores.keys.first);
    return core;
  }

  /// The resolved liturgical day of [date] for [diocese] (memoized).
  OrdoDay resolve(Object date, {String diocese = kDefaultDiocese}) {
    final iso = date is DateTime ? isoOf(date) : '$date';
    final dioceseId = normalizeDioceseId(diocese).isEmpty
        ? kDefaultDiocese
        : normalizeDioceseId(diocese);
    final key = '$iso|$dioceseId';
    final cached = _days[key];
    if (cached != null) return cached;
    final today = _core(iso, dioceseId);
    final tomorrow = _core(addDays(iso, 1), dioceseId);
    final yesterday = _core(addDays(iso, -1), dioceseId);
    final display = today.display;
    // The evening follows the Office source (All Souls on a Sunday: the
    // Sunday, §11.1).
    final evening = resolveEvening(
      display.officePrimary,
      today.season,
      tomorrow.display.officePrimary,
      tomorrow.season,
    );
    final eve = resolveEvening(
      yesterday.display.officePrimary,
      yesterday.season,
      display.officePrimary,
      today.season,
    );
    final day = OrdoDay._(
      season: today.season,
      diocese: dioceseId,
      candidates: today.candidates,
      primary: OrdoOption(display.primary),
      officePrimary: OrdoOption(display.officePrimary),
      alternatives: [for (final item in display.alternatives) OrdoOption(item)],
      commemorations: [
        for (final item in display.commemorations) OrdoOption(item),
      ],
      suppressed: [for (final item in display.suppressed) OrdoOption(item)],
      appliedRules: display.appliedRules,
      transfers: [
        for (final item in today.plan.transfers)
          if (item.from == iso || item.to == iso) item,
      ],
      evening: evening,
      firstVespersCelebratedOnEve:
          eve.vespersType == 'first' &&
          eve.celebrationId == display.officePrimary['id'],
    );
    _days[key] = day;
    if (_days.length > _dayCacheLimit) _days.remove(_days.keys.first);
    return day;
  }

  /// Every date of a civil year.
  List<OrdoDay> year(int year, {String diocese = kDefaultDiocese}) => [
    for (final iso in daysOfYear(year)) resolve(iso, diocese: diocese),
  ];

  /// Final (post-transfer) date of a celebration id or alias around [iso].
  List<String> datesOfCelebration(
    String celebrationId,
    String iso,
    String diocese,
  ) {
    final year = parseIso(iso).year;
    final result = <String>[];
    for (final y in [year - 1, year, year + 1]) {
      final plan = this.plan(y, diocese);
      final direct = plan.celebrationDates[celebrationId];
      if (direct != null) {
        result.add(direct);
        continue;
      }
      final anchor = _anchorAliases[celebrationId];
      if (anchor != null) {
        result.add(plan.anchors[anchor]!);
        continue;
      }
      final byCode = plan.celebrations.values.where((item) {
        final code = item['feastCode'];
        return code == celebrationId ||
            '${code ?? ''}'.replaceFirst(RegExp('^feast-'), '') ==
                celebrationId;
      }).firstOrNull;
      final date = byCode == null
          ? null
          : plan.celebrationDates['${byCode['id']}'];
      if (date != null) result.add(date);
    }
    return result;
  }

  final Expando<List<Json>> _selectedNotes = Expando();

  List<Json> _notesSelected(OrdoDay day) {
    if (_notes.isEmpty) return const [];
    return _selectedNotes[day] ??= selectOrdoNotes(
      _notes,
      day.noteView,
      diocese: day.diocese,
      dateOfCelebration: (id) => datesOfCelebration(id, day.date, day.diocese),
    );
  }

  /// Canonical Ordo notes of a resolved day (layer notes are part of the
  /// notes collection), without the `books` volume markers (§13.1).
  List<Json> notesOf(OrdoDay day) => [
    for (final note in _notesSelected(day))
      if (!isBooksNote(note)) note,
  ];

  /// Lectionary / Liturgy of the Hours volumes of a resolved day (notes of
  /// the category `books`; most specific selector wins), or null.
  OrdoBooks? booksOf(OrdoDay day) => booksFromNotes(_notesSelected(day));

  /// The civil date of a liturgical position in [year], found by the engine
  /// itself; null when the position does not exist that year (never a date
  /// of another period).
  String? dateForPosition(int year, String period, int week, int dayOfWeek) {
    for (final iso in daysOfYear(year)) {
      final season = computeSeason(iso);
      if (season.period == period &&
          season.periodWeek == week &&
          season.dayOfWeek == dayOfWeek) {
        return iso;
      }
    }
    return null;
  }
}

const _anchorAliases = {
  'divinemercy': 'divineMercySunday',
  'eastersunday': 'easterSunday',
  'easter-sunday': 'easterSunday',
  'holythursday': 'holyThursday',
  'goodfriday': 'goodFriday',
  'holysaturday': 'holySaturday',
};
