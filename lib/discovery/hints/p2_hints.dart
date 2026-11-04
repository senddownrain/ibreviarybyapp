import 'package:mybrev_flutter/discovery/hint_definition.dart';

const kFactPrayersAvailable = 'discover.prayers_available';
const kFactPrayersVisits = 'discover.prayers_visits';
const kFactSongbookLoaded = 'discover.songbook_loaded';
const kFactSongbookVisits = 'discover.songbook_visits';
const kFactCompendiumAvailable = 'discover.compendium_available';
const kFactCompendiumVisits = 'discover.compendium_visits';
const kFactBibleAvailable = 'discover.bible_available';
const kFactBibleVisits = 'discover.bible_visits';

/// Dock switches the person made in this session. P2 stays silent until the
/// person has moved around the app on purpose, so it never greets someone
/// who has only just finished onboarding.
const kFactNavSwitches = 'discover.nav_switches';
const kP2MinNavSwitches = 2;

/// P2 is an invitation, not a nag: at most two automatic displays per ID.
const kP2MaxShows = 2;

/// «Не знаком»: the section has never been entered (engine visit counter).
FactRequirement _neverVisited(String key) =>
    FactRequirement(key, (value) => value == 0);

final _activity = FactRequirement.atLeast(kFactNavSwitches, kP2MinNavSwitches);

/// P2 hints, owned by Stage 5. Edit only this file to add or defer one.
///
/// Copy follows `02-be-copy-and-scenarios.md`; the Compendium hint says
/// «Кампендый Катэхізіса», never the full Catechism. Every hint needs loaded
/// data, a fully visible anchor and a section the person has not entered yet.
final List<HintDefinition> p2Hints = [
  HintDefinition(
    id: 'discover.prayers',
    version: 1,
    priority: HintPriority.p2,
    screenId: 'hours_root',
    anchorId: 'discover.prayers.tab',
    copyBe:
        'У раздзеле «Малітоўнік» ёсць малітвы і набажэнствы на розныя патрэбы',
    actionLabelBe: 'Паказаць',
    maxShows: kP2MaxShows,
    requirements: [
      FactRequirement.isTrue(kFactPrayersAvailable),
      _neverVisited(kFactPrayersVisits),
      _activity,
    ],
  ),
  HintDefinition(
    id: 'discover.songbook',
    version: 1,
    priority: HintPriority.p2,
    screenId: 'prayers',
    anchorId: 'discover.songbook.link',
    copyBe: 'Шукаеце спеў? Зазірніце ў «Спеўнік пілігрымковы»',
    actionLabelBe: 'Паказаць',
    maxShows: kP2MaxShows,
    requirements: [
      FactRequirement.isTrue(kFactSongbookLoaded),
      _neverVisited(kFactSongbookVisits),
      _activity,
    ],
  ),
  HintDefinition(
    id: 'discover.catechism',
    version: 1,
    priority: HintPriority.p2,
    screenId: 'prayers',
    anchorId: 'discover.compendium.link',
    copyBe: 'Адказы на пытанні веры можна шукаць у Кампендыі Катэхізіса',
    actionLabelBe: 'Паказаць',
    maxShows: kP2MaxShows,
    requirements: [
      FactRequirement.isTrue(kFactCompendiumAvailable),
      _neverVisited(kFactCompendiumVisits),
      _activity,
    ],
  ),
  HintDefinition(
    id: 'discover.bible',
    version: 1,
    priority: HintPriority.p2,
    screenId: 'prayers',
    anchorId: 'discover.bible.tab',
    copyBe: 'Поўныя кнігі Святога Пісання — у раздзеле «Біблія»',
    actionLabelBe: 'Паказаць',
    maxShows: kP2MaxShows,
    requirements: [
      FactRequirement.isTrue(kFactBibleAvailable),
      _neverVisited(kFactBibleVisits),
      _activity,
    ],
  ),
];
