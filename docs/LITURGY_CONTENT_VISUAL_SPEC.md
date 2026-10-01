# Liturgy content visual specification

Статус: **CURRENT-аудит существующей реализации; дизайн не унифицирован**.

Срез кода: `1540a7d`, 29 сентября 2026.
Область: экран Чтений (`ReadingsScreen`), legacy/detail-экран отдельного чтения (`ReadingDetailScreen`) и все реально реализованные варианты Литургии часов (`OraScreen`).

Этот документ — источник правды для следующего этапа. `CURRENT` описывает код как есть. `TARGET` намеренно оставлен `—`: его можно заполнять вручную, не меняя идентификаторы.

## Как читать спецификацию

- `B` — пользовательский размер reader-текста: `settings.fontSize`; по умолчанию `16`, допустимо `11.2…28.8` (`70…180%`).
- Reader-family — `Literata` по умолчанию, `Source Serif 4` или системная гарнитура; источник: `ReadingScaffold → ReaderTheme.body(B, family)`.
- UI-family — системная гарнитура Flutter для текущей платформы; источник: `ThemeData(...).textTheme`.
- Все размеры и отступы — logical px Flutter.
- `inherit` ниже всегда сопровождается источником. Значение `normal` означает реально не переопределённый параметр у названного `TextStyle`, а не неизвестный default.
- У HTML итоговый отступ — объявленный margin элемента в `flutter_html`; фактическое поведение соседних CSS-like margins принадлежит `flutter_html 3.0.0`.
- `CURRENT / TARGET` относится к визуальному контракту. В `TARGET` везде `—` до ручного решения владельца дизайна.

## Фактически реализованные экраны

Один `OraScreen` строит девять вариантов по `oraType` из `kHoraItems`:

| Route type | Экран | Источник последовательности |
|---|---|---|
| `invitatorium` | Заклік / Invitatorium | `_buildInvitatorium` |
| `morning` | Агульная гадзіна: Invitatorium + Officium lectionis + Laudes | `_buildMorning` |
| `lectionis` | Гадзіна чытанняў / Officium lectionis | `_buildLectionis` |
| `laudes` | Ютрань / Laudes matutinae | `_buildLaudes` |
| `terz` | Малітва перад поўднем / Tertia | `_buildSextHour(num: 1)` |
| `sext` | Малітва апоўдні / Sexta | `_buildSextHour(num: 2)` |
| `non` | Малітва пасля поўдня / Nona | `_buildSextHour(num: 3)` |
| `vespers` | Нешпары / Vesperae | `_buildVespers` |
| `completorium` | Камплета / Completorium | `_buildCompline` |

Отдельный `ReadingsScreen` показывает библейские чтения дня. Это **не** `lectionis`: у экранов разные модели, композиция и renderer. Route `reading/:readingId` открывает ещё один связанный экран — `ReadingDetailScreen` с legacy `Reading` model и собственной HTML/plain реализацией.

## Цепочки данных до пикселя

### Литургия часов

```text
Firestore → Hive days/invitatoriums/completoriums
→ LiturgicalDay._raw + StaticLiturgicalService
→ LiturgicalDayService / LiturgicalContentService / day resolver
→ OraScreen._build* → List<_OraItem>
→ _OraItem.build → _HtmlOrText / _LabeledSection / plain/custom
→ AlternativeText (если вариантов > 1)
→ formatLiturgicalHtml / formatPsalmHtml / formatIntercessions
→ flutter_html Html или SelectableText.rich
→ ReadingScaffold → ReaderTheme + settings.fontSize/fontFamily
→ ReaderScaffold / ReaderContentSurface
```

Ключевые файлы:

- `lib/screens/ora_screen.dart` — композиция всех часов, локальные renderer-стили и spacing;
- `lib/models/day.dart` — динамические поля `LiturgicalDay.field(name)`;
- `lib/services/liturgical_day_service.dart`, `lib/services/liturgical_content_service.dart` — выбор/слияние дня;
- `lib/services/static_liturgical_service.dart` — `invitatoriums` и `completoriums`;
- `lib/utils/liturgical_html.dart` — семантическая разметка legacy HTML;
- `lib/utils/liturgical_alternatives.dart` — разбиение вариантов и структура просьб;
- `lib/widgets/alternative_text.dart`, `lib/widgets/psalm_choir_html.dart` — альтернативы и хоры;
- `lib/widgets/reading_scaffold.dart`, `lib/theme/reader.dart` — reader typography;
- `lib/widgets/reader/reader_scaffold.dart` — header, ширина и внешние padding.

### Чтения дня

```text
Firestore readings → Hive/cache
→ ParsedReadingsService → ParsedReading / ParsedSection
→ readingsLoaderProvider → selection/group/cycle resolver
→ ReadingsScreen → _ReadingBody
→ _ReadingSection / _PsalmSection / _AlleluiaSection
→ _ReadingText → Text.rich или flutter_html Html
→ ReadingScaffold → ReaderTheme + settings.fontSize/fontFamily
→ ReaderScaffold / ReaderContentSurface
```

Ключевые файлы: `lib/screens/readings_screen.dart`, `lib/models/parsed_reading.dart`, `lib/providers/readings_loader_provider.dart`, `lib/services/parsed_readings_service.dart`, `lib/utils/reading_content.dart`.

### Отдельное чтение (`ReadingDetailScreen`)

```text
Hive readingsBox[readingId]
→ Reading.fromMap (`title`, `text/body`, `cycle`)
→ ReadingDetailScreen
→ raw SelectableText или local flutter_html Html
→ formatLiturgicalHtml только в HTML branch
→ ReadingScaffold → ReaderTheme
```

Файл: `lib/screens/reading_detail_screen.dart`. Экран доступен и как nested `readings/reading/:readingId`, и через compatibility route `/reading/:readingId`.

## Общий контейнер и темы

| Property | CURRENT | TARGET | Источник |
|---|---|---|---|
| max document width | `700` | — | `ReaderScaffold.maxContentWidth` |
| document padding | `left/right 22; top 25; bottom 42 + MediaQuery.padding.bottom` | — | `ReaderContentSurнемface` |
| top scroll inset | visible chrome: `safeTop + 76`; hidden: `safeTop + 16` | — | `ReaderScaffold` |
| reader surface light/dark | `#FDFCF9` / `#171917` | — | `ReaderTheme.surface` |
| reader ink light/dark | `#20211F` / `#E9ECE7` | — | `ReaderTheme.ink` |
| reader muted light/dark | `#62645F` / `#AEB3AB` | — | `ReaderTheme.muted` |
| rubric light/dark | `#9B302A` / `#EF9188` | — | `ReaderTheme.rubric` |
| UI onSurface light/dark | `#20211F` / `#E9ECE7` | — | `AppPalette → ColorScheme.onSurface` |
| UI onSurfaceVariant light/dark | `#5F625C` / `#AEB3AB` | — | `AppPalette → ColorScheme.onSurfaceVariant` |
| liturgical accent | dynamic by season/rank; see `liturgicalColorForDay` | — | `lib/utils/liturgical_theme.dart` |
| ambient background | season-colour hero wash behind header; not inside document surface | — | `ReaderScaffold → AmbientWash.hero` |
| top/bottom overlay | gradient from reader surface: top alpha light `.92`, dark `.86`; bottom light `.62`, dark `.46` | — | `ReaderEdgeProtection` |

