# Phase 4A — Reader & Content Consistency Audit

**Срез:** `main` @ `ad437ff`, 2 октября 2026. Статус: audit/prototype, без изменений production readers. **Метод:** `CODE` — проверено по указанному production-коду; `LAB` — проверено на изолированных mock-сценариях; `DEVICE` — требует проверки реального содержимого и платформенного рендеринга. Ни одна рекомендация не означает, что соответствующее runtime-поведение уже проверено. Канон: [Concept](DESIGN_CONCEPT.md) → [System](DESIGN_SYSTEM.md) → [Liturgy content spec](../LITURGY_CONTENT_VISUAL_SPEC.md); [consolidated review](../DESIGN_CONCEPT_VNEXT.md) используется как датированный контекст. `TOP_CHROME_AUDIT.md`, `FOUNDATIONS_POST_MERGE_AUDIT.md` и `ROOT_SCREEN_SYSTEM.md` отсутствовали в `main` на этом срезе. Draft-аудиты Phase 2B/3A прочитаны для координации, но их незавершённые решения не приняты здесь как API.

## 1. Executive summary

**Уже общее (`CODE`).** Шесть detail readers используют `ReaderScaffold` с непрозрачным `ReaderContentSurface`, общим контекстным header и `ReadingScaffold → ReaderTheme.body`: Hours, Prayer/Mass, Bible, Song и Compendium question (`lib/widgets/reader/reader_scaffold.dart:64,434,593`; вызовы в названных ниже экранах). `ReaderTheme.blockHeading`, `LiturgicalSpacing` и `liturgicalDocumentStyles` уже закрепляют смысловые роли Hours/Readings (`lib/theme/reader.dart:36,158`; `lib/theme/liturgical_document.dart:7`). Это сохранять.

**Главные расхождения (`CODE`).** `ReadingDetailScreen` использует собственный `Scaffold`/`SingleChildScrollView` с полями 16/40 вместо reader page (`lib/screens/reading_detail_screen.dart:63-121`); Compendium part — отдельный `Scaffold`/`ScrollablePositionedList` с полями 20 и нижним резервом 104 (`lib/screens/compendium_screen.dart:183-236`). Контекст Readings собран отдельно (`lib/screens/readings_screen.dart:763-870`). Prayer/Mass держат параллельную HTML-карту с собственными `p`, `h2`, `h3` и rubric spacing (`lib/screens/prayer_detail_screen.dart:363-466`). У `ReaderContextHeader` низ 22 и у `ReaderContentSurface` верх 25: до первого блока получается 47 logical px ещё до внутренних margins (`lib/widgets/reader/reader_scaffold.dart:455-472,638-645`). Это измеримая зона для `REFINE`, а не доказанный визуальный дефект на каждом тексте.

**Вывод.** Общий контракт нужен для книжной колонки, роли контекста, семантических metadata и понятного конца документа. Различия структуры Hours, ритуала Mass, стихов Bible, песенных аккордов и вопросов Compendium сохраняются.

## 2. Current shared foundations

`ReaderScaffold` ограничивает header и страницу одним `maxContentWidth = 700`, размещает контекст над непрозрачной поверхностью и закрашивает остаток экрана `ReaderTheme.surface` (`lib/widgets/reader/reader_scaffold.dart:75-171`). `ReaderContentSurface` даёт поля 22, верх 25, низ `42 + MediaQuery.padding.bottom` (`:434-477`). `ReadingScaffold` применяет сохранённый размер/гарнитуру к body (`lib/widgets/reading_scaffold.dart:6-25`). `ReaderTheme` даёт body 1.68, rubric 1.48, reference 1.40, metadata 1.42 и Cormorant content headings (`lib/theme/reader.dart:36-155`). Цвета поверхности/чернил/рубрик/границ берутся из semantic `IbColors`, светлого или тёмного (`lib/theme/reader.dart:46-57`). Эти foundations не менять в 4A.

## 3. Reader inventory

