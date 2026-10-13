# Web <-> Flutter Lectionary synchronization (final report, 2026-10-13)

## Heads

| Repo | Head |
|---|---|
| web (mybrev, read-only) | `2c56a93` (main) |
| Flutter (this worktree, branch `sync/flutter-web-final`) | base `e2643a4` (origin/main), see `git log` for the commits |
| Flutter SDK | 3.41.4 (`~/.cache/flutter-3.41.4`) |

## Data

* Production Firestore snapshot `20261013074043449` (read-only `db:backup`),
  bundle built with `npm run content:app-release` (compare-live: "bundle =
  published manifest"; NEW IN THIS RELEASE warning for the held-back
  `liturgical*` collections, compendium and compendiumMeta).
* `readings`: manifest v7, digest `93314983ba9c1bd5`, contentVersion
  1791875455429; bundle contentVersion 1791877294111, 822 documents, digest
  equal to the manifest; hashes of all 822 documents equal the manifest.
* All 324 rewritten documents (321 resync + `24-06-nativity-john-baptist`,
  `06-08-transfiguration-lord`, `ordinary-w28-d1--A`) are in the bundle with the
  after-hash of the web apply plan (`lectionary_delivery_test`).
* Compared with the previous bundle (2026-10-07): 363 of 822 readings
  documents changed. Other collections: Ordo/days/templates unchanged; prayers
  117 -> 115 documents and prayerCategories changed (production state of the
  web prayer-storage work, shipped as published).

## What changed in Flutter

1. `lib/ordo/memorial_readings.dart`: registry of 12 prescribed proper
   memorials (Budslav only in Pinsk) and `memorialReadingsRule`.
2. `readingsLookupOf` (diocese-aware): memorial lookup order `[proper, weekday]`
   when prescribed else `[weekday, proper]`; `OptionReadingsPlan.defaultPurpose`;
   Pentecost Saturday lookup `_variant: pentecost-vigil` when a feast takes the
   day; `selectReadingDocuments` honours `_variant` in period lookups.
3. `orderReadingsByPlan` tags each document with `ordoOptionRoles`; the Hours
   `dayId` link only adds documents the plan offers.
4. `resolveDefaultReadings`: the option opens its default group (role
   `default`), then the first tagged group; memorials now pass their option id
   (the weekday-first special case is gone).
5. Local Мк 22 -> Мц 22 correction removed; tests assert the bundle holds Мц.
6. Fixtures regenerated from web main + production snapshot: `ordo_parity`
   (2025-2035, 16 068 days), `lectionary_parity` (20 717 options),
   `lectionary_delivery` (now with the old-bundle scenario and the 324 ids).
   `scripts/lectionary/build_delivery_fixture.mjs` gained `--old-bundle` and
   `--applied`.
7. Tests: `memorial_readings_rule_test` (every memorial option 2025-2035 x 4
   dioceses: 7 215 options, 56 celebrations weekday-default with own readings
   as alternative, prescribed ones open proper), policy tests for 24.06, 06.08,
   Pentecost 2031, 22.10, Budslav; delivery tests re-run on the new data.

## Results

* `flutter analyze`: clean. `flutter test`: all green (811 tests; includes
  `ordo_parity`, `hours_parity` and reading-reference parity with 0 mismatches
  over 2025-2035 x 4 dioceses).
* Readings parity: 16 068 date x diocese pairs, 20 717 options, 2 382 sets,
  155 466 sections, **0 mismatches**.

| Status | Options |
|---|---:|
| OK | 20 648 |
| REFERENCE_ONLY_EXPECTED | 60 |
| UPSTREAM_MISSING | 9 |
| BUNDLE_STALE, OVERLAY_STALE, WRONG_LOOKUP, WRONG_DEFAULT, BAD_RENDER | 0 |
| NOT_VERIFIED | iOS device, real Firestore client run, Android release run |

Memorial classification (web `memorials.json`, 203 celebrations): 56 weekday
default + own alternative, 7 prescribed with document, 5 prescribed without
document, 135 weekday only (the task text said 8/4/136: the web report now
counts 7/5/135). The Flutter test confirms the 56 and that prescribed
memorials open their proper group. The former 140 "weekday-first" cases are
no longer special: they are the general weekday-default rule and equal the web.

## Delivery scenarios (real Dart client code)

* Current bundle: check = `current`, nothing downloaded.
* App with the OLD 2026-10-07 bundle: patch of exactly 363 documents of 822
  (44.2 %), not rebuild-sized (guard: more than 50 % of the collection or 12 MB);
  apply gives digest `93314983ba9c1bd5`, second check `current`; corrupted
  download changes nothing; offline mid-update keeps the bundle; interrupted
  after staged/ready/written never yields a mix; an app update with the new
  bundle drops the overlay; a newer overlay survives.

## Still depends on the web owner

Not worked around in Dart (see `reports/lectionary/pending-authorization.json`):

* `budslav-link`: `_dayIds` on `02-07-our-lady-budslav-minsk`; until then Pinsk
  (prescribed memorial) has the rule but no linked document.
* `lent-w3-d1-B-first-reading` (long form text missing in the source).
* `christmas-05-01--sunday` obsolete copy; `christmas-w1-d5/6/7` unsourced.
* 5 memorials with prescribed proper readings without a document;
  9 options without an upstream document.
* The six `liturgical*` Ordo collections stay out of the manifest (bundle only).

## Preparing builds (not run, no release triggered)

```
export PATH="$HOME/.cache/flutter-3.41.4/bin:$PATH"
flutter pub get
flutter analyze && flutter test
# Android: flutter build appbundle --release
# iOS (release Mac): FLUTTER=$HOME/.cache/flutter-3.41.4/bin/flutter bundle exec fastlane ios
```
