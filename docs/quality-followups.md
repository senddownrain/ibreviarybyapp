# Reader interaction follow-ups from the 2026-09-13 audit

The historical post-merge audit is preserved in Git history. These findings were outside the 2026-09-28 visual polish batch and have not been revalidated here:

- Linked Hours/Readings selection provenance may lose the manual group marker after synchronization (former P1-01).
- Fullscreen still depends on a double tap without an explicit in-reader exit, and its gesture may compete with child actions (former P1-02).
- Psalm choir discoverability/semantics, Markdown search across inline formatting, and web cache byte accounting were previously reported as P2 follow-ups.

Treat these as follow-ups requiring their own reproduction and tests before release decisions. The current layout acceptance contract lives in `test/layout/android_layout_lab_test.dart`; reader and cycle behavior are covered by active tests under `test/`.