Обозначение `700/22` — max width/горизонтальные поля, logical px. `RS` — `ReaderScaffold`, `RCS` — его `ReaderContentSurface`. Таблица описывает код, а не одобрение каждого отступа.

| Reader | Page width | Header | Body role | Section headings | Metadata | Footer/end | Bottom reserve | Special UI | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| Hours, все 9 `oraType` | RS 700/22 | `ReaderContextHeader` + optional feast comment | `ReaderTheme.body`, HTML/plain | `LiturgicalSectionHeading`, HTML roles | date, day, psalter, rank | `· · ·` | RCS 42+safe area | antiphons, alternatives, psalms | PRESERVE + REFINE |
| Readings collection/day | RS 700/22 | собственный `_ReadingsContextHeader` | `ReaderTheme.body`, parsed/HTML | `blockHeading`, shared spacing | date, cycle, references | content adds 32 | RCS 42+safe area; selection extra | group/cycle/alternatives, sentence selection | REFINE + DOMAIN-SPECIFIC |
| Reading detail (legacy route) | без RS, поля 16 | `AdaptiveAppBar` | `ReaderTheme.body`, HTML/plain | shared HTML roles | cycle chip | scroll padding 40 | 40 only | raw HTML/share | UNIFY selectively |
| Ordinary Prayer | RS 700/22 | `ReaderContextHeader` | `ReaderTheme.body`, HTML/plain | local HTML `h2/h3` based on blockHeading | tags | raw body end | RCS 42+safe area | favorite, Aa, local edit | REFINE |
| Holy Mass | RS 700/22 | `ReaderContextHeader` | `ReaderTheme.body`, structured HTML | major/subsection/minor | language, ritual roles | ritual text end | RCS + measured Mass bar | rubric/dialogue/sections/language | PRESERVE + DOMAIN-SPECIFIC |
| Song | RS 700/22 | `ReaderContextHeader` | `SongText` from reader body | refrain/strophes in song renderer | tags, source | source divider if present | RCS 42+safe area | chords/transpose/favorite | PRESERVE + REFINE |
| Bible chapter | RS 700/22 | `ReaderContextHeader` with title action | `ReaderTheme.body` verses | chapter title in context | testament, translation, attribution | last verse | RCS + chapter bar/selection reserve | verse selection/highlight/search | PRESERVE + DOMAIN-SPECIFIC |
| Compendium question | RS 700/22 | `ReaderContextHeader` | `CompendiumAnswer` from reader body | question title in context | number, trail, CCC refs, source | pager then attribution | RCS 42+safe area | prev/next, search, citations | REFINE + DOMAIN-SPECIFIC |
| Compendium part/list | no RS; fields 20 | `_PartHeader` | UI list styles, citation text | `_PartItem` local hierarchy | part label, citations | attribution | fixed 104+system inset | anchored list/search | REFINE + DOMAIN-SPECIFIC |

Sources: `lib/screens/ora_screen.dart:420,508-541,562`; `readings_screen.dart:610,763,1245`; `reading_detail_screen.dart:63-135`; `prayer_detail_screen.dart:245-291,363-466`; `song_detail_screen.dart:94-151,156-188`; `bible_chapter_screen.dart:243-340,744-813`; `compendium_reader_screens.dart:84-120`; `compendium_screen.dart:149-236`; `widgets/compendium/compendium_widgets.dart:341-489`. Hours variants map to `invitatorium`, `morning`, `lectionis`, `laudes`, `terz`, `sext`, `non`, `vespers`, `completorium` in `ora_screen.dart:497-507`; `morning` is the composite variant.

## 4. Geometry and header → content rhythm

**CODE.** The six RS detail readers inherit the same 700 max width, 22 side padding, 25 content top, and 42+safe bottom. Header is outside the page, constrained to the same max width, with 22 side padding and 22 bottom (`lib/widgets/reader/reader_scaffold.dart:147-171,434-472,630-646`). Thus a plain first line begins 47 px below the final header item; the first Hours/Readings section may add `LiturgicalSpacing.sectionBefore = 24` (`lib/theme/reader.dart:158-170`). An Ora feast comment adds its own 22 bottom below the header (`lib/screens/ora_screen.dart:611-625`). Check actual start gaps by content kind before changing either owner.

