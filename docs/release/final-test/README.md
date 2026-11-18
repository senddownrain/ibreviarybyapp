# PR #117 single offline bundle — 2026-11-18

Bundle content version **1795025405000** (`2026-11-18T18:10:05.000Z`), aggregate SHA256 **1d0066ead7e7b9f69cb83e8bc96e6346ce3a17111cc0e241233693240bbbf173**. Manifest file SHA256 `e776a6ddced8b0e6cbefd7ba0a02b86618371bd711b50cdd0e599ad7e3b33a2b`. [Per-file checksums, collection digests and approved source substitutions](nov18-refresh-report.json).

The existing bundle holds **394 public prayers**. Three reviewed devotions were added, and the Eucharistic procession was updated under its production ID `Fd9rN0S9NU1mAmqb2isZ`. All four are in «Набажэнствы» via the category's existing tag. The saved public snapshot confirms two older bundled IDs were removed from production. The refresh applies **316** canonical edition-title substitutions from Web #278 and sets the existing procession’s source to the verified Agenda attribution. [Reviewed texts and publication evidence](https://github.com/senddownrain/mybrev/pull/288) · [Source policy](https://github.com/senddownrain/mybrev/pull/278).

Calendar revision **6** includes the white (`albus`) dedication of the Roman basilicas of Saints Peter and Paul on November 18. The bundled December exclusions and all other calendar definitions are carried forward. [Calendar patch readback](https://github.com/senddownrain/mybrev/actions/runs/44342368712).

The changed assets are prayers, celebrations, calendar metadata and the bundle manifest. The 13 other gzip files, including the 7,791 published corrections, are byte-for-byte identical to the preceding PR #117 candidate. The offline checker compares each changed payload with the reviewed inputs, verifies every file SHA256, and checks the manifest. The refresh used zero production reads and writes.

Before the test APK, confirm the app version, build the signed candidate and run the Android native smoke. Browser and unit-test evidence is retained below.

## Previous candidate and historical evidence

### Bundle snapshot from 2026-11-17

Content version **1794938564491** (`2026-11-17T18:02:44.491Z`). Aggregate bundle SHA256 **b0809b03da9b04cb21979b8d0d5fdbe999a52af1aa4451c5e156d2b896753e77**. Manifest file SHA256 `16860a876b94aaa375c13e27ec2510204a285896116be2070bfc3aa3e9875178`.

One candidate for separate acceptance. No APK, Play upload or iOS binary/release was produced.

## Content and source of truth

Includes 7,791 readback-verified fields in 749 days/templates documents, published Proper406/Advent14, the original 37 Web values +307 importedAt reconciliation, public prayers, verbatim canonical/held sources and categories/subcategories. All843 held fields and29 disputed sources remain unchanged. Three newer production fields in days/office-for-dead and one Proper vesperPs2 were preserved outside reviewed masks. Source migrations were not repeated.

| Collection | Documents |
|---|---:|
| days | 736 |
| liturgicalTemplates | 16 |
| liturgicalProperTexts | 291 |
| readings | 822 |
| invitatoriums | 4 |
| completoriums | 35 |
| prayers | 393 |
| prayerCategories | 22 |
| songs | 447 |
| compendium | 27 |
| compendiumMeta | 1 |
| liturgicalCalendarMeta | 1 |
| liturgicalCelebrations | 242 |
| liturgicalDioceseOverrides | 77 |
| liturgicalYearOverrides | 15 |
| liturgicalOrdoNotes | 1,347 |
| **Total** | **4,476** |

bundle-report.json binds all file SHAs, collection digests, document hash/size maps and both snapshot manifests. Liturgical collections derive from actual readbacks and the transaction-fenced catalog. The remaining13 collections were captured once in a read-only transaction (3,430 reads). Protected/draft inclusion zero; existing priest-cache cleanup retained. Full source snapshots remain private and ignored.

All17 files rebuilt byte-for-byte from the same inputs (reproducibility.json). No second candidate version was created. Rebuild uses scripts/build_final_test_bundle.mjs and pinned Web codec b2b85ba98371c1335168442e87c1c6c020e6813f.

## Pending calendar/server parity

The corrected candidate preserves the exact four accepted calendar assets from main#107 (bundled revision4); captured Firestore is revision3. Their server updateTimes all precede the accepted contentVersion. Twelve collections match the saved Firestore snapshot; calendar parity requires the existing guarded revision4 publication then the separately accepted two-entry revision5 patch. No revision5 publication is claimed. See calendar-preservation.json. The corrected candidate reproduced17 files byte-for-byte and its calendar/updater tests passed on2026-11-18.

The old metadata plan below has been RETIRED by merged WebPR272 (07a658daa599bbff72e0148816cc6460bb80cbe7). Do not run it. A new exact plan must bind the final actually published state.

## Historical manifest quota blocker

**LITURGICAL FIRESTORE: 7791/7791 VERIFIED**. The original publication completed749 data writes +4 atomic manifest writes; current contentVersion1794938108754. Digests: days b80a2589e5651bd7/v7, templates a1d498c34dd96ab8/v4, Proper b23370f9d589fff1/v1.

Additional full manifest parity was owner-approved. Web PR271 merged99b9191fa111607dca91ef64d4e2fec6385c56b2; CI44184447584 passed. Exact metadata-plan SHA256707e13042ed74996cf996aacbd9564c2dc3200448f05eca11946abe502d1e95a.

Production run [44185030376](https://github.com/senddownrain/mybrev/actions/runs/44185030376) stopped with **code8, Quota exceeded** before preparing any manifest write. No retry. Actual receipt: manifest-quota-stop.json. Artifact ZIP SHA256a1cc8b80381a3fa775035ba193023a4391fcdbb6126050f88d7560aa3471e133.

Parity with the captured document data is verified; full parity with a newly published16-collection manifest is **pending**. Four stale indexes cannot roll back this newer bundle: collection-specific minimumRemoteVersion floors are enforced/tested. Unobserved production edits after the saved snapshots are not claimed as verified.

Continuation uses existing guarded calendar publisher/approved seals, then a newly SHA-bound coordinated manifest contract. The retired raw-calendar plan cannot execute or access credentials. Reuse verified readbacks and perform only the required metadata/changed-document checks.

## Presentation and validation

Common uppercase headings; red normal-case/weight right-aligned Scripture references wrapping below; compact p/div/br responsories; hymn/Psalm stanza spacing and reading alignment settings retained. Book/author introductions and Patristic annotations remain body text. Gadzinki accepts both observed Камплета and legacy Напрыканцы дня without modifying source.

Actual Google Chrome157:78 scenes, light/dark/marian,320/390/768/1440px, text100/200%; real Lauds/Vespers/Sext/first+second readings/Gadzinki and isolated reference/div/br fixtures. No browser errors or Firebase calls. Screenshots saved and viewed. Evidence: audit-evidence/final-test/office-chrome/results.json.

Targeted Office/layout/parser/theme, prayer source/category/security/old decoder, offline cold-start/restart, updater and personal-data preservation checks executed. Two old devotional expectations failed against the new production heading; support was corrected and both devotional suites passed19 tests. Actual logs and validation.json retain the initial failure honestly. Analyzer: zero errors/warnings,29 existing infos.

Compatibility: six historical updater source revisions,102 prior source/unit/Hive checks, plus2 earliest-updater tests with all known final-bundle collections. Mass activation/restart and interrupted download/restart preserve settings, favorites and personal prayers. Newer test clients may require an app update before document download. Installed-client inventory/native binary testing were unavailable and are not claimed.

Before APK: complete pending manifest parity after quota recovery, separate owner acceptance/version decision, target-platform native smoke, signing and separate mobile release authorization. Chrome does not replace native smoke. No mobile publishing workflow invoked.
