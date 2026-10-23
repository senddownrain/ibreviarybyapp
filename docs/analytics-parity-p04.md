# Analytics v2 parity with WEB (P04)

The WEB repository owns the contract and the golden; see `docs/analytics-parity.md` in
`senddownrain/mybrev` for the guard design, the 27‑id `feature_use` table and the QA matrix.

Flutter side:

- `test/fixtures/analytics/analytics-parity-v2.json` — byte-identical copy of WEB
  `tests/fixtures/analytics-parity-v2.json`. Never edit here; regenerate in WEB
  (`node scripts/analytics/parity.mjs --write`) and copy.
- `test/analytics/analytics_parity_test.dart` — contract surface, content-id probes, 28 route cases
  (`mapLocation`), 16 synthetic visit scenarios on android and ios (`AnalyticsCollector`).
- `test/analytics/analytics_feature_coverage_test.dart` — 22/27 `feature_use` ids hooked through
  `analyticsFeature('<id>')`; `copy_use`, `install_prompt_open` NOT APPLICABLE; `search_open`,
  `search_submit`, `offline_update_apply` declared with a reason.
- P04 hooks (id only, no value, only with `--dart-define=ANALYTICS_LOCAL=true`): `date_pick`,
  `picker_open`, `hour_switch`, `hour_option_select`, `text_settings_open`, `chord_transpose`,
  `mass_section_nav`, `ordo_diocese_change`.

Run: `flutter test test/analytics` (and `flutter test`). Evidence: `docs/analytics-evidence/p04/`.
