# Flutter source-label acceptance — 2026-11-17

Flutter 3.41.4 / Dart 3.11.1; actual Google Chrome 157.0.8103.78 launched by Flutter, local URL http://127.0.0.1:5237/. Production reader and devotional office use an isolated provider harness; no Firebase initialization or production content queries/writes.

50 targeted tests passed (including 6 source tests), formatting passed. Analyze using the repository CI policy `--no-fatal-infos` passed: 29 pre-existing info messages, no errors or warnings, no diagnostics in changed modules.

Actual Chrome screenshots: ordinary and office, light 100% and dark 200%, 390 px. Source remains short; ordinary Scripture and link navigation preserved, office scrolling reaches source; no horizontal overflow. All eight captures were inspected through the representative ordinary and office views. `visual.json` records assertions and browser version.

Chrome's engine assets are fulfilled from the identical local SDK CanvasKit engine; bootstrap Roboto is cached. All other external app requests are blocked, including Firebase. CanvasKit/Roboto CDN availability is not assumed.

Reproduce after `flutter devices`:

```sh
flutter --suppress-analytics run --no-pub -d chrome -t tool/prayer_source_smoke.dart --web-hostname 127.0.0.1 --web-port 5237 --web-browser-flag=--headless=new --web-browser-flag=--no-sandbox
# Use this instance's actual --remote-debugging-port from its command line:
FLUTTER_CDP_URL=http://127.0.0.1:PORT FLUTTER_ROOT=/path/to/flutter SMOKE_ROBOTO=/path/to/cached/Roboto.woff2 node tools/capture_prayer_sources.mjs
```

The Node capture script uses sibling Web repo playwright-core or `PLAYWRIGHT_PACKAGE` pointing to a package.json with playwright-core. Native smoke was not needed for this shared reader change; required before a mobile release. No shipped bundle or manifest was published.
