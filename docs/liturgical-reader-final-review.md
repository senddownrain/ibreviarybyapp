# Executive verdict

Stage 9 · 2026-09-10 · READ-ONLY PWA → Native Liturgical Reader Review.

**Сохранить семантику MyBrev и завершить её перенос; адаптировать типографику и взаимодействия к нативному reader. Архитектура Stage 8 достаточна.** Основная работа Stage 10 — VISUAL ADAPTATION, но перед ней нужны несколько конкретных исправлений NORMALIZATION / SEMANTIC DETECTION. Не маскировать их размерами шрифта.

Production code не изменён. Этот документ — спецификация для Sol, а не начало implementation. AppShell, четыре branches, date model, resolver, база, Bible architecture и модель Prayerbook остаются за пределами redesign.

## Evidence и границы проверки

- Flutter: `senddownrain/ibreviarybyapp`, `feature/mobile-ux-migration`, HEAD `09401b6698e1469d3c56be877d409b424f310c02`.
- PWA: локальный `../mybrev`, HEAD `86d51b38d1448d6f650b6d88c6b9731ae3174248`, чистое рабочее дерево при исследовании. Это reference данного review; идентичность текущему deployed bundle не проверена.
- Изучены [handoff](ibreviary-ux-handoff.md), [Stage 7](migration-visual-audit-stage7.md), [Stage 8](migration-stage8-finalization.md), [reader foundation](reader-foundation.md), [Hours](hours-root-migration.md), [Readings](readings-root-migration.md), production renderers и их вызовы.
- PWA: `src/components/oras/{Invit,Lectionis,Laudes,Terz,Sext,Non,Vesper,Completorium,Morning}.vue`; `oraparts/{Psalms,AlternativeText,Reading,Lectio,Hymnus,Inters,Resp,LastPrayer,Benedictus,Magnificat,Nunc,Intro,Exam,EndOfVesper,EndOfCompline}.vue`; `src/utils/liturgicalHtml.js`, `liturgicalAlternatives.js`; `src/components/readings/ParsedReadingCard.vue`; `src/styles/main.scss`; источники availability/Compline.
- Flutter: [Ora](../lib/screens/ora_screen.dart), [Readings](../lib/screens/readings_screen.dart), [AlternativeText](../lib/widgets/alternative_text.dart), [HTML](../lib/utils/liturgical_html.dart), [alternatives](../lib/utils/liturgical_alternatives.dart), [ReaderTheme](../lib/theme/reader.dart), [reader chrome/surface](../lib/widgets/reader/reader_scaffold.dart), Settings, drawer, Prayerbook, HoraItem и модели данных.
- По `mybrev/AGENTS.md` использован локальный snapshot через `scripts/lib/firestore-snapshot.mjs`, с проверкой checksum библиотекой. Snapshot `20260827124414214`, экспорт 27 августа: **743 fixedDays**. Дополнительно prayer snapshot `20260828123704094`, экспорт 28 августа: 85 prayers, точечная проверка Mass entity. Snapshot не обновлялся, live Firestore reads не выполнялись, содержимое backup не копировалось в репозиторий.
- Выполнены реальные JS formatters на snapshot-примерах; существующие PWA HTML/alternatives tests: **30 passed**. Отдельный временный Dart probe импортировал production `liturgical_html.dart` и подтвердил уменьшение mixed-dialogue paragraph и сохранение `<br>` после `†`. Probe находится вне репозитория; production не инструментировался.
- Это **source + local production-snapshot review**, не новый live visual audit. Скриншоты native iOS/Android, TalkBack/VoiceOver, 200% и текущая серверная полнота контента здесь не подтверждены. Размеры ниже — спецификация, не результаты измерения экрана. Stage 8 сообщает 114 tests/analyzer/builds PASS; эти gates в Stage 9 повторно не запускались.
- В snapshot отсутствуют `invitatoriums`, `completoriums`, Mass `readings`. Их composition и fallback проверены по source; полная проверка реальных текстов этих коллекций остаётся Stage 10 QA. Это не основание придумывать контент или менять liturgical policy.

## Таблица решений PWA → Flutter

Классификация относится к конкретному аспекту: **PRESERVE** — смысл/порядок; **VISUAL ADAPTATION** — оформление; **POSSIBLE LOGIC IMPROVEMENT** — изменение самого PWA поведения, только с production evidence. Исправление Flutter до PWA parity не относится к последней категории.

| Element | PWA | Flutter после Stage 8 | Decision |
| --- | --- | --- | --- |
| Main headings | Структурные заголовки часа/чтения; отдельный context | Context + sectionTitle, uppercase | ADAPT: сохранить роли; убрать конкуренцию с body |
| Minor headings | Leading metadata, centered captions, inline bibliography | Более широкая red-heuristic; inline reference role отсутствует | PRESERVE PWA: исправить detection; ADAPT размеры |
| Rubrics | Explicit classes, red HTML, отдельные speaker spans | Rubric palette хорошая; часть static instructions без explicit role | PRESERVE PWA + ADAPT: explicit blocks, inline без уменьшения абзаца |
| Psalm | Cadence normalization, strophes, условное удаление embedded antiphon | Есть strophes, но не весь preprocessing и nested role mapping | PRESERVE PWA |
| Antiphon | Поле/вложенная роль; opening/repeat связаны; визуально тоже panel | Связанные controllers; один тяжёлый panel для opening/repeat | ADAPT; сохранить выбор и количество повторов |
| Responsory | `Resp`/reading HTML; смысл по тексту и К./Н. | Generic/reading HTML; mixed paragraph может уменьшаться | PRESERVE PWA; текстовое оформление |
| Intercession | Intro/refrain/petition/response/conclusion; refrain тоже с фоном | Почти тот же parser и выраженный refrain block | PRESERVE PWA + ADAPT; перенос marker styling |
| Prayer | `LastPrayer`, kind=prayer; условия и варианты | LabeledSection, короткое «Ойча наш.» | PRESERVE PWA; единый block heading |
| Reading | Structured fields, порядок, reference и closing acclamation | Shared reader, вертикальный reference; несколько fallback gaps | KEEP FLUTTER foundation; PRESERVE PWA content fallbacks |
| Alternatives | Где существуют, split/dedup/shared content, linked repeats | Перенос parser, огромный inline list | PRESERVE PWA recognition; ADAPT interaction |
| Chrome/scale | Web layout и CSS multiplier | Общий reader, Full/Compact/Hidden, persisted Aa, branch context | KEEP FLUTTER — DO NOT REGRESS |