`ReadingDetailScreen` has 16 side, `MediaQuery.padding.top + kFloatingAppBarContentInset`, and 40 bottom, without max width or opaque RCS (`lib/screens/reading_detail_screen.dart:63-121`). Compendium part/list use 20 side, top `safeTop + 90`, bottom `104 + viewPadding.bottom`, without max width (`lib/screens/compendium_screen.dart:120-132,202-214`). These are real geometry exceptions; part anchors/search make wholesale RS replacement risky. Bible adds measured chapter-bar or selection reserve inside content (`lib/screens/bible_chapter_screen.dart:285-328`); Mass uses a measured section-bar height (`lib/screens/prayer_detail_screen.dart:565-590,650-700`). Do not substitute a fixed padding for either. The design-system 36em/roughly 660 guideline is a **hypothesis to test**, not a new production value (`DESIGN_SYSTEM.md`, Reader rhythm).

## 5. Typography, heading hierarchy, rubrics and dividers

**CODE.** Hours/Readings share Cormorant `blockHeading` with semantic spacing; `liturgicalDocumentStyles` maps headings, references and rubric classes (`lib/theme/liturgical_document.dart:7-91`; `lib/screens/ora_screen.dart:1490-1548`; `readings_screen.dart:1253-1280`). Mass uses `majorHeading`/`blockHeading` faces for ritual levels, plus local styles for role labels, responses, posture and alternatives (`lib/screens/prayer_detail_screen.dart:465-534`). Those local semantic ritual levels are justified. Prayer/Mass also define local `p` bottom 10, `h2` top16/bottom8, `h3` top14/bottom6 and `.prayer-rubric` as an inset, italic, bordered block (`:383-462`); compare visual rhythm against the shared HTML factory before any 4B consolidation. Do not turn every red line into a heading: rubrics, references and service headings have separate roles.

Bible verse number is an intentional local `TextStyle` at 0.64× body size with weight 800 and top-aligned `WidgetSpan`; its baseline and TalkBack sequence require device review (`lib/screens/bible_chapter_screen.dart:775-811`). Song chord size/layout is resolved from available width and text scale, with fallback from side to above (`lib/widgets/songs/song_text.dart:11-83`); prose styling would break the chord grid. Compendium answer uses reader body and local paragraph spacing `size * .6`, citations `size * .8`, CCC refs via `reader.metadata` (`lib/widgets/compendium/compendium_widgets.dart:341-439`); part headings instead use UI `TextTheme` (`lib/screens/compendium_screen.dart:238-354`). This distinction is structurally valid, but the boundary between reading hierarchy and list UI needs visual comparison. `LiturgicalSectionDivider` is structural in Hours (`lib/theme/liturgical_document.dart:91-106`); Song and Compendium source blocks have a top border (`lib/screens/song_detail_screen.dart:156-188`; `compendium_widgets.dart:24-91`). Preserve each meaning, do not replace all with one divider.

## 6. Context headers, metadata and references

`ReaderContextHeader` supports optional eyebrow/title/subtitle/metadata/details/actions and tappable title with explicit semantics (`lib/widgets/reader/reader_scaffold.dart:593-698`). Hours uses date, feast/day summary, location and hour-switch; Bible uses book title as picker plus chapter and translation; Song uses chord controls in `details`; Prayer/Mass use simple title/tags (`lib/screens/ora_screen.dart:562-625`; `bible_chapter_screen.dart:268-283`; `song_detail_screen.dart:106-135`; `prayer_detail_screen.dart:281-286`). **Minimum shared contract:** one content title, optional small context, optional source/metadata, explicit action semantics, and alignment with the text column; not identical fields or tap behavior.

The shared header currently styles its title from `textTheme.headlineSmall` at 27 rather than `ReaderTheme.displayTitle` (`lib/widgets/reader/reader_scaffold.dart:622-630`). The canonical Cormorant page-title role therefore still needs a coordinated decision with Phase 3B; changing this shared widget in 4A would affect all readers at once.

