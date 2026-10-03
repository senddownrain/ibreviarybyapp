# Phase 3B — minimal top chrome, implemented scope

Base: merged Phase 2B rollback in `main @ 81cf4b1`. This replaces the broad
Phase 3A implementation proposal with the small production changes supported
by the fresh [top chrome audit](TOP_CHROME_AUDIT.md).

## Implemented

- Hours and Prayerbook start their page titles at the same top/side rhythm as
  the reader roots. Prayerbook uses the existing Cormorant page-title style.
- AppShell Menu and FloatingTopActions share the existing 48 dp reader control
  geometry and neutral platform surface. This also aligns Back controls on
  collection screens without changing their routes or content.

## Left as is

- Readings and Bible remain root readers. Their existing document context and
  top actions are already clear; neither gains a duplicate page title.
- Ora, Prayer, Mass, Song, and Compendium reader actions retain their current
  composition. Prayer-only search, standalone Songbook/Compendium, Bible picker
  and inline chapter navigator, Mass navigator, Ora return, and all bottom dock
  behavior remain with their current owners.
- Settings/About and collection content retain their existing screen structure.

## Deferred to Phase 4B or later

Universal `TopChromeSpec`, route migrations, search architecture, reader
typography, semantic content headings, and broad manual-inset cleanup have no
confirmed Phase 3B benefit. Reconsider only with a concrete visible defect.
