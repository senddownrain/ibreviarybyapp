# Stage 2 evidence — discovery engine + QA harness

Base: `24f8d94` (origin/main at start). All screenshots are real device frames.

| File | State |
|---|---|
| `ios_/android_01_ready_with_alternatives.png` | `Ёсць варыянты` → `readings.day_variants` |
| `…02_no_alternatives.png` | `Няма варыянтаў` → `none` |
| `…03_loading.png`, `…04_error.png` | `Loading` / `Памылка` → `none` |
| `…05_disabled.png` | `Выключана` → `none` |
| `…06_hint_shown.png` | `Паказаць hint / no-op` → card shown, counted after mount |
| `…07_after_restart_dismiss_kept.png` | `Не паказваць` + `Імітаваць перазапуск` → session 2, `none`, reason `dismissed` (real Hive) |
| `…08_after_qa_reset.png` | `Скінуць толькі гісторыю…` → `readings.day_variants` again |

Devices: iPhone 16 Simulator, iOS 18.6 (fresh `cd-s2-iphone16`); Android AVD
`analytics_test`, API 34 (emulator-5556, debug APK, driven with adb
uiautomator taps). The harness uses its own Hive directory — app data is
not touched.

## Reproduce

```bash
# iOS (copy is temporary: `flutter test -d` only runs integration_test/)
cp test/discovery/device/discovery_qa_device_run.dart integration_test/discovery_qa_device_run_test.dart
flutter test -d <ios-simulator-id> integration_test/discovery_qa_device_run_test.dart
rm integration_test/discovery_qa_device_run_test.dart
# or interactively
flutter run -d <device> -t lib/discovery/qa/discovery_qa_main.dart
```

## Release absence proof

Main app, release, searching the AOT snapshot (`strings -a`) for
`mybrev_flutter/discovery`, `discovery/qa`, `discovery_qa_main`,
`QA harness is not available`:

* Android `flutter build apk --release --target-platform android-arm64`
  → `libapp.so` : 0 / 0 / 0 / 0
* iOS `flutter build ios --release --no-codesign` → `App.framework/App` :
  0 / 0 / 0 / 0
* Positive control (search method works): release build of the QA
  entrypoint itself (`-t lib/discovery/qa/discovery_qa_main.dart`) →
  1 / 1 / 1 / 1; even there the harness widgets are tree-shaken because
  `kReleaseMode` makes `main()` throw before `runApp`.
* `test/discovery/qa_isolation_test.dart` keeps the import graph clean.