Readings has a distinct date action, celebration title, cycle metadata, Today/Options buttons and a 36-point Cormorant root title (`lib/screens/readings_screen.dart:763-870`). This is collection/context, not the same thing as an individual long-form reading; preserve the date control while aligning roles/spacing. `ReadingDetailScreen` has title only in the app bar plus a cycle chip (`lib/screens/reading_detail_screen.dart:63-112`), a stronger visual disconnect. Metadata can be grouped into **context trail** (date/cycle/part), **document reference** (Bible/psalm/CCC), **source attribution** (end block/link); links remain interactive and announced. Do not coerce tags, references and citations into one visual token. `ReaderTheme.referenceStyle` and `metadata` already provide a foundation (`lib/theme/reader.dart:103-153`).

## 7. End-of-document

**CODE.** Ora appends 12 and `· · ·` after its content (`lib/screens/ora_screen.dart:508-541`). Readings appends 32 before RCS bottom 42 (`lib/screens/readings_screen.dart:1244-1249`). Prayer/Mass end with their last HTML/plain block, then RCS bottom, with Mass bar reserve calculated separately (`lib/screens/prayer_detail_screen.dart:287-291,363-466,650-700`). Bible ends at the final verse, with chapter-bar/selection reserve (`lib/screens/bible_chapter_screen.dart:285-344`). Compendium question puts pager before source attribution and RCS bottom (`lib/screens/compendium_reader_screens.dart:104-120`); part ends in attribution after 104+system padding (`lib/screens/compendium_screen.dart:202-233`). Song has a source border only when source exists (`lib/screens/song_detail_screen.dart:136-188`). Legacy Reading detail has 40 bottom (`lib/screens/reading_detail_screen.dart:90-121`). **Proposal:** shared *end clearance* rule measured against the active bottom owner, with optional source shell and domain-specific terminal marker; `· · ·` stays Hours-specific unless visually justified elsewhere. No generic end marker is required.

## 8. Reader surface, dark mode and states

**CODE.** RS always paints the document with `ReaderTheme.surface`; the header area uses scaffold/ambient backing (`lib/widgets/reader/reader_scaffold.dart:137-200,434-477`). Part/list Compendium draws on `AmbientWash` without RCS (`lib/screens/compendium_screen.dart:183-236`); Reading detail draws a plain `Scaffold` (`lib/screens/reading_detail_screen.dart:63-121`). This answers the surface question: one clear opaque page exists for RS readers, not yet for every reading route. `ReaderTheme` supplies dark semantic ink/muted/rubric/border, but Bible verse text/number/selection use `ColorScheme` directly (`lib/screens/bible_chapter_screen.dart:758-810`), and Compendium part uses UI colors (`lib/screens/compendium_screen.dart:238-354`). Inspect contrast on actual composited light/dark screens before labelling either invalid.

Loading/empty/error presentations vary: Hours falls back to a separate `Scaffold` for missing/error (`lib/screens/ora_screen.dart:439-493`); Prayer has RCS not-found but separate empty-body illustration (`lib/screens/prayer_detail_screen.dart:225-229,330-361`); Song/Compendium use `AppProgressLine` within RS (`lib/screens/song_detail_screen.dart:68-85`; `compendium_reader_screens.dart:17-30`); Reading detail uses its own app bar/empty state (`lib/screens/reading_detail_screen.dart:38-59`); Readings uses `_ReadingsStatus` (`lib/screens/readings_screen.dart:1041-1101`). A 4B state pattern should keep *loading, missing locally, empty and error* distinct while sharing page position and tone. No state renderer is changed in 4A.

## 9. Scaling and long-form comfort