Reader body contract:

| Property | CURRENT | TARGET |
|---|---|---|
| fontFamily | setting: `Literata` default / `Source Serif 4` / system | — |
| fontSize | `B`, default `16` | — |
| fontWeight/style | normal/normal unless a role overrides it | — |
| height | `1.68` body; `1.72` hymn | — |
| letterSpacing/decoration | none | — |
| color | `ReaderTheme.ink` | — |
| align/maxLines/overflow | left / unlimited / visible | — |

## Карта экранов

### `invitatorium` — Заклік

```text
[CONTEXT_DATE] → [DAY_TITLE] → [HOUR_TITLE] → context metadata/actions
[RUBRIC_BLOCK]
[INTRO_DIALOGUE]
[INVITATORY_PSALM_TRIGGER] (только если вариантов > 1)
([ANTIPHON_TEXT] → [PSALM_METADATA/PSALM_STROPHE] × до 6) → [ANTIPHON_TEXT]
[DOCUMENT_END_MARK]
```

Данные: `day.invitatoriumAnt`; `invitatoriums[].invitatoriumPs1…6`. При пустом кеше вместо псалма выводится `CONTENT_NOTICE`.

### `morning` — Агульная гадзіна

```text
Invitatorium без повторного standard intro
→ [SECTION_TITLE Гімн] → [HYMN_BODY] (laudesHymn)
→ [SECTION_TITLE Псалмодыя] → officeOfReadings Ant/Ps × 3
→ [VERSICLE_BODY]
→ [OFFICE_READING_TITLE Першае чытанне] → [OFFICE_READING_BODY]
→ [OFFICE_READING_TITLE Другое чытанне] → [OFFICE_READING_BODY]
→ optional [SECTION_TITLE Гімн] → [TE_DEUM_BODY]
→ [SECTION_TITLE Псалмодыя] → laudes Ant/Ps × 3
→ [RESPONSORY_BODY]
→ [ANTIPHON_TEXT] → [SECTION_TITLE Песня з Евангелля]
→ [GOSPEL_CANTICLE_CAPTION] → [CANTICLE_BODY] → [ANTIPHON_TEXT]
→ [INTERCESSION_TITLE Просьбы] → intercession roles
→ [PATER_NOSTER]
→ [PRAYER_TITLE Малітва] → [PRAYER_BODY]
→ [ENDING_DIALOGUE] / rubrics
```

Важно: это не простая конкатенация `_buildLectionis + _buildLaudes`. Используется гимн Ютрани; окончания и повторные introductions подавлены.

### `lectionis` — Гадзіна чытанняў

```text
[INTRO_DIALOGUE]
→ [SECTION_TITLE Гімн] → [HYMN_BODY]
→ [SECTION_TITLE Псалмодыя] → (Ant → Psalm → Ant) × 3
→ [VERSICLE_BODY]
→ [OFFICE_READING_TITLE Першае чытанне] → [OFFICE_READING_BODY]
→ [OFFICE_READING_TITLE Другое чытанне] → [OFFICE_READING_BODY]
→ optional [SECTION_TITLE Гімн] → [TE_DEUM_BODY]
→ [PRAYER_TITLE Малітва] → [PRAYER_BODY]
→ [ENDING_DIALOGUE]
```

Поля: `officeOfReadingsHymn`, `officeOfReadingsAnt1…3`, `officeOfReadingsPs1…3`, `officeOfReadingsVers`, `officeOfReadingsR1/R2`, `officeOfReadingsPr`. Старый заголовок чтения удаляется `stripLeadingReadingHeading`, native label остаётся один.

### `laudes` — Ютрань

```text
[INTRO_DIALOGUE]
→ [SECTION_TITLE Гімн] → [HYMN_BODY]
→ [SECTION_TITLE Псалмодыя] → (Ant → Psalm → Ant) × 3
→ [RESPONSORY_BODY]
→ [ANTIPHON_TEXT] → [SECTION_TITLE Песня з Евангелля]
→ [GOSPEL_CANTICLE_CAPTION] → Benedictus → [ANTIPHON_TEXT]
→ [INTERCESSION_TITLE Просьбы] → intercession roles
→ [PATER_NOSTER]
→ [PRAYER_TITLE Малітва] → [PRAYER_BODY]
→ ending rubrics / [ENDING_DIALOGUE]
```

Поля: `laudesHymn`, `laudesAnt1…3`, `laudesPs1…3`, `laudesR`, `laudesAntBen`, `laudesInter`, `laudesPr`.

### `terz`, `sext`, `non` — дневные часы

Одинаковая карта, разные номера `sext1`, `sext2`, `sext3`:

```text
[INTRO_DIALOGUE]
→ [SECTION_TITLE Гімн] → [HYMN_BODY]
→ [SECTION_TITLE Псалмодыя] → (Ant → Psalm → Ant) × 3
→ [OFFICE_READING_BODY / RESPONSORY_BODY]
→ [PRAYER_TITLE Малітва] → [PRAYER_BODY]
→ [ENDING_DIALOGUE]
```

`sext2/*` и `sext3/*` получают per-field fallback к `sext1/*` через `daytimeHourField`; поэтому один экран может визуально смешивать данные разных наборов, но renderer один.

### `vespers` — Нешпары

```text
[INTRO_DIALOGUE]
→ optional [VESPERS_VARIANT_LABEL]
→ [SECTION_TITLE Гімн] → [HYMN_BODY]
→ [SECTION_TITLE Псалмодыя] → (Ant → Psalm → Ant) × 3
→ [RESPONSORY_BODY]
→ [ANTIPHON_TEXT] → [SECTION_TITLE Песня з Евангелля]
→ [GOSPEL_CANTICLE_CAPTION] → Magnificat → [ANTIPHON_TEXT]
→ [INTERCESSION_TITLE Просьбы] → intercession roles
→ [PATER_NOSTER]
→ [PRAYER_TITLE Малітва] → [PRAYER_BODY]
→ ending rubrics / [ENDING_DIALOGUE]
```

Поля: `vesperHymn`, `vesperAnt1…3`, `vesperPs1…3`, `vesperR`, `vesperAntMag`, `vesperInter`, `vesperPr` с fallback на `laudesPr`. Label I/II Нешпаров строится из календарного resolver-а.

### `completorium` — Камплета

