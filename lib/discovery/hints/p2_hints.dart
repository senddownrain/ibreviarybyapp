import 'package:mybrev_flutter/discovery/hint_definition.dart';

const kFactPrayersAvailable = 'discover.prayers_available';
const kFactSongbookLoaded = 'discover.songbook_loaded';
const kFactCompendiumAvailable = 'discover.compendium_available';
const kFactBibleAvailable = 'discover.bible_available';

/// P2 hints, owned by Stage 5. Edit only this file to add or defer one.
final List<HintDefinition> p2Hints = [
  HintDefinition(
    id: 'discover.prayers',
    version: 1,
    priority: HintPriority.p2,
    screenId: 'navigation',
    anchorId: 'discover.prayers.tab',
    copyBe: 'У раздзеле «Малітвы» ёсць малітвы і набажэнствы на розныя патрэбы',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.isTrue(kFactPrayersAvailable)],
  ),
  HintDefinition(
    id: 'discover.songbook',
    version: 1,
    priority: HintPriority.p2,
    screenId: 'navigation',
    anchorId: 'discover.songbook.link',
    copyBe: 'Шукаеце спеў? Зазірніце ў «Спеўнік»',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.isTrue(kFactSongbookLoaded)],
  ),
  HintDefinition(
    id: 'discover.catechism',
    version: 1,
    priority: HintPriority.p2,
    screenId: 'navigation',
    anchorId: 'discover.compendium.link',
    copyBe: 'Адказы на пытанні веры можна шукаць у Кампендыі Катэхізіса',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.isTrue(kFactCompendiumAvailable)],
  ),
  HintDefinition(
    id: 'discover.bible',
    version: 1,
    priority: HintPriority.p2,
    screenId: 'navigation',
    anchorId: 'discover.bible.tab',
    copyBe: 'Поўныя кнігі Святога Пісання — у раздзеле «Біблія»',
    actionLabelBe: 'Паказаць',
    requirements: [FactRequirement.isTrue(kFactBibleAvailable)],
  ),
];