**CODE.** Production `ReadingScaffold` applies stored reader font size independently of Flutter's system `TextScaler` (`lib/widgets/reading_scaffold.dart:6-25`). Current setting permits Aa 70–180%; design-system 85% lower bound is future direction, not an authorized value change (`lib/providers/settings_provider.dart`; `DESIGN_SYSTEM.md`, Aa). Main RS max width remains 700, while design system suggests testing ~36em/~660. Long titles, Compendium question, Bible verse `WidgetSpan`, Song right-chord fallback and Mass section headings are priority cases. **LAB:** mock layout matrix covers widths 320/360/390/700 × Aa 70/100/180 × system 100/150/200 × light/dark, with Aa and system represented independently. Lab success does **not** prove production HTML, data-driven titles, screen-reader order or physical safe areas. **DEVICE:** those cases remain open until a real-content visual pass on iOS/Android.

## 10. Accessibility, controls and scroll

**CODE.** Shared context title action has a button label (`lib/widgets/reader/reader_scaffold.dart:655-677`); Compendium source announces a link (`lib/widgets/compendium/compendium_widgets.dart:76-91`). Bible verse is tappable and highlights/selection are visible but verse number is embedded as `WidgetSpan`; verify announced verse number, selected state and reading order on TalkBack/VoiceOver (`lib/screens/bible_chapter_screen.dart:744-813`). Mass section navigation, language switching and active section tracking form a ritual reader contract (`lib/screens/prayer_detail_screen.dart:245-291,535-700`); preserve it. Song chord toggles/transpose need state labels under large scaling (`lib/screens/song_detail_screen.dart:106-135`; `lib/widgets/songs/song_chord_control.dart`). Compendium question has `PageStorageKey` and swipe prev/next; part has indexed anchor jumps; Bible disables chapter swipe while verses are selected (`lib/screens/compendium_reader_screens.dart:84-120`; `compendium_screen.dart:183-214`; `bible_chapter_screen.dart:243-249`). These are purposeful differences. The interaction with scroll-to-top, double-tap focus mode and restored anchors needs device QA, especially after Aa changes; audit does not replace that test.

On this `main` slice scroll-to-top is enabled for ordinary Prayer, Song and Compendium question, disabled for Mass, and not requested by Ora, Readings or Bible (`lib/screens/prayer_detail_screen.dart:252`; `song_detail_screen.dart:101`; `compendium_reader_screens.dart:94`; `ora_screen.dart:420-430`; `readings_screen.dart:610-628`; `bible_chapter_screen.dart:243-259`). Phase 2B is already changing Ora's control, so 4B should re-read the integrated code rather than copy this snapshot.

Content controls: alternatives, cycle, chords, verse selection and source links belong with their document/context. Aa, back, share, favorite and Mass language are reader chrome actions in current layouts; classification does not authorize relocation during 4A. Search and bottom ownership belong to parallel phases.

## 11. Differences that MUST remain

| Domain | Required distinction |
|---|---|
| Hours | fixed office order; antiphons, psalmody, rubrics, hymn cadence, optional feast comment and Hours end marker |
| Readings | date/cycle/group/alternative selection, biblical reference, separate collection context and long-form reading |
| Prayer | short, simple body with favorite and optional tags; no ritual controls |
| Mass | ritual section hierarchy, posture/rubric/dialogue/response semantics, language variants and existing measured section navigator |
| Bible | chapters, numbered verses, selection/highlights, translation and search entry context |
| Compendium | question/answer, part hierarchy, CCC refs, citations, source link, indexed anchor and search |
| Song | strophes/refrain, chord typography and measured fallback, visibility and transpose |

## 12. Shared reader contract and plausible primitives

1. **Page:** opaque semantic reader surface, text-aligned context and body, bounded readable column. Width ≤36em/~660 is a candidate to compare, not an automatic migration of existing 700.
2. **Context:** one document title plus optional eyebrow, subtitle, context trail and actions. Collection headers may be richer; action labels and tap targets stay explicit.
3. **Body:** selected reader family/size for prose; accepted Cormorant semantic headings; `ReaderTheme`/`liturgicalDocumentStyles` for existing roles. Ritual, biblical, catechetical and musical renderers remain separate.
4. **Metadata:** context trail, document reference and source attribution are the three useful shared roles; rubric is its own content role.
5. **Rhythm:** header owns its internal spacing; page owns the header→first-block handoff and terminal clearance. Domain blocks own their internal cadence; the bottom owner supplies measured obstruction height.