```text
[INTRO_DIALOGUE]
→ [RUBRIC_BLOCK рахунак сумлення]
→ [SECTION_TITLE Гімн] → [HYMN_BODY]
→ [SECTION_TITLE Псалмодыя] → до 2 × (Ant → Psalm → Ant)
→ [OFFICE_READING_BODY]
→ [RESPONSORY_BODY]
→ [SECTION_TITLE Песня з Евангелля] + caption
→ [ANTIPHON_TEXT] → Nunc dimittis → [ANTIPHON_TEXT]
→ [PRAYER_TITLE Малітва] → [PRAYER_BODY]
→ [RUBRIC_BLOCK] → [ENDING_DIALOGUE]
→ optional [SECTION_TITLE Marian antiphons] → [MARIAN_ANTIPHON_BODY]
```

Данные приходят не из `LiturgicalDay`, а из `completoriums` по `{periodType}-d{weekday}` с правилами Sunday/solemnity/Holy Week.

### Чтения дня

```text
[READINGS_SCREEN_TITLE]
→ [CONTEXT_DATE]
→ [CELEBRATION_TITLE]
→ optional [READINGS_CYCLE_METADATA] + actions
→ optional [CONTENT_NOTICE]
→ [MASS_READING_SECTION_TITLE]
   [MASS_READING_REFERENCE]
   optional [MASS_READING_COMMENT]
   optional [MASS_READING_PERICOPE_TITLE]
   [MASS_READING_BODY]
   [MASS_READING_ACCLAMATION]
→ optional [RESPONSORIAL_PSALM_*]
→ optional second reading (те же роли)
→ optional [GOSPEL_ACCLAMATION_*]
→ optional Gospel (те же reading-роли)
```

Фактический порядок `_ReadingBody`: `firstReading → psalm → reading2 → alleluia → gospel`. Варианты weekday/Sunday/solemnity отличаются наличием `reading2`, но не renderer-ом.

### Отдельное чтение (`ReadingDetailScreen`)

```text
[LEGACY_READING_APPBAR_TITLE]
→ optional [LEGACY_READING_CYCLE]
→ [LEGACY_READING_BODY]
   либо [LEGACY_READING_RAW_HTML] по кнопке “Паказаць HTML”
→ empty state, если readingId отсутствует в Hive
```

Rendered HTML имеет собственную, третью таблицу стилей: body `B/h1.68`, paragraph bottom14, subheading `.84B/h1.42`, heading `.94B/h1.28/w700/tracking.7`, cadence marker rubric+w600. Plain rendered text не проходит marker RichText parser.

## Подтверждённое направление для будущего TARGET

Экран Чтений **не обязан визуально повторять экран Часов**. Основание для подобия — общий reader foundation: выбранная книжная гарнитура и масштаб, ширина строки, ink/muted/rubric palette, доступность и стабильные semantic roles. Композиция может различаться: Часы — последовательная молитва оффиция, Чтения — порядок провозглашения чтений с самостоятельным респонсарийным псалмом.

Для респонсарийного псалма Чтений подтверждён обязательный line-break contract:

1. каждая строка, начинающаяся номером вида `N.`, должна начинаться с новой строки;
2. текст после каждой звёздочки `*` должен начинаться с новой строки;
3. правило должно одинаково работать для plain text и HTML, включая `&nbsp;`, существующие `<br>` и inline spans;
4. это специальное правило `RESPONSORIAL_PSALM_VERSE` на экране Чтений; автоматически переносить его на псалмы Часов без отдельного решения не следует.

**CURRENT:** plain path уже выполняет оба преобразования в `formatReadingPsalmText`. HTML path в `formatReadingPsalmHtml` восстанавливает `<br>` после `*` и перед `N.` внутри размеченных `.psalm-strophe`. Для абсолютной гарантии на любом допустимом HTML нужна отдельная fixture-проверка параграфа с номером, который не получил `.psalm-strophe`.

Заключительная формула после чтения имеет ID `MASS_READING_ACCLAMATION`:

- `Гэта слова Божае.` — после первого/второго чтения;
- `Гэта слова Пана.` — после Евангелия.

В обеих формулах `слова` должно начинаться со строчной буквы. Это не `GOSPEL_ACCLAMATION_*`: последние ID относятся к блоку «Акламацыя: Аллелюя…» перед Евангелием.

Во **всех псалмах** действует ещё один подтверждённый обязательный TARGET:

1. звёздочка `*` всегда rubric red;
2. крестик `†` всегда rubric red;
3. правило распространяется на Invitatorium, псалмодию всех Часов и Агульнай гадзіны, Benedictus/Magnificat/Nunc dimittis, респонсарийный псалом Чтений и отдельный reading detail, если он содержит псалом;
4. результат не должен зависеть от renderer-а (plain/HTML/RichText), от literal/entity формы символа или от того, вложен ли marker в inline tag;
5. цвет берётся из `ReaderTheme.rubric`: light `#9B302A`, dark `#EF9188`.

**CURRENT:** HTML formatter распознаёт literal `*`, `†`, `&ast;`, `&dagger;`, decimal и hex entities и создаёт `.psalm-marker`. Основные plain Ora/Readings RichText-ветки распознают literal `*`/`†`. Но plain branch `ReadingDetailScreen` выводит обычный `SelectableText`, поэтому marker там не красный. Иные визуальные cross glyphs, например `✝`, текущим pattern не охвачены.

## Master Liturgical Style Catalog

В таблице `Use` перечислены экраны, а `Implementation` — фактический источник. `B` сохраняет зависимость от пользовательского масштаба.

