# Ordo / Hours: план переноса web-архитектуры во Flutter

> Октябрь 2026. Источник истины — web MyBrev (`src/utils/ordo/*`,
> `ordoDayOptions.js`, `daysResult.js`, `officeAssembly.js`). Итог работы —
> `docs/ordo-flutter-port.md`.

## Что Flutter уже умеет

- **Контент «офлайн с установки»**: `assets/content/<collection>.json.gz` +
  Hive-overlay (`ContentStore`, атомарный `commit`, восстановление после
  сбоя), обновления по манифесту версий (`ContentUpdater`).
- **Вычисляемый календарь**: `computeYearOptions`, `CalendarService`,
  `computeLiturgicalContext` (период/неделя/день, Пасха, подвижные праздники).
- **Sparse Proper** частично: `office_assembly.dart` — порт `officeAssembly.js`
  (slots, `_fieldRules`, `sunday-week-1`, выбор «З дня» ↔ Common), parity с web
  на фикстуре.
- **Hours root** нового мобильного вида (AmbientWash, «Іншыя літургічныя
  варыянты», выбор шаблона), Hora picker, Ora, Readings, picker
  `/hours/picker`.

## Что сейчас legacy

| Где | Что | Чем заменить |
|---|---|---|
| `LiturgicalContentService.getContentForDate` | варианты дня = все документы `days` на дату + сортировка по рангу-строке (`_celebrationPriority`, `obligatoryMemorialOutranksDay`) | порт `buildOrdoDayOptions`: карточки только из PRIMARY + LEGAL ALTERNATIVES движка |
| fixed feasts | только из `days` (`_date`), sparse — только если лежит в `days` | `liturgicalProperTexts` (канон), `days` — аудируемый fallback |
| `office_assembly.dart` | office kind из `_rank` документа; `complementary` молча падает на день | office kind и слоты — из дескриптора движка; `complementary` без шаблона — integrity error |
| `liturgical_theme.dart` | цвет по эвристикам названия («мучан», «апостал»…) | один резолвер по vestment colour движка |
| `LiturgicalPickerScreen` | «Святы» из `HiveService.daysBox` (`_loadFixedFeasts`), годы `2030…2019` по убыванию, `calculateDateForContext` | список года из движка (переносы, дыяцэзіі), числовой выбор года, позиции — движком |
| диоцез | нет вообще | Settings «Літургічны каляндар», несколько дыяцэзій |

## Что портируется почти 1:1

`dates`, `movableFeasts`, `season`, `definitions`+`layers`, `yearOverrides`,
`transfers`, `yearPlan`, `candidates`, `precedence`, `display`, `office`,
`readings` (descriptors), `notes`, `index`/`runtime` (`optionDescriptor`,
`planReadings`), `dayOptionsUnion`, `ordoDatePicker.ordoDateForPosition`,
`liturgicalVisual`. Структура: `lib/ordo/*.dart` (по файлу на web-модуль),
внутренние кандидаты — `Map` (та же семантика spread), наружу — типизированные
`OrdoDay` / `OrdoOption`.

Данные: `liturgicalCelebrations`, `liturgicalDioceseOverrides`,
`liturgicalYearOverrides`, `liturgicalCalendarMeta`, `liturgicalProperTexts`,
`liturgicalOrdoNotes` добавляются в bundle-контракт (Node
`APP_CONTENT_COLLECTIONS` = Dart `kContentCollections`). `yearOptions` не
возвращается.

## Mobile-specific решения

- Вход в Ordo: заметная капсула «Каляндар» в правом верхнем углу заголовка
  «Літургія гадзін» (не на Чытаннях).
- Ordo: один экран — месяц (точки/сегменты реальных цветов) + раскрывающаяся
  карточка дня под сеткой; из дня — в Гадзіны / Чытанні.
- Несколько дыяцэзій: движок решает одну за вызов, объединение — в
  презентационном слое (бейджи «Мінск/Гродна/Пінск/Віцебск»).
- Notes (1204 шт.) декодируются после ядра Гадзін (lazy).
- Reading references — проекция корпуса `readings` в памяти (без новой
  коллекции).

## Порядок миграции

1. A: контракт контента (MyBrev + Dart списки), бандл, parity-фикстура.
2. B: движок `lib/ordo`, parity-тест (точное совпадение).
3. C: Hours на движке: Proper из `liturgicalProperTexts`, fallback `days`
   с аудитом, дескрипторы в assembler, регрессии (Анёлы-Ахоўнікі, Бруна, All
   Souls, Адвэнт 17–24, Каляды, Вялікі тыдзень, актава Пасхі).
4. D: Settings + union + route context.
5. E: Ordo UI, F: picker, G: Readings identity, H: визуальный проход, I:
   замеры, отчёты.

## Риски

- Публикация манифеста с новыми коллекциями до релиза: старые клиенты их
  игнорируют, но порядок всё равно фиксируем (сначала релиз).
- Два источника Proper в переходный период (Proper texts / legacy days): аудит
  `properSource`, ни одного «тихого» смешения.
- Расхождение содержимого Office (не календаря) из-за мелких различий
  `resolveDayAgainstPeriod`: сверяется хешем Office в той же фикстуре.
- Размер бандла (+~0.7 МБ) и время декодирования; notes — lazy.
- Старые deep links (`/hours/hora/:date/:dayId`) должны открываться: id
  документа остаётся частью маршрута, вариант — query.
