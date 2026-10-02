# Foundations Post-Merge Audit

## 1. Current HEAD

Проверено 2 октября 2026 после `git fetch origin main`:
**`origin/main = HEAD = b13f129deef1b7f4d1ddf95930c894023aa6f82d`**,
`Align liturgical heading contract and mobile rhythm`. Checkout называется
`fix/liturgy-visual-alignment`, но его содержимое совпадает с main; новых
коммитов после `b13f129` на момент проверки нет. Production-код не изменялся.

Полностью прочитаны [Concept](DESIGN_CONCEPT.md), [System](DESIGN_SYSTEM.md),
[Liturgical spec](../LITURGY_CONTENT_VISUAL_SPEC.md) и
[consolidated review](../DESIGN_CONCEPT_VNEXT.md). Проверены четыре указанных
коммита и текущие theme, chrome, readers, HTML formatter, Compendium,
Songbook, settings, main, pubspec и font assets.

**Вывод:** typography/HTML/Office rhythm уже имеют работающую основу.
Следующий Phase 1 следует сузить до **общего источника semantic colors и
нейтрального generic chrome**, не повторять стилизацию документов.

Проверка: `flutter test --no-pub` для `reader_theme_test.dart`,
`bundled_fonts_test.dart`, `liturgical_visual_contract_test.dart`,
`liturgical_screen_smoke_test.dart` — **34 passed** (Flutter 3.38.9).
Это кодовый и тестовый аудит; нового визуального device QA не было.
Smoke включает 360×800 / 390×844 и B=24 в отдельных случаях, но не доказывает
полную матрицу Aa180 × system200, все source-варианты или cold offline launch.

## 2. What changed in recent merges

| Commit | Реальное изменение | Следствие для следующей задачи |
| --- | --- | --- |
| `20cf1b4` | Cormorant `blockHeading`/`majorHeading`; service/rubric roles; `liturgicalDocumentStyles`; semantic HTML normalization, cadence/reference/responsory fixes; `LiturgicalSpacing` и divider | Общая фабрика и ритм уже в main. Не писать вторую; не возвращать старые независимые style maps |
| `7d48807` | Compendium root → Part с плоским source outline → question; old node/topic redirects к Part/anchor. Songbook оставляет query + tags, убирает favorites-only filter; chord fixes также входят в коммит | Не восстанавливать drill-down, favorites-only и прежнюю раскладку аккордов |
| `7b72cc9` | Консолидирует Concept/System; документально возвращает Literata document headings, тогда как код `20cf1b4` сохраняет Cormorant | В этот момент существовал реальный конфликт docs/code, не два равноценных канона |
| `b13f129` | Согласует канон с Cormorant page/semantic section headings; вводит `LiturgicalSectionHeading`, `startsSection`, `plainTextAfter`, helpers переходов; Te Deum получает hymn rhythm; расширяет phone smoke | Последнее решение отменяет конфликт гарнитуры. Сохранять его и исправленный Office rhythm |

Mass language наверху, suppression глобального dock, центровка single-action
icons и три bundled base faces сделаны ещё раньше. Не включать их повторно
как незавершённые задачи Foundations.

## 3. Typography contract now

**Новый контракт целостен:** Cormorant — page titles и смысловые content
section headings; Literata/reader-family — длительное чтение; System — UI.
Concept, System, TARGET `SECTION_TITLE`, implementation-status liturgical
spec и верхний уровень consolidated review теперь согласны. Пользовательский
выбор body-family намеренно не меняет Cormorant headings.

В таблице RF = выбранная reader-family, по умолчанию Literata.
Sources: [ReaderTheme](../../lib/theme/reader.dart),
[HTML roles](../../lib/theme/liturgical_document.dart),
[shared header](../../lib/widgets/reader/reader_scaffold.dart).

