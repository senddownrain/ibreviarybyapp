# iOS visual audit — continuation notes

Saved 2026-09-27, approximately 01:40 Europe/Moscow.

## Request and constraints

Full original brief: `docs/ios-ux-visual-audit-brief.txt`.
Perform a short visual audit of the real iPhone Simulator build from current main through Codemagic App Preview. No production implementation, no web imitation, no code-only substitute, no Android geometry changes. Preserve content-first reader and floating glass dock philosophy.

## Verified state

### Progress after new link and 06:30 wakeup

- New working URL: https://codemagic.io/s/preview/MXMXH5MHSJKw7_3k . Rendered real iPhone 14 Pro / iOS 16.2, Light.
- Embedded Appetize URL observed in its DOM: https://appetize.io/embed/v4xlwwxp4r4jbb4uf5widxjbtu? . Direct tab avoids the browser tool's fractional iframe input error; interactions work there. On 06:30 wakeup it offered Tap to Start; resume attempt in progress.
- Completed: Hours root, alternatives sheet, bottom; Ora beginning/middle/end, Compact and Full dock, text-size sheet; Readings default A, variants sheet, manual B, text selection palette (last palette screenshot was seen in conversation but not saved).
- Evidence saved: 01 Hours/dock, 02 liturgical sheet, 03 Ora compact, 04 Ora scrolled chrome, 05 Readings cycle A, 06 manual cycle B.
- Observations to validate across remaining readers: scrolling text visibly intersects status bar/Dynamic Island in Ora; text remains visible below dock/palette near home indicator. Full dock geometry itself has an apparent adequate home indicator gap. Cycle B duplicates metadata as pill plus “Цыкл B · зменены”. No P1 asserted yet.
- KEEP candidates: Hours hierarchy, subtle liturgical green accent, readable serif body/rubrics, compact Ora dock, short floating text-size sheet, clear Hours bottom reachability.
- Outstanding: Readings long-text bottom/highlight completion, Prayerbook/search/detail/Bible full walkthrough, Dark, Hidden dock, choir, actual build SHA/defines and logical viewport. Do not present the audit as complete.

### Initial blocker (historical; superseded by new link)

- Preview: https://codemagic.io/preview/6ab847de964d7dc247455bbb
- Opened in Codex in-app browser; dismissed cookie banner. Page visibly reads **“The simulator session has finished.”** The only remaining link is sales feedback, with no launch/restart control.
- No app screen was rendered or audited. Build SHA, iPhone model, iOS version, viewport and theme are unknown. Do not invent findings or treat missing findings as a clean audit.
- `git fetch origin main` succeeded. Current remote main: `270f0d4416faefd35fd7fcd4e4d8a09fd0ebfbbe`.
- Local branch main at `8ed5b7509b1861025982a6d8efc2417ebf3485d2`. These are repository references, NOT audited build SHAs.
- Pre-existing changes must be preserved: `lib/screens/bible_chapter_screen.dart`, `lib/screens/readings_screen.dart`, untracked `audit-evidence/layout-lab/`, `test/layout/`. No checkout/reset/stash or production edits performed.

## Next steps at 06:30 Moscow, 27 September 2026

1. Read full brief and these notes. Check for any fresh Preview URL supplied in this task. Recheck session availability; if launch access is unavailable, request a fresh Quick Launch / App Preview session from the user. The old link itself exposes no restart action.
2. Before an actual audit, fetch main again and verify simulator build commit. Use an isolated checkout of current main if source context is needed, preserving the dirty working directory.
3. Record actual device model, iOS, viewport, theme and relevant build defines from evidence.
4. Walk Hours; Ora (top/middle/bottom, Full/Compact/Hidden, choir); Readings (alternatives/cycles/manual cycle/highlights/bottom); Prayerbook/categories/all/Favorites/Mass; prayer search with keyboard; prayer detail/Markdown/text size; Bible picker/translation/selection/palette/bottom; sheets. Check main screens Light and Dark, compact device if quick.
5. Save at most 10–15 app screenshots in `audit-evidence/ios-visual/`. Prioritize dock backing/geometry, home indicator, reader consistency, cycle metadata, overlays.
6. Replace the blocked report with the short evidence-backed audit. Minimum 5 KEEP items, P1/P2/P3 with calibrated severity, max 5 paradigm mismatches, dock and cycle verdicts, max 3–6 systemic Sol tasks. Do not implement.

