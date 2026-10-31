import 'package:mybrev_flutter/discovery/hint_definition.dart';

const kFactFontControlReady = 'display.font_control_ready';
const kFactPsalmChipsReady = 'hours.psalm_chips_ready';
const kFactNextHourReady = 'hours.next_hour_ready';
const kFactDateAnchorReady = 'readings.date_anchor_ready';
const kFactBibleNavigationReady = 'bible.navigation_ready';
const kFactSearchReady = 'app.search_ready';

/// P1 hints, owned by Stage 4. Edit only this file to add or defer one.
final List<HintDefinition> p1Hints = [
  HintDefinition(
    id: 'display.font_scale',
    version: 1,
    priority: HintPriority.p1,
    screenId: 'hours',
    anchorId: 'display.font.button',
    copyBe: 'Памер тэксту можна змяніць тут',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.isTrue(kFactFontControlReady)],
  ),
  HintDefinition(
    id: 'hours.psalm_layout',
    version: 1,
    priority: HintPriority.p1,
    screenId: 'hours',
    anchorId: 'hours.psalm_chips',
    copyBe: 'Можна наладзіць перанос радкоў і размяшчэнне вершаў',
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
    requirements: [FactRequirement.isTrue(kFactDateAnchorReady)],
  ),
  HintDefinition(
    id: 'bible.navigation',
    version: 1,
    priority: HintPriority.p1,
    screenId: 'bible',
    anchorId: 'bible.book_picker.button',
    copyBe: 'Выберыце кнігу і раздзел Святога Пісання',
    requirements: [FactRequirement.isTrue(kFactBibleNavigationReady)],
  ),
  HintDefinition(
    id: 'app.search',
    version: 1,
    priority: HintPriority.p1,
    screenId: 'prayers',
    anchorId: 'app.search.button',
    copyBe: 'Шукаеце малітву або тэкст? Скарыстайцеся пошукам',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.isTrue(kFactSearchReady)],
  ),
];
