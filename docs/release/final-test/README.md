# Single final test candidate — 2026-11-17

Content version **1794938564491** (`2026-11-17T18:02:44.491Z`). Aggregate bundle SHA256 **19ed6b4b8247baa4d97e20a8404975b6f539a9531bf9061e1b063f73c9e9152c**. Manifest file SHA256 `ae51bd2db7207cfbddb2845519077e501e87f36d067887da9527caaaa2be32b6`.

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
| liturgicalCelebrations | 241 |
| liturgicalDioceseOverrides | 75 |
| liturgicalYearOverrides | 15 |
| liturgicalOrdoNotes | 1,347 |
| **Total** | **4,473** |

bundle-report.json binds all file SHAs, collection digests, document hash/size maps and both snapshot manifests. Liturgical collections derive from actual readbacks and the transaction-fenced catalog. The remaining13 collections were captured once in a read-only transaction (3,430 reads). Protected/draft inclusion zero; existing priest-cache cleanup retained. Full source snapshots remain private and ignored.

All17 files rebuilt byte-for-byte from the same inputs (reproducibility.json). No second candidate version was created. Rebuild uses scripts/build_final_test_bundle.mjs and pinned Web codec b2b85ba98371c1335168442e87c1c6c020e6813f.

## Published manifest and quota blocker

**LITURGICAL FIRESTORE: 7791/7791 VERIFIED**. The original publication completed749 data writes +4 atomic manifest writes; current contentVersion1794938108754. Digests: days b80a2589e5651bd7/v7, templates a1d498c34dd96ab8/v4, Proper b23370f9d589fff1/v1.

Additional full manifest parity was owner-approved. Web PR271 merged99b9191fa111607dca91ef64d4e2fec6385c56b2; CI44184447584 passed. Exact metadata-plan SHA256707e13042ed74996cf996aacbd9564c2dc3200448f05eca11946abe502d1e95a.

Production run [44185030376](https://github.com/senddownrain/mybrev/actions/runs/44185030376) stopped with **code8, Quota exceeded** before preparing any manifest write. No retry. Actual receipt: manifest-quota-stop.json. Artifact ZIP SHA256a1cc8b80381a3fa775035ba193023a4391fcdbb6126050f88d7560aa3471e133.

Parity with the captured document data is verified; full parity with a newly published16-collection manifest is **pending**. Four stale indexes cannot roll back this newer bundle: collection-specific minimumRemoteVersion floors are enforced/tested. Unobserved production edits after the saved snapshots are not claimed as verified.

After quota recovery, use existing protected pr245-reviewed-content.yml: scope final-test-manifest, mode execute, batch_size25, release_authorization_path docs/releases/final-test-2026-11-17/plan.json, exact plan_sha256 above. The existing atomic transaction must freshly fence all4,473 IDs/updateTimes and read back17 manifests. If data changed, stop and reconcile only changed documents. Do not rerun source/liturgical migrations. No automatic retry.

## Presentation and validation

Common uppercase headings; red normal-case/weight right-aligned Scripture references wrapping below; compact p/div/br responsories; hymn/Psalm stanza spacing and reading alignment settings retained. Book/author introductions and Patristic annotations remain body text. Gadzinki accepts both observed Камплета and legacy Напрыканцы дня without modifying source.

Actual Google Chrome157:78 scenes, light/dark/marian,320/390/768/1440px, text100/200%; real Lauds/Vespers/Sext/first+second readings/Gadzinki and isolated reference/div/br fixtures. No browser errors or Firebase calls. Screenshots saved and viewed. Evidence: audit-evidence/final-test/office-chrome/results.json.

Targeted Office/layout/parser/theme, prayer source/category/security/old decoder, offline cold-start/restart, updater and personal-data preservation checks executed. Two old devotional expectations failed against the new production heading; support was corrected and both devotional suites passed19 tests. Actual logs and validation.json retain the initial failure honestly. Analyzer: zero errors/warnings,29 existing infos.

Compatibility: six historical updater source revisions,102 prior source/unit/Hive checks, plus2 earliest-updater tests with all known final-bundle collections. Mass activation/restart and interrupted download/restart preserve settings, favorites and personal prayers. Newer test clients may require an app update before document download. Installed-client inventory/native binary testing were unavailable and are not claimed.

Before APK: complete pending manifest parity after quota recovery, separate owner acceptance/version decision, target-platform native smoke, signing and separate mobile release authorization. Chrome does not replace native smoke. No mobile publishing workflow invoked.
