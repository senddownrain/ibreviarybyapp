# Flutter: план передачи сезонных вариантов, `_mainSection` и выбора чтений (D-1)

Состояние на 2026-10-24, `main` = 2164345. **Это план, код не менялся, Flutter не выпускался и не собирался.** Источники: WEB `docs/common-seasons-flutter-handoff.md`, фикстура `reports/liturgy/common-seasons-flutter-fixture.json` (schema 1: 5400 cases, 11 assembly, 48 calendar), WEB PR [mybrev#164](https://github.com/senddownrain/mybrev/pull/164) (D-1).

## 1. Что уже есть в `main` (проверено чтением кода и бандла)

| Часть | Где | Статус |
|---|---|---|
| Сезон Office → ключ варианта (`holyweek`: только `palm-sunday` и `holy-week` → `lent`) | `lib/utils/common_seasons.dart` `commonSeasonVariant` | есть, совпадает с WEB `variantKeyForSeason` |
| `materializeCommonForSeason` (строка/массив, `null` → `omit`, `{rule}`, неизвестное поле пропускается, исходник не мутируется) | там же | есть |
| Сезон применяется только к Common, материализация на каждую сборку | `lib/utils/office_assembly.dart:387-392` | есть |
| `_mainSection` (D-2): основная секция вместо слитого поля, кроме `saturday-blessed-virgin-mary` и сезонных полей | `office_assembly.dart:470-480` | есть, логика равна WEB `fromTemplate` |
| `assembly.season` в результате | `office_assembly.dart:744` | есть |
| Данные в офлайн-бандле | `assets/content/liturgicalTemplates.json.gz` | 16 шаблонов, **814** сезонных полей (advent 118/christmas 118/lent 144/easter 434), `_mainSection` у `blessed-virgin-mary`: совпадает с цифрами WEB |
| Вид `office-reading` для R1/R2 Часа чтений | `ora_screen.dart:1203-1206`, `1919-1970` | есть как вид отображения; **разбор вариантов для него отсутствует** (см. §2.3) |

Вывод: передача сезонных вариантов и `_mainSection` в коде и бандле **уже сделана**. Для публикации нужна только проверка и релиз (§4).

## 2. Что не сделано

### 2.1 Нет теста на фикстуру 5400/11/48
`test/common_office_test.dart` использует свою `test/fixtures/common_office_parity.json` (`webCommit` 0612d53, до #141). Фикстура `common-seasons-flutter-fixture.json` в Flutter не подключена: grep по `valueSha256`/`5400` пусто. Нужно:
1. Скопировать фикстуру в `test/fixtures/` (с указанием WEB-коммита) и добавить `test/common_seasons_parity_test.dart`: (a) `cases`: `materializeCommonForSeason(template, season)[field]` → `sha256(utf8)` (массив — элементы через `\u0000`), `length`, `variant`, `source`; (b) `calendar`: `commonSeasonVariant(computeSeason(date))` для 48 дат; (c) `assembly`: 11 случаев через `assembleOffice` (свой Proper побеждает, «З дня», `church-dedication` Lent/Easter, `blessed-virgin-mary` Advent/Christmas, `memorial pastors easter`).
2. Шаблоны брать из бандла (`HiveService.templates()`), а не из фикстуры: так проверяется и бандл.
3. Сверить `templatesRevision` (3) и digest (`fd4b4f8eac9c9902` в `common_office_test.dart`) с текущим WEB (`reports/liturgy/common-seasons-import-plan.json`); если бандл старше данных WEB — обновить через `scripts/refresh_common_bundle.mjs` (отдельное разрешение на чтение источника; Firestore не читать без разрешения).
4. Регрессии из WEB §5.6: ни одно поле дня не содержит два сезонных текста, нет «(Велікодны перыяд» / «У Вялікі пост:».

### 2.2 Негативные/пограничные тесты D-2
Тесты на `_mainSection` в Flutter есть в `common_office_test.dart` (Marian section). Добавить из WEB `tests/common-seasons-saturday.test.mjs` (6 случаев): свободная суббота Звычайнага перыяду — полное поле; праздник/обязательная память Марыі — `_mainSection`; сезонное поле сезонного варианта `_mainSection` не перекрывает.

### 2.3 D-1: выбор чтений (порт WEB #164)
В Flutter `getLiturgicalAlternatives(kind: 'office-reading')` (`lib/utils/liturgical_alternatives.dart`) использует названия только для `kind == 'reading'` (`_optionTitle`, строка ~365) и не знает про отсылку. Поэтому у `holy-women` R1/R2 будет то же, что было в WEB до #164: вкладка «Варыянт 1» с отсылкой, склеенные чтения R1, названия «Варыянт N». План порта (по WEB `src/utils/liturgicalAlternatives.js`):
1. Границы выбора для `office-reading`: «Або іншае, пра …:» и «Іншае, пра …:» (`READING_QUALIFIED_MARKER`), абзац «Выбіраюцца найбольш адпаведныя …» (`READING_REFERENCE`) как отдельная группа.
2. Флаг `reference` у варианта, `getReadingChoices(html) → (notes, options)`; без вариантов кроме отсылки — отсылка остаётся единственным текстом.
3. Заголовки: книга + стих (пробел между «Прыпавесцяў» и «31»), «Першае пасланне» + «св. апостала Пятра …» в одну строку, произведение + автор для отцов Церкви; лимит 84 символа для office-reading.
4. `lib/widgets/alternative_text.dart`: заметка (Semantics `liveRegion` не нужен, обычный блок) над переключателем; без переключателя при одном варианте; клавиатурная навигация не требуется на мобильных.
5. Запоминание выбора: ключ «поле + дата + id варианта Часа», хранение в памяти сессии (Riverpod/StatefulWidget-контроллер, как `alternativeController`), сброс при смене дня/периода/Proper↔Common. Не хранить в Hive.
6. Тесты: Dart-эквивалент `tests/reading-choices.test.mjs` (10 случаев) на тех же текстах из бандла: holy-women R2 по четырём сезонам (заметка + Хрызастом/Аўгустын; Пія XII нет), R2 обычное время (заметка + один вариант без пикера), R1 (две женские чтения), «слова не теряются».
7. Виджет-тест 320 px и масштаб текста 1.8 (как в WEB).

### 2.4 Данные, которых нет и в WEB
Чтения `holy-men` не добавлены в `holy-women` R1 (все сезоны) и в R1/R2 тома III, хотя отсылка на них указывает (см. WEB `reports/liturgy/d1-reading-choices.md`, «Что осталось», п. 1). Решение владельца; затем изменение данных, WEB-публикация и обновление бандла Flutter.

## 3. Порядок работ (каждый шаг — отдельный PR, без выпуска)

| № | PR | Содержание | Зависит |
|---|---|---|---|
| F1 | тесты | §2.1–2.2: фикстура 5400/11/48 + D-2, без изменения `lib/` (если падают — отчёт, не правка текстов) | — |
| F2 | порт D-1 | §2.3, после слияния WEB #164 | WEB #164 |
| F3 | бандл | обновление `liturgicalTemplates` только если F1 покажет расхождение с WEB | F1, разрешение владельца |
| F4 | выпуск | приёмка, сборка, Google Play `alpha`, TestFlight (`docs/RELEASE_BETA.md`) | F1–F3, **явное разрешение**, не входит в эти PR |

## 4. Публикация контента (не в этих PR, только с разрешением владельца)

Отдельная адресная публикация коллекций `liturgicalProperTexts` и `liturgicalCalendarMeta` в `contentManifest` после выпуска совместимого приложения (`docs/app-content-distribution.md` в WEB). Сначала read-only проверка актуального production-манифеста; повторный импорт 13 Common не нужен. Порядок и условия SAFE CONTENT PATCH — по WEB `AGENTS.md`.

## 5. Риски и оговорки

- Документ WEB `docs/common-seasons-flutter-handoff.md` устарел по цифрам (530 полей; сейчас 814) и по числу tests; источник истины — фикстура.
- Тема в WEB-фикстуре `holyweek` без фазы → `null`; в Dart `computeSeason` обязан отдавать `periodPhase`: F1 это проверит по 48 датам.
- Не выполнялось: `flutter analyze`/`flutter test` (план, кода нет); Flutter 3.41.4 лежит в scratchpad главной сессии, системный 3.38.9 слишком старый.
