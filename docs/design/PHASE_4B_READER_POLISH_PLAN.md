# Phase 4B reader polish — implementation record

Base: merged `main @ 7795d9f`. The attached Phase 4B brief supplies the requested scope; the merged code and design system supply current behavior. Phase 4A is historical research.

| Step | Work | Status |
| --- | --- | --- |
| 4B.1 | Record canonical roles and adapt existing reader tokens | Implemented |
| 4B.2 | Align document titles, content headings, and true rubrics | Implemented; domain structure retained |
| 4B.3 | Align body, references, metadata, and sources where redundant local styling exists | Implemented; contextual metadata remains screen-owned |
| 4B.4 | Inspect first block, end clearance, width, dark mode, and large text using real content | Representative inspection implemented; exhaustive visual matrix deferred |
| 4B.5 | Add focused regression checks, run Flutter analysis and tests, record intentional differences and debt | Implemented |

No universal reader or parallel spacing system. Keep routes, search, Aa settings, liturgical resolution, source data, Bible dock behavior, Mass navigation, and domain structures intact.

## Result

- `ReaderContextHeader` and the Compendium part header use `documentTitle`. Mass and Prayer content headings use the shared Cormorant hierarchy. Compendium sections/subsections use the same hierarchy while its outline, question rows, and navigation keep their own composition.
- Ora, Prayer, and Mass true rubrics now share the `rubric` metrics and color. Mass dialogue, role labels, red linked liturgical headings, Ora antiphons, Bible verse numbers, and Song chords keep their semantic styles.
- CCC citations use `reference`. Song, Mass, and all Compendium attributions use `source` while preserving their links and placement. Bible verse body ink now comes from the reader role.
- On the Android emulator, inspected real Ora, Readings, Prayer, Mass, Bible, Song, and Compendium content in the light application theme at its native 411 dp width. Inspected the long Prayer document in the dark application theme at 320, 390, and 700 dp. The first Mass major heading had an extra top gap; only that first heading now omits the section-before margin. No comparable width defect was established, so 700 dp remains the page maximum.
- Widget coverage checks the shared roles in both themes; the reader header at 320/390/700 dp with system text at 200% and Aa at 180%; domain suites cover Bible selection/dock, Mass sections, Song chord layouts, and Compendium references. A complete device screenshot matrix across every section, width, theme, system scale, and Aa value remains deferred.
- `flutter analyze --no-pub` reported no issues. The initial full suite had two unrelated deterministic test failures: a pending gesture timer in the Bible dock test and a stale floating-button width expectation. Both tests were corrected without changing product behavior; focused rerun passed. The final full suite passed all 499 tests.

## Remaining debt

- Opening Readings from an Ora header action on the debug emulator triggered an existing Riverpod provider mutation during `_ReadingsBranchHostState.initState`. Opening Readings through the bottom tab worked. This is a navigation lifecycle issue and remains outside this semantic-styling phase.
