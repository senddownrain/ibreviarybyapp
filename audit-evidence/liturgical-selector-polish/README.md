# Minimal PR #14 polish

Code SHA: `de10a1c861e9dd8cecc2e0915a13b03c9bf16953`.

- Calendar month/year text: 19 sp locally; sheet title and 48 dp arrow targets unchanged.
- Ordo alternatives: 8 dp spacing and 0.5 dp divider, without cards.
- Ordinary weekday: structured week title and separate weekday, without redundant rank.
- Shared readings: secondary text; existing reference deduplication and routes retained.
- Selected celebration, colors, selectors, dioceses and content logic unchanged.

Validation: two addressed widget tests PASS; Chrome 390 px and
320 px / 200% PASS. Native Flutter integration assertions PASS (411 dp,
48 dp bottom inset, three-button navigation). Native visual SafeArea:
**NOT TESTED** — a System UI ANR dialog obscured the screenshot.
The diagnostic image and raw logs remain in ignored `build/selector-driver`;
only these three usable PNGs are added to the repository.
Final `flutter analyze --no-pub`: **PASS**, no issues (178.9 s); covers all changed files after the nullable test argument fix.
The first scoped analysis found a nullable argument in the new integration
test; it was corrected before the passing browser run.

Screenshots (maximum four, no new matrix):

1. [Calendar](polish-chrome-light-calendar.png)
2. [16 October 2026, Hedwig selected](polish-chrome-light-hedwig.png)
3. [Alternative celebrations](polish-chrome-light-alternatives.png)

No Android device was connected at task start. The old local debug APK was
built before PR HEAD, without an embedded source SHA. Its correspondence to
the user's installed APK could not be confirmed (**NOT TESTED**).
The AVD had no discoverable old package. One x64 debug APK was built
(`1.0.0+6`, local SHA256
`479471de3b0c30ffe71fe07031b1f574f76c4cb5cb1af3f627e8ac3b800b1463`).
The running test printed the declared source SHA `de10a1c`.
Exact correspondence to a clean PR HEAD is **NOT CONFIRMED**: parallel,
uncommitted `app_overflow_menu.dart` changes were present before this build.
They were preserved and excluded from this PR update. The post-run package
hash/version query returned no path; installed APK hash verification is
**NOT TESTED**. No second APK build was attempted.
No merge, deploy or release build performed by this task.
