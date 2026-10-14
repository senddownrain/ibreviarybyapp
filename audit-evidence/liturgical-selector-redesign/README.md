# Liturgical selector evidence

The application is Flutter MyBrev. All calendar colors and options use bundled
Ordo/content data. The fixture for A/B/C is 11 October 2026; the fixture for
three Mass sets is 2 November 2025. No liturgical combinations were fabricated.

## Chrome: real browser screenshots

Captured by Flutter integration_test with the official Chrome WebDriver.
Each viewport was exercised in light/dark themes and with 150/200% text.
`widget-*.png` are a separate widget rendering matrix, not browser captures.

| Required state | Chrome screenshot |
|---|---|
| Hours, calendar collapsed | [390 px light](chrome-390-light-hours-collapsed.png) |
| Hours, calendar expanded | [390 px light](chrome-390-light-hours-expanded.png) |
| Month selector | [390 px light](chrome-390-light-month-picker.png) |
| Year selector | [390 px light](chrome-390-light-year-picker.png) |
| Office variants | [390 px light](chrome-390-light-office-variants.png) |
| Readings, two cycles | [390 px light](chrome-390-light-readings-two-cycles.png) |
| Readings, three cycles | [390 px light](chrome-390-light-readings-three-cycles.png) |
| Multiple Mass reading sets | [390 px light](chrome-390-light-multiple-mass-sets.png) |
| Ordo with alternatives and four dioceses | [390 px light](chrome-390-light-ordo-alternatives.png) |
| Ordo date-only calendar | [390 px light](chrome-390-light-ordo-date-only.png) |
| Narrow large text, calendar | [320 px, 200%](chrome-320-text-2-calendar.png) |
| Narrow large text, Ordo | [320 px, 200%](chrome-320-text-2-ordo.png) |
| Dark Hours | [360 px dark](chrome-360-dark-hours-collapsed.png) |

Completed Chrome results: [320 JSON](chrome-320-result.json),
[360](chrome-integration-360.log), [390](chrome-integration-390.log),
[430](chrome-integration-430.log), [800](chrome-integration-800.log).
[Successful flutter run -d chrome startup](chrome-retry.log) is recorded separately;
layout/interaction results come from the integration runs above.

## Android: native emulator

Native integration PNGs start with `android-<logical width>-system-text-...`.
Whole-device `adb screencap` PNGs start with `android-<font scale>-<navigation>-system-...`.
The latter include Android status/navigation bars. Both are captured from the
actual debug Flutter APK, not a browser. Font scaling uses Android settings.

Final Android results and links are recorded in
[the implementation report](../../docs/liturgical-selector-redesign.md#android-emulator).

| Native state | Whole-device screenshot |
|---|---|
| Hours collapsed, system bars | [100%, gesture](android-1.0-gesture-system-light-hours-collapsed.png) |
| Hours expanded, colors/today/selection | [100%, gesture](android-1.0-gesture-system-light-hours-expanded.png) |
| Month/year modes | [Months](android-1.0-gesture-system-light-month-picker.png), [years](android-1.0-gesture-system-light-year-picker.png) |
| Nested Office | [100%, gesture](android-1.0-gesture-system-light-office-variants.png) |
| Two/three reading cycles | [I/II](android-1.0-gesture-system-light-readings-two-cycles.png), [A/B/C](android-1.0-gesture-system-light-readings-three-cycles.png) |
| Multiple Mass sets | [100%, gesture](android-1.0-gesture-system-light-multiple-mass-sets.png) |
| Four dioceses and alternatives | [100%, gesture](android-1.0-gesture-system-light-ordo-alternatives.png) |
| Date-only Ordo | [100%, gesture](android-1.0-gesture-system-light-ordo-date-only.png) |
| Dark Hours | [100%, gesture](android-1.0-gesture-system-dark-hours-collapsed.png) |
| Large text | [150%, Hours](android-1.5-gesture-system-light-hours-collapsed.png), [150%, Ordo](android-1.5-gesture-system-light-ordo-alternatives.png) |
| Narrow large text and system navigation | [320 dp, 200%, threebutton](android-2.0-threebutton-320-system-light-ordo-alternatives.png) |

## Automated checks

- [Final targeted tests](final-targeted-tests.log)
- [Regression coverage: all 86 files](regression-summary.json)
- [117 tests after heading polish](heading-polish-tests.log)
- [842 completed tests and resource abort](regression-resource-interrupted.log)
- [89 remaining tests](final-regression-tests.log)
- [Earlier integration tooling analyze](integration-analyze.log)
- [Android debug build](android-debug-build.log)
- [Calendar/Hours stage](hours-tests.log)
- [Readings stage](readings-tests-sequential.log)
- [Ordo stage](ordo-tests.log)
- [Widget layout matrix](selector-matrix-final.log)

Early failures caused by disk exhaustion are retained as historical evidence
in `android-start.log` and `chrome-run.log`. They do not count as passing runs.
See the implementation report for the final results and any NOT TESTED cases.
The last Chrome repeat was stopped at the user's request:
[stopped run](chrome-final-320-user-stopped.log). Remaining repeats, focused
native screenshots and final analyze were skipped. Completed screenshots
predate the final selected-celebration heading fix; 117 widget tests cover it.
