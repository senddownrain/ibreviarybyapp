# Top chrome audit — Phase 3B

Production review against `main @ 81cf4b1` after the Phase 2B rollback. The
Phase 3A audit and root screen research were read from
`codex/phase3a-top-chrome`; their broad migration proposal is historical
research. The current, restored behavior is the source of truth.

| Screen | Current top owner; leading; actions | Title / safe area / manual space | Decision |
| --- | --- | --- | --- |
| Hours root | AppShell; Menu; date actions in content | Page title in flow; safe top + 78 + 16, 24 side | **FIX NOW:** align page title, side and top rhythm with the other roots. |
| Readings root | ReaderChrome; Menu; Aa | Page title and date in reader context; safe top + 76, 22 side | **LEAVE AS IS:** already a root and reader with clear context. |
| Prayerbook root | AppShell + FloatingTopActions; Menu; prayer-only Search | System-font title in flow; safe top + 78 + 16, 20 side | **FIX NOW:** page-title role and root rhythm; preserve search destination. |
| Bible root/chapter | ReaderChrome; Menu; Search, Aa | Full book/chapter context in reader header; safe top + 76 | **LEAVE AS IS:** avoid a duplicate root title; preserve picker and chapter flow. |
| Ora reader | ReaderChrome; Back; Aa | Date/hour in reader context; safe top + 76 | **LEAVE AS IS:** existing context and return behavior. |
| Prayer detail | ReaderChrome; Back; Favorite, Aa, optional overflow | Prayer title in reader context; safe top + 76 | **LEAVE AS IS:** essential actions already fit. |
| Mass | ReaderChrome; Back; Language, Aa | Mass title in reader context; safe top + 76 | **LEAVE AS IS:** section navigator remains independent. |
| Song detail | ReaderChrome; Back; Favorite, Aa | Song title in reader context; safe top + 76 | **LEAVE AS IS:** chord controls remain in the document. |
| Compendium question | ReaderChrome; Back; Aa, local search | Question and trail in reader context; safe top + 76 | **LEAVE AS IS:** existing hierarchy is clear. |
| Prayer catalog/search | FloatingTopActions; Back; optional local action | List title in flow; safe top + 90 | **FIX NOW:** shared floating button geometry only; **LATER:** top reserve if a visible defect is measured. |
| Songbook | FloatingTopActions; Back; local search | List title in flow; manual top reserve | **FIX NOW:** shared floating button geometry only. |
| Compendium root | FloatingTopActions; Back; local search | Collection title in flow; manual top reserve | **FIX NOW:** shared floating button geometry only. |
| Settings / About | SecondaryPageScaffold; Back/Close; local actions | Standard app bar and safe area | **LEAVE AS IS:** coherent utility chrome. |

The one confirmed shared geometry mismatch was the 52 dp AppShell/FloatingTopActions
control versus the existing 48 dp ReaderChrome/AdaptiveAppBar control. Phase 3B
uses the existing neutral `AdaptiveChromeSurface` at 48 dp, with a 48 dp hit
target. The 320 dp / high-text case does not require an overflow migration for
the current root actions. No duplicate top owner was found in the four roots.

**Phase 4B / later:** reader-content typography, semantic headings, page width,
end rhythm, and a larger top-reserve cleanup. No utility or collection migration
is justified by this pass.
