# Picker navigation and Readings palette — audit 18.10.2026

Status: **Draft, not ready for release**. Base: `014b14a380aa29c2778a1cb0338cc94c52667148`
(fresh `origin/main`, PR #19). Branch: `fix/picker-native-navigation-and-readings-palette`.
The September Hours migration and `1ac88571de894d9fc6d2601b4b8b0d042dc82236` were
used as compatibility references; no reset/revert was made.

## Result and routes

* Hours feast search applies the legal date, assembly ID and temporary diocese
  through the existing controller, then pushes `/hours` and the existing Home.
  Office/Common choices stay in the existing selector.
* Readings feast search pushes `/readings?date=…&dayId=…&option=…&diocese=…`.
  Proper readings are selected through the reader's existing group state.
  Weekday readings require an AlertDialog confirmation; cancel retains search.
  The same explicit intent is checked when opening Readings from Home or Ora.
* `/hora/:date/:dayId` and `/hours/hora/:date/:dayId` redirect to
  `/hours?date=…&dayId=…&diocese=…`. The context is committed after build.
  Encoded IDs survive; unavailable IDs produce Home's empty state, not primary.
* A different legal year schedules one five-second SnackBar after navigation.
  Both years are dynamic. Beginning a sentence selection dismisses that notice
  so it cannot obstruct the palette.
* Feast cards use nominal fixed dates / actual movable dates and existing
  liturgical accents, including Marian blue with a white vestment marker.
* `HoraPickerScreen` and its navigation helper were removed. Home/Ora/Ordo,
  Readings and the existing option selectors were retained. Ordo priorities,
  period positions, the Christmas fix, Settings and bundled assets are unchanged.

## Palette lifecycle defect

`AppRouteEntryAdapter` resets an entry when its URI/document key changes.
Previously `BranchShellController.resetEntry()` removed the contextual bottom
slot even when the reused Readings widget still had `_selectedSentenceId` and
an open palette. With unchanged chrome mode this state change could also occur
without a shell notification. Reader state, dock ownership and painted chrome
then disagreed. A production AppShell/route-tree test reproduced broken dock
restoration after query normalization and applying a color.

The entry now retains its live slot; the reader releases it when selection
actually ends, including document changes and disposal. An inactive registered
owner can release its slot. Build-time releases publish after the frame.
PopScope handles pushed readers; BackButtonListener also handles the branch
root where GoRouter has no page to pop, and ignores inactive branches/entries.

The widget regression checks actual dock removal, palette hit testing, saved
Hive color, URI reuse plus a shell rebuild, cancel, system Back, date changes,
re-entry, ordinary readings, feast search and period search. It is not just a
boolean controller test. This establishes the code-level defect; acceptance
of the original APK symptom on Android remains unverified.

## Verification

Final completed command results are recorded below. Intermediate failed
runs are retained in the evidence directory and are not final pass results.

* `dart format`: `format.log` — 198 files, no additional formatting changes.
* Picker/navigation first pass: `picker-tests.log` — **62 passed**.
* Focused persistence pass: `palette-persistence-final.log` — **1 passed**.
* Root Back / Hours-to-Readings confirmation: `palette-back-final.log` — **2 passed**.
* `flutter analyze --no-pub`: `analyze-clean.log` — **No issues found**.
* Offline patch absorption retry: `offline-retry.log` — **2 passed**, with
  `--timeout=3m`; no assertion or production code was relaxed.
* Final acceptance: `acceptance-final.log` — **83 passed**, exit 0:
  `ordo_day_flow_test`, `readings_stage4_test`, `app_shell_state_test`,
  `ordo_picker_test`, `reader_navigation_test`, sequential execution.
* The broader run also exercised Bible, Prayerbook, Holy Mass, Songbook,
  shell restoration and offline content. Its intermediate failures are
  explained below; the affected tests subsequently passed in the final
  acceptance / offline retry. A complete repository-wide run was not made.
* Earlier broad regression: `regression-final.log` — 181 passed, 12 failed:
  one intermediate Back/re-entry test, nine isolated Readings tests requiring
  a router (the old `context.canPop()` assertion), and two 30-second offline
  patch-absorption timeouts. The first ten were subsequently addressed; the
  offline tests passed separately with a three-minute command timeout.

## Real Chrome screenshots and limits

Started with `flutter devices`, then real `flutter run --no-pub -d chrome
-t lib/main.dart --web-port 5237`. Exact tab URL: `http://localhost:5237/`.
Used real bundled content, with no synthetic production Firestore data.
Saved screenshots were opened and inspected:

* [Joseph, light, 390 px](../audit-evidence/picker-native-navigation/chrome-joseph-390-light.png):
  search `19.03`, visible `19 сакавіка`, gold accent, white vestment marker.
* [Nicholas on existing Home](../audit-evidence/picker-native-navigation/chrome-nicholas-home.png):
  `Св. Мікалая, біскупа`, actual `6 снежня 2027`, normal Hours rows.
* [Feast accents, desktop light](../audit-evidence/picker-native-navigation/chrome-feasts-desktop-light.png):
  Marian blue date tile/border and white vestment, next white celebration.

**Chrome visual smoke is PARTIAL, not complete.** Final matrix of dark theme,
320/390/430 px, 2x system text, scrolling/links, transfer date, readable year
SnackBar, missing-proper dialog and palette has not been visually accepted.
Initial browser/host resource pressure caused timeouts. A later Windows
Computer Use attempt was stopped by the tool because it could not determine
the browser URL confidently enough to enforce its policy. No further GUI
input was issued after that stop. Widget coverage does not replace these
missing visual checks. Reproduce with the command above and the routes listed.

## Native

**ANDROID NOT TESTED.** Pixel7_LiturgicalFinal was attempted, including a cold
boot. The first debug APK built, but installation did not complete. The
emulator later showed an OS ANR:
[System UI is not responding](../audit-evidence/picker-native-navigation/android-boot.png).
The final build/smoke attempt was stopped after this failure. There is no
accepted screenshot of Android Home, the palette, its saved color or Back.
Native smoke is required for this native dock bug and before release. Keep PR
Draft until a stable emulator/device completes all requested paths and screenshots.

**iOS NOT TESTED** — no iOS device/simulator on this Windows host.
No merge, beta, deployment, Firestore/bundle edit or store publication was made.
