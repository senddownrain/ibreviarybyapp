# Android runtime visual check

## Environment

- HEAD: `224aa1852d1e394f7cbb411c4ac55be54ed3353c`
- AVD: `Pixel7_API34_Audit`; serial: `emulator-5554`; Android 14 / API 34.
- Viewport: 1080 × 2400 px (about 411 × 914 dp); density: 420 dpi / 2.625 px per dp.
- Android `navigation_mode=0`: three buttons (Back, Home, Recents) visibly present in the screenshots. All measurements below are approximate visual distances, not layout test assertions.
- Main pass: Light. Short repeat: Dark via Android night mode; restored Light afterward. Evidence: [`audit-evidence/android-runtime/`](../audit-evidence/android-runtime/).

## Search bars

- **Songbook:** closed search is **CORRECT**, about 12 dp above the top of the black navigation area. Open search is **TOO HIGH**, about 60 dp above the visible IME top. Dismiss returns it to the original closed position, with no stale inset. The final song is reachable, but its subtitle touches the search surface/shadow at maximum scroll: **TOO TIGHT**. [Closed](../audit-evidence/android-runtime/songbook-search-closed.png), [IME](../audit-evidence/android-runtime/songbook-search-keyboard.png), [end of list](../audit-evidence/android-runtime/songbook-bottom.png).
- **Prayerbook search:** same bottom positions as Songbook: **CORRECT** closed and **TOO HIGH** with IME. Query `amen` produced results that remained scrollable; dismiss restored the closed gap. [Closed](../audit-evidence/android-runtime/prayer-search-closed.png), [IME/results](../audit-evidence/android-runtime/prayer-search-keyboard.png).
- **Compendium:** available and loaded. Closed positioning matched the other searches; open positioning was likewise **TOO HIGH**. Dismiss restored the closed position. [IME](../audit-evidence/android-runtime/compendium-search-keyboard.png).

## Keyboard spacing

All three searches follow one visible spacing policy. The search bottom is about 60 dp above the IME top, compared with about 12 dp above system navigation when closed: roughly 48 dp of additional lift. The three system buttons remain beneath the IME. There is no keyboard contact or control overlap, but the unused band compresses results and looks like an extra navigation-height compensation. This **differs from** `test/layout/android_layout_lab_test.dart`, which expects a 12 dp Prayer search/IME gap. It is a runtime inference; the direct `floatingOverlayBottom` helper returns only the requested gap while IME is open, so the next batch should inspect the surrounding Scaffold/body inset composition rather than assume the helper alone is responsible. Dark search showed the same geometry. [Dark closed](../audit-evidence/android-runtime/dark-search-closed.png), [dark IME](../audit-evidence/android-runtime/dark-search-keyboard.png).

## 3-button navigation spacing

Search closed: about 12 dp; full dock: about 12 dp; compact dock: about 8–10 dp; selection palette: about 16 dp from the control bottom to the system navigation top. There is no control/system-button overlap. The compact/full difference is minor but visible (**INCONSISTENT**). Open IME uses the IME top as the visual reference; the app should not retain another navigation-height gap there.

## App dock

- Full dock on Hours, Readings, Prayerbook, and expanded Bible: **CORRECT** height and placement, with content separated by a light supporting fade. [Full](../audit-evidence/android-runtime/dock-full.png).
- Compact dock on scrolled Readings and Bible: **CORRECT**, although about 3–4 dp tighter to navigation than full. [Compact/Readings bottom](../audit-evidence/android-runtime/dock-compact.png), [Bible bottom](../audit-evidence/android-runtime/bible-bottom.png).
- Hidden on search routes and while selection palette is visible: dock disappears; no dock remnant overlaps the navigation area. The Bible chapter control is a separate content control and remains above the palette when both are visible. [Bible palette at chapter end in Dark](../audit-evidence/android-runtime/dark-palette.png).

## Readings palette

Text selection replaces the dock with a palette at about 16 dp above navigation: **CORRECT**. No palette/navigation overlap or obvious appearance jump. At the bottom, the final text remains above the compact dock with usable spacing; no large empty tail. [Palette](../audit-evidence/android-runtime/readings-palette.png), [bottom](../audit-evidence/android-runtime/readings-bottom.png). Runtime palette gap agrees with the Layout Lab expectation of 16 dp; this pass did not rerun that test.

## Bible palette

Verse tap replaces dock with a palette at the same height and gap as Readings: **CORRECT**. At chapter end, the chapter control stays about 24 dp above the palette, matching Layout Lab, and last verses are visible. [Palette](../audit-evidence/android-runtime/bible-palette.png), [Dark at chapter end](../audit-evidence/android-runtime/dark-palette.png).

## Bottom content

- Prayerbook: final destinations can be reached; no overlap or excessive tail. [Bottom](../audit-evidence/android-runtime/prayerbook-bottom.png).
- Hours: final `Камплета` row clears full dock; no excessive tail. [Bottom](../audit-evidence/android-runtime/hours-bottom.png).
- Readings: final `Гэта Слова Пана.` clears compact dock; reserve is comfortable. [Bottom](../audit-evidence/android-runtime/readings-bottom.png).
- Bible: final verse and chapter switcher are usable, but the chapter switcher stops roughly 165 dp above compact dock at maximum scroll, leaving a conspicuous empty tail: **TOO HIGH** for the last meaningful control. [Bottom](../audit-evidence/android-runtime/bible-bottom.png).
- Songbook: the last row reaches the search overlay, but its subtitle is partly lost in the surface/shadow. Repeated upward swipes do not reveal more space: **TOO TIGHT**. [Bottom](../audit-evidence/android-runtime/songbook-bottom.png).

## Supporting surface

**GOOD** in Light and Dark. The fade behind full/compact dock separates moving text without reading as a heavy bottom bar. The area above the system buttons remains visually connected to the dock. [Light](../audit-evidence/android-runtime/dock-full.png), [Dark](../audit-evidence/android-runtime/dark-dock.png).

## Findings

| Severity | Count | Runtime finding |
| --- | ---: | --- |
| P1 | 0 | No unusable interaction or control/system overlap found. |
| P2 | 3 | Search bars gain about 48 dp of extra IME gap; Songbook last-row subtitle is too close to search; Bible chapter end has about 165 dp of empty tail. |
| P3 | 1 | Compact dock is about 3–4 dp closer to system navigation than full dock. |

## Recommended Sol fixes

1. **P2 — Shared search/IME:** inspect the Scaffold/body inset composition around `floatingOverlayBottom` for Songbook, Prayerbook search, and Compendium. Anchor the search bottom about 12–16 dp above the actual IME top, without another navigation-height lift; retain the closed 3-button gap and dismiss restoration.
2. **P2 — Songbook list end:** adjust the list's final scroll reserve so the final song's complete title, subtitle, and actions clear the search surface by at least 16 dp at maximum scroll. Current list bottom padding is `104 + viewPadding.bottom` in `lib/screens/songbook_screen.dart`.
3. **P2 — Bible chapter end:** reduce the unselected chapter's bottom tail so the chapter switcher sits closer to compact dock, while keeping the separate selection-palette reserve when a verse is selected. Check `ReaderContentSurface.bottomSpacing` and chapter content spacing together.
4. **P3 — Dock consistency:** align compact dock's bottom gap with the full dock (target roughly 12 dp above the system navigation area) without changing its height or supporting fade.

Production code was not changed in this QA pass.