| Роль | Current family / source | Canonical target | Конфликт / остаток |
| --- | --- | --- | --- |
| Page title | Cormorant Bold: `displayTitle`, Home 38 / Readings 36; Prayerbook, Songbook, Compendium roots — System `headlineLarge` | Cormorant 600–700, baseline 32–34 | PARTIAL adoption; не смешивать различие baseline с поломкой гарнитуры |
| Document title | System 27/w600/h1.18: `ReaderContextHeader.titleText` (Ora, Prayer/Mass, song, question) | System §2: Cormorant 700, если содержательный page title | Не внедрено; условие «если» требует явного route/role mapping, не слепой замены всех headers |
| Major heading | Cormorant 700: `majorHeading = blockHeading ×1.12`; Mass `_massStyles.major` | Cormorant, h1.12 | Family совпадает; Mass локально ставит h1.25 |
| Block/section heading | Cormorant 700, max(1.42B,22)/h1.12: `blockHeading`, Ora `LiturgicalSectionHeading`, Readings `_SectionLabel`, shared `.liturgical-heading`, Prayer h2/h3 | Та же роль Cormorant | Основной контракт работает. Mass subsection h1.3; Compendium `_PartHeader/_PartItem` пока System |
| Service heading | `serviceHeading`: RF аргумент, default Literata; Ora вызывает без family. HTML `.liturgical-service-heading` наследует body-family | Малый служебный red max(.88B,14)/h1.42, не display | Нет причины переводить в Cormorant; native/HTML inheritance при пользовательском override нужно уточнить отдельно |
| Rubric | `rubricStyle`: RF; `rubricBlock`: default Literata, non-italic; shared `.liturgical-rubric` наследует body, .90B min14/h1.48 | Literata/книжная роль, обычный стиль для explicit block; inline наследует строку | Core соответствует. Prayer `.prayer-rubric` остаётся ink/italic с red border; Mass имеет свои semantic variants — не считать всё одной ролью |
| Reference | `referenceStyle` RF 600/h1.40; `rubricReference` RF 500; HTML reference наследует body | Книжная малая роль; red/muted по смыслу | `_BibleRef` передаёт `textStyle.fontFamily`, а `body()` ждёт ID `system/sourceSerif4/literata`: выбранная family может сбрасываться в Literata |
| Metadata | UI context — System; `ReaderTheme.metadata()` default Literata; HTML psalm metadata — RF | UI metadata System; liturgical metadata собственная книжная роль | Разделение верное; native metadata не принимает family, HTML наследует её — контракт override не полностью явен |
| Body | `ReadingScaffold → body(B, settings.fontFamily)`, Literata / Source Serif 4 / System, h1.68 | RF, baseline ≈17, независимый TextScaler | Family соответствует; текущая база 16 — отдельная preference migration |
| Psalm | `psalm → body`; реальные Ora/Readings renderers сохраняют RF, h1.68, локальные strophe/choir rules | Книжная psalm role с source structure | Не нужен Cormorant для metadata/строф; различие псалмов Hours/Readings не дефект само по себе |
| Hymn | `hymn → body` h1.72; Ora HTML `kind:hymn` h1.72, stanza15, включая Te Deum | RF h1.72 / stanza15 | HTML/Te Deum соответствует; обычный plain hymn идёт через generic `_LiturgicalSelectableText` с исходным h1.68 — узкий edge case, не повод переписывать foundation |

**Оценка Cormorant:** ясная книжная иерархия возможна, потому что headings
отделены от мелких service/reference/rubric и длинного body. При B=16 heading
22.72, при B=28.8 — 40.896 до system scale: короткие повторяющиеся разделы
и длинные названия могут визуально доминировать. Home дополнительно использует
`displayTitle(29)` для празднования, а не только титула страницы. Это риск
двух display-уровней, не доказанный новым скриншотным аудитом дефект.

Граница: Cormorant только для смыслового начала раздела/книги, не для каждой
красной строки, подписи псалма, номера вопроса, rubric, controls или body.
Не множить крупные headings ради любого HTML `h2/h3`. Проверять плотность и
длинные заголовки на 320/360/390 и совместном большом масштабе отдельной
типографической задачей. Прежнее Literata-решение автоматически не возвращать.

## 4. Liturgical rhythm / spacing status

`LiturgicalSpacing` в `reader.dart`: sectionBefore24, titleToBody8,
paragraphAfter8, hymnStrophe15, antiphonToPsalm4, psalmBlockToNext22,
metadataToBody7, dividerBefore22 / after21, plainTextAfter12.
`LiturgicalSectionDivider` и `LiturgicalSectionHeading` в
`liturgical_document.dart`; композиционные helpers в `ora_screen.dart`.

