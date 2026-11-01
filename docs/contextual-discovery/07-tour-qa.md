# Stage 6 — Product Tour: QA

Base: `claude/cd-stage2-engine` (`5a60857`). Code: `lib/discovery/tour/`, thin hooks in
`lib/widgets/app_shell.dart`, `lib/screens/settings_screen.dart`,
`lib/discovery/discovery_coordinator.dart` (`automaticBlocked`).

## Behaviour

| Rule | Implementation |
|---|---|
| Invitation once, quiet | Small card above the dock after 1.5 s of calm on a section root. No scrim, no barrier. |
| Conditions | `tourStatus == not_offered`, hints on, section root, dock visible, shell is the top route (no sheet/dialog/menu), no keyboard, not scrolling, no automatic hint on screen. |
| Never nags | The offer is stored as `declined` the moment it is shown. Ignoring it, leaving the screen, killing the app: no repeat. |
| Tour | 6 steps (sections, date, text size, variants vs cycles, Bible/Prayerbook, repeat tour). «Далей», «Назад» (not on step 1), «Прапусціць», «Гатова» on the last step, progress «N з M». |
| Missing anchor | Step is dropped, progress recounted (`N з M` over steps really shown). Waits 0.7 s in place, 2.5 s after a section switch. |
| Context | Section switches only when a step needs another section (never `goBranch(initialLocation)` on the section the person is in). The origin section is restored on finish/skip/back. Date, diocese and reading settings are never touched. |
| Not parallel | While the invitation or the tour is up, `DiscoveryCoordinator.automaticBlocked` and `tourStatus == in_progress` stop automatic hints; the tour does not start with a keyboard, modal or hint on screen (manual start retries for 3 s). |
| Manual tour | «Налады → Як карыстацца дадаткам». Works with hints off and after «Не зараз»; writes no hint record and no quota stamp. |
| Settings | «Паказваць падказкі» switch, «Як карыстацца дадаткам», «Скінуць падказкі» (confirm dialog; clears only hint records and quota stamps, keeps switch, tour status, session count and all other Hive data). |
| Cut-off run | A persisted `in_progress` found at launch becomes `skipped`; never resumed, never re-offered. |
| Back button | System back during the tour = skip. |
| Accessibility | Card is a route scope with a name («Тур па дадатку, крок N з M»), header and progress nodes, labelled buttons, a screen-reader announcement per step; the app behind is blocked from semantics (`BlockSemantics`). Text scrolls inside the card, buttons stay pinned (200 %). |
| Off switch | `tourEnabledProvider` = `HiveService.isSettingsReady`; widget tests without Hive do not touch the discovery box. |

## Automated tests

`test/discovery/tour_test.dart` (22 tests): policy (first-run/declined/skipped/completed/in-progress,
hints off, reader, busy), invitation (first run, restart, keyboard, dialog, reader, no dock,
coordinator block), tour (six steps + restore, back/«Гатова», skip + restart, cut-off run,
missing anchors, only-dock, anchor lost mid-step, system back, manual with hints off and after
«Не зараз» without touching quota, manual waits for keyboard), looks (200 % on 360×640, light and
dark; semantics), settings (switch, cancel/confirm reset, manual start).

Commands (`/Users/gleb/.cache/flutter-3.41.4/bin`):
`flutter test test/discovery` → 86 passed; `dart format --set-exit-if-changed` clean;
`flutter analyze` → 12 infos, none in changed files (baseline: `pastors_hymn.dart`,
`consent_mock_test.dart`, `reading_choices_test.dart`). Full suite: run file by file (a single `flutter test` run was cut by external SIGTERMs of `flutter_tester` from other sessions) — 119 of 119 test files pass, 0 failed.

## iOS Simulator (cd-s6-iphone, iPhone 16, iOS 18.6, fresh profile, debug build)

Date used: 2026-10-31 (Saturday, XXX week), diocese Мінска-Магілёўская (defaults).

| # | Step | Result | Evidence |
|---|---|---|---|
| 1 | Fresh install, Hours | Invitation card, nothing dimmed | `ios-01-invitation.png` |
| 2 | «Не зараз» | Card gone; menu, scrolling, settings work | — |
| 3 | «···» → «Налады» → «Падказкі» | Switch on, tour row, reset row | `ios-02-settings-hints.png` |
| 4 | «Як карыстацца дадаткам» | Settings closes, step 1 з 6 on the dock | `ios-03-tour-step1.png` |
| 5 | «Далей» | Step 2 з 6 on the calendar button, «Назад» appears | `ios-04-tour-step2.png` |
| 6 | «Далей» ×2 | Step 4 з 6 — switched to Чытанні, ring on «Іншыя варыянты» | `ios-05-tour-step4-readings-variants.png` |
| 7 | «Прапусціць» | Back on Літургія, no scrim | `ios-06-after-skip-back-on-origin.png` |
| 8 | Dark + Dynamic Type AX2 (≈200 %) | Settings readable; tour card fits, buttons visible | `ios-07-…`, `ios-08-dark-200pct-tour-step1.png` |
| 9 | Restart app (wait >1.5 s) | No invitation, no tour | `ios-09-restart-no-invitation.png` |
| 10 | «Паказваць падказкі» off | Switch off | `ios-10-hints-off.png` |
| 11 | Manual tour with hints off | Starts, 1 з 6 … 5 з 6 (Біблія і Малітоўнік, both tabs ringed), 6 з 6 «Гатова» | `ios-11-…`, `ios-12-tour-step6-done.png` |
| 12 | «Гатова» | Back on Літургія, no scrim | `ios-13-tour-completed-back-on-origin.png` |

Observed on this run: step 3 («···», text size) was not captured on a screenshot; the steps
counted 1 з 6 → 2 з 6 → 4 з 6 in the first run because two taps were sent between screenshots.

### Not covered / honest gaps

- **Video:** `simctl io recordVideo` did not produce a file in this environment; screenshots only.
- **Automatic hints off on Readings:** this branch is based on Stage 2, which has no hint
  presenter (Stage 3/4 supply it), so "no coachmark with hints off" cannot be shown on screen
  here. The engine rule (`hintsEnabled=false` → no hint) is covered by the Stage 2 tests and the
  tour tests; re-check on the integrated build in Stage 7.
- **Rotation / backgrounding during the tour:** covered by unit-level re-measure (metrics change)
  only; not driven on the simulator.
- **Android:** NOT TESTED (the only AVD `MyBrev_Test_API34` belongs to the Android session).
  Stage 7 to run: invitation → «Не зараз» → manual tour → skip, hints switch, restart,
  TalkBack reading of the card, system back = skip.
- **VoiceOver on a device:** NOT TESTED (semantics asserted in widget tests only).

## Known follow-ups

- `anchor_finder.dart` (Stage 4) and `tour_anchor_finder.dart` do the same job with different
  matchers; merge them when Stage 4 lands.
- `main.dart`/`router.dart` must stay free of `discovery` per `qa_isolation_test` on this base;
  the tour needs no change there.
