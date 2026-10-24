# P04 evidence (Flutter)

Base `origin/main` 57c78b7. Flutter 3.41.4 / Dart 3.11.1, macOS arm64.

- `parity.json` — output of `node scripts/analytics/parity.mjs --flutter <this checkout>` run from the WEB branch (problems: []).
- `flutter-test-full-summary.txt` — full `flutter test`: 3 failures, all known from P02 (ibreviarybyapp#32): two stale tests fixed there, `lectionary_parity_test` is an open content decision. None touch analytics.
- `flutter test test/analytics`: 51 passed, 1 skipped, 0 failed.
- `flutter analyze --no-fatal-infos`: 8 infos, all pre-existing (none in changed files).
