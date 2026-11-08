The full content bundle was regenerated from the authorized post-migration Firestore snapshot (2026-11-08T22:12:30.576Z), using `npm run content:app-release -- --snapshot … --out …` on mybrev main 564a894.

All 2,598 approved field hashes in 295 documents match the doxology dry-run exactly. Firestore writes used updateTime preconditions and exact field masks; readback passed. The full snapshot includes 4,169 documents in 16 collections; it contains current content and does not apply any additional migrations.

BLOCKED — do not release this bundle yet. The standard app-release command exits 3: `BUNDLE ≠ PUBLISHED: days, readings, liturgicalTemplates, prayers`. The manifest dry-run is MASS CONTENT REBUILD (370 documents, 28.2 MiB), so publishing it as a patch is forbidden. No force or override was used. The current workflow has no supported baseline activation step that resolves these two gates. Proper and other new collections must enter the manifest only after a compatible app is released. Keep this PR draft until that release mechanism is implemented and validated.

The existing Android workflow supports only closed testing alpha, not production. iOS upload requires the developer Mac. Native smoke is still required before a store release. No Google Play or App Store upload was performed for this bundle.