| ID | CURRENT typography | CURRENT color | CURRENT layout/spacing | Use / Implementation | TARGET |
|---|---|---|---|---|---|
| `READINGS_SCREEN_TITLE` | Cormorant Garamond, `36`, w700, h1.06, tracking `-0.02` | ink | header top 8; after 10 | Readings; `ReaderTheme.displayTitle(36)` | — |
| `CONTEXT_DATE` (Readings) | UI `labelLarge` 14/w700/h≈1.43 | dynamic liturgical accent | tap padding y7; after row 7 | `_ReadingsContextHeader` | — |
| `CONTEXT_DATE` (Hours) | UI `titleSmall` overridden `16`, w700, h1.3 | accent | context header top 10; after to day title 7 | `ReaderContextHeader.eyebrowStyle` | — |
| `DAY_TITLE` | UI `titleMedium` overridden `18`, w500, h1.4 | `ColorScheme.onSurfaceVariant` | after 9 before hour title | Hours header | — |
| `HOUR_TITLE` | UI `headlineSmall` overridden `27`, w600, h1.18 | `onSurface` | title tap padding y5; metadata begins after 8 | shared `ReaderContextHeader` | — |
| `CELEBRATION_TITLE` | UI `headlineSmall` 24, w600, h1.2 | inherited `onSurface` | after date 7; metadata after 10 | Readings header | — |
| `CONTEXT_METADATA` | UI `bodySmall` 12/400/h≈1.33 | `onSurfaceVariant` | after 8 | Hours header | — |
| `READINGS_CYCLE_METADATA` | UI `labelMedium` 12/w600/h≈1.33 | `onSurfaceVariant` | before 10; actions after 10 | Readings header | — |
| `CONTEXT_PLACE` | UI `bodySmall` 12/400/h≈1.33 | `onSurfaceVariant` | row after 8; icon gap 5 | Hours header | — |
| `CONTEXT_ACTION` | Material TextButton `labelLarge` (14/w500 token) | theme primary/accent | Wrap gap 8; button min 48 | Hours “Чытанні”, Readings “Сёння/Варыянты” | — |
| `FEAST_COMMENT_TITLE` | UI `titleMedium` 16/w700/h≈1.5 | `onSurface` | card padding top14; after 8 | `_ExpandableFeastComment` | — |
| `FEAST_COMMENT_BODY` | UI `bodyLarge` overridden 16/400/h1.45 | `onSurfaceVariant` | maxLines 3 collapsed; after 8 | same | — |
| `FEAST_COMMENT_ACTION` | UI `labelLarge` 14/w700 | theme primary | bottom card padding14 | same | — |
| `SECTION_TITLE` | Hours: fixed Literata; Readings: selected reader family; `max(1.10B,18)`, w600, h1.28 | rubric | top24, bottom9 in Hours; top24, bottom8 in Readings | `_OraItem.blockHeader`; `_SectionLabel` (явно копирует body family) | — |
| `HTML_SUBHEADING` | reader family, `max(.88B,14)`, inherited weight/style, h1.42 | muted | bottom7; optional center for `.psalm-metadata` | `.liturgical-subheading` | — |
| `HTML_SECTION_HEADING` | reader family, `max(.98B,15)`, w700, h1.28 | rubric | Hours bottom12; Readings inherits `p` bottom8 | `.liturgical-heading` | — |
| `BODY_TEXT` | reader family, `B`, normal, h1.68 | ink | HTML `p` bottom8; plain has no automatic paragraph margin | `_HtmlOrText`, `_ReadingText` | — |
| `INTRO_DIALOGUE` | reader family, `B`, normal/source emphasis, h1.68 | ink + rubric inline speakers/markers | each HTML `p` bottom8; outer item bottom4 | `_kStandardIntro`, `_kInvitIntro` | — |
| `ENDING_DIALOGUE` | reader family, `B`, normal/source emphasis, h1.68 | ink + rubric inline speakers | each `p` bottom8; explicit rubric paragraphs use rubric role | `_kEndOfSext`, `_kEndOfVesper`, `_kEndOfComplineBlessing` | — |
| `HYMN_BODY` | reader family, `B`, source emphasis, h1.72 | ink | HTML `p` bottom15; section-title bottom9 | `_HtmlOrText(kind: hymn)` | — |
| `TE_DEUM_BODY` | reader family, `B`, source emphasis, **h1.68** | ink | HTML `p` bottom8 | `_kTeDeum` is added as generic HTML, not `kind: hymn` | — |
| `RUBRIC_BLOCK` | explicit class: `max(.90B,14)`, h1.48; fully-red legacy paragraph: `max(.88B,14)`, h1.42; weight inherited, italic only from source `<em>/<i>` | rubric (legacy paragraph gets rubric from child span) | explicit `p` bottom8/15; legacy subheading bottom7 | `.liturgical-rubric` versus leading-red → `.liturgical-subheading` + inline rubric | — |
| `RUBRIC_INLINE` | inherits surrounding family/size/height/weight | rubric | no own spacing | normalized red `span/font` → `.liturgical-rubric-inline` | — |
| `DIALOGUE_MARKER` | surrounding size/h/weight (обычно normal) | rubric | inline | red `К./Н./С.` normalized as rubric inline | — |
| `CADENCE_MARKER` | surrounding size/h; w600 in HTML and main RichText branches; plain `ReadingDetailScreen` inherits normal body | rubric, **except plain ReadingDetail CURRENT** | inline; break immediately after marker is removed | `.psalm-marker`, literal `*`/`†` and HTML entities | all psalms: `*` and `†` rubric red regardless of renderer/source encoding |
| `ANTIPHON_TEXT` | reader family, `B`, w600, h1.68 | ink | outer padding 0; HTML last `p` bottom8; picker may add 18 before text | `_OraItem.antiphon`; `.ora-ant` same weight | — |
| `PSALM_METADATA` | `max(.88B,14)`, h1.42, centered | muted | bottom7 | umbrella visual role for psalm leading metadata | — |
| `PSALM_TITLE` | selected reader family, `max(.88B,14)`, source weight/style, h1.42, centered | muted | bottom7 | source first metadata paragraph → `.liturgical-subheading.psalm-metadata` | — |
| `PSALM_REFERENCE` | same current renderer as `PSALM_TITLE`; no independent span | muted | part of metadata paragraph or next bottom7 paragraph | `formatPsalmHtml` leading metadata | — |
| `PSALM_SUBTITLE` | same current renderer as `PSALM_TITLE`; no independent token | muted | bottom7 | `formatPsalmHtml` leading metadata | — |
| `PSALM_STROPHE` | reader family, `B`, normal, h1.68 | ink | Hours bottom8; Readings odd inherits `p` bottom8 | `.psalm-strophe` | — |
| `PSALM_STROPHE_EVEN` | same as strophe | ink | Hours left16 + bottom8; Readings no left inset + bottom14 | renderer-local `.psalm-strophe-even` | — |
| `PSALM_VERSE_NUMBER` | inherits strophe family/size/weight/height; no separate span | ink | inline | numbers remain source text | — |
| `PSALM_DOXOLOGY` | same as psalm strophe/body; no dedicated class | ink + rubric cadence | paragraph/strophe bottom8 (Readings even rule may give14) | source final paragraph | — |
| `PSALM_CHOIR_MUTED` | strophe style with alpha `.60` | ink/rubric at 60% | same geometry | `PsalmChoirHtml` Hours only | — |
| `VERSICLE_BODY` | reader family, `B`, source styles, h1.68 | ink/rubric inline | item bottom4 + last `p` bottom8 | generic `_OraItem.html` | — |
| `OFFICE_READING_REFERENCE` | `max(.88B,14)`, w500, h1.68 inherited | muted | inline inside known reading paragraph | `.liturgical-reading-reference` Hours | — |
| `OFFICE_READING_TITLE` | fixed Literata, `max(1.10B,18)`, w600, h1.28 | rubric | then gap6; no own top24 | `_LabeledSection` | — |
| `OFFICE_READING_BODY` | reader family, `B`, normal/source strong/em, h1.68 | ink | labeled gap6; `p` bottom8; section after8 | `_LabeledSection(kind: reading)` | — |
| `RESPONSORY_BODY` | same renderer/style as `OFFICE_READING_BODY` | ink/rubric inline | generic item bottom4; `p` bottom8 | `*R`, `*Resp`; no dedicated class | — |
| `GOSPEL_CANTICLE_CAPTION` | reader family, `max(.88B,14)`, italic, h1.42 | muted | bottom7 | single fully-emphasized paragraph is classified `.liturgical-subheading` | — |
| `CANTICLE_BODY` | same as psalm strophe/body, cadence w600 rubric | ink | `p`/strophe bottom8 | Benedictus/Magnificat/Nunc constants | — |
| `INTERCESSION_INTRO` | reader body B/h1.68 | ink | bottom13 | `.intercessions__intro` | — |
| `INTERCESSION_REFRAIN` | reader body B/w700/h1.68 | ink | top4, bottom22 | `.intercessions__refrain` | — |
| `INTERCESSION_PETITION` | reader body B/normal/h1.68 | ink | top18, bottom5 | `.intercessions__petition` | — |
| `INTERCESSION_RESPONSE` | reader body B/normal/h1.68 | ink | left12, bottom15 | `.intercessions__response` | — |
| `INTERCESSION_MARKER` | inherits response style | rubric | inline | `.intercessions__marker` | — |
| `INTERCESSION_CONCLUSION` | reader body B/italic/h1.68 | muted | top22 + base paragraph margin | `.intercessions__conclusion` | — |
| `INTERCESSION_TITLE` | fixed Literata, `max(1.10B,18)`, w600, h1.28 | rubric | then gap6; no own top24 | `_LabeledSection` | — |
| `PATER_NOSTER` | reader family, `B`, normal, h1.68 | ink | plain item then SizedBox12 | `_OraItem.plain` | — |
| `PRAYER_TITLE` | fixed Literata, `max(1.10B,18)`, w600, h1.28 | rubric | direct; then gap6; no own top24 | `_LabeledSection` | — |
| `PRAYER_BODY` | reader family, `B`, normal/source emphasis, h1.68 | ink | `p` bottom8; after section SizedBox8 | `_LabeledSection(kind: prayer)` | — |
| `VESPERS_VARIANT_LABEL` | UI `labelMedium` 12/w700 | dynamic accent | bottom12 | custom Ora widget | — |
| `MARIAN_ANTIPHON_BODY` | reader family, `B`, source emphasis, h1.68 | ink | header bottom9; `p` bottom8; optional picker +18 | `_OraItem.html(kind: marian-antiphon)` | — |
| `ALTERNATIVE_TRIGGER` | UI `labelLarge` overridden 14/w600/h1.3 | rubric | button padding x12/y10, min48; content after18 | `_AlternativePicker` | — |
| `INVITATORY_PSALM_TRIGGER` | fixed Literata overridden 14/w600/h1.35 | rubric | button min48; parent bottom12 | `_InvitSelector → ReaderTheme.body(16)` without family argument | — |
| `DOCUMENT_END_MARK` | UI `bodyMedium` 14/400, tracking6 | muted | before12; content surface bottom follows | Ora only | — |
| `CONTENT_NOTICE` | reader-derived 14 (= `.875B` at default), normal | `onSecondaryContainer` | container padding12, bottom16 | Readings memorial notice | — |
| `MASS_READING_SECTION_TITLE` | same as `SECTION_TITLE` | rubric | top24, bottom8 | `_SectionLabel` | — |
| `MASS_READING_REFERENCE` | reader family, `max(.88B,14)`, w600, h inherited 1.68, tracking `.02` | muted | no explicit margin | `_BibleRef` | — |
| `MASS_READING_COMMENT` | reader family, `.875B`, w500 italic, h1.68 inherited | muted | top4 | `_ReadingSection` | — |
| `MASS_READING_PERICOPE_TITLE` | reader family, `B`, w600, h1.68 | ink | top6, bottom4 | `_ReadingSection.s.title` | — |
| `MASS_READING_BODY` | reader family, `B`, normal, h1.68 | ink | before6; HTML `p` bottom8 | `_ReadingText` | — |
| `HIGHLIGHTED_SENTENCE` | `MASS_READING_BODY`; selected also underline 1.5 | ink; bg accent `.18` selected or highlight `.30` light/`.32` dark | inline | `_sentenceStyle` | — |
| `MASS_READING_ACCLAMATION` | reader family, `B`, w700, h1.68 | ink | before8 when source phrase; before12 when generated | closing phrase in `_ReadingSection`: `Гэта Слова Божае.` / `Гэта Слова Пана.` в generated CURRENT | `Гэта слова Божае.` / `Гэта слова Пана.` — `слова` со строчной |
| `RESPONSORIAL_PSALM_REFRAIN_LABEL` | reader family, `max(.88B,14)`, w800, h1.2 | rubric; alternate muted | label-to-text 5 (3 compact) | `_ChorusBox` | — |
| `RESPONSORIAL_PSALM_REFRAIN_TEXT` | reader family, `B`, w700, h1.5 | ink | box top2/bottom13 | opening/final `_ChorusBox` | — |
| `RESPONSORIAL_PSALM_REFRAIN_REPEAT` | reader family, `B`, w600, h1.48 | ink | box top5/bottom9 | compact `_ChorusBox` | — |
| `RESPONSORIAL_PSALM_VERSE` | reader family, `B`, normal, h1.68 | ink/rubric cadence | wrapper padding y10; HTML odd p8/even14 | `_ReadingText(isPsalm)` | каждый `N.` с новой строки; после каждого `*` новая строка; одинаково для plain/HTML |
| `GOSPEL_ACCLAMATION_LABEL` | reader family, `B`, bold, h1.68 | ink | line wrapper y4 | “Акламацыя:” TextSpan | — |
| `GOSPEL_ACCLAMATION_TEXT` | reader family, `B`, normal, h1.68 | ink | same line | fixed “Аллелюя…” | — |
| `GOSPEL_ACCLAMATION_VERSE` | reader family, `B`, normal, h1.68 | ink/rubric cadence | before4 | `_ReadingText` | — |
| `LOADING_TITLE` | UI `bodyMedium` 14/400/h≈1.43 | inherited `onSurface` | notice padding16; progress-to-title12 | `DataLoadingNotice.label`; Readings loading status | — |
| `LOADING_DETAIL` | UI `bodyMedium` 14/400/h≈1.43 | inherited `onSurface` | before6 | online/offline text in `DataLoadingNotice` | — |
| `LOADING_CACHE` | UI `bodySmall` 12/400/h≈1.33 | inherited `onSurface` | before6 | cache size in `DataLoadingNotice` | — |
| `STATUS_TITLE` | UI `bodyMedium` 14/400/h≈1.43 | onSurface/inherited | icon after14; centered | `_ReadingsStatus`, empty Ora states | — |
| `STATUS_DETAIL` | UI `bodySmall` 12/400/h≈1.33; one Readings inner empty-state uses explicit 13 | `onSurfaceVariant` | before7/8 | status/empty/error branches | — |
| `ERROR_DETAIL` | UI `bodySmall`, maxLines4, ellipsis, center | `onSurfaceVariant` | before8 | Ora `_errorState` | — |
| `EMPTY_CONTENT_TEXT` | UI `bodyMedium` inherited | inherited | centered | Ora “Няма зместу” | — |
| `CHOICE_SHEET_TITLE` | UI `titleLarge` 22/w700/h≈1.27 | `onSurface` | shared sheet x8/top8/bottom12; Readings options title has no local padding | `_ReaderChoiceSheet`, `_ReadingsOptionsSheet` | — |
| `CHOICE_OPTION_TITLE` | Material `ListTile` title style from theme (UI family; normally bodyLarge 16) | theme ListTile text color/selected color | tile geometry from Material; Readings date minHeight52 | hour/alternative/date/group choices | — |
| `CHOICE_OPTION_SUBTITLE` | Material `ListTile` subtitle style (UI bodyMedium 14) | `onSurfaceVariant` via component theme | below title in tile | variants/cycles subtitles | — |
| `OPTIONS_HEADING` | UI `labelSmall` 11/w800/h≈1.45, uppercase, tracking1.05 | inherited | padding x16/y4 | Readings options group headings | — |
| `SELECTION_CARD_TITLE` | UI `titleMedium` 16; w700 selected, w500 unselected | `onSurface` | card padding x16/y14 | Readings cycle cards | — |
| `LEGACY_READING_APPBAR_TITLE` | UI AppBar title token; platform family, ellipsis | AppBar foreground / `onSurface` | floating `AdaptiveAppBar` | `ReadingDetailScreen` | — |
| `LEGACY_READING_CYCLE` | Material Chip label style from `ChipTheme` | `onSurfaceVariant` | chip parent bottom12 | `ReadingDetailScreen` | — |
| `LEGACY_READING_BODY` | selected reader family, `B`, normal, h1.68; HTML: `p` bottom14, subheading `.84B`, heading `.94B/w700/tracking.7` | ink/muted/rubric by local selectors | screen padding x16, top `safeTop + floatingAppBarInset`, bottom40 | `_buildRendered` | — |
| `LEGACY_READING_RAW_HTML` | monospace, `B`, normal, h1.68 | `ColorScheme.onSurfaceVariant` | same screen padding | `_showRaw → SelectableText` | — |