## Scheduled continuation

Created one-shot thread heartbeat `ios-visual-audit-06-30`, active, 06:30 local time (Europe/Moscow), COUNT=1. This resumes the Codex task, not the expired Codemagic simulator itself. No usage reset credit was consumed.

## 06:30 result — blocked again

The scheduled one-shot continuation ran on 2026-09-27 at 06:30 Europe/Moscow. Direct Appetize Tap to Start briefly showed Loading and returned to Tap to Start without the app. Reloading the NEW Codemagic shared URL explicitly showed The simulator session has finished. A fresh active Preview/Quick Launch session is required; no restart control is exposed on the finished Codemagic page.

Partial findings and coverage are now recorded in docs/ios-ux-visual-audit.md; six screenshots exist. Do not repeat initial Hours/Ora/Readings checks unnecessarily. Remaining coverage is listed in that report. SHA/build defines/logical viewport are unverified. origin/main fetched again: 270f0d4416faefd35fd7fcd4e4d8a09fd0ebfbbe.

Additional concurrent pre-existing modification seen at wakeup: lib/theme/reader.dart. Do not overwrite it; this audit did not edit any production file. No further wakeups scheduled by this continuation.

## Latest live pass (new user links)

User confirmed build SHA 270f0d4416faefd35fd7fcd4e4d8a09fd0ebfbbe for shared URL https://codemagic.io/s/preview/izrWM9bV6qYfAOT2 . Its observed Appetize embed was https://appetize.io/embed/psgo3zaw2ph7hcrrpdbuxqdeti? . iPhone 14 Pro / iOS 16.2 / Light again.
Completed: Prayerbook root, Marian category, favorite toggle and root favorite result, Holy Mass reader and section navigation card visible, all-prayers list; long prayer detail with numbered list and bold Markdown, middle/end, same text-size sheet. Search keyboard open, query entered with on-screen keys (`ace`), two results, Search key dismissed keyboard, clear query restored list. Browser typeText only affected hidden Appetize textbox; use on-screen keys for native input.
Saved additional evidence 07 Prayerbook, 08 search keyboard/results, 09 prayer detail, 14 search without keyboard. Main new observation: search bar without keyboard sits visibly much closer to home indicator than dock/palette. Text in top status area repeats in Prayer detail and Prayerbook scrolled root. Prayer ending fully reachable above dock.
Next: Bible; Dark major screens; Hidden dock; choir; remaining Readings bottom/highlight. Latest user provided replacement https://codemagic.io/s/preview/UdZ7UEkYDe-1bxHf ; tab 7 loading. Current production tree is clean, only audit docs/evidence untracked.

## Latest checkpoint — all main sections sampled, session ended

Completed Bible Light chapter/picker chapter 2/BEL-RUS/verse selection/palette/end; Dark settings, Bible bottom Compact and Full, Hours root Full. Saved 10 Bible, 11 selection, 13 Bible Dark. Hours Dark capture attempted after disconnect and contained Tap to Start, so that invalid file 12 was removed. There are 13 valid screenshots total. Do not recreate already-completed passes.

Newest user URL https://codemagic.io/s/preview/2wh36o7RtTwWkkAg immediately showed The simulator session has finished. User reconfirmed commit 270f0d4. Previous go2prglycaezsbnw3xp4ggcpdu embed also disconnected. A transient Appetize handshake encode error had previously been resolved with one reload, but the latest finished Codemagic session is a different blocker.