| Переход | Фактический владелец / оценка |
| --- | --- |
| Divider → section | Divider 22 + line box1 + 21; следующий labeled heading `startsSection:false`, затем titleToBody8. Исправлено двойное владение section gap |
| First reading → second reading | `_addOfficeReadings`: один divider перед первым существующим чтением; R2 `startsSection:hasFirst`. При отсутствии R1 второй не получает лишние 24 после divider |
| Pater → prayer | `_addPaterAndPrayer`: Pater trailing0 при наличии prayer; prayer heading владеет 24. Без prayer сохраняется plainTextAfter12 |
| Intercessions → Pater | `_LabeledSection` оставляет paragraphAfter8 после source/HTML margins; Pater не добавляет leading section gap. Это continuity той же молитвенной группы, отдельного токена перехода нет |
| Te Deum | В Lectionis и Morning `kind:'hymn'`: h1.72 / stanza15 вместо generic h1.68 / p8. Header использует общий section gap |
| Prayer → closing | Closing rubric/dialogue не получает нового heading/sectionBefore; остаются paragraphAfter и собственные HTML margins. Не добавлять divider автоматически |
| Psalm blocks | Общий `_addPsalmBlockResolved`, ant→psalm4 / следующий block22; сохранены single-ant, structured source, связанные варианты и suppression внешнего повтора |

Это **хорошая foundation для Office**, не универсальный layout engine:
`startsSection` назначает вызывающий код, автоматического collapse нет;
source paragraph margins и outer gaps всё ещё могут складываться. Тесты
проверяют startsSection, Te Deum и smoke, но не измеряют каждый итоговый
межблочный интервал и все missing-field combinations. Сохранить существующие
helpers/roles/tests; не заменять их общим spacing-rewrite или новой системой
IbSpace без конкретного дефекта и fixture.

## 5. Foundation status

DONE означает выполненный названный объём, а не завершение всей дизайн-системы.

| Foundation | Статус | Что уже есть / остаток |
| --- | --- | --- |
| Reader typography roles | PARTIALLY DONE | Core body/content/service roles есть; doc headers, native/HTML family mapping и plain hymn остаются |
| Shared HTML roles | PARTIALLY DONE | Ora/Readings/ReadingDetail используют общую factory. Prayer/Mass используют те же heading tokens, но собственные maps; не обещать единую factory для четырёх |
| Office semantic spacing | DONE | Исправленные переходы `b13f129` и общие psalm gaps; сохранять в текущем scope |
| Bundled base fonts | DONE | Три faces, pubspec asset directory и лицензии; hardening runtime policy отдельно ниже |
| Page titles | PARTIALLY DONE | Cormorant уже в Hours/Readings, корни коллекций ещё System |
| Content headings | PARTIALLY DONE | Core Cormorant работает; Compendium и Mass line-height исключения |
| AppPalette | PARTIALLY DONE | Общая нейтральная ColorScheme есть; отдельные reader/glass literals и container alpha остаются |
| ReaderTheme colors | STILL NEEDED | Перенести semantic values в общий источник, сохранив методы типографики |
| Seasonal primary | STILL NEEDED | Ora подменяет primary **и primaryContainer** |
| Seasonal generic chrome | STILL NEEDED | Цвет проходит через shell/dock/top/reader/platform boundary |
| Liturgical color resolver | DO NOT TOUCH YET | Действующий heuristic resolver; отдельная domain migration |
| Aa baseline/min/step | DO NOT TOUCH YET | Сейчас 16 / .70 / .10, max1.80; изменение preferences отдельной задачей |
| ThemeExtension / IbTokens | STILL NEEDED | В lib нет; ближайший scope — только colors, не все восемь семейств |
| TopChrome | PARTIALLY DONE | Существуют FloatingTopActions, ReaderChrome, AdaptiveAppBar; объединение компонентов отложить |
| BottomSlot | PARTIALLY DONE | Route suppression и contextual requests работают, полного арбитра/inset-owner нет |
| ReaderBottomBar | DO NOT TOUCH YET | UI-гипотеза до 2–3 прототипов; не часть color phase |
| Compendium | DONE | Новый browsing flow и compatibility redirects; точечная typography migration отдельно |
| Songbook | DONE | Query/tags filters, compact rows, chords/transposition; generic chrome debt не отменяет сделанное |