# PWA semantic behavior to preserve

**PRESERVE:** роли следуют composition, полям и существующим HTML conventions; текст не классифицируется заново по впечатлению от его содержания. `em` не означает автоматически rubric, красный span не превращает весь абзац в metadata. Чтение, просьба и молитва остаются основным текстом даже с inline указаниями.

## Покрытие часов

| Час | PWA → Flutter: обязательный порядок/behavior | Evidence и действие |
| --- | --- | --- |
| Invitatorium | Рубрика → К./Н. → выбранный псалом по частям с одной и той же антифоной между частями и в конце | `Invit.vue`, `_addInvitatoriumContent`; snapshot `01-01-holy-mary-mother-of-god.invitatoriumAnt`. Сохранить отдельный выбор invitatorium и Christmas default. Полные Ps1–6 — source-only. Flutter прекращает цикл на первом пустом поле; не менять без реального sparse record |
| Office of Readings | Intro → hymn → psalmody → versicle → R1 → R2 → условный Te Deum → prayer → ending | `Lectionis.vue`, `_buildLectionis`; январский snapshot содержит весь набор. Перенести removal повторных R1/R2 labels |
| Laudes | Intro/hymn/psalmody → short reading с responsory → Benedictus и связанная антифона → intercessions → Pater → prayer → ending | `Laudes.vue`, `_buildLaudes`; январский день + Budslav intercessions + `office-for-dead.laudesPs3` |
| Tertia | Intro → hymn → 3 psalms → `sext1R` → `sext1Pr` → ending | `Terz.vue`, `_buildSextHour(num:1)`; январский `sext1R` содержит red heading и body в одном p: body нельзя уменьшать |
| Sexta | Тот же порядок; существующий per-field fallback | `Sext.vue`, num:2; январские `sext2Ps2/3` содержат literal `†<br/>`; перенос PWA normalization |
| Nona | Тот же порядок; fallback не переосмыслять | `Non.vue`, num:3; `01-05-dedication-pinsk-cathedral-diocese.sext3R` даёт 2 reading options |
| Vespers | Existing selected Vespers context → hymn/psalmody → reading → Magnificat → intercessions/Pater/prayer → ending | `Vesper.vue`, `_buildVespers`; prayer fallback к laudesPr сохраняется. I/II Vespers metadata не новый раздел молитвы |
| Compline | Intro → examination instruction → hymn → 1/2 psalms → compR → compResp → Nunc → prayer → blessing → Marian antiphon | `Completorium.vue`, `_buildCompline`; renderer source-only, availability defect отдельно ниже |
| Combined Morning | Invitatorium → **laudesHymn** → Office psalmody/vers/R1/R2/Te Deum → Laudes psalmody/reading/Benedictus/intercessions/Pater/prayer/ending | `Morning.vue`, `_buildMorning`: используется, включена в HoraItem. Не соединять три полных экрана с повторными intro и окончаниями |

Для обычной psalmody: `ant1–ps1–ant1`, затем пары 2/3; для single-antiphon: `ant1–ps1–ps2–ps3–ant1`. Shared content и suffix выбранного варианта не исчезают. Gloria Patri сохраняется там, где она присутствует в источнике/фиксированной песне; общий formatter не должен автоматически дописывать её каждому псалму. В PWA Psalms такого append нет.

# Flutter behavior to preserve

**DO NOT REGRESS:**

- Общий ReaderScaffold/ReaderContentSurface, непрозрачная нейтральная колонка и adaptive chrome. Не возвращать Vuetify card composition и браузерную оболочку.
- Full/Compact/Hidden и существующий владелец chrome в AppShell; branch stacks, контекст Ora → Readings → Back и scroll restoration.
- ReaderTheme: Literata body; фиксированная reader family без возврата font customization. Persisted Aa 70–180% и системный TextScaler — независимые пользовательские механизмы. Исправить зависимость вспомогательных ролей от Aa, не потерять system scaling.
- Readings: reference под label на mobile уже правильный; нет необходимости воспроизводить desktop PWA reference справа. Plain text selectable и markers уже поддерживаются.
- AlternativeText: один показанный вариант, общий controller opening/repeat, скрытый picker в повторе, сброс при смене source/kind, ограничение допустимого index. Эти механизмы полезны; большой selector не причина их переписывать.
- Современные state/error/offline paths и компактная expandable feast biography. Существующие данные и preferences keys сохраняются.

# Semantic role matrix

**VISUAL ADAPTATION**, основанная на перечисленных реальных полях/компонентах. Это небольшой набор reusable styles + modifiers, а не новая content model.

`B` = текущий persisted reader font size (сейчас default 16 logical px), до системного TextScaler. `S` = max(B, 16) только для расчёта spacing. Все размеры текста проходят системный scaler ровно один раз. Значения ролей ниже минимизируют микротекст при Aa 70%; это новый presentation rule, не изменение диапазона настройки. `ink/muted/rubric` = ReaderTheme. Spacing указан до/после в долях S; смежные интервалы **max, не сумма**. Все роли слева; body без justify; italic только по указанному правилу. Минимум размера применяется до системного scaling.

