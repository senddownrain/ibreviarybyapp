# Unified Flutter reader settings

Base: `origin/main` `19125bb` (Marian theme). Branch: `feat/reader-settings-unified`.

All choices remain in `settingsProvider` and the existing Hive `settings` box.
`fontFamily` IDs `literata`, `system`, `sourceSerif4` and all psalmody IDs/keys
retain their meanings. New IDs: `oldStandardTT`, `kurale`; new key
`textAlignment`: `start` (including missing/invalid values) or `justify`.
No Hive reset, second preferences store, new analytics, Firebase mutation or release.
Font size/family setters write their own keys rather than asynchronously saving
unrelated preferences. This also makes a close/reopen test deterministic.

`ReaderTextSettings` is one `ExpansionTile` with local `PageStorage` expansion:
size, existing font example, shared five-family selector, and alignment.
Psalmody remains the next independent section. The reader sheet reuses the
same family/alignment controls; `showPsalmody` selects the original three-mode
selector instead of alignment. The long example appears only in Settings. The panel header measures its title and percentage at the current system scale; a narrow 320 dp panel moves the percentage below the title instead of breaking the word. The start-section dropdown uses available width and variable-height items so enlarged labels fit.

## Renderer coverage

| Reader | Font/size | Prose alignment | Deliberate exclusions |
| --- | --- | --- | --- |
| Bible | `ReadingScaffold` → `ReaderTheme.body` | `_VerseRow`'s existing `RichText`, including verse number | Explicit line breaks/markers |
| Readings | same | `_ReadingText` plain paragraphs and `ReaderProseHtml` | Psalms, sequences, acclamations, Passion roles, labels, citations, rubrics |
| Reading detail | same | HTML paragraphs / plain selectable text | Markers and fixed lines |
| Prayerbook + editor preview | `PrayerContent` / shared style | Semantic HTML prose | Speakers, rubrics, lists, strophes, fixed `<br>` |
| Mass | same, all language variants | `_MassDocument` chunks after semantic parsing | Headings, role labels, responses, posture, alternatives, rubrics, fixed lines |
| Catechism / Compendium | same | `CompendiumAnswer`'s existing rich spans | Question headings, references, printed citation blocks, navigation |
| Ora / Hours | same, including both new families | Never opts in | Entire Office, all three psalmody modes, hymns and responses |
| Devotional offices / songs | same | Never opts in | Existing lineation and choir rendering |

`prepareReaderProseHtml` only marks eligible paragraph elements; it preserves
inline emphasis, links, text and semantic role classes. The shared HTML widget
applies alignment to that class, never to `body`, a global theme or all `Text`.
Separate Flutter prose paragraphs keep the final line short; paragraphs with
forced line breaks remain at start. Existing sentence recognizers and highlight
IDs remain stable across Readings paragraphs.

## Fonts and licenses

Installed `google_fonts` is 6.3.3 and implements `oldStandardTt` and `kurale`.
The genuine upstream TTFs and verbatim OFL texts are bundled under
`assets/google_fonts/`, already declared in `pubspec.yaml`. Application startup
disables runtime font fetching and registers both licenses with `LicenseRegistry`.
Old Standard TT includes regular, italic and bold; Kurale has the upstream regular
face (Flutter synthesizes emphasis from that face, as for the existing body faces).

Sources:

- <https://github.com/google/fonts/tree/main/ofl/oldstandardtt>
- <https://github.com/google/fonts/tree/main/ofl/kurale>

[Font inventory and SHA-256](../audit-evidence/reader-settings/fonts.json) records
actual internal family names and verifies `ўЎіІёЁ†*` in every bundled face.
Reproduce with `python tool/audit_reader_fonts.py` (fontTools required).
The Flutter typography test loads all five choices with network fetching disabled.

## Psalm example shared with Web

The source is **Psalm 63 (62), 2–3**, the exact three strophes in
[Web PR #202](https://github.com/senddownrain/mybrev/pull/202), pinned to commit
`38e94e65b2d944eb34b6c86ef761b1d5b28284cd`,
[`src/constants/psalmodyPreview.js`](https://github.com/senddownrain/mybrev/blob/38e94e65b2d944eb34b6c86ef761b1d5b28284cd/src/constants/psalmodyPreview.js).
The documented real text source is `patchs/json/ordinary-w5-d1-fixed-day.json`,
field `laudesPs1`. The independent JSON fixture captures that Web constant and
its provenance; the test compares Flutter's HTML byte for byte with it.

`formatPsalmHtml` and `PsalmChoirHtml` are precisely the production Hours
pipeline. No new psalm layout algorithm or source-content edits are introduced.
The excerpt contains three `*` markers; the existing pipeline's `†` handling is
covered by the psalmody rendering tests, without inventing extra sample verses.

## Overflow menu

The existing root-overlay popup, contextual actions and post-dismiss navigation
are preserved. Width is measured from actual labels using the active UI font
and `TextScaler`, plus icon/gap/padding; a compact 224 dp minimum grows as needed,
with a 360 dp ceiling limited by the viewport and safe horizontal insets.
Standard short actions therefore no longer allocate a blanket 360 dp.

The popup anchor is the button's right edge, four dp below its bottom, recomputed
in overlay coordinates by `positionBuilder`. Framework safe-edge clamping remains
in charge; no translations or device offsets. All actions are direct actions,
so their trailing chevrons are removed. Touch rows remain at least 48 dp.
Existing shell, adaptive app bar, floating actions and reader scaffold share this
one implementation, including Prayerbook's category action.

## Validation and visual evidence

See [acceptance evidence](../audit-evidence/reader-settings/README.md) for exact
commands, results, before/after screenshots and platform limitations.
