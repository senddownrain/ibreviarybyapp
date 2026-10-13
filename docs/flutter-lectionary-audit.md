# Flutter Lectionary audit: parity with the web, delivery, rendering

Branch `audit/flutter-lectionary` (from origin/main `2986cae`). Web reference:
mybrev `main` = `e2deccc` (`docs/lectionary-full-audit.md`), dataset
`readings@1e8aadb3fc05e137` (production snapshot `20261012171555724`,
manifest v3). Machine-readable result: `reports/flutter-lectionary-parity.json`.
Flutter SDK for every number below: 3.41.4 (`~/.cache/flutter-3.41.4`).

## Verdict (not a 100 % claim)

* Lookup, selection and structured content of the Readings screen equal the
  web's for **20 717 legal Mass options** (16 068 date x diocese pairs, 2025-2035,
  four dioceses): 0 mismatches in groups, canonical document, all 2 118 set
  entries (ids, labels, contexts, defaults, reference-only, cycles), selected
  set, cycles and **154 814 rendered sections compared by a hash of their full
  content**. 172 deliberate, documented differences remain (below).
* Not complete, by design: the web audit still has 323 identities whose text
  differs from Catholic.by in production, the resync is **not applied**; 9
  planned options have no document upstream; the app bundle is 75 documents
  behind the published manifest. Nothing here repairs source text.

| Status | Options | Meaning |
|---|---:|---|
| OK | 17 864 | equals the web, content current on an updated phone |
| BUNDLE_STALE | 2 784 | equals the web once the manifest patch is installed; a fresh offline install shows the older text of 75 documents |
| REFERENCE_ONLY_EXPECTED | 60 | citations only (cathedral dedications, Lahishyn, Trakai, ...), never invented text |
| UPSTREAM_MISSING | 9 | no readings document upstream (Budslav outside Minsk, 24.06 vigil set, ...) |
| WRONG_LOOKUP / WRONG_DEFAULT / BAD_RENDER | 0 | after the fixes below |
| OVERLAY_STALE | n/a | not observable on a device; the mechanism is tested (below) |
| NOT_VERIFIED | see below | iOS device, real Firestore, Android release run |

## Method

1. `scripts/lectionary/build_parity_fixture.mjs` runs the web's own pipeline
   (`planReadings -> readingQueriesOfPlan -> orderReadingsByPlan ->
   resolveReadingsScreen`, plus the Hours `dayId` of each option) on the
   production snapshot and writes `test/fixtures/lectionary_parity.json.gz`.
   Read-only on the web checkout; output only into this repo.
2. `test/lectionary_parity_test.dart` runs the **app's own loader**
   (`loadReadingsForDate` + `resolveDefaultReadings`, the code of the screen) on
   the content an updated phone has (bundle + the real manifest patch) and
   compares per option; it also compares the Readings root without a chosen
   celebration against the web default.
3. `test/fixtures/ordo_parity.json.gz` regenerated from web main for
   2025-2035 (`build-flutter-parity-fixture.mjs`, 16 068 days). Ordo, Hours
   (assemblies) and reading-reference parity: 0 mismatches.
4. `test/lectionary_delivery_test.dart`: the real published manifest vs bundle.

Regenerate: `node scripts/lectionary/build_parity_fixture.mjs --web ../mybrev
--snapshot <dir> --out test/fixtures/lectionary_parity.json.gz`,
`node scripts/lectionary/build_delivery_fixture.mjs ...` (same flags + `--bundle
assets/content`), then
`LECTIONARY_REPORT=reports/flutter-lectionary-parity.json FLUTTER_HEAD=<sha>
flutter test test/lectionary_parity_test.dart`.

## What was wrong locally (all fixed)