| Роль / реальный источник | Размер | Weight / цвет | Italic | Indent | До / после |
| --- | --- | --- | --- | --- | --- |
| Major section heading — час; R1/R2 | max(.98B, 15) | 600 / ink | нет | 0 | 1.5S / .65S |
| Block heading — Гімн, Псалмодыя, Просьбы, Малітва | max(.90B, 14) | 600 / rubric | нет | 0 | 1.4S / .5S |
| Psalm heading — номер/название | max(.95B, 14) | 600 / ink | нет | 0 | .65S / .25S |
| Metadata/reference/theme — leading captions, bible/comment | max(.88B, 14) | 400; reference 500 / muted | только source quote/comment | 0 | .25S / .65S |
| Explicit rubric block — instructions/ending | max(.90B, 14) | 400 / rubric | нет по умолчанию; сохранить source em | 0 | .65S / .55S |
| Inline rubric / К., Н., С. | 1B | 400; marker 600 / rubric | нет | внутри строки | 0 / 0 |
| Body — prayer, hymn, scripture, psalm/strophe, Gospel canticle | 1B | 400 / ink | source emphasis | psalm modifier ниже | 0 / .65S |
| Antiphon — opening/repeat | 1B | 600 / ink; label rubric | нет | 0 | .75S / .6S; repeat .6S / .9S |
| Responsory/dialogue body | 1B | 400 / ink; явный общий response 600 | source emphasis | continuation под текстом, marker в первой строке | .55S / .55S |
| Refrain — intercessions/Responsorial Psalm | 1B | 600 / ink; label rubric | source em допустим | 0 | .6S / .75S; repeat .45S / .6S |
| Intercession petition / response | 1B | 400 / ink | source emphasis | response до .75S | petition .85S / .2S; response 0 / .65S |

Prayer, scripture и Gospel canticle не требуют трёх отдельных размеров: разница в composition, межабзацном ритме и source emphasis. Major/block/metadata/inline/body/emphasized-body — reusable styles; repeat/psalm/dialogue — modifiers. Межстрочный интервал: body 1.65; scripture prose 1.7; antiphon/response 1.55–1.6; heading 1.3; metadata/rubric 1.45. Не применять глобальную сетку фиксированной высоты строки.

# Typography recommendations

1. Управляемые приложением заголовки отображать обычным регистром: «Гімн», «Просьбы», «Песня з Евангелля». Убрать `.toUpperCase()` и tracking 0.9–1.5 в этих ролях. Не lower-case произвольный HTML/source. Canonical labels можно заменить независимо от source.
2. Убрать повторное крупное название часа внутри документа, если тот же час уже однозначно назван в context; сохранить один semantic heading. В Combined Morning оставить смысловые границы двух psalmody/readings, не добавлять intro.
3. Единый scale contract для `_LabeledSection`, `_OraItem.blockHeader`, HTML roles и Readings labels. Сейчас Ora использует фиксированные 14/Theme.labelSmall, HTML — .84B/.94B, Readings — .80B. Маленький uppercase и opacity .45 у prayer label заменить ролью из матрицы.
4. Сохранить нынешнюю reader surface и max width 760. На 320–359 logical px допустимо уменьшить внутренние 22 до 16; от 360 оставить 22. Не складывать HTML body padding с padding поверхности.
5. Main prayer body остаётся главным. Не менять default B=16 в этом этапе без device comparison; размеры заголовков исправлять относительно B. Aa и system 200% должны увеличивать actual rendered HTML и plain text, не только toolbar.

Контраст проверять на реальных Light/Dark surfaces: нормальный текст, metadata и rubric не менее 4.5:1 как критерий QA. Не использовать полупрозрачный onSurface .45 для важного текста. ReaderTheme уже имеет отдельные light/dark rubric (`#9B302A` / `#EF9188`); сохранить основу и измерить rendering. Длинные labels и actions переносятся, 200% не лечится ellipsis или уменьшением текста.

# Rubrics

**PRESERVE + VISUAL ADAPTATION.** Единый приглушённый rubric token для red HTML, explicit instructions и speaker markers. Литургический цвет дня остаётся context accent, не заменяет rubric по всему документу.

- `К.`, `Н.`, `С.` — inline role markers размера B; последующие слова ink/B. Сохранять буквы, точки и порядок реплик. Hanging alignment допустим в explicit dialogue, но не отдельная узкая колонка, которая оставит слишком мало места при 200%.
- Red span внутри молитвы — локальный цвет, **не metadata родителя**. `officeOfReadingsVers` январского дня — подтверждённый regression example.
- `<em>` может быть припевом, цитатой, subtitle или инструкцией. Не вводить `em { rubric; font-size: .9em }` глобально.
- Static `_kInvitRubric`, инструкции `_kEndOfVesper`, Compline instruction получать explicit rubric-block role независимо от позиции в HTML. Сейчас leading heuristic не гарантирует единое оформление поздних инструкций; `_kStandardIntro` сам попадает под ошибку mixed red.
- Source red `span/font` нормализовать в theme role, сохраняя прочие attributes/emphasis. PWA CSS поддерживает также `[style*=color...]` без ограничения на tag; Flutter сейчас ограничен span/font. Не объявлять все цвета rubrics и не обнулять все inline styles.
- Plain-text `К.` в `office-for-dead.officeOfReadingsVers` не повод regex-замены по всем текстам. Для известного dialogue field можно стилизовать начальные marker tokens; в обычной прозе не искать случайные буквы.

# Psalms

**PRESERVE:** алгоритм strophes PWA, отдельные metadata, оба cadence markers, antiphon composition и варианты целого psalm block.

