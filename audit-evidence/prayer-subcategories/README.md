# Flutter prayer subcategories — contract v1

Web source: [PR #246](https://github.com/senddownrain/mybrev/pull/246),
`dab7b3157c34e0f9c4ec2137fb22d5494648a6b7` (rechecked on 2026-11-14).
[Contract](https://github.com/senddownrain/mybrev/blob/dab7b3157c34e0f9c4ec2137fb22d5494648a6b7/docs/prayer-categories-contract.md)
and [fixture](https://github.com/senddownrain/mybrev/blob/dab7b3157c34e0f9c4ec2137fb22d5494648a6b7/shared/prayer-categories/fixture.json).

Flutter base: current `main` `aacfd044546d6f2a8e1cc5eff2589fde6bd1ee99`,
including icons PR #108 (`60e8e7f9dbe69676d1042ae63809822f7cdf0046`).
Changes were checkpointed in `8cad1ed4443f46670ca81961de22847bb321c262`
before merging the newer main (local checkpoint). The original workspace was preserved.

## Behavior and storage

- Global model retains `iconKey`, `icon`, `iconId`, parent and finite order;
  optional `prayerIds` defaults to an empty list. The 48-icon catalog, SVGs,
  picker, user icon migration and chosen icons from #108 remain in use.
- One direct matcher implements tags OR manual IDs OR legacy IDs. Results are
  unique by prayer ID; descendants never expand the parent's prayer list.
  Personal tags/local manual membership retain their previous behavior.
- Access policy covers manual links at every keyed input: catalog, public
  snapshot, update overlay, public filtering and legacy Hive migration.
  Restriction wins; invalid parents, cycles and paths over 64 nodes close access.
- The public menu filters access before user hiding, promotes permitted children
  of user-hidden parents, prunes empty branches and retains global same-name IDs.
  Parents expand in place; their own prayers use a separate direct-list action.
  Leaves and old category URLs use the existing list and reader.
- Session state contains expanded IDs only. Back/remount retains expansion;
  reader/back retains scroll. Protected data stays in the existing grant-gated
  memory channel. Opaque private IDs remain in canonical public category data.
  Revocation also filters retained asynchronous category names in management UI.

## Contract matrix

`test/prayer_category_contract_test.dart` reads the Web fixture and its expected
IDs, including maps deliberately missing embedded IDs to exercise document keys.

| Case | Assertion | Result |
| --- | --- | --- |
| C01 | Missing optional field: tags and legacy work | PASS |
| C02 | Empty untagged folder is valid | PASS |
| C03 | Direct OR union, unique IDs, public restriction, no descendants | PASS |
| C04 | Two-level leaf membership | PASS |
| C05 | Own/inherited/manual restriction wins | PASS |
| C06 | Nonempty ancestors retained, empty branch removed | PASS |
| C07 | Removing manual ID preserves tag membership | PASS |
| C08 | Last restricting manual link removed: public again | PASS |
| C09 | Moving parent under closed ancestor restricts leaf prayer | PASS |

## OLD DECODER × NEW GZIP: PASS

Frozen old Flutter: `60e8e7f9dbe69676d1042ae63809822f7cdf0046` in a detached
checkout, with no tracked source edits. The decoder and schema version are
unchanged in this PR. The compatibility test uses only APIs present at that SHA.

The gzip was produced by the **actual Web `writeBundle`** from the SHA above,
with its real codec, hashing, public filtering and string table. Inputs are
synthetic C01–C09 plus an untagged `codec-probe` with a long opaque reference,
long name and existing icon fields to force string-table references.
No production snapshot or live Firestore was accessed.

```sh
# Web checkout must be at dab7b3157c34e0f9c4ec2137fb22d5494648a6b7.
node tool/generate_prayer_category_fixture.mjs /path/to/web-pr246

git worktree add --detach /path/to/flutter-old 60e8e7f9dbe69676d1042ae63809822f7cdf0046
cp -r test/fixtures/prayer-categories /path/to/flutter-old/test/fixtures/
cp test/prayer_category_old_decoder_test.dart /path/to/flutter-old/test/
cd /path/to/flutter-old
flutter pub get --offline
flutter test --no-pub test/prayer_category_old_decoder_test.dart --reporter expanded
```

Observed: **3 PASS** — schema/decode/string table/document hashes/old model;
ContentStore bundle → overlay → close/restart/reload; real old category list UI.
See [old-decoder.log](logs/old-decoder.log). The final model also retains and uses
manual IDs from the same gzip; the bundled fixture is under
`test/fixtures/prayer-categories/`, never under published `assets/content/`.

Decoder source blob: `b64bec3c6b74bab809e8db432afd782ed98a3384`.
Synthetic archive SHA-256:

```text
prayerCategories.json.gz  e69fbd4483b2a449ff412db3748434a9caf1f85ec74f5be9d7a6c2081e066354
prayers.json.gz           1f9025d974c41dd1837354d0d298181ac1ef9d2026f7e92b32f9eaeef8b775ac
```

This proves old Dart source compatibility, **not** an old APK/TestFlight binary.
Older versions still lack manual-membership and accordion semantics. Coordinate
Web and Flutter review, then test protected delivery and native builds before a
separate owner decision about publishing a new bundle/application release.

## Verification

Flutter 3.41.4, Dart 3.11.1; Linux with Flutter Chrome device (Chromium 154).

- Initial contract and existing prayerbook/security regression set: **70 PASS**,
  [log](logs/initial-targeted.log). No need to repeat the old frozen-client gate.
- Resumed widget/security/icon set: **56 PASS**, [log](logs/widget-security-icons.log).
  Includes all 48 icons/picker/personal icon storage, chosen Mary/rosary/candle
  icons in the expanded tree and after Hive restart, grant/background/offline/
  resume/revoke, absence of private disk data, opaque IDs, legacy migration,
  keyboard Tab/Space/Enter, direct-only list, reader/back and scroll.
- Widget layout matrix: Android and iOS **theme/platform configuration**, three
  themes × 320/375/768 widths × 100%/200% text = **36 configurations**.
  These are widget tests, not Android/iOS binary runs.
- `flutter analyze --no-pub`: **0 errors, 0 warnings, 29 existing infos**; strict
  command exits 1 on infos. Clean baseline/evidence: [baseline-main.txt](logs/baseline-main.txt).
  [Current analyzer output](logs/flutter-analyze.log).
- Full final `flutter test --no-pub --reporter expanded`: **2030 PASS / 9 SKIP /
  2 FAIL**, [summary](logs/flutter-full.log), [complete compressed output](logs/flutter-full.log.gz).
  Failures: `lectionary_parity_test.dart` (38 route-ID differences,
  `mary-mother-church` vs `feast-marymotherchurch`) and `hours_parity_test.dart`
  (existing Marian day routes/template differences). Clean-main reproductions
  are recorded below. No category/security/widget/icon test failed.
  The earlier clean-main run completed with 1957 PASS / 10 SKIP
  including the three added compatibility checks (1954 original tests).
- `dart format --output=none --set-exit-if-changed` on all 20 changed Dart files:
  **PASS**, zero changes. `git diff --check`: **PASS**.

Chrome reproducer:

```sh
flutter devices
flutter run --no-pub -d chrome -t tool/prayer_categories_smoke.dart --web-port 5237 \
  --web-browser-flag=--no-sandbox --web-browser-flag=--headless
# Use that Chrome instance's --remote-debugging-port (do not start another).
python3 scripts/smoke_prayer_categories.py --cdp http://127.0.0.1:PORT --flutter-sdk /path/to/flutter
```

Synthetic-only Chrome screenshots and machine results live in this directory.
Observed: **18 PASS** (3 themes × 3 widths × 2 font scales), plus the direct-only
list → leaf → real reader → existing in-app Back twice: **PASS**, no page errors.
[Machine results](results.json), [Chrome log](logs/chrome-visual.log),
[reader](reader.png) and [return to expanded tree](reader-back.png).
The resumed screenshot runner retained 15 completed cases after the debug tab
crashed on repeated DDC reloads, then completed the remaining three in the same
scenario using live theme/text controls. This is recorded in the machine results.
Screenshots were opened and inspected, including each theme at 320px/200% and
the complete three-icon tree at 375px/200% and 768px.
The harness shows Mary on the parent, rosary on its child and candle on the leaf.
The external engine/font CDN was unavailable; the browser script serves the
matching installed SDK CanvasKit and Roboto through request interception.
Actual app screens, SVG assets, navigation and reader are used.

Native smoke: **not run** — no Android/iOS device is attached. Required before
mobile release: grant verification/revoke/offline/background/foreground on a real
device, native Back, icon selection persistence and protected reader re-entry.
No binary, emulator or live Firebase authorization claim is made here.

## Clean current-main failures

Detached checkout `aacfd044546d6f2a8e1cc5eff2589fde6bd1ee99`, no tracked
source changes, same Flutter SDK and bundle:

```sh
flutter pub get --offline
flutter test --no-pub test/lectionary_parity_test.dart --reporter expanded
flutter test --no-pub test/hours_parity_test.dart --reporter expanded
```

Hours: **FAIL reproduced**, with an identical assertion body to this branch
([main-hours.log](logs/main-hours.log), [comparison](logs/baseline-comparison.json)).
Readings: **FAIL reproduced**, identical assertion and the same **38 route-ID
differences** ([main-lectionary.log](logs/main-lectionary.log)). Both clean-main
assertion bodies match this branch byte-for-byte. These broad
calendar/fixture differences need their own resolution before a green full suite;
category work does not change their sources or weaken their assertions.

## Scope and release

Only Flutter changes are proposed. No Web writes, production Firestore changes,
live apply, manifest/bundle publication, schema bump, merge, deploy or store release.
Published assets and the decoder have zero diff against the updated Flutter main;
calendar/bundle changes arriving from #107 are only part of the base branch.
Global structure remains read-only on the Flutter client.