| # | Defect | Path | Example |
|---|---|---|---|
| 1 | WRONG_LOOKUP: the Readings loaded every document of the date by date/period/feast index, not the engine's plan | `ParsedReadingsService.cachedForDate` | 1 May: the Pinsk cathedral dedication (reference-only) was offered in Minsk; 1 Jan offered the weekday readings of a solemnity; 4 Jan/5 Jan offered the obsolete `christmas-05-01--sunday` |
| 2 | WRONG_LOOKUP: web engine fixes not ported: Sundays in date-keyed windows (20 dates, 80 pairs) and Christmas Vigil on a Sunday 24.12 (2028, 2034) | `ordo/candidates.dart`, `ordo/readings_plan.dart`, `selectReadingDocuments` | IV Advent 2025-12-21 opened `advent-21-12` instead of `advent-w4-d1--A` |
| 3 | WRONG_LOOKUP: the Hours day id linked and ADDED the seasonal date document of a Sunday | `resolveDefaultReadings`, now plan-only + option tag first | same 20 Sundays (the web's Hours -> Readings route has the same defect in 1 265 option routes; the web date picker route is correct) |
| 4 | WRONG_DEFAULT: wrong Sunday/weekday cycle when Christmas is a Sunday (Advent I 2033-11-27 showed year B instead of C) | `utils/liturgical_cycle.dart`; the loader now takes the engine's `readingCycle` | 27.11.-03.12.2033 |
| 5 | BAD_RENDER: «Або» second readings of flat documents were dropped (Holy Name of Mary 12.09, Our Lady Mother of Mercy 16.11 lost Gal 4,4-7) | `ParsedSection` had no `alternatives` | now kept (also conclusion, rubrics, passion, form, year, altChorusRef) |
| 6 | Hours day screen subtitle joined the citations of every cycle and celebration | `hora_picker_screen.dart` | now the citations of the reading the screen opens |
| 7 | Group key differences (`normalizeRank`, places, `normalizeReadingTitle` used `\b` that never matches Cyrillic) | `reading_groups.dart` | ported |
| 8 | New section fields not parsed/rendered: `year`, `form`, `altChorusRef`, set `prayers`, `preface` | `models/mass_reading_sets.dart`, `readings_screen.dart` | rendered (form label, refrain citation, rubrics, prayers); `year` is kept, not filtered (as the web) |

## Differences kept on purpose (172 cases)

* **Memorials open the weekday readings first** (140 cases; optional memorials
  that have their own document: John Paul II 22.10, Martin de Porres 03.11,
  Clement 23.11, Andrew Bobola in Grodno, ...). The web date-picker route
  `?option=<memorial>` opens the memorial's own readings. The app keeps its
  tested product rule (weekday-first, own readings one tap away); **owner
  decision needed** whether an explicitly chosen memorial should open its own.
* **`ordinary-w28-d1--A` Gospel citation** (32): Catholic.by prints «Мк 22,
  1-10» under «паводле Мацвея»; the app shows «Мц 22» (existing local
  correction). Web should correct the document.

## Readings plan: `readings_plan.dart` vs `readings.js`

`common` lookups are dropped by the engine plan itself (web `planReadings`
filters them) and the Readings never used them. The vigil descriptor
(`vigilLookup`) is not used by the screen: vigils are sets of the canonical
documents. The Chrism/evening split is the `holyweek-w1-d5` sets. The one real
gap was the Sunday-24.12 lookup (fixed). Lookup lists are asserted equal to the
web's through the identical documents/groups of every option.

## Delivery chain (readings)

* Bundle: contentVersion 1791397285761, 822 documents, digest `6025a2f6...`
  (hashes self-consistent). Manifest v3 / production: `1e8aadb3fc05e137`.
  **BUNDLE_STALE: 75 documents** (66 differ only in paragraph layout; 9 in
  content: `12-09-holy-name-mary-minsk-mohilev-pinsk`,
  `16-11-our-lady-mother-mercy-minsk-mohilev-pinsk`, `25-01-conversion-saint-paul`,
  `advent-24-12--christmas-vigil`, `feast-palmsunday--A/B/C`, `lent-w4-d1--A`,
  `ordinary-w27-d5--2`).
* An installed phone with network gets exactly those 75 documents as one small
  verified patch (not rebuild-sized), atomically; a second check is current;
  corrupted download, offline mid-update and a crash after every phase leave the
  bundle or the whole set, never a mix; an app update whose bundle contains the
  published documents drops the overlay (bundle wins); a newer overlay survives.
* Ordo collections (celebrations, overrides, year overrides, Proper texts,
  notes) are **not in the manifest** (held back): they reach phones only inside a
  bundle; today they equal production digests.
* The bundle is **not rebuilt** here: production still holds old-parser text
  for 323 identities and the web resync plan (321 documents, `reports/lectionary/
  resync-plan.json`) is unapplied; rebuilding now would ship text that must be
  rebuilt again. After the owner applies the resync and publishes, rebuild
  once (below).

## Rendering and layout

Tests: `lectionary_model_test` (parse + hash of every contract field, 320 px,
text scale 1x and 2x without overflow), existing `mass_reading_sets_widget_test`
(three sets at 320 px / 2x), `lectionary_policy_test` (closed policies on what
the screen resolves): 15.08 and 29.06 vigil+day default day, label «Св. Імша ў
вігілію»; 25.12 three sets default day; 24.12 evening; Sunday 24.12 Advent +
Vigil Mass; Holy Thursday evening; Good Friday; Palm Sunday procession/Mass
default Mass; Easter Vigil seven readings + epistle in order; Easter and
Pentecost sequences; Pentecost Saturday vigil default; Ascension A/B/C; All Souls
on Sunday with three sets; no cross-diocese leak of reference-only documents.
Choosing variants/sets/cycles keeps the options sheet open (it closes only with
its button or «find day»), covered by the set-selection widget tests.

Android emulator: see the end of this file.

## Open dependencies on the web (not decided here)

Budslav 02.07 readings restricted to Minsk (3 dioceses without readings);
Pentecost Saturday 2031-05-31 vs Visitation; 24.06 vigil/day set (policy by
analogy); `christmas-05-01--sunday` obsolete copy (the app no longer shows it);
`lent-w3-d1--B` has no long-form text in the source; the 323 identities with
old parser text (resync plan); the «Мк 22» citation; the Hours -> Readings
`?dayId=` route of Sundays; whether an explicitly chosen optional memorial opens
its own readings.

## Preparing updated builds

* Android: `export PATH="$HOME/.cache/flutter-3.41.4/bin:$PATH"`, then
  `flutter build appbundle --release` (or the beta workflow, now pinned to
  3.41.4). iOS (on the release Mac only): the same SDK via
  `FLUTTER=$HOME/.cache/flutter-3.41.4/bin/flutter bundle exec fastlane ios`
  (docs/RELEASE_BETA.md). No store release was made or triggered.
* Content: after the web owner applied the resync and published the manifest,
  rebuild `assets/content` from the verified export with the web's
  `npm run content:app-bundle` (see mybrev `docs/app-content-distribution.md`),
  regenerate `lectionary_delivery.json.gz`, run `flutter test`.