Reusable candidates: `ReaderContentSurface`, `ReaderContextHeader`, `ReaderTheme` roles, an optional source-attribution shell and an end-clearance helper. No `UniversalReader`. In 4B compare a small semantic wrapper or role mapping against current local code before extracting components.

## 13. Preserve / Refine / Unify and real anti-patterns

**PRESERVE:** `ReaderTheme` roles, shared liturgical HTML/spacing, Mass section navigator, Bible verse semantics, Song chord fallback, Compendium source/anchor structures. **REFINE:** header→body air, semantic metadata presentation, short Prayer end, source shell, Compendium part reading surface. **UNIFY selectively:** Reading detail page geometry and source/end semantics, not its raw/share feature. **DOMAIN-SPECIFIC:** all items in §11.

Actual candidates for cleanup: parallel HTML style map in Prayer/Mass (`lib/screens/prayer_detail_screen.dart:363-466`); local width/padding literals in Reading detail and Compendium part (`lib/screens/reading_detail_screen.dart:90-121`; `compendium_screen.dart:202-214`); duplicated source border/text composition in Song and Compendium (`lib/screens/song_detail_screen.dart:156-188`; `lib/widgets/compendium/compendium_widgets.dart:24-91`); local metadata styles in Readings and part header (`lib/screens/readings_screen.dart:824-855`; `compendium_screen.dart:238-354`); bottom reserve arithmetic in Bible/Mass, which is **necessary measured behavior**, not a literal to delete (`lib/screens/bible_chapter_screen.dart:285-328`; `prayer_detail_screen.dart:650-700`).

## 14. Prototype and verification

Run the lab with the pinned SDK:

```powershell
C:\flutter-3.38.9\bin\flutter.bat run -d chrome --dart-define=IBREVIARY_READER_CONSISTENCY_LAB=true
```

Open `/#/design/reader-consistency-lab` in the flag build. The flag also selects that initial route; the route is absent from normal builds and no production navigation item points to it (`lib/router/router.dart`). Choose one of six mock domains, `CURRENT`/`NORMALIZED`, and Aa 70/100/180%. Current reproduces the shared 700/22/25/42 page anatomy and title role. Normalized compares 660 width, shorter header→body handoff, Cormorant document title, semantic metadata and 32 terminal spacing. Both retain domain content cues. The lab is a controlled visual hypothesis, **not** a screenshot or pixel copy of production; Reading detail and Compendium part exceptions are documented above rather than falsely represented as an RS mock.

`test/reader_consistency_lab_test.dart` exercises all six scenarios, source/end presence, and the full 4×3×3×2 matrix on both mock variants. **LAB result (3 October 2026):** 3 tests passed with Flutter 3.38.9. The route flag test passed both without the define (route absent) and with `--dart-define=IBREVIARY_READER_CONSISTENCY_LAB=true` (route present). Targeted existing production tests — `reader_foundation`, `router_architecture`, `liturgical_screen_smoke`, `mass_reader`, `songbook`, `bible_stage6`, `compendium_screens`, `readings_stage4` — passed (15 and 131 test cases in two runs). They exercise real widget/data fixtures, including Hours variants, Mass section navigation, Song chords and Compendium anchors, but not the entire width × Aa × system × theme matrix. Production real-content **DEVICE** visual and screen-reader QA remains open; no screenshot or mock pass is claimed as a device result.

## 15. Risks and Phase 4B dependency

See [Phase 4B plan](PHASE_4B_READER_POLISH_PLAN.md). Highest risks are Ora HTML spacing/source structure, Mass ritual headings and bottom clearance, Bible selection/verse accessibility, Song chord alignment, and Compendium part search/anchor behavior. Re-read current code after Phase 2B/3A and begin 4B only after Phase 3B; names or bottom/top metrics from concurrent branches are not presumed stable. 4A has **no production reader changes**, only docs and a flag-only mock route.
