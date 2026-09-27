# Кампендый Катэхізіса Каталіцкага Касцёла

Отдельный read-only домен внутри branch `Малітоўнік`: не молитва, не
использует `Prayer`, коллекции/категории/фильтры молитв. Reference —
MyBrev (`docs/compendium.md`, `src/utils/compendiumData.js`,
`compendiumSearch.js`, `compendiumLoader.js`); архитектура — нативная
Riverpod/Hive/go_router, по образцу Спеўніка.

## Данные

- `assets/compendium/compendium.json.gz` — канонический экспорт MyBrev
  (`meta/parts/units`, `schemaVersion: 1`, 598 вопросов, 27 units), и
  `assets/compendium/compendium_search_aliases.json` — скрытые RU→BE алиасы.
  Оба файла генерируются в MyBrev и вручную не правятся:
  `node scripts/build-compendium.mjs --flutter-asset <path>/assets/compendium/compendium.json.gz`.
- Модели (`lib/models/compendium.dart`) неизменяемые: `CompendiumDataset`,
  `CompendiumMeta`, `CompendiumPart` (+ sections/chapters), `CompendiumUnit`,
  `CompendiumTopic`, `CompendiumQuestion` (с контекстом unit и `groupId`),
  `CompendiumCitation`, `CompendiumEmphasis` (UTF-16 offsets, как в JS).
- `lib/utils/compendium_data.dart` — порт `validateCompendiumDataset`,
  `compendiumFromDocuments`, `isNewerCompendium`, `indexCompendium`
  (`CompendiumIndex`: порядок, lookup по номеру/`q042`, reading groups),
  `buildPartOutline`, `answerParagraphs`, `formatCccRefs`.

## Offline и синхронизация

- Seed декодируется лениво (`compute`, вне UI isolate) при первом открытии
  Кампендыя (`compendiumBundledProvider`) и проверяется валидатором. В startup
  path только открывается пустой Hive box `compendium`.
- `SyncTarget.compendium` (`automatic: false`), группа настроек «Кампендый
  Катэхізіса» (`sync-compendium`), входит в «Загрузіць усю базу», не входит в
  автоматическое окно. `CompendiumSync`: одно чтение `compendiumMeta/current`
  (`Source.server`); коллекция `compendium` скачивается одним запросом, только
  если `contentVersion` строго больше текущего (max(bundle, сохранённая копия))
  при той же схеме. Документы собираются `compendiumFromDocuments` и проверяются;
  невалидные данные, ошибка сети или отмена не трогают текущий контент.
- Hive: по записи на unit (+ `_contentVersion`) и `meta` (с `parts`) последним,
  затем удаляются устаревшие ключи. Сохранённая копия используется, только если
  все units совпадают по версии с `meta` и проходят валидацию, и только если
  она новее bundle (`selectCompendium`). Если seed не читается, показывается
  валидная сохранённая копия.
- При открытии корня (`compendiumRefreshProvider`), если сеть есть и проверки
  не было больше суток, ставится фоновая отменяемая синхронизация только
  `compendium` (`forceRefresh: false`).

Firestore: `compendium/{unitId}` (27 документов) + `compendiumMeta/current`
(meta + `parts` + `importedAt`); импорт — MyBrev `npm run db:import-compendium`.

## Поиск

`lib/utils/compendium_search.dart` — построчный порт `compendiumSearch.js`:
та же нормализация (lower case, NFD без диакритики, і→и, э→е, без ъ и
апострофов, латинские двойники рядом с кириллицей, прочее — разделитель),
AND по словам как префиксам, веса полей (вопрос 12, ответ 5, заголовки 3,
ККК 4), стемы ×0.6, алиасы ×0.85, бонусы фразы/полей/короткого вопроса,
номер `n`/`№n`/`#n` — вопрос `n` первым, затем диапазоны ККК, лимит 200,
сортировка score ↓, номер ↑.

- В Dart нет NFD: `compendium_fold_table.dart` (сгенерирован из Python
  `unicodedata`) сводит составные буквы латиницы/греческого/кириллицы к базе;
  классы `\p{M}` и `[^\p{L}\p{N}]` проверяются посимвольно с кэшем (regex с
  Unicode-свойствами в Dart на длинном тексте заметно медленнее).
- Индекс строится один раз на dataset при первом запросе.
- `test/fixtures/compendium_search_parity.json` — выдача MyBrev для 47 запросов
  (номера, score, поле); тест сверяет ранжирование полностью. Перегенерация:
  `node scripts/compendium_search_parity.mjs ../mybrev > test/fixtures/compendium_search_parity.json`.

## UI

| Route | Экран |
| --- | --- |
| `/prayers/compendium` | 4 части, поиск в нижнем dock (`PrayerSearchDock` без фильтра), результаты |
| `/prayers/compendium/part/:partId` | Раздзелы → главы → группы чтения |
| `/prayers/compendium/topic/:topicId` | Reader: раскрываемые вопросы, prev/next группа |
| `/prayers/compendium/question/:number` | Reader: вопрос, контекст, prev/next, «Уся тэма»; deep link |
| `/prayers/catechism` | redirect на `/prayers/compendium` |

- Плитка «Катэхізіс» (`catechism-destination`) открывает `/prayers/compendium`.
- Списки — `AmbientWash` + `FloatingTopActions` + строки как в Спеўніку;
  readers — `ReadingScaffold` → `ReaderScaffold` / `ReaderContextHeader` /
  `ReaderContentSurface` с общим `TextScaleControl`, свайпы prev/next.
- Запрос поиска (`compendiumSearchQueryProvider`) и раскрытые строки
  (`compendiumExpandedProvider`) живут в сессии; скролл — `PageStorageKey`.
  Enter на точном номере открывает вопрос.
- «Крыніца: Кампендый Катэхізіса Каталіцкага Касцёла, Catholic.by» + copyright
  на всех экранах; ссылка открывается `url_launcher` во внешнем браузере.
