import 'package:mybrev_flutter/discovery/hint_definition.dart';

const kFactFontControlReady = 'display.font_control_ready';
const kFactPsalmChipsReady = 'hours.psalm_chips_ready';
const kFactNextHourReady = 'hours.next_hour_ready';
const kFactDateAnchorReady = 'readings.date_anchor_ready';
const kFactBibleNavigationReady = 'bible.navigation_ready';
const kFactSearchReady = 'app.search_ready';

/// P1 hints, owned by Stage 4. Edit only this file to add or defer one.
///
/// Copy and anchors follow `02-be-copy-and-scenarios.md` of the Stage 1 audit;
/// `display.font_scale` points at the reader's «⋯» menu and `app.search` is
/// narrowed to the prayer search (there is no global search).
final List<HintDefinition> p1Hints = [
  HintDefinition(
    id: 'display.font_scale',
    version: 1,
    priority: HintPriority.p1,
    screenId: 'hours',
    anchorId: 'display.font.button',
    copyBe: 'Памер тэксту — у меню ⋯',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.isTrue(kFactFontControlReady)],
  ),
  HintDefinition(
    id: 'hours.psalm_layout',
    version: 1,
    priority: HintPriority.p1,
    screenId: 'hours',
    anchorId: 'hours.psalm_chips',
    copyBe: 'Выберыце адзін з трох рэжымаў псальмодыі',
    requirements: [FactRequirement.isTrue(kFactPsalmChipsReady)],
  ),
  HintDefinition(
    id: 'hours.next_hour',
    version: 1,
    priority: HintPriority.p1,
    screenId: 'hours',
    anchorId: 'hours.next_hour.button',
    copyBe: 'Перайсці да наступнай гадзіны можна адсюль',
    requirements: [FactRequirement.isTrue(kFactNextHourReady)],
  ),
  HintDefinition(
    id: 'readings.other_date',
    version: 1,
    priority: HintPriority.p1,
    screenId: 'readings',
    anchorId: 'readings.date.button',
    copyBe: 'Націсніце на дату, каб адкрыць каляндар',
    actionLabelBe: 'Паказаць',
    // Same anchor and meaning as `calendar.date_navigation` (Stage 3): never
    // both on one screen, so only that one is switched on.
    status: HintStatus.deferred,
    requirements: [FactRequirement.isTrue(kFactDateAnchorReady)],
  ),
  HintDefinition(
    id: 'bible.navigation',
    version: 1,
    priority: HintPriority.p1,
    screenId: 'bible',
    anchorId: 'bible.book_picker.button',
    copyBe: 'Выберыце кнігу і раздзел Святога Пісання',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.isTrue(kFactBibleNavigationReady)],
  ),
  HintDefinition(
    id: 'app.search',
    version: 1,
    priority: HintPriority.p1,
    screenId: 'prayers',
    anchorId: 'app.search.button',
    copyBe: 'Шукаеце малітву? Скарыстайцеся пошукам',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.isTrue(kFactSearchReady)],
  ),
];
