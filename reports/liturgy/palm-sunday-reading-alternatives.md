# Office reading boundaries: Flutter port of Web #187

## Cause and change

Web source: https://github.com/senddownrain/mybrev/pull/187, merged as
`0a21e298f49990434a1dd77232164c2ef7081774`. Flutter base: `2420c45`.

`_categoryMarker` matched the beginning of the Scripture paragraph
«Пра гэта сведчыць нам і Дух Святы, бо сказана: …». With no `<hr>`,
`_splitAtRules` treated that paragraph as another reading and hid the ending
and responsory behind a false choice.

For `office-reading`, `_isAlternativeBoundary` now accepts a category only
when it occupies the entire first nonempty line (before `<br>`). `_categoryTitle`
requires the entire paragraph to be a category heading, matching Web #187.
Other content kinds retain their category rules. `_splitAtRules` still honors
explicit rules, markers and structured choices. `getReadingChoices` still
separates D-1 reference notes from legal readings and preserves the reference-only
fallback; its API and selection storage have not changed.

The regression fixture `test/fixtures/office-readings/palm-sunday-r1.html` is
byte-for-byte the HTML in Web #187, with its original entities and formatting.
No Firestore access, liturgical text edits, content bundle refresh or manifest
publication is needed or performed. Read-only inspection found the same visible
words in the bundled `days/feast-palmsunday` and `days/holyweek-w1-d1` R1,
but those bundled fields use plain text rather than the captured HTML. The exact
HTML fixture exercises the failing parser path directly; a device displaying only
the plain-text bundle is a weaker regression check.

## Parity update and additional D-1 discrepancy

The existing generator was run against the clean merged Web checkout, pinned:

```sh
node scripts/build_reading_choices_parity.mjs --web /workspace/mybrev \
  --expect-web-commit 0a21e298f49990434a1dd77232164c2ef7081774
```

All 386 bundle R1/R2 fields remain in the fixture. There are still 10 fields
with reference notes. Fields offering a choice decrease from 63 to 52:

- `martyr-one` R2, base and all four seasons (5 fields): the paragraph
  «Пра гэты келіх казалі мучанікі: …» remains in its reading.
- St Sebastian R2 (1 field): «Пра такія ганенні кажа Апостал: …» remains
  in its reading.
- `religious` R1, base and all four seasons (5 fields): a separate, previously
  merged Web D-1 correction was missing in Flutter. The short responsory-only
  block «Пра законніцу: Пс … / Н. … / К. …» after `<hr>` belongs to the preceding
  reading; it must not be offered as another Scripture reading. The same Web
  predicate (heading with citation, response/verse markers, paragraph and length
  limits) is now ported. Its words and printed position, including the rule,
  are preserved. Genuine rule-separated readings remain separate choices.

These are the only changed cases; the generator was not modified. Note hashes
are unchanged. Expected title/body hashes now describe complete readings from
Web, rather than retaining the former false splits. Palm Sunday has a separate
exact-HTML regression because this captured day is outside the Commons/Propers
parity fixture.

## Regression coverage

The new tests fail on the original parser: Palm Sunday returns two options
instead of one; the widget shows a false picker; quoted prose and martyr-one
also split incorrectly. With the port:

- Raw Palm HTML, `stripLeadingReadingHeading` output and formatted reader HTML
  each yield one reading, with the correct title and every visible word in order.
  Tests explicitly check the theme, final Scripture paragraph and responsory end.
- `AlternativeText` receives the entire Palm R1 and renders it without a picker
  or reference note. A separate widget test uses the actual `flutter_html`
  renderer, compares every rendered word in order and scrolls to the responsory
  ending at 390 px width. These are widget checks, not native visual inspection.
- Martyr-one base/seasons and St Sebastian preserve every word of R2.
- Office for the Dead retains its three explicit first readings, each compared
  with its complete source body, shared heading and suffix.
- Religious base/seasons preserve the reading and responsory variant together.
- Existing holy-women / holy-men D-1 tests check seasonal reference notes,
  legal reading counts, titles, priority of Proper readings, memory/reset behavior,
  and the picker at 320 px / 180% text / dark theme.
- The parity test compares option titles, complete ordered visible text and
  notes with Web for all 386 fields.

## Validation

Flutter 3.41.4 / Dart 3.11.1, matching the repository pin.