### Важные свойства, общие для каталога

- `maxLines` отсутствует у литургического документа. Исключения: feast comment (`3` в collapsed), error detail (`4`) и UI status copy.
- `overflow` у документа не задан; исключения те же (`ellipsis`).
- `textAlign` документа — left. Исключения: `.psalm-metadata` center, status copy center.
- `decoration` отсутствует, кроме выбранного предложения Readings (underline) и ссылок хоров, которым `PsalmChoirHtml` принудительно задаёт `TextDecoration.none`.
- `strong/b` и `em/i` не имеют локальных Dart-токенов: их bold/italic добавляет стандартная tag stylesheet `flutter_html` поверх локального body style.

### Вспомогательные overlay-экраны

Hour choice, alternative choice, date actions и Readings options входят в аудит, потому что могут быть видимы поверх исследуемых экранов. Они используют platform UI typography, а не `B`. Общий reader-choice sheet ограничен `620×640`, имеет outer padding `16,0,16,20`; Readings date sheet — max `620×620`, padding `12,0,12,20+safeBottom`; options sheet — max `620×680`, padding `16,0,16,24+systemBottomInset`. Тексты этих overlay покрыты `CHOICE_SHEET_TITLE`, `CHOICE_OPTION_TITLE`, `CHOICE_OPTION_SUBTITLE`, `OPTIONS_HEADING`, `SELECTION_CARD_TITLE`.

