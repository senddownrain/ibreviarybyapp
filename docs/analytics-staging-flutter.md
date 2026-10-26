# Flutter → QA staging (R04)

Continuation of P01/P04/P07 (Dart collector, hooks, mock) and of the WEB staging contract
(`mybrev` `docs/analytics-staging-contract.md`, R02). Engineering only: no legal conclusions;
real collection from users stays **OFF** until a separate release card.

## Gate (compile time, fail closed)

Sending exists only when **all** are given at build time:

```
--dart-define=ANALYTICS_LOCAL=true
--dart-define=ANALYTICS_STAGING=true
--dart-define=ANALYTICS_STAGING_URL=<https://… or http://127.0.0.1:PORT>
```

Without any one of them `kAnalyticsStagingActive` is a `false` constant: no sender is built, the
address does not exist in the binary (it comes only from `--dart-define`), no socket is opened.
CI runs `flutter test test/analytics` in this state. URL rules (`parseStagingUrl`): `https`, or
plain `http` to loopback only; no credentials, query or fragment; path is fixed to `/v2/ingest`.
No secret is involved; the server's report/admin tokens are never in the app.

## Behaviour

* Batch-only: when the app goes to background, counted days are **drained** from memory
  (`AnalyticsCollector.drainPackets`), the removal is persisted to the Hive box, and only then each
  packet is POSTed once (`HttpStagingTransport`, `Content-Type: application/json`, no other
  headers of our own, no cookies, redirects not followed, 10 s timeout).
* **At-most-once**: any outcome except `204` (error, timeout, 4xx/5xx) is a loss; never retried.
* Packets older than 2 UTC days are dropped before sending (server `day_out_of_range`).
* Packet > 16 KiB is never sent. Local queue ≤ 64 KiB / 14 days (existing `LocalAnalytics`).
* Kill switch: `503` (`ingest_disabled`, …) or `426` halts the sender for the rest of the process
  and clears held counts (no queue is kept for a disabled server). Server side it is
  `INGEST_ENABLED` / `POST /v2/admin/ingest`; client side it is simply not building with the flags.
* No consent screen or checkbox. `consent_mock.dart` is not mounted anywhere (guard test).
* No new permissions (`INTERNET` already declared), no ATS exceptions (`dart:io` sockets are not
  subject to ATS and Info.plist is unchanged), no advertising SDK, no identifiers.
  `PrivacyInfo.xcprivacy` and Play declarations are **not** changed by this stage.

## Run it (3 steps)

1. Server (from the `mybrev` R02 branch): `INGEST_ENABLED=true REPORT_TOKEN=$(openssl rand -hex 24) ADMIN_TOKEN=$(openssl rand -hex 24) node experiments/analytics-ingest/worker/local-server.mjs --db /tmp/mybrev-staging.sqlite` (127.0.0.1:8788).
2. Android emulator: `adb reverse tcp:8788 tcp:8788`, then
   `flutter run --dart-define=ANALYTICS_LOCAL=true --dart-define=ANALYTICS_STAGING=true --dart-define=ANALYTICS_STAGING_URL=http://127.0.0.1:8788`.
   iOS Simulator: the same command (the Simulator shares the Mac's loopback; no `adb reverse`).
3. Open Утрань / a reading / a short song, change theme or font size, add a favorite, send the app
   to the background, then read the SQLite (`cell_counts`): rows with `platform=android|ios`.

## Tests

```
flutter analyze --no-fatal-infos
flutter test test/analytics
flutter test --dart-define=ANALYTICS_LOCAL=true test/analytics
# against the real Worker code (R02 local server running):
flutter test test/analytics/staging_http_test.dart --dart-define=R02_URL=http://127.0.0.1:8788 [--dart-define=R02_ADMIN_TOKEN=…]
```