- `dart format --output=none --set-exit-if-changed` on the three changed Dart files: passed.
- `flutter test --no-pub test/reading_choices_test.dart test/liturgical_alternatives_test.dart`:
  34 passed in a fresh process after the broad run (exit 0), including all 386
  Web parity cases.
- Web `node --test tests/reading-choices.test.mjs tests/liturgical-alternatives.test.mjs`:
  29 passed on the pinned merged source.
- `flutter analyze --no-pub`: no errors or warnings; 12 info diagnostics in
  existing lines in `pastors_hymn.dart`, `consent_mock_test.dart`, and
  `reading_choices_test.dart` (line 58, formerly line 57). Flutter exits nonzero for infos.
  The repository preflight variant `flutter analyze --no-pub --no-fatal-infos`
  passed (exit 0), with the same diagnostics.
- Chrome visual smoke: not completed. `flutter devices` detected Chromium;
  `flutter run --no-pub -d chrome -t tool/palm_reading_temp_smoke.dart --web-port 5293`
  compiled an isolated offline harness with the exact fixture and real
  `AlternativeText` / `flutter_html` rendering, but Chromium aborted because its
  SUID sandbox helper is misconfigured. No screenshot/visual result is claimed;
  no browser security settings were weakened. The temporary harness was removed.
  To check the actual reader in a configured Chrome environment, use the existing
  `flutter run -d chrome -t tool/d1_reading_choices_smoke.dart --web-port 5291`,
  open `http://localhost:5291/?date=2026-03-29&dayId=feast-palmsunday&hour=lectionis`,
  and apply the steps below (this harness uses bundled content).
- Native smoke: not run; no native/plugin changes. Android visual checks below
  remain manual; native smoke is required before a separately authorized release.
- Baseline `2420c45` analyzed in a separate detached worktree: the same 12
  diagnostics and messages (one line shifts by the new import). No new analyzer findings.
- `flutter test --no-pub` completed in 25:03: **1698 passed, 9 skipped,
  7 failed** (exit 1). Five failures are existing calendar/navigation tests,
  reproduced independently on both this branch and the untouched base `2420c45`
  in a detached worktree. The first isolated command in each checkout was:

  ```sh
  flutter test --no-pub test/ordo_day_flow_test.dart \
    --plain-name 'Day → ORDO → Month → Day → back preserves month cursor'
  ```

  Both fail at `ordo_day_flow_test.dart:457` with `Bad state: No element` after
  tapping the month day, then report a disposed Riverpod container during cleanup.
  Four more failures are `day and month utility layout` in `ordo_ux_test.dart`
  (dark/light × 1.0/1.5 text scale). All four reproduce on both checkouts with
  `flutter test --no-pub test/ordo_ux_test.dart --plain-name 'day and month utility layout'`:
  `ordo_ux_test.dart:991` cannot hit-test `ordo-day-2026-11-01`.
  These tests and navigation code are unchanged; no test was skipped or weakened.
  The five existing navigation failures remain outside this parser fix.

  The other two full-run failures were `religious R1` and reading-choices parity
  (57 choices versus 52). That long-running process was started before the
  additional D-1 responsory port was complete and retained its earlier compiled
  parser. Its results are not claimed as a full run of the final commit.
  Fresh-process tests of the final parser are recorded above; the complete
  broad suite was not rerun after that source change. The large hours,
  lectionary, Ordo, runtime-audit and memorial-rule checks completed successfully
  in the broad run. The final reading test run additionally covers every bundle
  R1/R2 field with the corrected parser.

## Android visual check (1–2 minutes)

Use an Android debug build from this branch. Select 29 March 2026, Pinsk,
Palm Sunday (`Вербная нядзеля`), then `Час чытанняў`.

1. Under `Першае чытанне`, verify Hebrews 10:1–18 appears without a choice picker.
2. Scroll through «Пра гэта сведчыць нам і Дух Святы…» to the responsory ending
   «Вось іду, каб выканаць волю Тваю, Божа.» before the second reading.
3. Open Office for the Dead on an ordinary weekday and switch its three first
   readings. Check that each includes its ending and responsory. Return to Palm
   Sunday: the first reading still has no picker.
4. If convenient, repeat with large text/dark theme. St Sebastian (20 January)
   and Common of One Martyr R2 should likewise have one complete reading.

No merge, Android/iOS release or content publication is part of this change.
