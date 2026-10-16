# Universal liturgical lookup: Web / Flutter contract

Flutter implementation on `feature/universal-liturgical-picker-flutter`, from
`origin/main` `4a6491fca5e841b537eb62e7b81088709327f9b1`. Initial checkout HEAD:
`fbbe43d138f2b494cfefdc8b56ba86de5f6373d5`. Existing untracked local artifacts
were retained. The current main includes AGENTS.md, requiring a real Chrome visual smoke with saved screenshots. This requirement is included in validation.
README and pubspec were read; the installed Flutter 3.41.4 / Dart 3.11.1 matches
the current pubspec. README's older 3.38.9 instruction is stale; no SDK upgrade
or dependency constraint change was made.

Reference: [Web draft PR #131](https://github.com/senddownrain/mybrev/pull/131),
commit `b7bf12d85fc86a7e85a87b2571c445cd395570b4`. The structure, permanent IDs,
date-rule filters, occurrence statuses, civil-year semantics, and JSON fixtures
follow that implementation. Flutter uses its existing native styling and palette.

## Three independent objects

### CatalogEntry

`lib/ordo/liturgical_catalog.dart`: permanent `id`, `title`, `rank`, `dateRule`,
`scope` (from `layer`), applicable `dioceses`, `color` / alternatives, `templates`,
`defaultTemplate`, `daysRef`, `fallbackDaysRefs`, `readingsRef`, `contentStatus`
are retained in `data`. The effective source is `OrdoRuntime.engine.definitions`
from ContentStore's bundled publication plus its active overlay.
`buildCalendarLayers` applies diocesan add/modify/suppress before catalog creation.
Annual suppressions never delete the permanent catalog entry. The legacy
`pickerFeastsOfYear` API remains available to existing clients/tests but is no
longer a source for the UI catalog. Legal day alternatives are unchanged.

Grouping compares all definition fields except diocesan provenance (`dioceseId`,
`layerTrail`, `inheritedFrom`). Distinct ranks, rules, colors, source IDs or layers
remain separate. A diocesan suppression excludes the entry only in that diocese.
Search accepts name, nominal DD.MM (also DD.MM.YYYY), rank and diocese.
Filters: «Усе», «Нерухомыя», «Рухомыя». Only `fixed` is fixed; `movable`,
`named`, `last-weekday-of-month` are movable. Movable rows show a rule until a
calendar year is explicitly requested. Sorting uses nominal month/day, title and
stable identity/context fields.

Period IDs match Web: `period:<period>-w<week>-d<weekday>` (Sunday = 1), or
`period:<period>-DD-MM` with `specialDateKey` DD.MM. All potential positions
exist without a year: Advent I–IV; Lent I–V and week 0 Wednesday–Saturday;
Holy Week including the Triduum; Easter I–VII and Pentecost VIII/Sunday;
Ordinary I–XXXIV; Advent 17–24 December; Christmas 25–31 December, 1–13 January
and Sunday positions. Sources may honestly be missing. January belongs to the
selected civil year. Christmas entries outside the actual Christmas season are
never resolved by guessing a nearby date. Dated Advent and Christmas ferias
cannot substitute for Sundays; explicit fixed Christmas Proper carriers keep
their source identity on Sundays.

### CalendarOccurrence

Inputs: entry, civil year, selected diocese and mode (`hours` / `readings`).
The year appears only after «Адкрыць у календары», initially the current year,
with current/next shortcuts and a numeric year grid. Flutter retains the app's
supported calendar navigation bounds, **2019–2050**, whereas Web supports
1583–4099. The pure resolver accepts 1583–4099; suggestions and navigation obey
Flutter's bounds. This is an explicit platform difference.

Outputs: `entryId`, `year`, `diocese`, `mode`, `originalDate`, `effectiveDate`,
`optionId`, `status`, `reason`, `canOpenHours`, `canOpenReadings`, `color`.
Feast placements come only from `OrdoEngine.plan`, including removed placements,
year overrides and transfers. The resolver checks the effective date through
Ordo even when a transfer crosses a year boundary; it cannot invent permission.
Periods match the exact semantic identity in `engine.year`, then use the actual
legal option ID (including merged temporal identities and Christmas carriers).

| Status | Meaning |
| --- | --- |
| `primary` | Primary legal option for the requested mode. |
| `legal-alternative` | Other legal option for that mode. |
| `commemoration` | Only commemoratio; cannot open an independent Office/readings. |
| `transferred` | Legal option with different original/effective dates. |
| `suppressed/impeded` | Omitted, impeded, unavailable in the mode, or absent period position. |
| `not-applicable-in-diocese` | Definition absent/suppressed in the effective diocesan layer. |
| `no-content` | Confirmed absent source content; never permission to open a substitute. |

Hours checks `officeOptions`; Readings checks `options`. All Souls on a Sunday
has different Office/Mass sources; commemorations are not alternatives. The
source preview reports `no-content` separately from the rubrical occurrence
status so a missing yearless Proper does not claim that prescribed weekday
readings are missing. Source load errors mean unavailable, not confirmed absent.
The opening adapter revalidates the legal option ID immediately before routing;
an absent Hours assembly cannot fall back silently to the day's primary Office.

Nearest-year suggestions search forward, then backward at each distance, bounded
to ±12 years and the app's calendar range. Every suggestion is checked by Ordo in
the same diocese and mode. No substitute week/season/day is accepted.

### ContentPreview

`lib/services/catalog_preview_service.dart` reads real public documents from
ContentStore: `liturgicalProperTexts` first, legacy `days` second, explicit
fallback references, `_feast` selectors, real Common template IDs and available
seasonal variants. It does not call the Office assembler or contentForDate.
`current-day`, first-week and own-text markers are instructions, not prose.
Structured field rules are described without inventing a missing psalter.
Provenance (`collection/id`), available fields, instructions, missing IDs, read
errors, availability and content status are retained separately. Seasonal deltas
preserve inherited text, omissions and structured rules.

Readings reuse `selectReadingDocuments` and `collapseCoveredReadings`, preserving
all A/B/C and I/II documents and structured Mass sets/alternatives. A saint with
the same nominal date is not a substitute. Reference cycle display never updates
calendar selections. Unlike Web's remote transport, Flutter can enumerate the
already bundled in-memory readings collection; no remote collection fetch or
database write is introduced.

The source screen displays actual Proper/Common parts with HTML rendering,
source provenance, reading cycles and incompleteness notices. It explicitly says
that this is a reference view, not a complete Office for a calendar date. Missing
content is not replaced by the Sunday or another saint.

## User flow and navigation

«Па перыядзе» / «Па свяце» → entry card → two independent actions:
«Праглядзець тэксты» and «Адкрыць у календары». Year does not filter search.
Selected dioceses come from Settings; local entry context does not rewrite them.
The incoming Hours/Readings mode is carried throughout. Source preview uses a
normal back stack. On calendar selection the detail page returns the verified
occurrence to the picker, which pushes the existing production destination;
back restores the picker query/tab/scroll state. Source/cycle browsing does not
change the selected liturgical date.

The old `/hours/picker/options` and `/readings/picker/options` deep links now use
the same catalog detail and gates, preserving their branch mode. They no longer
run the competing legacy date calculation. The original Hours/Readings loaders,
Office assembly, navigation synchronization and Ordo legal-option algorithms
remain the authority for calendar content.

## Colors

Existing `VestmentMarker`, `VestmentColorLine` and `kVestmentColors` are retained:
albus white with neutral ring, ruber red, viridis green, violaceus violet,
rosaceus rose, niger black. Marian blue remains decorative. Date type never
determines color. Catalog color belongs to the selected celebration, including
suppressed Nicholas (albus); calendar segments still include only legal options.
Rank, type, color and occurrence status also appear in text.

## Audit path and fixtures

Audited UI → `pickerFeastsOfYear` / `pickerPositions` / `pickerExactDates` →
definitions/layers → engine/year plan/runtime → content service/ContentStore →
Hours and Readings navigation adapters and production router. The defect was
the year list excluding impeded celebrations. `liturgical_day_options_screen`
was a competing legacy route and has been moved onto the shared catalog flow.
Existing calendar sheet, vestment markers, Office and day-flow tests were read.

`test/fixtures/liturgical-catalog-occurrences.json` is copied from the exact Web
commit above. Every expected field is asserted against the actual bundled Flutter
engine for **both** modes, not regenerated from the result being tested.

| Entry / year | Engine evidence |
| --- | --- |
| Nicholas, 2026, Minsk and Grodno | 2026-12-06, suppressed/impeded, no independent Hours/Readings, albus. |
| Nicholas, 2027, Minsk | 2027-12-06, legal-alternative, both modes legal, albus. |
| Nicholas, 2027, Grodno | Suppressed by `grodno-cathedral-dedication`; neither mode legal. Does not inherit Minsk permission. |
| Annunciation, 2027 | Transfer 2027-03-25 → 2027-04-05. |
| Casimir, 2026 | Commemoration, neither independent route legal. |
| Advent IV Saturday, 2026 | No date; no guessed fallback. |
| Ash Wednesday / Good Friday, 2026 | Exact merged Ordo identities and correct colors. |
| Christmas January 1, 2026 | 2026-01-01, correct fixed carrier. |

Nicholas's actual `06-12-sv-nicholas` Proper and `pastors` Common are checked in
the bundled data and displayed in widget tests independently of suppression.
Additional tests cover diocesan suppress/add/modify, all 34 Ordinary weeks,
fixed/movable classification, missing sources, unchanged legal alternatives,
All Souls mode split, exact period matches, source UI, production navigation,
back state and narrow light/dark layouts at 200% text.

## Validation and limitations

Android/iOS live tests: **NOT TESTED**; `flutter devices` reports only Windows,
Chrome, Edge. Native smoke is required before a mobile release; none is being
published here.

Chrome visual smoke: **NOT TESTED / BLOCKED**. The isolated entry point
`tool/liturgical_catalog_smoke.dart` was compiled and launched successfully with
`flutter run -d chrome -t tool/liturgical_catalog_smoke.dart --web-port 5241`.
It reads the real bundle in an isolated local Hive namespace, disables runtime
font fetching and content updates, and never initializes Firebase. It uses the
production picker and destination routes. Optional query parameters are
`?dark=1&scale=2&width=320&mode=readings`. The expected local URL is
`http://localhost:5241/`; no production browser or Firestore data is used.

Computer Use's automatic safety check stopped the first Chrome window capture
because it could not determine the current browser URL confidently. No further
browser input was attempted, no screenshot was obtained, and no visual success
is claimed. In accordance with AGENTS.md, compilation and widget checks do not
replace this missing visual check. This is a reason to keep the PR draft.

The production-navigation regressions also exposed an existing Readings scroll
reset that could call `jumpTo` before viewport extents were initialized. The
small guard in `readings_screen.dart` checks mounted/content dimensions; the
actual production navigation tests cover that trigger.

Production network overlay completeness is not exhaustively audited; tests use
the real bundled publication plus injected source/definition cases. No release,
beta, deployment, migration or merge is part of this change.

Final targeted verification:

```powershell
dart format lib/ordo/liturgical_catalog.dart lib/services/catalog_preview_service.dart lib/screens/catalog_entry_screen.dart lib/screens/catalog_year_selector.dart lib/screens/liturgical_picker_screen.dart lib/screens/liturgical_day_options_screen.dart lib/screens/readings_screen.dart lib/router/router.dart test/liturgical_catalog_test.dart test/ordo_picker_test.dart test/ordo_day_flow_test.dart test/ordo_visual_test.dart tool/liturgical_catalog_smoke.dart
flutter test --no-pub test/liturgical_catalog_test.dart test/ordo_day_flow_test.dart test/ordo_picker_test.dart test/ordo_visual_test.dart --reporter expanded
git diff --cached --check
```

All **107 targeted tests passed**, including 40 catalog/source tests, real
production Hours and Readings routes with back navigation and preserved Vitebsk
context, and the existing visual/layout matrix (320, 360, 390, 430, 834px;
light/dark; 100%, 140%, 200% text). These are widget/layout checks, not a Chrome
visual smoke. All 12 portable Web fixtures pass in both modes. Formatting and
staged whitespace checks pass. `flutter pub get` succeeded using the existing
lockfile; pubspec/lockfile have no diff.

`flutter analyze --no-pub lib test tool/liturgical_catalog_smoke.dart`:
**No issues found**. A preceding whole-workspace `flutter analyze --no-pub`
found only a dangling library-doc comment on the new smoke entry point; adding
the explicit library declaration fixed it. A prior analysis before that entry
point was added also passed. No analyzer diagnostic was disabled.

`flutter test --no-pub --reporter expanded`: **INCOMPLETE, NOT GREEN**.
The broad run was stopped after roughly 18 minutes, with **618 passed, 1 skipped,
5 failed** already reported and remaining long-running parity checks unfinished.
These counts are an observed partial run, not a final suite total. The failures
were:

- `test/analytics/transport_and_guard_test.dart`, “stage guard: only main.dart
  reaches local_analytics”: compares Windows `lib\\…` paths with `lib/…`; the
  analytics-directory exclusion and expected main path do not match. That test,
  analytics sources and main.dart have no diff from origin/main.
- Four 30-second timeouts in unchanged `test/content_offline_test.dart`, under
  “corrections and app releases”: v101 wrong text returning to the bundled text,
  v102 third text, older patch/newer bundle, and a bundle absorbing patches.
  Timeout cleanup was followed by “Box has already been closed” errors. These
  observed failures are retained; no assertion or timeout was weakened.

Follow-up isolation:
`flutter test --no-pub test/content_offline_test.dart --plain-name 'corrections and app releases' --reporter expanded`
passed **all 5 tests** in that group, including the four cases that timed out in
the broad run, with their original assertions/timeouts. A preceding isolated
`--plain-name 'v101 wrong text'` run also passed. This supports a broad-run load /
timeout explanation, but does not turn the incomplete full run green. After the
final catalog metadata change, all 40 catalog/source tests passed again.

The complete broad suite and the outstanding visual/native checks remain
acceptance work. This draft does not claim completed cross-platform acceptance.

Changed files:

- `lib/ordo/liturgical_catalog.dart`: catalog and Ordo occurrence adapter.
- `lib/services/catalog_preview_service.dart`: independent source reader.
- `lib/screens/catalog_entry_screen.dart`, `catalog_year_selector.dart`:
  entry/calendar details, source display and responsive year selection.
- `lib/screens/liturgical_picker_screen.dart`: year-independent tabs and guarded
  calendar adapter; `liturgical_day_options_screen.dart` and `lib/router/router.dart`:
  legacy deep links use the same implementation and preserve mode.
- `lib/screens/readings_screen.dart`: initialized-viewport guard for scroll reset.
- `test/liturgical_catalog_test.dart`, the shared JSON fixture, and existing
  `ordo_picker_test.dart`, `ordo_day_flow_test.dart`, `ordo_visual_test.dart`:
  unit/source/parity/layout/navigation regression coverage.
- `tool/liturgical_catalog_smoke.dart`: isolated reproducible Chrome entry point.
- This document: contract, audit, expected occurrences, validation and limitations.