## HTML / RichText contract

### Нормализация до рендера

`formatLiturgicalHtml` выполняет:

1. распознавание первых metadata-параграфов (`.liturgical-subheading`);
2. выделение ссылки в известном heading чтения (`.liturgical-reading-reference`);
3. перевод legacy red `span/font` в `.liturgical-rubric-inline`;
4. удаление legacy `text-align`, `margin-left`, `font-size` из inline `style`;
5. разметку `*` и `†` как `.psalm-marker`.

`formatPsalmHtml` дополнительно:

- удаляет `<br>` непосредственно после cadence marker;
- режет содержащие `*` параграфы на строфы;
- чередует `.psalm-strophe` / `.psalm-strophe-even`;
- разрешает `PsalmChoirHtml` приглушать противоположный хор до 60%.

`formatReadingPsalmHtml` после psalm-formatting добавляет переносы перед нумерованными стихами. Plain-text ветка делает эквивалент через `formatReadingPsalmText`.

### Таблица локальных HTML selectors

| Selector/tag | Ora | Readings | TARGET |
|---|---|---|---|
| `body` | B, h1.68; hymn h1.72; margin/padding0 | B, h1.68; margin/padding0 | — |
| `p` | bottom8; hymn bottom15 | bottom8 | — |
| `.liturgical-subheading` | `.88B≥14`, h1.42, muted, bottom7 | то же | — |
| `.psalm-metadata` | center | center | — |
| `.liturgical-heading` | `.98B≥15`, h1.28, rubric, w700, bottom12 | то же, но без локального bottom12 | — |
| `.psalm-strophe` | bottom8 | нет отдельного selector; наследует `p` | — |
| `.psalm-strophe-even` | left16, bottom8 | bottom14, без left inset | — |
| `.psalm-marker` | rubric, w600 | rubric, w600 | — |
| `.liturgical-rubric` | rubric, `.90B≥14`, h1.48 | **не задан локально** | — |
| `.liturgical-rubric-inline` | rubric | rubric | — |
| `.ora-ant` | ink, w600 | не задан | — |
| `.ora-sub` | muted, `.88B≥14` | не задан | — |
| `.ora-psalm` | не задан; body inheritance | не задан | — |
| intercession classes | все шесть локальных roles | не применяются | — |
| `em/i`, `strong/b` | стандартные правила `flutter_html` | стандартные правила `flutter_html` | — |

`ReadingDetailScreen` не использует ни одну из этих двух maps целиком. Его третья local map задаёт: `body B/h1.68`, `p bottom14`, `.liturgical-subheading .84B/h1.42` без minimum clamp, `.liturgical-heading .94B/h1.28/rubric/w700/tracking.7`, `.psalm-marker rubric/w600`, `.liturgical-rubric-inline rubric`. Psalm strophe, explicit rubric и intercession selectors отсутствуют.

### Plain/RichText ветки

- Ora без HTML: `SelectableText.rich`; текст делится вокруг `*`/`†`, marker получает rubric+w600.
- Readings без HTML: `Text.rich`; чтения дополнительно делятся на предложения для подсветки. Marker span получает rubric+w600.
- ReadingDetail без HTML: обычный `SelectableText`; `*`/`†` не получают отдельного span и остаются ink.
- Plain Ora использует `SelectableText.rich`, Readings — `Text.rich`, ReadingDetail — `SelectableText`; выбор/копирование и marker styling поэтому различаются.

## Карта вертикального ритма

Ниже указана сумма **явно объявленных** contributions. Высота строк зависит от B и системного text scaling.

### Общий переход header → document

```text
последний элемент context header
↓ 22 (header bottom padding)
[граница ReaderContentSurface]
↓ 25 (document top padding)
первый document element
```

Если у первого элемента есть собственный top padding (например `SECTION_TITLE`), он добавляется: `22 + 25 + 24` от последней строки header до glyph box заголовка, не считая line box последней строки.

### Ora

