# Reader content consistency audit — Phase 4B

Baseline: merged `main @ 7795d9f` (Phase 3B). This audit maps visible meaning to existing `ReaderTheme`, `LiturgicalSpacing`, `liturgicalDocumentStyles`, and domain renderers. `B` is the selected Aa body size; system `TextScaler` is applied by Flutter.

## Canonical semantic reader roles

| Role | Purpose | Canonical typography and color | Spacing | Readers; justified exceptions |
| --- | --- | --- | --- | --- |
| `documentTitle` | Name of the open document | Cormorant Garamond 700, 32–34, ink; system scaled | Context header owns transition to content | Ora hour, Prayer, Mass, Song, Bible book, Compendium question; Readings root already has a page title, Bible chapter and Compendium number remain context |
| `majorHeading` | Major division within a document | Cormorant 700, `blockHeading × 1.12`, rubric | Section before 24; title to body 8, unless divider owns transition | Mass ritual divisions; Compendium part divisions use the same hierarchy but preserve its outline |
| `blockHeading` | Ordinary content section | Cormorant 700, `max(1.42B, 22)`, height 1.12, rubric | Section before 24; body after 8, with first-block gap omitted when header already owns it | Ora, Readings, Prayer, Mass, Compendium part; source wording and ritual section IDs unchanged |
| `body` | Spoken prayer or long-form prose | Selected reader family at B, ink, height 1.68 | Paragraph after 8; structured strophes keep their own cadence | Ora, Readings, Prayer, Mass, Bible, Compendium; Song lyrics retain stanza layout, Mass dialogue retains speaker layout |
| `rubric` | Unspoken ritual direction | Reader family, `max(.90B, 14)`, regular, non-italic, height 1.48, rubric color | Paragraph after 8; source-specific section gap only when structurally justified | Ora, Prayer, Mass; red speaker labels, references, and selection are different roles |
| `reference` | Scripture, psalm, or CCC citation | Reader family, `max(.88B, 14)`, weight 500–600, height 1.40, muted | Gap to related body 7 | Ora, Readings, Compendium; a citation fused into a printed liturgical heading may retain rubric red |
| `metadata` | Date, cycle, translation, tags, context trail | Context UI uses system metadata; document metadata uses reader family, `max(.88B, 14)`, height 1.42, muted | Related body after 7; header composition retains its own gaps | All readers; Compendium number and trail and Bible translation retain their structure |
| `source` | Attribution or origin | Reader-family small text, muted; actual link underlined with accessible link semantics | Separated from document ending; no universal box | Song, Mass, Compendium; link and non-link presentation remain distinct |
| `divider` | Boundary between sections | Existing neutral separator | 22 before, 21 after where used | Ora; Mass separator keeps ritual width |
| `antiphon` | Liturgical refrain | Reader body with domain weight and cadence | 4 to psalm; 22 between psalm blocks | Ora only; never a generic heading |
| `bibleVerseNumber` | Verse address | Smaller high-contrast domain label | Inline beside verse | Bible only; selection and highlights stay on verse row |
| `massDialogue` / `massResponse` | Ritual speakers and responses | Reader body with domain emphasis | Ritual turn rhythm | Mass only; role labels are not rubrics |
| `songLyrics` / `songChord` | Stanzas and optional chords | Reader body / monospace chord | Stanza and side/above layout | Song only; transpose and visibility unchanged |
| `compendiumQuestionNumber` / `hierarchyTrail` | Question address and location | Context metadata | Header or outline rhythm | Compendium only; part anchor/navigation unchanged |

## Confirmed inconsistencies

- `ReaderContextHeader` uses a local system headline for semantic document titles while Readings uses Cormorant.
- Prayer and Mass `prayer-rubric` renders instructions as italic ink in a bordered block, unlike the Ora rubric role.
- Mass major/subsection line heights and gaps override the shared heading contract.
- Compendium part content headings use Material UI styles; CCC citations use `metadata` rather than `reference`.
- Song, Mass, and Compendium attribution each use local text styles rather than one source typography role.

## Intentional differences and evidence gates

- Bible verse numbers, selection, chapter navigation and measured bottom clearance; Mass dialogue, language, section navigator and bottom clearance; Ora antiphons and psalmody; Song chords and stanza layout; Compendium outline and pager remain domain-owned.
- The shared 700 dp maximum width remains until real-content comparisons at 320, 360, 390, and 700 dp demonstrate a clear improvement. No first-block spacing is removed without a rendered duplicate.

## Phase 4B resolution

The confirmed inconsistencies above were addressed in the existing reader tokens and domain renderers. A 360 dp emulator render of the first Mass block showed redundant space before its first major heading, so that heading alone loses its top section gap; later headings retain the standard 24 dp separation. Existing end clearances in Bible and Mass were left in place. No evidence warranted changing the 700 dp content maximum. The full cross-product of device widths, themes, system scaling, and Aa settings is still a visual QA follow-up; widget layout and semantic tests cover the most fragile combinations.