## 6. Remaining conflicts

### Color: A–D

| Проверка | Статус | Current source / следствие |
| --- | --- | --- |
| A: независимые ReaderTheme colors | CURRENT | `reader.dart:53–62`: ink, muted, rubric, rubricSoft, surface, border. AppPalette дублирует ink/rubric; light muted **#62645F** против UI **#5F625C**. Reader surface **#FDFCF9** отличается от generic surface **#F8F8F5** намеренно |
| B: seasonal scheme Ora | CURRENT | `ora_screen.dart:403–429`: copyWith(primary, primaryContainer) + nested Theme. Удалить обе сезонные подмены |
| C: generic chrome tint | PARTIALLY FIXED | `app_shell.dart:112`: сезон только hours, другие ветки получают neutral primary; но dock/menu его смешивают. FloatingTopActions default берёт seasonal provider, ReaderChrome передаёт seasonColor. AdaptiveChromeSurface Android alpha .055; iOS GlassSurface pill .065/.08. Частичная нейтральность веток не закрывает проблему |
| D: Settings/legacy washes | CURRENT | Settings, Favorites, MyPrayers, About берут seasonal provider. Prayerbook/Compendium/Songbook `AmbientWash(cs.tertiary)` — уже нейтральный tonal tint, не календарная окраска; не объявлять его тем же дефектом |

Разделить **visual application** (scheme/chrome/washes) и **domain resolution**
(`liturgicalColorForDay`: period/rank/template, слова martyr/apostle и т. п.).
Первое — Phase 1; второе не менять. Сохранить цвет празднования, hour icons,
подписи и допустимый day-context ambient; не обнулять все seasonColor в lib.

### Документы и границы канона

- В четырёх основных документах активного противоположного Literata-heading
  правила больше нет. Старые Literata строки Master Catalog явно датированы
  `1ac450d`; это история, не новый TARGET. Аналогично заголовок «Current
  inconsistencies» внутри этого исторического каталога нельзя использовать
  как свежий список багов (Te Deum, missing rubric и отдельные maps уже исправлены).
- `DESIGN_SYSTEM` §5 всё ещё говорит использовать factory «после интеграции
  ветки», хотя она в main. Это устаревший статус, не blocker реализации.
- Исторические `reader-typography-vnext.md` §2 и DL1.1 ещё содержат старые
  serif scales/display-only рекомендации; их banners отменяют authority.
  Не возрождать эти решения при поиске по отдельному фрагменту.
- System задаёт Cormorant docTitle и Compendium target, но текущий код ещё не
  полностью мигрировал. Mass h1.25/1.3 и native/HTML family inheritance нужно
  явно оформить как исключения либо исправить отдельным typography pass.

### Fonts: запрос face и синтез — разные вещи

`assets/google_fonts/`: **Literata-Regular.ttf, SourceSerif4-Regular.ttf,
CormorantGaramond-Bold.ttf**, три OFL; directory объявлена в pubspec,
`main._registerFontLicenses` регистрирует лицензии. В production lib всего
четыре GoogleFonts call sites, все в ReaderTheme: два Cormorant с w700 normal
и два body-face с default w400 normal. Эти запросы покрыты bundle.

Проверен установленный `google_fonts 6.3.3`, `src/google_fonts_base.dart`:
variant выбирается **в момент вызова GoogleFonts**; asset ищется до cache/network.
Последующий `.copyWith(w600/italic)` или HTML `strong/em` не вызывает новый
GoogleFonts-запрос. Поэтому отсутствие отдельных italic/semibold TTF не
доказывает их runtime-download: это риск синтеза/подбора начертания, требующий
отдельной визуальной проверки. UI использует `base.textTheme`, не сетевой font.

**Отключать runtime fetching уже разумно для текущих call sites**, но отдельным
маленьким hardening change: до release проверить настоящую сборку с пустым
font cache, сетью off и `allowRuntimeFetching=false`, обе book preferences,
headings, нужные глифы и ошибки загрузки. Текущий тест проверяет наличие файлов,
не заменяет cold-launch gate. В color phase flag/asset composition не менять;
повторный bundling трёх faces не нужен. Новый GoogleFonts-вызов с другим weight
потребует соответствующий asset до выключения fetching для такого вызова.

## 7. Revised Phase 1 scope

