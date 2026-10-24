# P01 — sd=fit (Flutter), evidence
Base: origin/main 57c78b7. Flutter 3.41.4 / Dart 3.11.1, macOS. Flag: `--dart-define=ANALYTICS_LOCAL=true`.

Before (`before.log`): `fit_detection_test.dart` on unchanged code -> 6 pass, 1 FAIL:
"a text that ends within the screen is fit although the blank reserve ... scrolls by a few points":
view scrollable by 30pt (inside the 42+34pt bottom reserve), text fully visible, got `sd=p75_99`, expected `fit`.
After (`after_fit.log`): 7/7 pass. `after_analytics.log`: test/analytics 44 pass (no flag), 51 pass (flag).
Full `flutter test`: +1399 ~8 -3, the 3 failures are the same pre-existing ones
(prayerbook_stage5, ordo_day_flow, lectionary_parity), see `after_full_tail.log`.
Not tested: real iOS / Android UI (no device run in this stage); Chrome visual smoke not needed (no UI change; flag-only analytics glue).
