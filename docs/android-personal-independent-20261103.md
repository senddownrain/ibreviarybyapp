# Independent personal Android APK, 2026-11-03

## Confirmed history

Certificate aliases (SHA-256):
- A: `21b8f556979f25f321a3f6f21d8fe347ef1ac7d5ddd5b9738cae1e95ee408c3f` — permanent local Android debug key.
- B: `43183a2abf5a69de85cc8aeb6130e6b6ffb75bd36cc6ec0b6c7b1b4659ddfc4e` — former ephemeral CI debug key.
- C: `0df7e050b62a932b298d114c601cce7a46f503574b7c5b38d935f179b6ee308d` — existing repository upload key.

| APK / evidence | Package | versionCode | Certificate | Installation evidence |
|---|---|---:|---|---|
| Original MyBrev-PR20-phone-test-21a2206e-release.apk, rechecked with aapt/apksigner | by.mybrev.playtest2026 | 6 | A | Not evidence of the phone version 16 certificate |
| Latest former local release | by.mybrev.playtest2026 | 6 | A | Owner: VERSION_DOWNGRADE, Android retains 16 |
| Former cloud release | by.mybrev.playtest2026 | 6 | B | No successful owner installation |
| v17 with PR20 signer | by.mybrev.playtest2026 | 17 | A | Owner: UPDATE_INCOMPATIBLE |
| Intermediate v17 with repository upload signer | by.mybrev.playtest2026 | 17 | C | No owner installation result established |
| Archived installed-base.apk on this computer | com.example.ibrevapp | 6 | A | Historical file; not evidence of current phone state |
| Retained Samsung S23 package state | by.mybrev.playtest2026 | 16 | UNKNOWN | Only version and error codes confirmed |

No certificate is attributed to the retained phone version 16 without evidence. The original PR20 APK is versionCode 6, not 16.

## Independent configuration

The personal build explicitly opts into `MYBREV_PERSONAL_ANDROID=true`: package `com.example.ibrevapp`, launcher label `MyBrev Personal`, versionCode 18. An ordinary build still uses `by.mybrev.playtest2026` and its original Firebase options. Namespace `com.example.mybrev_flutter`, MainActivity, application logic, liturgical texts, content bundle, and Discovery are retained. D-1 comes from the verified application base 9d33116 / fix b3b17b8.

The existing Firebase Android client `1:344097781816:android:87ccd0e0b2d2ce93fd8ecd` was fetched read-only from project ibreviaryby via the authenticated installed Firebase CLI. The returned SDK JSON matches the repository google-services.json exactly. No Firebase project, client, API key, SHA registration, rules, database, or production data was changed. No new Firebase permissions are required for reusing this existing client. This is an independent local Android installation using the existing backend, not a newly isolated Firebase project. Network features on the physical phone remain untested.

Both the Android Gradle plugin and Dart select the same existing personal client. CI checks the packaged google_app_id, package name, label, unchanged launchable Activity, ARM64 support, minSdk 24, and absence of the old package/sharedUserId in the personal manifest.

## Signing and future updates

The final personal APK must use certificate A, matching the permanent local key in `%USERPROFILE%/.android/debug.keystore` and the known historical com.example.ibrevapp APK. The private keystore is never committed, published, or sent to GitHub. It must be preserved for future updates; future personal APKs must keep this package/certificate and use a non-decreasing versionCode. An ephemeral runner key is used only for an intermediate CI file, never the final delivered installation.

The final locally signed APK is passed to GitHub Actions as a prepared binary, verified against its exact SHA-256, package, version and signer, and uploaded as an Actions artifact. Only the APK and public verification metadata are transferred; temporary unpublished staging assets are removed after successful upload.

## Validation scope

New unit tests compare both Dart Firebase option sets with the native JSON and run with and without the personal build flag. Existing duplicate-app bootstrap tests are retained. CI also runs D-1, seasonal Common/hymn, P0 and tour regression tests, analysis and Release compilation. The previous full application suite passed 1699 tests with 9 explicit skips; that result is historical, not a claim that the new build has already completed a new full suite.

Chrome visual smoke: not needed for native identity/configuration and no Flutter screen changes; earlier graphical checks were excluded by owner due to RAM. Native smoke: NOT TESTED - OWNER WILL TEST ON PHYSICAL ANDROID DEVICE. No emulator is started. Package/signature/minSdk checks establish APK properties, not a successful installation on the S23.

A different Android applicationId is a separate package from by.mybrev.playtest2026: it does not update that old package or use its local data. No old package or saved data needs to be removed. If com.example.ibrevapp itself has unrelated retained state on the phone, that is a separate unknown and a new exact installer error would be required. No installation success is claimed before owner verification.