**Один узкий change set — semantic colors + neutral generic chrome.**

A. Ввести минимальный `IbTokens` ThemeExtension с `colors`/`IbColors`,
подключить в light/dark ThemeData. AppPalette и ReaderTheme читают один
источник; сохранить публичные typography methods и `LiturgicalSpacing`.
Reader surface/rubric/border — явные роли. Сохранить существующие цвета:
readerMuted/UI muted временно разные именованные роли, не скрытое изменение
палитры. Их последующее слияние в System baseline — отдельное решение.

B. Снять обе seasonal scheme overrides в Ora. Сохранить тот же domain
resolver и явно передаваемый day-context accent. Кнопки/Aa/selection chrome
наследуют neutral scheme; rubric и смысловые маркеры сохраняют свои роли.

C. Сделать generic control/navigation surfaces нейтральными на обеих ОС:
AppShell → dock/menu, FloatingTopActions, ReaderChrome/scroll control,
AdaptiveChromeSurface. Удалить seasonal provider fallback из generic top
actions. `ReaderScaffold.seasonColor` может остаться **для контекста**, но не
передаваться в chrome. У прямых legacy GlassSurface отделить control tint от
day content; не глобально удалять AmbientWash/GlassSurface или менять материал.
В Settings/Favorites/MyPrayers/About убрать provider-derived page wash,
оставив neutral backdrop и прежнюю геометрию. Прочие compatibility screens —
только те же color-call-site изменения; контекстные liturgical pickers сохранить.

D. Добавить focused regression checks: light/dark × Android/iOS, разные
day colors дают одинаковые primary/container/generic chrome colors; day marker
меняется, rubric нет; Settings не зависит от season. Проверить реальную цепочку
Ora → Aa и shell → dock, а не только равенство констант. Повторно запустить
существующие typography/spacing, platform и navigation tests, не менять их
ожидания ритма ради прохождения color refactor.

## 8. Explicitly deferred

- Calendar/color resolver migration, Marian/Requiem policy, rank/template logic.
- Aa **16/.70/1.80/.10 → ≈17/.85/1.80/.05**: отдельная версия preferences.
  `normalizeReaderFontSize` применяется уже при чтении Hive; простой новый min
  молча увеличит сохранённые 11.2…14.45. Нужна политика grandfathering либо
  явного перехода пользователя, сохранение допустимых абсолютных размеров,
  отдельный reset-default и тесты миграции. В ближайшем Phase 1 не менять.
- Page/doc titles, Compendium headings, Mass line-height, `_BibleRef` family-ID,
  plain hymn и synthetic faces — точечные typography/font задачи.
- Новые HTML factories, Office spacing rewrite, перенастройка paragraph gaps.
- Full IbTokens tree, JSON export, blanket literal lint, новая palette, radius,
  gutter, glass blur/elevation; TopChrome/BottomSlot/ReaderBottomBar и routes.
- Compendium hierarchy, Songbook query/tags/chords, Mass language placement,
  dock suppression, circular-icon centering, bundled base assets и branding.

## 9. Recommended Sol 6 task

> От актуального main выполни только Color Foundations Phase 1: минимальный
> color-only IbTokens/ThemeExtension и общий источник для AppPalette/ReaderTheme;
> удаление seasonal primary **и primaryContainer** в Ora; neutral generic chrome
> через существующие компоненты; neutral Settings и указанные non-liturgical
> legacy washes. Сохрани текущие numerical color roles, включая различие
> readerMuted/UI muted и opaque reader surface, кроме намеренного снятия tint.
> Сохрани day-context accents, rubric и liturgicalColorForDay без изменений.
> Добавь регрессионные проверки из §7D и выполни существующие затронутые тесты.
>
> Не меняй Cormorant-контракт, font assets/fetching policy, Aa/preferences,
> typography/HTML maps, LiturgicalSpacing/startsSection, source content,
> Compendium/Songbook behavior, Mass controls, routes, insets, размеры,
> материалы или геометрию TopChrome/BottomSlot. Не создавай новый renderer.
> Изменения экранов ограничь color wiring. Отдельно перечисли сохранённые
> ограничения; не исправляй их попутно. Если main изменился, сначала проверь
> только затронутые цветовые контракты, не возобновляй redesign.
