# Ordo / Hours во Flutter: перенос web-архитектуры MyBrev

> Октябрь 2026. План — `docs/ordo-flutter-port-plan.md`. Источник истины по
> логике — web MyBrev (`src/utils/ordo/*`, `ordoDayOptions.js`,
> `daysResult.js`, `officeAssembly.js`). Отчёты — `reports/flutter-*.json`.

## Архитектура

```text
assets/content (bundle) ⊕ Hive overlay  →  ContentStore (атомарные поколения)
        │
        ├─ liturgicalCelebrations / DioceseOverrides / YearOverrides / CalendarMeta
        │      → OrdoRuntime.engine (пересобирается при изменении коллекций)
        │      → OrdoEngine.resolve(date, diocese) → OrdoDay
        │            season · candidates · layers · year overrides · transfers
        │            · precedence · PRIMARY / ALTERNATIVES / COMMEMORATIONS /
        │            SUPPRESSED · Office и Readings descriptors
        │
        ├─ days (temporal) · liturgicalProperTexts (Proper) · liturgicalTemplates
        │      → LiturgicalContentService.contentForDate(date, diocese)
        │            карточки = только законные опции движка; сборка Office
        │            по дескриптору (current-day, sunday-week-1,
        │            complementary-psalmody, template/common, ref, omit)
        │
        ├─ readings → ReadingReferenceIndex (проекция в памяти) → ссылки в Ordo,
        │             порядок чтений выбранной опции на экране Чытанні
        └─ liturgicalOrdoNotes (lazy) → нататкі дня в Ordo
```

Модули `lib/ordo/` — по одному на web-модуль: `dates`, `movable_feasts`,
`season`, `definitions` (+ слои), `year_plan` (year overrides, transfers),
`precedence`, `candidates`, `display`, `office`, `readings_plan`, `notes`,
`engine` (index + runtime), `runtime` (движок из контента), `day_union`,
`reading_references`, `ordo_picker`. Внутри кандидаты — `Map` (та же
семантика spread, что в JS), наружу — `OrdoDay` / `OrdoOption`.
Сортировки стабильные (`stableSort`), как `Array.prototype.sort`.

Независимого второго алгоритма приоритета больше нет:
`_celebrationPriority`, `obligatoryMemorialOutranksDay`, эвристическая
сортировка `days` удалены; `calculateDateForContext` и
`computeLiturgicalContext` остаются только для легаси-путей Readings
(контекст периода совпадает с движком — проверено parity).

## Parity web ↔ Flutter

Генератор (MyBrev, read-only): `npm run ordo:flutter-fixture -- --snapshot
backups/firestore-snapshot --out ../ibreviarybyapp/test/fixtures/ordo_parity.json.gz`
— web-движок, web-сборка Гадзін и web reading references на том же snapshot,
из которого собран бандл. 2025–2032 × 4 дыяцэзіі = **11 688 дней**.

| Тест | Что сверяется | Расхождений |
|---|---|---|
| `test/ordo_parity_test.dart` | period, phase, week, day, psalter week, цыклы, колер (+альтэрнатывы), primary/alternatives (id, kind, rank, rankKind, color, officeKind, precedence, category, dioceseId, transfers), commemorations, suppressed (+reason), transfers, вечар (I/II Vespers, Compline), Te Deum / Compline / Vespers для кожнай опцыі, Ordo notes | 0 |
| `test/hours_parity_test.dart` | карткі Гадзін (key, option, source, properSource, missingProper), зборкі (id, label, choice, integrity) і хэш тэксту Office кожнай зборкі (27 432) | 0 |
| `test/reading_references_parity_test.dart` | статус і дакументы чытанняў кожнай опцыі | 0 |

Наўмысных адрозненняў няма (`kIntentionalDifferences` пусты). Адзінае
прыбліжэнне: `localeCompare(…, 'be')` для назваў раўназначных
дэмотаваных успамінаў замешчана беларускім алфавітным парадкам
(`compareBelarusian`); на фікстуры адрозненняў не дае.

## Калекцыі і бандл