| Переход | CURRENT formula | TARGET |
|---|---|---|
| generic HTML paragraph → следующий item | `p bottom 8 + item bottom 4` для `_OraItem.html` | — |
| hymn title → hymn body | `SECTION_TITLE bottom 9 + first p top 0` | — |
| hymn paragraph → следующий hymn paragraph | `p bottom 15` | — |
| previous block → new `SECTION_TITLE` | previous last `p` margin (`8/15`) + item bottom (`0/4/8`) + title top24 | — |
| antiphon → psalm | antiphon last `p` bottom8 + both outer padding0 | — |
| psalm → repeated antiphon | psalm last strophe bottom8 + outer padding0 | — |
| labeled title → body | `6` | — |
| labeled body → next item | last `p` bottom8 + section trailing8 | — |
| plain Pater noster → next | `12` | — |
| alternative trigger → selected content | `18` | — |
| invitatory trigger → next | parent bottom12 | — |
| intercession intro → refrain | intro bottom13 + refrain top4 | — |
| refrain → petition | refrain bottom22 + petition top18 | — |
| petition → response | petition bottom5 + response left12/bottom15; next top from following rule | — |
| final item → end marker | final internal spacing + `12` | — |
| content end → viewport bottom | `42 + MediaQuery.padding.bottom` | — |

`SECTION_TITLE` в `_LabeledSection` отличается от `_OraItem.blockHeader`: у первого нет top24; он начинается сразу в Column, затем gap6. Поэтому `Першае чытанне`, `Малітва`, `Просьбы` могут стоять ближе к предыдущему блоку, чем `Гімн`/`Псалмодыя`.

### Readings

| Переход | CURRENT formula | TARGET |
|---|---|---|
| previous section end → next section title | previous closing gap (`8` или `12`, если есть) + title top24 | — |
| section title → Bible reference | title bottom8 + reference line | — |
| reference → comment | comment top4 | — |
| reference/comment → pericope title | title top6 + bottom4 | — |
| last metadata/title → reading body | body top6 | — |
| reading body → source acclamation | `8` | — |
| reading body → generated acclamation | `12` | — |
| psalm title/reference → opening refrain | explicit `10` + box top2; fallback path uses `8 + 2` | — |
| refrain label → refrain text | `5`; compact repeat `3` | — |
| opening/final refrain outer | top2, bottom13 | — |
| verse | wrapper top10 + body + wrapper bottom10 | — |
| repeated refrain outer | top5, bottom9 | — |
| last verse → final refrain | explicit8 + box top2 | — |
| alleluia title → reference | title bottom8 + explicit4 | — |
| reference → first acclamation | explicit8 + line padding top4 | — |
| acclamation → verse | line bottom4 + explicit4 | — |
| verse → repeated acclamation | no explicit gap + line padding top4 | — |
| whole document tail | SizedBox32 + surface bottom `42 + inset` | — |

### ReadingDetail

| Переход | CURRENT formula | TARGET |
|---|---|---|
| floating app bar → content | `safeTop + kFloatingAppBarContentInset` | — |
| screen horizontal/bottom inset | left/right16; bottom40 | — |
| cycle chip → body | chip parent bottom12 | — |
| rendered HTML paragraphs | bottom14 | — |
| raw/plain body | no added paragraph spacing beyond source line breaks | — |

## Светлая и тёмная темы

Геометрия и typography одинаковы. Меняются цвета и alpha effects:

| Role | Light CURRENT | Dark CURRENT | TARGET |
|---|---|---|---|
| reader ink | `#20211F` | `#E9ECE7` | — |
| reader muted | `#62645F` | `#AEB3AB` | — |
| rubric | `#9B302A` | `#EF9188` | — |
| reader surface | `#FDFCF9` | `#171917` | — |
| selected sentence | primary at 18% | primary at 18% | — |
| persisted highlight | palette color at 30% | palette color at 32% | — |
| muted psalm choir | ink/rubric at 60% | ink/rubric at 60% | — |
| feast card surface | `ColorScheme.surface` at 72% | same semantic token at 72% | — |
| top fade | surface 92% → 0 | surface 86% → 0 | — |
| bottom fade | 0 → surface 62% | 0 → surface 46% | — |

Литургический accent не имеет отдельной dark-коррекции: один цвет выбирается по периоду/рангу и используется в обеих темах. Он влияет на context controls и ambient wash, но не на основной body ink.

## Current inconsistencies

Ниже — наблюдения, не предложения автоматически менять дизайн.