- `*` и `†` сохраняются как знаки молитвенного текста; небольшой rubric accent/600, тот же размер. Удалять legacy `<br>` непосредственно после marker, включая закрывающие inline tags, decimal/named entities и `&#x2020;` для dagger. Другие breaks сохранять. Это позволяет естественный mobile wrap, а не уничтожает строфы.
- Разделение paragraph на strophes по оставшимся `<br>` после накопленного `*` перенести с PWA. Нельзя просто заменить все `<br>` пробелом. Metadata не участвует в чётности strophes.
- Alternating indentation в PWA реально существует: `nth-child(even of p[data-psalm-strophe])`, 1rem. Сохранить marker/parity; native indent 12–16 px только при достаточной колонке. На ширине <360 или system scale ≥1.5 — 0. Это presentation adaptation, не утверждение о смене хора. Legacy `margin-left:30px` не должен складываться с native indent.
- Embedded trailing antiphon удаляется **только при отдельной антифоне, которую реально выводит composition**. Snapshot `01-05-dedication-pinsk-cathedral-diocese.officeOfReadingsPs1/2/3` содержит такую копию. В Flutter сейчас она остаётся внутри psalm плюс повторно выводится отдельным `_OraItem.antiphon`.
- `office-for-dead.laudesPs3` — два `data-alternative-title` блока с вложенными `.ora-ant/.ora-psalm` и собственными повторами. PWA специально подавляет внешнюю `ant3`, Flutter `_addPsalmBlockResolved` этого не делает. Сохранить цельный выбранный комплект, его internal role mapping и ровно свои антифоны; не заменять это безусловным stripping.
- PWA caption Benedictus идёт после opening antiphon, перед самой песней; Flutter ставит caption перед opening antiphon. Рекомендуется вернуть caption к песне для ясной привязки, сохранив один heading и исходные слова. То же правило для Magnificat/Nunc.
- Gloria Patri в фиксированных canticles — тот же psalm body/strophe, без панели/нового большого заголовка. Не дописывать или удалять текст ради визуальной симметрии.

# Antiphons

**VISUAL ADAPTATION:** отказаться от заливки, скруглений и постоянной полосы 3px внутри молитвы. У opening — B/600/ink, «Ант.» rubric, ясный интервал. В повторе тот же текст и размер, более спокойное spacing; нет нового заголовка, selector или icon.

Это осознанная адаптация и PWA, и Flutter: PWA `.ora-ant` тоже имеет panel. Не представлять PWA как уже полностью лишённый cards. Gospel antiphon использует ту же текстовую роль; subtitle песни остаётся metadata.

Сохранять shared selection opening/repeated. У repeated нет второго action. В Invitatorium все повторы следуют одному выбору. В Combined Morning не связывать выбор Office ant1 и Laudes ant1 между собой: Flutter сейчас использует одинаковые controller keys `${widget.oraType}-psalmody-ant-0` для обоих наборов. Это source-level риск независимости; Stage 10 должен воспроизвести двумя различающимися наборами вариантов и изолировать ключи по секции, сохранив связь только внутри одной пары. Наличие двух наборов альтернатив в конкретном production Morning здесь не подтверждено.

# Responsories and refrains

**PRESERVE:** отличать Ora versicle/responsory от Mass `psalm.chorus`. `Resp.vue` не создаёт обязательный большой section heading; `Reading.vue` может содержать short reading и responsory вместе. Не разбивать их по слову «К.» на независимые alternatives.

**VISUAL ADAPTATION:** ответ выделяется weight, marker и интервалом, без card. `_ChorusBox` сейчас содержит border 3–4px, radius, shadow, почти непрозрачный fill (`withValues(alpha:.95)` заменяет исходную малую alpha) и label .67–.70B. Убрать эту декорацию, label привести к читаемой metadata/rubric role, body оставить B/600. Opening refrain заметнее интервалом; repeats компактны. Final refrain не новая секция. Не удалять повторные слова, чтобы укоротить экран.

Alleluia Flutter уже показывает как текст с inline «Акламацыя:» — **KEEP FLUTTER**, без возврата PWA card. Источник и сезонная логика не меняются в typography stage.

# Intercessions

**PRESERVE:** `formatIntercessions` после выбора варианта: legacy br → paragraphs; поиск refrain в первых трёх по em либо после двоеточия; intro, refrain, последовательные petition/response, точные refrain repeats и «Ойча наш.» conclusion. Не улучшать эти эвристики произвольно.

Production sample: `02-07-our-lady-budslav.laudesInter`, первый из четырёх вариантов. JS formatter выдаёт intro «Ушаноўваючы…», refrain «Пане, няхай Твая Маці заступаецца за нас.», затем пары «Езу, Сонца справядлівасці…» / «дапамажы нам заўсёды жыць у Тваім святле.». Сохранить такую группировку. Название класса response не лицензия добавлять отсутствующее тире или переписывать вторую половину просьбы.

Native: refrain текстовый, petition/response остаются B и ink; continuation отличается небольшим indent, не сильным осветлением. Реальный leading dash сохранить и окрасить rubric через PWA `.intercessions__marker`; Flutter этот marker pass пока пропускает. `.intercessions__refrain--repeat` использовать только для spacing, не нового selector. Существующий `em` припева не превращать в мелкую инструкцию.

# Prayers

**PRESERVE:** kind=prayer, исходные условия употребления, shared prefix/suffix и formula. «Малітва» — block heading, молитва — B/400. `vesperPr → laudesPr` fallback сохранить. Сокращение «Ойча наш.» не разворачивать автоматически: это existing content convention обоих readers, а не UI placeholder.

`01-05-dedication-pinsk-cathedral-diocese.laudesPr` даёт три варианта; `office-for-dead.laudesPr` содержит explicit titles и условия. Не превращать условия вроде «У касцёле…» в новые категории приложения. Prayerbook entity Holy Mass не участвует в parser Ora prayers.

# Alternatives UX

## Recognition: PRESERVE PWA

Приоритет: gospel-cycle handling для kind `gospel-antiphon` → structured direct-child `data-alternative-title` (минимум 2) с shared prefix и `data-alternative-suffix` → direct `<hr>` → marker boundaries при отсутствии hr. Сохранять substantive dedup, порядок, titles до 56 символов, disambiguation одинаковых titles. `У тыя дні:` не boundary; не расширять category regex за `Пра/За/Для`. Один вариант не создаёт action.