Новыя ў `kContentCollections` = MyBrev `APP_CONTENT_COLLECTIONS`:
`liturgicalCalendarMeta`, `liturgicalCelebrations`,
`liturgicalDioceseOverrides`, `liturgicalYearOverrides`,
`liturgicalProperTexts`, `liturgicalOrdoNotes`. `yearOptions` не вяртаецца.

| Калекцыя | Дакументаў | stored | у бандле (gzip) | дэкод (хост) |
|---|---:|---:|---:|---:|
| liturgicalCalendarMeta | 1 | <1 КБ | <1 КБ | 0.02 мс |
| liturgicalCelebrations | 241 | 133 КБ | 22 КБ | 1.9 мс |
| liturgicalDioceseOverrides | 74 | 52 КБ | 9 КБ | 0.7 мс |
| liturgicalYearOverrides | 4 | 1 КБ | <1 КБ | 0.04 мс |
| liturgicalProperTexts | 290 | 3.0 МБ | 0.56 МБ | 17.6 мс |
| liturgicalOrdoNotes | 1 204 | 0.64 МБ | 0.09 МБ | 8.0 мс |
| **Ordo разам** | 1 814 | 3.9 МБ | **0.70 МБ** | 28 мс |

- `assets/content` (сума файлаў калекцый): 3 814 670 → **4 530 127 Б** (+0.72 МБ).
- APK arm64-v8a release (той жа машына, main 33945b4 → гэтая галіна):
  32 032 193 → **33 077 224 Б (+1.05 МБ)**: +0.70 МБ ассеты, ~0.35 МБ код.
- iOS-зборка не рабілася (подпіс заняты іншым заданнем).
- Дэкод літургічнага ядра (days, readings, templates, invitatoriums,
  completoriums + каляндар + Proper): ~130 мс на хосце (было 145–150 мс у
  `data-loading-architecture.md` без Ordo; розніца ў шуме вымярэння);
  усё — ~143 мс. Notes дэкадуюцца лена: толькі калі адкрыты Ordo.
- Рухавік: пабудова 5 мс; першы дзень 16 мс; увесь 2027 год 27 мс;
  першы змест Гадзін дня 22 мс, той жа дзень зноў 6 мс; notes дня 4 мс.
