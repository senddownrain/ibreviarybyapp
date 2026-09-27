# Deterministic Android Layout Lab — complete

Completed: 2026-09-27 (Europe/Moscow).

Starting repository state: branch `main`, HEAD `8ed5b75`. The working tree was
clean at task start. Android Emulator, ADB and AVD were not used.

## Harness

- `test/layout/android_layout_lab_test.dart`
- Android `TargetPlatform` with production Prayerbook, Prayer search,
  Readings, Bible, reader surface, and floating dock widgets.
- Local Riverpod/Hive fixtures only; no Firebase or network dependency.
- 390×840 and 320×720 dp; measured audit insets 48 dp (3-button) and 24 dp
  (gesture); explicit padding, viewPadding, systemGestureInsets, and IME.
- `ReaderTypographyScope` supplies Flutter's deterministic test font only when
  explicitly installed by the harness. Production typography is unchanged.
- Stable non-visual Keys were added for palette and content-reserve probes.

## Measurements

Prayerbook root:

| viewport | mode | window inset | descendant viewPadding | descendant padding | dock top | last item bottom | gap | scroll extent | verdict |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| 390×840 | 3-button | 48 | 0 | 126 | 720 | 690 | 30 | 134 | CORRECT |
| 390×840 | gesture | 24 | 0 | 102 | 744 | 714 | 30 | 110 | CORRECT |
| 320×720 | 3-button | 48 | 0 | 126 | 600 | 570 | 30 | 346 | CORRECT |
| 320×720 | gesture | 24 | 0 | 102 | 624 | 594 | 30 | 322 | CORRECT |

Prayer search:

| mode | closed gap | IME-open gap | verdict |
|---|---:|---:|---|
| 3-button | 12 | 12 | CORRECT |
| gesture | 36 | 12 | TOO LOOSE closed; CORRECT with IME |

Selection palettes at 390×840:

| surface | mode | system-safe gap | selection reserve | final tail | scroll extent | verdict |
|---|---|---:|---:|---:|---:|---|
| Readings | 3-button | 16 | 136 | 96.4 | 1092 | DOUBLE RESERVE |
| Readings | gesture | 40 | 136 | 72.4 | 1068 | DOUBLE RESERVE |
| Bible | 3-button | 16 | 72 | 32.4 | 4202.6 | INCONSISTENT |
| Bible | gesture | 40 | 72 | 8.4 | 4154.6 | INCONSISTENT |

At 320×720 both palettes and Prayer search fit horizontally and retain the
same safe gaps.

Reader dock modes at gesture inset 24:

| mode | descendant content padding | last item bottom | scroll extent | verdict |
|---|---:|---:|---:|---|
| Full | 102 | 696 | 1105 | CORRECT |
| Compact | 94 | 704 | 1097 | CORRECT |
| Hidden | 0 | 798 | 943 | CORRECT; no stale dock reserve |

Visual verdicts:

- Dock: `SUBTLE SUPPORTING SURFACE` (not implemented).
- Cycle metadata: `TEXTUALIZE` (not implemented).

## Evidence

- `prayer-search-3button.png`
- `prayer-search-gesture.png`
- `readings-palette-3button.png`
- `readings-palette-gesture.png`
- `bible-palette-3button.png`
- `bible-palette-gesture.png`
- `dock-light.png`
- `dock-dark.png`
- `cycle-current.png`
- `cycle-dark.png`

## Verification

- Layout Lab: 17 tests passed.
- Full Flutter suite after merging `origin/main`: 220 tests passed.
- `dart analyze`: completed with one pre-existing info-level `avoid_print` in
  `docs/audit-evidence/cache_bound_probe.dart`.
- `flutter analyze --no-pub`: same single pre-existing info; command exits 1
  because Flutter treats it as an analyzer issue.
- `git diff --check`: passed (line-ending notices only).

The original repository-hygiene exclusions were not modified:
`lib/repositories/bible_repository.dart`, `pubspec.lock`,
`test/bible_repository_test.dart`, and
`docs/audit-evidence/android-layout/emulator-start.log`.

Unrelated untracked iOS audit files appeared in the shared workspace while this
task was running. They were not read, modified, or included in this work.

Production layout fixes were deliberately not implemented. The evidence-backed
five-task plan is in `docs/android-layout-system-audit.md`.
