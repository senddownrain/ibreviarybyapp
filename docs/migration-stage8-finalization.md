# Stage 8 migration finalization

Дата: 2026-09-10. Ветка: `feature/mobile-ux-migration`.

## Commits

- `9841062` — `fix: resolve Stage 7 P1 migration issues`
- `c1016e2` — `refactor: apply Stage 7 migration polish`
- `2b930e0` — `chore: remove verified legacy migration UI`

Starting SHA: `50c4f46`. Baseline audit SHA: `991cfe4`.

## Removed legacy

- `lib/screens/bible_screen.dart`: production Bible root is `BibleBranchHost`; no router, import or test references remained.
- `lib/widgets/bottom_nav.dart`: old date/navigation widgets had no references; `app_navigation_dock.dart` remains the production dock.

Repo-wide symbol/import search was repeated before and after deletion. No compatibility route was removed.

## Retained compatibility

The following redirects remain intentionally registered because they can be external/deep links or still protect old app locations:

- `/`, `/ora/:date/:dayId/:type`, `/hora/:date/:dayId`
- `/reading/:readingId`
- `/prayer/:id`, `/prayer/add`, `/prayer/edit/:id`
- `/favorites`, `/my`, `/my-prayers`
- `/bible/:version/:book/:chapter`
- `/picker`, `/picker/options`

Also retained: `hora_picker_screen.dart`, `reading_detail_screen.dart`, `ReadingScaffold`, AppRouteDescriptor/branch observers/contextual bottom slot, GlassSurface primitive, all SharedPreferences/Hive-compatible keys, Bible highlights/location, local prayers, favorites and category data.

## Automated QA

| Gate | Result |
| --- | --- |
| `flutter analyze` | PASS — 0 issues |
| `dart analyze` | PASS — 0 issues |
| `flutter test --reporter compact` | PASS — 114 tests |
| `flutter build web --dart-define=IBREVIARY_PLATFORM=android` | PASS |
| `flutter build web --no-wasm-dry-run --dart-define=IBREVIARY_PLATFORM=ios` | PASS |

Regression coverage added or strengthened for Full → Full chrome ownership, actual Bible body scaling at 320 px/system 200%, palette semantics and targets, Readings group/cycle overrides, All Prayers repeat-entry state, and start-section routing.

## Remaining device QA

- Android Light/Dark and iPhone Light/Dark visual confirmation of the continuous background below Full/Compact dock and palette replacement.
- TalkBack/VoiceOver names, order, selected announcements and focus return.
- iOS interactive back swipe and Android predictive/system Back.
- Native safe areas, cutouts, keyboard/viewInsets and home indicator at 320/390 widths.
- System text 100/150/200 combined with reader Aa 100/130/180 on Ora, Readings, Prayer Detail, Bible and Full dock.
- Seasonal visual matrix for real ordinary, Marian, Advent/Lent and red/martyr dates across Hours → Ora → Readings.
- Final visual sweep of retained secondary compatibility screens; Stage 8 removed no live functionality to force superficial uniformity.

## Merge readiness

All confirmed P1 implementation defects are resolved and automated gates/builds are green. The migration architecture remains unchanged. The branch is **ready for final device QA / merge review**, but is not claimed to be fully production verified until the native checks above pass.