| Реальный kind/case | Evidence | Native interaction |
| --- | --- | --- |
| hymn | `01-06-sv-justin.officeOfReadingsHymn`: 3 options; `office-for-dead` structured hymn сохраняет общий текст | C: action у «Гімн», sheet с полными названиями/первой строкой |
| ordinary antiphon | `Psalms.vue`, отдельные ant fields через generic parser | C у opening antiphon; только при >1; repeat без action |
| Gospel antiphon | Budslav `laudesAntBen`: 7; cycle markers `Год А/В/С` реализованы и покрыты PWA tests | C; текущий год/title вторично. Не вводить новый automatic cycle resolver |
| reading/responsory | Pinsk `sext3R`: 2; Alphonsus `officeOfReadingsR1`: 2 | C у reading label; selector не отделяет responsory от выбранного текста |
| prayer | Pinsk `laudesPr`: 3; `office-for-dead.laudesPr` structured | C с условиями употребления в sheet, без автоподбора |
| intercession | Budslav `laudesInter`: 4, `vesperInter`: 2 | C у «Просьбы»; меняется весь комплект |
| psalm block | `office-for-dead.laudesPs3`: 2 комплекта | C «Псальм… · Варыянт 1 з 2»; менять комплект вместе с antiphons |
| Marian antiphon | `EndOfCompline.vue` / Flutter compAntM, kind `marian-antiphon` | C с узнаваемой первой строкой; реальные collection options не проверены |
| Invitatorium psalm | отдельная `invitatoriums` collection; это не HTML alternatives | C с именем псалма и текущим выбором; сохранить собственный state/default |

## Сравнение interaction

| Вариант | Плюс | Цена | Решение |
| --- | --- | --- | --- |
| A: current full selector block | Все options видны сразу | Высота растёт с count; конкурирует с молитвой, особенно 7 вариантов | REMOVE из постоянного document flow |
| B: inline segmented selector у heading | Быстро для двух коротких названий | Не подходит длинным условиям и 200%; даёт несколько patterns | Не default; возможен позже при доказанном выигрыше |
| C: «Варыянт 1 з 3» → adaptive sheet/popover | Видно наличие; text остаётся главным | Дополнительный tap | **Рекомендуемый default для всех перечисленных kinds** |
| D: tap-cycle по одному варианту | Мало chrome | Нельзя просмотреть список/понять результат заранее | Не использовать |

C: неброская text action, visual text max(.88B,14), touch target ≥48 logical px. Справа от heading только если помещается; иначе следующая строка слева. Для antiphon без отдельного heading — короткая строка перед opening, без искусственного section title. «Варыянт 1 з N» + accessibility label с kind/current title; не tooltip-only и не прятать в общий overflow.

Телефон: существующий adaptive sheet с прокручиваемым списком; широкий viewport может использовать anchored popover. Selected state обозначен текстом/галочкой и semantics. Tap option применяет и закрывает; cancel/back сохраняет выбор. Focus возвращается на action; reader остаётся у начала изменённого блока, не прыгает к началу часа. Не добавлять persistent preference для каждого поля; existing session/reset behavior сохранить. Reduced motion не требует animated height jump.

Не объединять field alternatives с celebration/day/template selector Hours или group/cycle Readings. Никаких новых вариантов на основании похожих абзацев.

# Readings formatting

**PRESERVE PWA field semantics, KEEP FLUTTER reader.** Mass Readings структурированы моделью, а Ora часто legacy HTML. Не прогонять весь Mass document через Ora alternatives parser.

| Часть | Правило Stage 10 |
| --- | --- |
| Першае чытанне / weekday Чытанне | Existing firstReading selection сохранить; label единый block/major style, source text B |
| Reference | Под heading, max(.88B,14), muted/500; exact duplicate cleanup без потери первого предложения |
| comment/title | comment metadata; title вроде вводной формулы — B/600, не красная мелкая инструкция только из-за имени PWA `.reading-rubric` |
| Responsorial Psalm | Existing chorus → verses с repeats → altChorus либо final chorus; role и повторения сохранить, panels убрать |
| Psalm verses | Сохранять structured array boundaries. Не складывать `leftInset:16` нечётного verse с `.psalm-strophe-even` внутри HTML. Один владелец indent |
| Другое чытанне | Только когда field есть; тот же язык reference/body; без placeholder |
| Alleluia/acclamation | Текстовый opening/closing; verse либо text fallback как в PWA; не invent seasonal formula |
| Gospel | Heading/reference/title/body; «Гэта Слова Пана.» один раз при действительном отсутствии в тексте |
| Rubrics | Explicit instruction отделена от произносимой вводной/closing formula; последние остаются body |

Подтверждённые source gaps: PWA acclamation отображает `verse || text`, Flutter `_AlleluiaSection` только `verse`; PWA показывает `altChorus` после verses даже без основного chorus, Flutter заключает весь финальный блок в `if(hasChorus)`. В Stage 10 восстановить эти существующие fallback contracts и покрыть локальными fixtures; частота на production data не установлена. Это migration parity, не новый PWA behavior.

PWA поддерживает dynamic readingN, Flutter model явно reading/reading1/reading2. Без реального additional-reading document не объявлять потерю production чтений подтверждённой и не расширять модель в визуальном этапе; оставить отдельный data-coverage check. Аналогично сезонное hardcoded Alleluia присутствует в обоих renderers: без production case не предлагать здесь новую liturgical policy.

# HTML normalization findings

## DATA

Подтверждённых оснований менять database в Stage 9 нет. Snapshot содержит mixed paragraphs, inline красные markers, legacy `margin-left:30px`, embedded repeats и structured choices: это **существующие формы контента**, а не автоматически испорченные записи. Исправлять renderer parity, не запускать массовую очистку.

