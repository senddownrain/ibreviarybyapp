# Reader settings acceptance — 2026-11-07

Implementation: `f174dd8`, based on current Flutter `main` `19125bb`.
Web example contract: [MyBrev PR #202](https://github.com/senddownrain/mybrev/pull/202),
commit `38e94e65b2d944eb34b6c86ef761b1d5b28284cd`.

## Results

- **Visual:** 43 real Flutter Web frames and 2 additional live-reader frames;
  all reviewed through originals and the contact sheets. No browser page errors.
  [15 recorded visual assertions](visual-checks.json) passed, including actual
  font-family resolution, viewport dimensions, menu geometry and Ora isolation.
- **Live reading:** the same real public prayer retained its scroll offset when
  font family, size and alignment changed in an open sheet and after closing it.
  Settings immediately showed Old Standard TT / 20 dp (125%).
  [Recorded before/during/after state](scroll-preservation.json).
- **Fonts:** genuine bundled TTFs loaded with Google Fonts networking disabled;
  Belarusian `ўЎіІёЁ` and `†*` verified in every cmap.
  [Internal family names and SHA-256](fonts.json).
- **Analyzer:** 0 errors, 0 warnings, the same 27 existing info diagnostics as
  clean `main`; `flutter analyze` therefore retains the baseline nonzero status.
- **Targeted tests:** preference/typography/prose/settings checks (18), shared
  controls/menu matrix (87), Bible/keyboard/prayer-style regression group (38),
  exact Web example (3), final narrow header/keyboard checks (5), final prose
  guards (4): passed. These groups overlap and are not an aggregate count.
- **Full suite:** immutable checkout `f174dd8`: **1892 passed,
  9 skipped, 2 failed**. No new failures.
  Remaining baseline failures: `test/discovery/p0_hints_screens_test.dart`, `test/hours_parity_test.dart`.
  [Machine-derived result and error messages](test-results.json).
  Clean `main`: **1867 passed, 9 skipped, 2 failed** (`hours_parity` and the
  intermittent Readings date-navigation hint). The current run's failures are
  from that same baseline set. [Recorded mismatch comparison](baseline-comparison.json).

The final run used four workers and a two-minute default timeout for large local
bundle tests. Its code was isolated from documentation/artifact changes.
The unchanged offline content tests also passed separately on `main` (38 tests).
The analyzer retains the same 27 existing info diagnostics; [full output](analyze.txt).

## Screenshots

| State | Evidence |
| --- | --- |
| Settings, collapsed / expanded | [collapsed](after-settings-collapsed-393.png), [expanded](after-settings-expanded-393.png) |
| Five genuine font choices | [all five](after-settings-five-fonts-393.png), [Old Standard TT](after-font-oldStandardTT-393.png), [Kurale](after-font-kurale-393.png), [Literata](after-font-literata-393.png), [Source Serif 4](after-font-sourceSerif4-393.png), [system](after-font-system-393.png) |
| The same Web Psalm 63 excerpt | [breaks](after-psalmody-leftBreak-393.png), [indents](after-psalmody-leftBreakIndent-393.png), [alternation](after-psalmody-alternatingStanzas-393.png) |
| Compact wide psalmody selector | [768 dp](after-psalmody-wide-768.png) |
| Prose alignment / Ora unchanged | [start](after-reader-start-393.png), [justify](after-reader-justify-393.png), [Ora with justify selected](after-ora-justify-selected-393.png) |
| Reader / Ora sheets | [ordinary reader](after-sheet-reader-393.png), [Hours](after-sheet-ora-393.png) |
| Before / after menu | [before](before-overflow-393.png), [home after](after-overflow-home-393.png), [inside Hours](after-overflow-reader-393.png), [long real context action](after-prayerbook-overflow-393.png) |
| Before Settings | [before](before-settings-393.png) |
| Light / dark / Marian | [light](after-theme-light-393.png), [dark](after-theme-dark-393.png), [Marian](after-theme-marian-393.png) |
| 320 dp / 200% | [Settings](after-settings-320-scale2.png), [reader sheet](after-sheet-reader-320-scale2.png), [Ora sheet](after-sheet-ora-320-scale2.png), [menu](after-overflow-320-scale2.png) |
| 360 dp / 200% | [Settings](after-settings-360-scale2.png), [reader sheet](after-sheet-reader-360-scale2.png), [Ora sheet](after-sheet-ora-360-scale2.png), [menu](after-overflow-360-scale2.png) |
| Cupertino adaptation in Chrome | [Settings](after-ios-adaptation-settings-393.png), [sheet](after-ios-adaptation-sheet-393.png) |
| Other real readers | [Bible](after-bible-justify-393.png), [Readings](after-readings-justify-393.png), [Prayerbook](after-prayerbook-justify-393.png), [Mass](after-mass-justify-393.png) |
| Live update | [sheet over scrolled prayer](after-live-sheet-reader-font-393.png), [synchronized Settings](after-live-settings-font-393.png) |

Contact sheets: [1](contact-sheet-1.jpg), [2](contact-sheet-2.jpg),
[3](contact-sheet-3.jpg), [4](contact-sheet-4.jpg).
[All captured UI state and geometry](visual-states.json).

The normal short menu is **224 dp**, versus the previous **360 dp**.
The real Prayerbook context menu expands to **269.59 dp** for
«Паведаміць пра памылку». Right-edge deviation from the inner button's animated
paint bounds is 0.8 dp (the outer 48 dp anchor is exact); popup top is 4 dp below
that outer anchor. No direct action has a trailing chevron.

## Reproduction

Environment: [Flutter / Dart versions](flutter-version.json),
[devices](devices.txt), [emulators](emulators.txt). Flutter 3.41.4 / Dart 3.11.1;
Chromium 154 on Linux. No live Firebase initialization or content writes.
The harness uses the production app/router, Riverpod/Hive and shipped public
content, with offline gateways and update checks disabled only in this test host.

```sh
flutter analyze --no-pub
flutter test --no-pub --concurrency=4 --timeout=2m --machine
python tool/audit_reader_fonts.py
flutter run -d chrome --no-pub --no-web-resources-cdn \
  -t tool/reader_settings_smoke.dart --web-port 5241
node tool/reader_settings_capture.cjs <Chrome-CDP-port> audit-evidence/reader-settings
node tool/reader_settings_scroll_smoke.cjs <Chrome-CDP-port> audit-evidence/reader-settings
```

Node must have Playwright available. These scripts attach to the Chrome instance
launched by Flutter; they never create a competing browser. Every accepted frame
asserts that `MediaQuery` and the actual view match. The viewport and platform
adaptation are inspected in the app, rather than inferred from screenshot names.

In this cloud container, Flutter engine CDN fonts are blocked. Actual Roboto and
Noto Sans were supplied locally to the **test host only**, via
`--dart-define=READER_AUDIT_LOCAL_FONTS=true`. Reproduce that workaround by placing
actual `Roboto.ttf` and `NotoSans.ttf` in `web/reader-audit/`; the guarded host
loads them as those same families. They were removed after capture and are not
part of the app or this PR. Roboto came from Google Fonts' official repository,
Noto Sans from the installed system fonts. The four book families always came
from the app's own bundled assets. Chrome ran headless with the container's
`--no-sandbox` browser flag; application access controls and native dependencies
were unchanged. Engine fallback-request warnings can still occur for auxiliary
characters; the captured UI labels and real reader faces render correctly.

## Native limits

**Android native: not performed.** No Android SDK/AVD or attached Android device.
**iOS native: not performed.** This Linux executor has no Xcode/iOS Simulator.
The iOS pictures show Flutter's Cupertino adaptation in Chrome, not an iPhone
Simulator. Chrome does not establish native plugin, keyboard, system-font or
lifecycle correctness. Widget matrices cover Android/iOS platform choices,
SafeArea, keyboard changes and large text. A native smoke pass remains necessary
before a mobile release. No merge, Play/TestFlight release or production Firebase
operation was performed.
