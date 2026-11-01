import 'package:mybrev_flutter/discovery/hint_definition.dart';

// Fact keys the Readings/calendar screens report (Stage 3). The four kinds
// of alternative are separate facts and are never added together.
const kFactDayVariantCount = 'readings.day_variant_count';
const kFactAllowedAlternativeCount = 'readings.allowed_alternative_count';
const kFactOtherCycleLoaded = 'readings.other_cycle_loaded';
const kFactDioceseDiffers = 'ordo.diocese_cards_differ';
const kFactCalendarAnchorReady = 'calendar.anchor_ready';
const kFactHolidaySearchWorks = 'calendar.holiday_search_works';

/// P0 hints, owned by Stage 3. Edit only this file to add or defer one.
final List<HintDefinition> p0Hints = [
  HintDefinition(
    id: 'readings.day_variants',
    version: 1,
    priority: HintPriority.p0,
    screenId: 'readings',
    anchorId: 'readings.day_variants.button',
    copyBe: 'На гэтую дату ёсць іншыя варыянты літургічнага дня',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.atLeast(kFactDayVariantCount, 2)],
  ),
  HintDefinition(
    id: 'readings.allowed_alternatives',
    version: 1,
    priority: HintPriority.p0,
    screenId: 'readings',
    anchorId: 'readings.alternatives.button',
    copyBe: 'Для гэтага дня даступны іншыя варыянты чытанняў',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.atLeast(kFactAllowedAlternativeCount, 1)],
    // DEFERRED (Stage 3): the wording about a choice of weekday or proper
    // readings is a legal statement (GIRM 357 / OLM 83) that the owner has
    // not confirmed. No screen reports the fact either.
    status: HintStatus.deferred,
  ),
  HintDefinition(
    id: 'readings.other_year',
    version: 1,
    priority: HintPriority.p0,
    screenId: 'readings',
    anchorId: 'readings.cycle.button',
    copyBe: 'Тут можна паглядзець чытанні іншых літургічных гадоў',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.isTrue(kFactOtherCycleLoaded)],
  ),
  HintDefinition(
    id: 'ordo.calendar_variants',
    version: 1,
    priority: HintPriority.p0,
    screenId: 'ordo',
    anchorId: 'ordo.diocese.button',
    copyBe: 'Варыянты дня могуць залежаць ад дыяцэзіі',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.isTrue(kFactDioceseDiffers)],
  ),
  HintDefinition(
    id: 'calendar.date_navigation',
    version: 1,
    priority: HintPriority.p0,
    screenId: 'readings',
    anchorId: 'calendar.date.button',
    copyBe: 'Выберыце дату, каб адкрыць тэксты на патрэбны дзень',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.isTrue(kFactCalendarAnchorReady)],
  ),
  HintDefinition(
    id: 'calendar.more_periods',
    version: 1,
    priority: HintPriority.p0,
    // Shown inside the calendar sheet the person opened; the sheet is not
    // closed by the hint, so it has «Зразумела» and no action of its own.
    screenId: 'calendar_sheet',
    anchorId: 'calendar.search.button',
    copyBe: 'Можна шукаць па літургічных перыядах і святкаваннях',
    allowSnooze: false,
    requirements: [FactRequirement.isTrue(kFactHolidaySearchWorks)],
  ),
];