- Hive па-ранейшаму 0 байт кантэнту пасля ўсталёўкі: Ordo-калекцыі — у
  бандле. Retained heap асобна не вымяраўся (Proper-тэксты падзяляюць радкі
  праз табліцу радкоў; ~+3.9 МБ JSON-аб'ектаў у горшым выпадку).
- Першы кадр на прыладзе не мяраўся (няма прылады ў гэтым асяроддзі).

## Абнаўленні кантэнту (атамарна)

Каляндар, Proper і notes адной публікацыі актывуюцца адным
`ContentStore.commit`; `OrdoRuntime` бачыць новыя азначэнні толькі пасля
пераключэння ўсіх калекцый. `test/ordo_content_update_test.dart`: колер
святкавання + яго Proper — або абодва новыя, або абодва старыя, у тым ліку
пасля збою на кожнай фазе і перазапуску.

## Парадак выпуску (маніфест)

Стары кліент бярэ з маніфеста толькі калекцыі са свайго спісу, таму:

```text
1. snapshot → content:app-release → assets/content (ужо зроблена ў гэтай галіне)
   сверка: «NEW IN THIS RELEASE …» — папярэджанне, не памылка
2. рэліз Flutter з гэтым бандлам
3. пасля рэлізу: npm run content:manifest → вердыкт NEW COLLECTIONS
   npm run content:manifest -- --apply --introduce-collections
4. далей — звычайныя SAFE CONTENT PATCH
```

Маніфест у гэтай задачы **не публікаваўся**, Firestore не змяняўся.

## Fallback і дэфіцыты

- `liturgicalProperTexts` — канон; legacy фіксаваныя `days` — толькі
  fallback з аўдытам `properSource`. На 2025–2032 × 4 дыяцэзіі
  **0 залежнасцей** ад legacy days → fallback можна лічыць transition-only.
  Legacy-дакументы ў Firestore не выдаляліся.
- Sparse Proper: `complementary-psalmody` без шаблона — integrity error
  (`_integrityErrors`, поле пустое), ніколі не «з дня»; 0 такіх на бандле.
- Без уласнага дакумента (scaffold, `missingProper`): `mary-mother-church`,
  `saturday-blessed-virgin-mary` — Office збіраецца з Common/дня.
- Office недаступны: `temporal:lent-w5-d1` (няма дакумента `lent-w5-d1` у
  `days`) — дзень бачны ў Ordo і Гадзінах як «няма тэкстаў».
- Чытанні reference-only: `dedication-cathedral`, `sv-maximilian-kolbe`;
  missing: `our-lady-budslav`, `our-lady-lahishyn`, `our-lady-trakai`
  («Тэкст / спасылкі пакуль недаступныя»). Тэксты не выдумваліся.
- Падрабязна: `reports/flutter-liturgy-runtime.json`.

## Налады: некалькі дыяцэзій

Налады → «Літургічны каляндар»: Мінска-Магілёўская (па змаўчанні, як web),
Гродзенская, Пінская, Віцебская; мінімум адна (апошнюю зняць нельга).
`primary` кіруецца аўтаматычна: першая выбраная; можна зрабіць асноўнай
зорачкай, калі выбрана некалькі. Міграцыя: ключы `diocese`,
`selectedDiocese`, `liturgicalDiocese` → `liturgicalDioceses`.

Рухавік — адна дыяцэзія за выклік; Гадзіны аб'ядноўваюць
(`unionDayOptions`): агульнае — адна картка, частковае — бэйджы
«Мінск/Гродна/Пінск/Віцебск», тое ж святкаванне з іншым рангам — асобна.
Выбар картачкі памятае сваю дыяцэзію (`HoursChoice`), маршруты нясуць
`?diocese=` — налады не мяняюцца.

## Маршруты

`/hours/hora/:date/:dayId` і `/hours/ora/:date/:dayId/:type` — як раней
(старыя спасылкі, у т.л. `/ora/…`, `/hora/…`, ідэнтыфікатары
`<id>--<template>` і `<id>--day`, працуюць); `?diocese=` і `?option=` —
кантэкст. `/readings?date&dayId&option&diocese`. Новы `/hours/ordo?date=`.

## Ordo UI

- Уваход: круглая кнопка `calendarDots` (48 pt) у верхняй панэлі справа,
  сіметрычная меню. Адкрывае выбраны дзень (`HoraPickerScreen`), а з яго
  `listChecks` / «Падрабязны Ordo гэтага дня» адкрывае Ordo даты.
- `OrdoScreen` — асобная дэталь дня: hero з датай, перыядам, псалтыром,
  цыклам і колерам; карткі святкаванняў, Імшы/чытанняў, Гадзін, указанняў
  і заўваг. Дзённыя літургічныя ўказанні адкрытыя, іншыя групы і агульныя
  ўказанні перыяду згорнутыя. Святкаванні, якія саступаюць месца, таксама згорнутыя.
- `OrdoMonthScreen` (`/hours/ordo/month?date=`) адкрываецца спасылкай
  «увесь каляндар» унізе дня; націск даты адкрывае Ordo гэтай даты,
  Back вяртае месяц з захаваным курсорам. Экран дня і абодва Ordo экраны
  маюць `showsNavigationDock: false` і ўлічваюць system/home-indicator inset.
- `LiturgicalMonthCalendar` — адзіная каляровая сетка для месяца Ordo
  і `showAmbientDatePicker` на Android/iOS. Выбар у modal адразу вяртае
  дату ў `liturgicalNavigationController.openDate()`. Колеры (уключаючы
  альтэрнатывы), святкаванні і дыяцэзіі чытаюцца з `OrdoRuntime.engine`.
- Выбар Office аддзелены ад выбару святкавання: `hasOfficeTemplates`
  і `hasCelebrationAlternatives` разам утвараюць `hasLiturgicalChoices`.
  07.10.2026, `our-lady-rosary`: «З дня» па змаўчанні і
  «Пра Найсвяцейшую Панну Марыю» (`blessed-virgin-mary`). Абодва
  адкрываюцца ў Гадзінах і Ora; чытанні належаць святкаванню, абодва
  варыянты захоўваюць weekday-first план Ordo. Маршруты нясуць date,
  dayId, option і diocese, не мяняючы асноўную дыяцэзію Налад.
- Рэгрэсіі: `test/ordo_day_flow_test.dart` (рухавік, UI выбару, Ora,
  месяца/Back, чытанні, date picker, згорнутыя заўвагі, вузкі экран і вялікі тэкст).
- Адзін рэзолвер колеру `lib/utils/liturgical_visual.dart`: albus, ruber,
  viridis, violaceus, rosaceus, niger; марыйны блакітны — толькі акцэнт
  марыйнага белага свята. Дакументы Гадзін маюць штамп `_vestmentColor`,
  `liturgicalColorForDay` бярэ яго першым (эўрыстыкі — толькі для старых
  дакументаў без Ordo).
- Мэты дат ≥ 44 pt; калі шырыні недастаткова для 7 клетак, сетка
  мае невялікую гарызантальную пракрутку. Тэкст маштабуецца без overflow.

## Picker

- «Святы»: усе святкаванні абранага года з рухавіка для выбраных дыяцэзій,
  на канчатковых датах (пераносы, year overrides), з колерам, рангам і
  бэйджамі; адкрываюць менавіта гэтую опцыю. Без `HiveService.daysBox`.
- Год: «‹ 2027 ›» + сетка гадоў у лікавым парадку, абраны год заўсёды ёсць і
  падсвечаны, 2027 — адзін дотык.
- «Перыяды»: пазіцыі года, знойдзеныя рухавіком (толькі існуючыя тыдні і
  дні), колер перыяду і рэальныя колеры дзён.

## Тэсты

`ordo_parity_test`, `hours_parity_test`, `reading_references_parity_test`,
`hours_regression_test` (Анёлы-Ахоўнікі, Бруна, All Souls, свята — Ютрань
нядзелі I, урачыстасць — комплементарная псалмодыя / integrity, 17–24.12,
25.12–12.01, Вялікі тыдзень, актава Пасхі), `diocese_settings_test`,
`diocese_settings_section_test`, `ordo_screen_test`, `ordo_picker_test`,
`route_identity_test`, `ordo_visual_test`, `ordo_content_update_test`,
`liturgy_runtime_report_test`. Справаздачы:
`ORDO_PARITY_REPORT=1`, `HOURS_PARITY_REPORT=1`, `ORDO_RUNTIME_REPORT=1`.

### Завяршэнне UI-пераносу (07.10.2026)

Змененыя файлы:

- Экраны: `lib/screens/home_screen.dart`, `lib/screens/hora_picker_screen.dart`,
  `lib/screens/ordo_screen.dart`.
- Навігацыя: `lib/router/router.dart`, `lib/widgets/app_shell.dart`.
- Каляндар і выбар даты: `lib/widgets/ordo/liturgical_month_calendar.dart`,
  `lib/widgets/ambient_date_picker.dart`.
- Даныя і выбар Office: `lib/providers/ordo_provider.dart`,
  `lib/utils/hours_liturgical_options.dart`.
- Тэсты: `test/ordo_day_flow_test.dart`, `test/hours_root_test.dart`,
  `test/ordo_screen_test.dart`, `test/ordo_visual_test.dart`,
  `test/platform_design_test.dart`.
- Дакументацыя: `docs/ordo-flutter-port.md`.

На Flutter 3.38.9: `flutter analyze` — без заўваг;
`flutter test --concurrency=2 --timeout=2m --reporter expanded` — усе 635 тэстаў
прайшлі, уключаючы ORDO/Hours/readings parity, route identity, office assembly
і Hours regression. Новы файл дадае 19 рэгрэсійных тэстаў.