Remaining: Dark Ora/Readings/Prayerbook/search/detail and overlays; Hidden dock/choir; Readings bottom/highlight confirmation; compact device only if quick. Evidence budget has 2 free slots (max 15). Build commit confirmed by user; logical viewport unmeasured. Config at 270f0d4 uses Flutter 3.38.9, debug simulator, no explicit dart-defines. Current main/HEAD is 31fe3b9fb1892e89110138521de6d59f13758e82 with later production changes; do not claim findings were verified on that HEAD.

Report updated with 0 confirmed P1, 3 P2, 1 P3; four proposed systemic Sol tasks. No production implementation. No additional scheduled restarts.

## Current checkpoint — 2026-09-28 (supersedes earlier remaining lists)
The 2wh36o7RtTwWkkAg session later became live with Appetize embed pevfhn7x4ob6wtfviwpecmjnte. Completed Dark Ora/root/body, Hidden by double-tap margin, restored Compact then Full; Psalm choir alternates contrast correctly. Completed Dark Readings root/body, Hidden/restored Full, selected paragraph, yellow highlight applied and visible after palette dismissed. Scrolled into Gospel, not absolute end.
Evidence now 15 valid PNGs. 12-hours-dock-dark.png was recreated successfully; 15-ora-dark-hidden-choir.png added. Both visually verified. Report updated to reflect these checks.
Newest user URL https://codemagic.io/s/preview/Pd-XT8Vsr1kTJsAl opened directly to “The simulator session has finished” on 2026-09-28; no restart/Quick Launch control exposed. Build SHA for this unavailable new session is not independently verified; prior completed observations remain 270f0d4 as confirmed by user.
Remaining ONLY: Prayerbook/root/search/detail Dark, Dark sheets beyond settings, absolute Readings bottom. Compact device optional if quickly available. Do not repeat completed Light walkthrough or Hidden/choir/highlight.
One-shot automation ios-visual-audit-06-30 deleted via app tool after repeated triggers, honoring the stop-after-one-run instruction. No further automated restarts. User needs to start a live Codemagic Quick Launch/App Preview and share its active link. Production code untouched; unrelated untracked test/layout/failures/ preserved.

Latest user URL https://codemagic.io/preview/6aba71d0083ff0a9a53a1b38 on 2026-09-28: initially Connecting, then visibly The simulator session has finished. No live app or restart control. Remaining coverage unchanged.

## Walkthrough completed — 2026-09-28
Repeated user shared link Pd-XT8Vsr1kTJsAl finally opened a new live embed ir7momuthjyndewmixad2geag4. iPhone 14 Pro/iOS16.2 again. Closed all remaining walkthrough gaps: Dark Prayerbook root/Full dock; search keyboard, native-key ave query/results/Search dismiss; prayer detail Markdown links and long body/scroll; Dark text-size sheet and dismiss; Readings cycle II, Dark variants sheet I/II and dismiss; absolute Readings bottom verified unchanged by another upward swipe, final “Гэта Слова Пана.” accessible above Compact dock.
Latest session SHA unknown, asked user asynchronously. Do not merge its provenance with confirmed 270f0d4 without answer. Search closed-keyboard gap is now visibly adequate, unlike prior Light capture 14; flag build/theme/state ambiguity rather than claim fix. Top status-area text conflict persists in Dark prayer and Readings.
Evidence remains 15 PNG. Replaced 05 with 05-readings-dark-bottom.png, and 09-prayer-detail.png with Dark detail/text-size sheet. These two belong to latest unconfirmed session. Report rewritten as completed bounded walkthrough, with 0 P1/3 P2/1 P3 for original build and conditional P2 search finding.
Fetched origin/main c2b31962fbc3aa7dd695fd09497a981bd5305944; no claim Preview matches it. Production and unrelated test/layout/failures untouched. No implementation; automation deleted already. Do not restart full audit. Only append SHA confirmation if supplied, or perform explicitly requested new-build verification.