Collection gaps ограничивают доказательства для Mass readings/Compline/Invitatorium. Не называть вымышленный fixture production example. Проверку sparse invitatorium, readingN>2 и сезонных acclamations передать отдельному QA; без evidence не превращать в обязательную logic migration.

## NORMALIZATION

| ID | Production/source evidence | PWA → Flutter | Required result |
| --- | --- | --- | --- |
| N1 | `01-01-holy-mary-mother-of-god.sext2Ps2`: «…скажы, Ізраэль, … †<br/>калі б Пан…» | PWA удаляет br после †; Dart probe его оставляет | Parity для literal/decimal/hex/named dagger и asterisk; остальные breaks сохраняются |
| N2 | Pinsk dedication `officeOfReadingsPs1/2/3` заканчиваются `<p>…Ант.…</p>` при отдельных ant fields | PWA `stripEmbeddedAntiphon:Boolean(antiphon)`; Flutter флага нет | Один внешний repeat; embedded copy сохранить, если внешнего источника нет |
| N3 | January `officeOfReadingsR1`: «ПЕРШАЕ ЧЫТАННЕ<br>Пасланне да Габрэяў…» | `Lectio` удаляет legacy label перед structural rendering; Flutter добавляет свой label поверх HTML | Один section heading, source line и reference не потеряны |
| N4 | Budslav intercessions и PWA formatter | Paragraph grouping почти parity; Flutter не создаёт `intercessions__marker` для dash response | Сохранить текст и pairing, перенести marker span без добавления отсутствующих слов/знаков |

Порядок обработки имеет значение: composition определяет владельца heading/antiphon → согласованный PWA preprocessing → alternatives с shared fragments → выбранный HTML → intercession formatting при нужном kind → semantic mapping → native styles. Для psalm parity сверять результат до/после split: PWA `Psalms` подготавливает HTML до `AlternativeText`, Flutter обычно форматирует уже выбранный фрагмент. Не утверждать эквивалентность без structured nested fixture. Нельзя многократно оборачивать markers или изменять boundaries из-за font normalization.

## SEMANTIC DETECTION

**S1 — MUST FIX:** `_markLeadingMetadata` считает любой красный фрагмент признаком metadata. На `01-01-holy-mary-mother-of-god.officeOfReadingsVers` PWA возвращает p без subheading, Dart реально возвращает `<p class="liturgical-subheading">…К.…Н.…</p>`. По стилю Flutter это .84B и muted для произносимого текста. Такой же риск у январских short readings, hymn с красными скобками и antiphons. Перенести PWA проверку **всего видимого styled content**, не `has red anywhere`. Centered caption и лимит двух leading metadata сохранить, ordinary body закрывает leading scan. Greedy fully-wrapped regexp Flutter также не считать эквивалентом PWA без mixed emphasis fixtures.

**S2 — MUST FIX:** `office-for-dead.laudesPs3` уже владеет `.ora-ant/.ora-psalm`; Flutter должен распознать эти роли и не выдавать внешнюю ant3 дополнительно. Две options — псалмы 146 (145) и 150; выбор меняет полный комплект. Не flatten structured HTML в generic body.

**S3 — parity:** PWA `markInlineReadingReference` помечает parenthesized span в mixed reading heading; Flutter такого mapping не имеет. Перенести контекстный scope, не regex «все скобки в тексте — reference». Для existing `.ora-sub`, `.liturgical-rubric`, ending speaker/rubric classes определить native role mapping там, где такой HTML/компонент реально поступает.

## PRESENTATION

**V1:** uppercase + tracking и несколько несвязанных scale rules; **V2:** repeated antiphon panels; **V3:** refrain fill/border/shadow и tiny labels; **V4:** full AlternativeText list; **V5:** неконтролируемые source justify/indent и разный ритм HTML/plain/static rubrics.

Для semantic content контейнеры left-aligned недостаточны, если потомок несёт inline `text-align:justify`. PWA явно переопределяет descendants. Flutter задаёт только body alignment; проверить фактический flutter_html precedence на production fixture и нормализовать только конфликтующие presentation attributes внутри reader. Не удалять centered-caption signal **до** semantic detection. Аналогично source font-size не должен обходить native role scale, а source `em/strong` должен сохранять смысл.

# Secondary menu decision

**REDUCE menu, REMOVE полноценный left Drawer из обычного flow.** Четыре primary branches уже в dock. Маленькая «Меню» action на roots → существующее adaptive secondary sheet с тремя пунктами: **Налады, Сінхранізацыя, Інфармацыя**. На вложенном reader leading остаётся Back; menu не заменяет reader overflow.

Current drawer реально содержит Mass, favorites, My Prayers и dynamic categories, а также Settings/About. Favorites/My Prayers/categories доступны в Prayerbook; повторная IA больше не нужна. Сначала обеспечить Mass shortcut ниже, затем убрать дубли drawer. Существующие routes/deep links и пользовательские categories сохраняются.

«Сінхранізацыя» открывает доступ к существующей sync секции Settings (возможно с anchor), **не начинает sync от простого открытия menu** и не создаёт новый сервис/экран с дублирующим state. После закрытия sheet сохранить branch/scroll/focus.

# Settings decision