1. **Два контракта одного section title.** `_OraItem.blockHeader` имеет top24/bottom9; `_LabeledSection` использует тот же `blockHeading`, но без top24 и с gap6/trailing8. Семантически равные заголовки разделов имеют разный ритм.
2. **Псалом часов и псалом Чтений различаются.** Hours: even strophe `left16/bottom8` и choir dimming; Readings: `left0/bottom14`, без choir interaction.
3. **`RUBRIC_BLOCK` отсутствует в HTML style map Readings.** Явная `.liturgical-rubric` красная/уменьшенная в Ora, но в `_ReadingText` наследует body, если встречается в данных.
4. **`.liturgical-heading` имеет bottom12 только в Ora.** В Readings собственный bottom не задан и остаётся общий `p bottom8`.
5. **`.ora-ant` и `.ora-sub` известны только Ora renderer-у.** Если структурированный HTML появится в Readings, роли визуально исчезнут.
6. **Reference line-height не соответствует `ReaderTheme.referenceStyle`.** `_BibleRef` вручную меняет size/weight/tracking, но оставляет body h1.68 вместо token h1.40. Ora inline reference также оставляет body h1.68 и w500, а token задаёт w600/h1.40.
7. **Rubric token фактически не используется HTML block-ом полностью.** `ReaderTheme.rubricBlock` умеет italic, но `.liturgical-rubric` задаёт только color/size/height; italic зависит от наличия source `<em>`.
8. **Canticle caption классифицируется эвристикой.** Текущие static captions состоят из одного `<p><em>…</em></p>` и стабильно становятся `.liturgical-subheading`, но контракт основан на позиции внутри HTML fragment, а не на явном canticle-caption ID в renderer-е.
9. **Responsory, short reading и versicle используют один generic renderer.** Их семантические ID разные, но отдельного style token нет; вид зависит от HTML source.
10. **Plain и HTML spacing различаются.** HTML имеет `p bottom8`, plain `SelectableText.rich` не имеет paragraph margin; `_OraItem.plain` добавляет только bottom12.
11. **Selectable behavior различается.** Ora body — `SelectableText.rich`; plain Readings — `Text.rich`, HTML — `flutter_html`. Визуальная подсветка и selection affordance не едины.
12. **Context date/day styles дублируются inline.** Размеры 16/18/h1.3/1.4 находятся в `ora_screen.dart`, тогда как Hour title 27/h1.18 — в shared `ReaderContextHeader`.
13. **Readings header отдельный от `ReaderContextHeader`.** У него Cormorant screen title и собственные padding/spacing; Hours используют другой shared header. Это намеренная композиция, но источник визуального “прыжка” между branches.
14. **Два selector trigger style.** Общие alternatives: system 14/h1.3; Invitatorium: fixed Literata 14/h1.35. Touch geometry тоже различается (explicit padding против только minSize).
15. **Refrain имеет три варианта одного текста.** Opening/final w700/h1.5/margins 2/13; repeats w600/h1.48/margins 5/9; alternate дополнительно меняет label color.
16. **Magic spacing сосредоточен в screen files.** `4,5,6,7,8,9,10,12,13,15,18,22,24` распределены между `_OraItem`, HTML maps, `_ReadingSection`, `_PsalmSection`, `_ChorusBox`, headers.
17. **HTML source всё ещё может влиять на weight/style.** Локальная нормализация снимает `font-size`, alignment и indent, но сохраняет `strong/em` и остальные inline properties; итог нельзя определить только по semantic field без просмотра HTML.
18. **Gospel/canticle antiphon selector связан с повтором, обычный HTML — нет.** Это корректно по state, но один `ANTIPHON_TEXT` может содержать trigger только в opening copy; повтор визуально начинается сразу с текста.
19. **Dynamic accent одинаков в light/dark.** Некоторые season/rank colors могут иметь разный perceptual contrast, хотя body colors адаптируются.
20. **Material UI typography не масштабируется reader setting.** Header/context/status остаются системных размеров, body меняется от 70 до 180%; относительная иерархия существенно меняется на крайних B.
21. **Ora headings игнорируют выбранную reader-family.** `ReaderTheme.blockHeading` вызывает `body()` без `family`; Hours section/labeled titles остаются Literata. Readings вручную возвращают `textStyle.fontFamily`, поэтому те же visual roles расходятся при System/Source Serif 4.
22. **Te Deum визуально не является hymn body.** Он получает заголовок `Гімн`, но добавляется `_OraItem.html(_kTeDeum)` без `kind: hymn`: h1.68 и paragraph gap8 вместо hymn h1.72/gap15.
23. **Два вида block rubric внутри Ora.** Явная `.liturgical-rubric` даёт `.90B/h1.48`; полностью красный legacy paragraph без класса эвристически становится `.liturgical-subheading` (`.88B/h1.42`) с rubric-colored child span.
24. **Reading-psalm line-break contract не полностью доказан для произвольного HTML.** Plain formatter безусловно обрабатывает `*` и пробел перед `N.`; HTML formatter выполняет обход только `.psalm-strophe`, поэтому numbered HTML paragraph без cadence marker/этого класса требует regression fixture или расширения formatter-а на implementation-этапе.
25. **Generated reading closing formula использует неверный регистр.** `_ReadingSection` создаёт `Гэта Слова Пана.` / `Гэта Слова Божае.` с прописной `С` (`readings_screen.dart`); подтверждённый TARGET — строчная: `Гэта слова …`. Формула, уже находящаяся в source text, отображается с исходным регистром.
26. **Cadence markers не красные в plain ReadingDetail.** HTML branch получает `.psalm-marker`, но plain branch возвращает `SelectableText(text, style: textStyle)` без разбиения `*`/`†`; это прямой источник наблюдаемого несоответствия.
27. **Третья независимая HTML style map.** `ReadingDetailScreen` использует paragraph bottom14, `.84B` subheading и `.94B/tracking.7` heading, отличаясь и от Ora, и от основного Readings renderer-а.

Наибольшее дублирование: три локальные HTML style maps (`ora_screen.dart`, `readings_screen.dart`, `reading_detail_screen.dart`), section heading composition, marker spans, psalm formatting/spacing и inline context-header styles.

## Потенциальная будущая схема токенов (не реализована)

```dart
LiturgicalTypography.body
LiturgicalTypography.hymnBody
LiturgicalTypography.sectionTitle
LiturgicalTypography.metadata
LiturgicalTypography.reference
LiturgicalTypography.rubricBlock
LiturgicalTypography.rubricInline
LiturgicalTypography.antiphon
LiturgicalTypography.psalmStrophe
LiturgicalTypography.cadenceMarker
LiturgicalTypography.readingBody
LiturgicalTypography.readingAcclamation
LiturgicalTypography.intercessionRefrain
LiturgicalTypography.prayerBody

LiturgicalSpacing.documentInsets
LiturgicalSpacing.sectionBefore
LiturgicalSpacing.sectionTitleToBody
LiturgicalSpacing.paragraphAfter
LiturgicalSpacing.hymnStropheAfter
LiturgicalSpacing.antiphonToPsalm
LiturgicalSpacing.psalmToRepeatedAntiphon
LiturgicalSpacing.readingMetadataToBody
LiturgicalSpacing.intercessionPetition
LiturgicalSpacing.refrainRepeat
```

При будущей миграции token должен принимать `B`, выбранную family и light/dark palette; нельзя фиксировать только `fontSize: 16`.

## Проверка полноты

Повторно пройдены сверху вниз:

- все 9 веток `_buildContent` в `OraScreen`;
- все `_OraItemType`: `blockHeader`, `antiphon`, `labeled`, `html`, `psalm`, `plain`, `custom`;
- оба пути `_HtmlOrText`: HTML + plain/RichText;
- alternative picker, linked antiphon repeats, structured `.ora-ant/.ora-psalm`, intercessions formatter;
- контекстный header, feast comment, loading/empty/error/no-content branches;
- все секции `_ReadingBody`: one/two readings, structured/raw psalm, alt chorus, alleluia fallback, Gospel, generated/source closing phrase;
- HTML и plain `_ReadingText`, cadence spans и sentence highlights;
- обе ветки `ReadingDetailScreen`: local HTML map и plain/raw `SelectableText`;
- light/dark colors, opacity, reader surface и edge gradients.

## Итог аудита

| Метрика | Результат |
|---|---:|
| Исследованные content screens | 11: 9 вариантов Ora + Readings + ReadingDetail |
| Стабильные semantic IDs в каталоге | 87 |
| Фактически различимые typography variants после схлопывания полных дублей | 49 |
| Зафиксированные inconsistencies / risk points | 27 |
| Главная зона дублирования | три HTML style maps и локальный vertical rhythm |

### 10 наиболее вероятных причин визуальной неравномерности

1. Три независимые HTML style maps.
2. Два способа строить section heading (`blockHeader` и `_LabeledSection`).
3. Разный psalm-even spacing в Ora и Readings.
4. Смешение HTML и plain renderers, включая plain ReadingDetail без marker spans.
5. Source-driven `em/strong` и частично сохранённые inline styles.
6. Позиционная эвристика leading metadata/captions.
7. Отдельные header implementations для Hours и Readings.
8. Раздельные alternative/invitatorium triggers.
9. Несоблюдение reader-family у Ora headings и invitatory trigger.
10. Множество локальных magic spacing numbers и независимое масштабирование body/UI.

На этом этапе production-код не менялся. Следующий этап унификации следует начинать только после заполнения `TARGET` и ручного подтверждения каталога.
