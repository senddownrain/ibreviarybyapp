# Flutter full suite — 2026-10 (P02)

Base: `origin/main` `57c78b7`. Flutter 3.41.4, `flutter pub get --enforce-lockfile`.
Branch `test/p02-flutter-full-suite`. CI/workflow changes are NOT part of this PR
(they live in PR #31, `flutter-full-suite.yml`); this PR depends on #31 only for
a CI full-suite run.

## Baseline on main (before this PR)

`flutter test` → 3 failing tests (also on GitHub, run 39994362499, 22m36s).

## Failures → cause → fix / evidence

| # | Test | Class | Introduced | Root cause | Status |
|---|------|-------|-----------|------------|--------|
| 1 | `test/prayerbook_stage5_test.dart:457` overflow → «Катэгорыі» | STALE TEST | go_router API contract | The test read `routeInformationProvider.value.uri.path`; the current location is `routerDelegate.currentConfiguration.last.matchedLocation` (proven in P00: file passes after the swap). | RESOLVED (test expectation only) |
| 2 | `test/ordo_day_flow_test.dart` «Rosary memorial has default weekday and assembled Marian Office» | STALE TEST | `a5a0396` (PR #22, 2026-10-21) | A/B: passes at `04f6610` (parent), fails at `a5a0396` and `95b7e3d`. PR #22 added `_mainSection` support for the Marian Common (documented in `docs/common-office-web-parity.md`, "Поддержаны `_mainSection` марианского Common … согласно Web"): a memorial assembles the Common's main hymn (verified: assembled `officeOfReadingsHymn` == `_mainSection.officeOfReadingsHymn` == first hymn of the raw field; raw field holds 4 hymns separated by `<hr />`). The test still compared against the raw multi-hymn field. | RESOLVED (expectation now reads `_mainSection`; no data/lib change) |
| 3 | `test/lectionary_parity_test.dart` «Flutter Readings screen equals the web screen for every legal option» | **REAL REGRESSION (latent order-dependence exposed by a data refresh)** | `a5a0396` (bundle refresh) | 10 `route-day-id` mismatches, all Grodno / `our-lady-trakai` (dates 2025-07-10 … 2034): web `05-07-our-lady-trakai-grodno`, app `05-07-our-lady-trakai-grodno-memoria-ad-libitum`. `liturgicalProperTexts` contains two sparse docs for the same celebration/date/place (`…-grodno` rank `memoria`, `…-grodno-memoria-ad-libitum` rank `memoria-ad-libitum`). `_selectFixedDocuments` (`lib/services/liturgical_content_service.dart:903`) scores both with equal title similarity and keeps both; the first in bundle order wins. PR #22 re-exported the bundle and swapped the order of the two keys, so the app now picks the `-memoria-ad-libitum` doc. A/B, year 2026 only: 0 mismatches at `04f6610`, 1 at `a5a0396`. `documentedDifferences` stays 0. | STILL FAILING — owner decision needed (see below). Not fixed: content/liturgical selection is out of scope. |

### Owner / content description for #3

Two documents describe the same optional memorial of Our Lady of Trakai in the
Grodno diocese: `05-07-our-lady-trakai-grodno` (`_rank: memoria`) and
`05-07-our-lady-trakai-grodno-memoria-ad-libitum` (`_rank: memoria-ad-libitum`),
both `_celebrationId: our-lady-trakai`, `_date: 05.07`, `_place: grodno`. Web
route id uses the first. Either (a) mark the duplicate `_obsolete` in the
published export, or (b) give `_selectFixedDocuments` a deterministic tie-break
(e.g. prefer the doc whose `_rank` equals the Ordo option rank, then lexical id)
— a liturgical-selection decision, hence not changed here. Reproduction (one year
is much faster than the ≈4.5 min all-years run):

```bash
LECTIONARY_FROM=2026 LECTIONARY_TO=2026 flutter test test/lectionary_parity_test.dart
```

## Earlier iOS-QA failures (31, after `8751196`)

Not carried over unverified. On `main` `57c78b7` all five files pass in the full
run (see below).

| File | Reported | On main 57c78b7 |
|------|----------|-----------------|
| `readings_stage4_test` | 9 | NOT REPRODUCED (passes) |
| `mass_reading_sets_widget_test` | 10 | NOT REPRODUCED (passes) |
| `android_layout_lab_test` | 6 | NOT REPRODUCED (passes) |
| `liturgical_screen_smoke_test` | 4 | NOT REPRODUCED (passes) |
| `lectionary_model_test` | 2 | NOT REPRODUCED (passes) |

(Cause of the old failures not re-investigated; they simply do not occur on current main.)

## Results on this branch (local, macOS, Flutter 3.41.4)

See the table at the end of the PR description; raw logs in `audit-evidence/p02/`.

| Command | Result |
|---|---|
| `flutter pub get --enforce-lockfile` | PASS |
| `flutter analyze --no-fatal-infos` | PASS (exit 0) |
| `dart format --set-exit-if-changed lib test` | FAIL on 10 pre-existing files (see below); files edited here are clean |
| `flutter test` run 1 (7m50s) | +1401 ~1 -1 — only #3 fails |
| `flutter test` run 2 (9m39s) | +1401 ~1 -1 — only #3 fails (same) |
| `flutter test test/analytics` | PASS |
| `prayerbook_stage5_test`, `ordo_day_flow_test` alone | PASS |
| CI full suite on this SHA | NOT RUN — `flutter-full-suite.yml` is in PR #31 (unmerged); `flutter-pr-ci.yml` runs only targeted tests |

Pre-existing, not touched: `dart format --set-exit-if-changed lib test` reports
10 unformatted files on `main` (`bible_repository`, `about_screen`, `ora_screen`,
`prayers_screen`, `pastors_hymn`, `app_overflow_menu`, `text_scale_control`,
`app_overflow_menu_test`, `ordo_picker_test`, `pastors_hymn_test`), so a
repo-wide format gate cannot be enabled until a separate format-only PR.
The one skipped test is flag-conditional (`ANALYTICS_LOCAL`), not disabled.

## Rollback

Revert this PR: it only changes two test expectations and adds docs/logs.