| Настройка/часть | После Stage 8 | Решение |
| --- | --- | --- |
| Theme: system/light/dark | Есть | KEEP |
| Text size | Slider 70–180%, shared preference с Aa | KEEP; общий scale и корректный preview |
| Font family customization | Из UI убрана; compatibility constants/keys остались | REMOVE из UI окончательно, не возвращать и не чистить ключи ради review |
| Не гасіць экран | Отдельный switch | KEEP; не связывать с fullscreen |
| Start section / last opened | Реализован | KEEP; не новый navigation model |
| Sync, last sync, progress/error/retry | Реализованы в Settings | KEEP как один функциональный центр; menu shortcut к нему |
| Counts/cache/date coverage/raw diagnostics | Сейчас на основном экране «Статыстыка» | DEBUG: убрать из основного reading preferences, раскрываемая «Дыягностыка» внутри sync; пользовательские status/errors оставить видимыми |
| Categories | Editor код остаётся в settings file, но canonical route уже `/prayers/categories` | KEEP в Prayerbook; **MOVE уже выполнен**. Не удалять class по имени файла |
| About/version | Короткая копия в Settings + `/about` | MOVE полное описание в Information; допустим компактный version/link |
| Global fullscreen preference | Не требуется | REMOVE из предложений, не добавлять |

# Fullscreen decision

**KEEP.** Ora передаёт secondary action «Поўнаэкраннае чытанне»; `ReaderChrome` открывает её через overflow: два taps. Hidden оставляет кнопку `reader-chrome-restore`, tooltip «Вярнуць кіраванне», выход в Compact. Это достаточная модель. Не вводить global fullscreen setting и не менять ownership AppShell. Native hit target/safe area/VoiceOver exit остаются QA, а не повод к redesign.

# Holy Mass pinned shortcut decision

**ADD system-pinned shortcut** на Prayerbook root в порядке:

`Абраныя → Святая Імша → Катэгорыі → Усе малітвы`.

Уже существующая entity: ID `eMmCtxwyJ75ogmL5rwye`, title **«Парадак святой Імшы»**, подтверждена prayer snapshot. Current drawer использует этот же ID. Label shortcut «Святая Імша» открывает existing `/prayers/prayer/eMmCtxwyJ75ogmL5rwye`. Без Mass branch, копии prayer, новой schema и forced favorite.

Одна обычная prominent destination row с небольшим church icon; без hero/card и без высоты, сопоставимой с favorites. Если entity также избрана, favorites не переписывать: это другой пользовательский статус той же молитвы, не duplicate data.

Если prayer отсутствует: сохранить узнаваемую строку и по tap показать компактное состояние «Тэкст пакуль недаступны» с переходом к существующей sync/retry. Не открывать пустой reader и не подменять другой молитвой. Во время загрузки отличать loading от missing. Offline cached prayer открывается нормально.

# Compline functional note

**FUNCTIONAL ISSUE — implementation stage.**

Источник дефекта подтверждён кодом и формой snapshot: `HoraItem.completorium.checkFields = ['compHymn','compAnt1']`; `isHourAvailable` читает их из `LiturgicalDay`. Во всех 743 snapshot fixedDays таких заполненных полей **0**. Ora `_buildForDay` независимо берёт record из `HiveService.completoriumsBox` по `_completoriumId(day)`. PWA `OrasList.vue` добавляет Compline entry, renderer загружает отдельный record через `useCompletorium`.

Следствие: для проверенной формы day Compline availability false даже при потенциально доступном отдельном record. Аналогичная day-field проверка есть в Ora hour navigation. Это подтверждённое несоответствие источников, но live tap и cache пользователя здесь не проверены.

Stage 10: согласовать root/hour-navigation availability с existing Compline source и отдельно показать loading/missing/retry, не redesign resolver и не копировать comp fields в каждый day. Использовать текущие period/day/solemnity rules; не менять date policy. Проверить normal cached, missing cached, после sync, Holy Week alias и Sunday/solemnity IDs существующими fixtures. Полный renderer изучен по source и должен получить те же semantic styles, даже если вход сейчас disabled.

# Implementation specification for Stage 10 Sol

## Must fix before merge

1. **S1 — mixed text shrinking.** `liturgical_html.dart`: PWA-equivalent leading detection; красная буква/скобка/heading внутри body не уменьшает весь p. Regression: January Vers, short reading с heading+body, fully styled metadata, centered later caption, mixed em/body.
2. **N1/N2/N3 + S2 — content parity.** Оба cadence markers/entities; conditional embedded-repeat stripping; Office labels ровно один раз; structured `office-for-dead` psalm alternatives со своими antiphons. Files: HTML utility, Ora composition, role style mapping. Сверить не только число options, но весь видимый текст, порядок, shared suffix и repeats.
3. **Compline functional mismatch.** Исправить availability у обоих callers по existing source, покрыть cached/missing states. Без новой date/resolver architecture.
4. **Readings fallback parity.** `verse || text`, altChorus при отсутствии chorus; regression fixtures с явной пометкой synthetic. Не менять default reading resolver. Дополнительно проверить HTML closing/acclamation: не разрезать теги и не дублировать формулу.
5. **DO NOT REGRESS gates.** Alternative selection остаётся связанной только внутри соответствующего блока; Morning Office/Laudes независимы. Нет потери текста/вариантов после normalization. Scale 200% не обрезает body/actions; существующая shell/route/state regression suite проходит.

## Recommended final polish

1. Ввести reusable native roles по матрице в ReaderTheme/HTML styles; Ora и Readings используют общий vocabulary. Explicit static rubric roles; перенос inline reference/dash mapping; source alignment/indent под контролем после detection.
2. Антифоны и refrains оформить как текст, repeats тише; убрать фон/radius/shadow/полосы из `_OraItem.antiphon` и `_ChorusBox`. Не терять повторения ради компактности.
3. AlternativeText C: компактный action → adaptive selector; применить также Invitatorium picker без объединения разных state. Existing parser и controllers сохранить.
4. Уменьшить Drawer до secondary menu, перенести Mass entry на Prayerbook root, оставить categories/My Prayers canonical paths. Settings очистить только по таблице, не возвращать font UI.
5. Caption привязать к canticle, mobile indentation адаптировать к ширине/scale; plain/HTML молитвы сравнить рядом. Focus entry/exit оставить.

Это согласованное направление финального Sol этапа, а не набор необязательных конкурирующих redesign-вариантов. Отдельная документация scope нужна только при новых доказанных functional/data defects.

## Optional future improvements

**Новых POSSIBLE LOGIC IMPROVEMENT для PWA в этом review не утверждено.** Нет предложения менять intercession heuristics, считать каждый red/em fragment отдельной ролью, автоматически выбирать prayer/cycle или преобразовывать altChorus в новый selector. Текущая задача — fidelity + presentation.

После получения реальных дополнительных records можно отдельно исследовать sparse Invitatorium, readingN>2 и seasonal acclamation. Чтобы рекомендовать изменение PWA behavior, для каждого нужны: production ID/field, текущий PWA output, проблема, конкретный новый output, риск и отдельный scope. До этого это coverage questions, не must-fix database migration.

## Проверка реализации и передача

- Local corpus fixtures: January Mother of God (все Ora field families), Pinsk dedication (embedded antiphons, R labels, prayer и short-reading variants), Budslav (4 intercession/7 Gospel-antiphon alternatives), office-for-dead (structured psalm/hymn/prayer/shared text).
- PWA JS output служит oracle для boundaries/text/roles; Flutter comparison не обязан выдавать те же CSS classes. Проверять visible text order и semantic role отдельно от spacing.
- Native visual: iOS/Android × Light/Dark × widths 320/390; system 100/150/200%, Aa 100/130/180 и короткий check Aa70. Для каждого из девяти часов — opening, long psalm, repeat, ending; Compline после functional fix. Для Readings — weekday и two-reading set, raw и structured psalm, reference, acclamation, Gospel.
- Focus/selection: 2 taps fullscreen, заметный exit; C selector cancel/apply/focus return, длинные titles, 7 options, linked repeats; переключение branches и Ora → Readings → Back сохраняет контекст. HTML и plain text реально увеличиваются при system scale.
- Functional tests на исправленные defects, затем analyzer/full tests и существующие platform builds по Stage 8. Не считать web build подтверждением native gesture/VoiceOver/material.
- В implementation report явно разделить подтверждённые device checks и оставшиеся gaps. Этот Stage 9 не даёт безусловный native visual PASS.

**Остановка Stage 9:** подготовлена только спецификация; production implementation и commits не выполнялись.

# Stage 10 implementation resolution

Дата реализации: 2026-09-10. Ветка: `feature/mobile-ux-migration`.

## Must Fix

| Пункт | Статус | Resolution |
| --- | --- | --- |
| S1 mixed red paragraph | FIXED | Leading metadata определяется по всему видимому styled content; inline `К./Н./С.` больше не уменьшает произносимый абзац. |
| N1 cadence markers | FIXED | Literal/named/decimal/hex `*` и `†` нормализуются; удаляется только legacy break сразу после marker. |
| N2 embedded antiphon | FIXED | Trailing copy удаляется только при точном известном external antiphon; без внешнего контекста сохраняется. |
| N3 duplicate R1/R2 heading | FIXED | Legacy structural label снимается до native label без удаления source/reference/body. |
| S2 structured psalm alternatives | FIXED | `.ora-ant/.ora-psalm` package остаётся цельным; внешний antiphon для такого package подавляется. |
| N4 intercession marker | FIXED | Сохранена grouping semantics, leading dash получает отдельную inline role без изменения текста. |
| S3 inline reading reference | FIXED | Parenthesized reference размечается только внутри known reading heading context. |
| Readings fallbacks | FIXED | Acclamation использует `verse || text`; lone `altChorus` остаётся видимым. |
| Closing/acclamation | FIXED | HTML не разрезается при поиске closing formula; fallback не добавляется при формуле в visible HTML. |
| Compline availability | FIXED | Hours root, compatibility picker и Ora sheet используют один adapter поверх `completoriumId` и отдельного Hive cache. Direct reader различает загрузку и missing content. |

## Recommended final polish

| Пункт | Статус | Resolution |
| --- | --- | --- |
| Native semantic roles | FIXED | ReaderTheme получил reusable major/block/metadata/rubric roles и readable minima для Aa 70%. |
| Headings/rubrics | FIXED | Управляемые headings спокойного регистра; inline rubric не меняет body size. |
| Psalms/antiphons/refrains/intercessions/prayer | FIXED | Card decoration убрана; hierarchy строится typography, spacing, weight и rubric markers. |
| Source presentation normalization | FIXED | Legacy justify/margin-left/font-size снимаются после semantic detection; emphasis/content сохраняются. |
| Alternatives UX | FIXED | Compact `Варыянт X з N` trigger открывает scrollable adaptive sheet; shared controllers и local selection сохранены. |
| Combined Morning controller isolation | FIXED | Controller keys включают section scope, поэтому Office/Laudes psalmody не связываются случайно. |
| Secondary menu | FIXED | Full Drawer удалён из ordinary AppShell flow; roots используют menu/sheet только с Settings, Sync и Information. |
| Settings | FIXED | Sync остаётся единым center; diagnostics свёрнуты, about сокращён до version/link. |
| Holy Mass shortcut | FIXED | Системная строка использует entity `eMmCtxwyJ75ogmL5rwye`, поддерживает available/loading/missing и sync action. |
| Fullscreen | NOT APPLICABLE | Existing reader overflow → Hidden → restore сохранён без концептуальных изменений. |
| Native accessibility/device comparison | DEFERRED DEVICE QA | Требуются реальные iOS/Android Light/Dark, VoiceOver/TalkBack, safe-area и gesture checks. |

## Verification resolution

- `dart analyze`: PASS, 0 issues.
- `flutter analyze`: PASS, 0 issues.
- `flutter test`: PASS, 129 tests.
- Android-defined web build: PASS.
- iOS-defined web build: PASS.
- Native device verification: DEFERRED DEVICE QA; web builds не считаются device evidence.

Implementation status: **ready for final native/device QA and final diff review**. Merge в `main` не выполнялся.
