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
  `buildCompendiumPartReadingOutline` / `CompendiumIndex.partReadingOutlines`,
  compatibility index `buildCompendiumPartOutline` / `CompendiumIndex.navigation`,
  `answerParagraphs`, `formatCccRefs`.

## Навигация и плоский план части

Normal browsing has two levels before a question: Compendium root → Part. A Part screen contains all questions of that Part in canonical order. РАЗДЗЕЛ, product ПАДРАЗДЗЕЛ, named topic and subtopic are inline structural headings rather than navigation destinations. Only an individual question opens its reader. Old node/topic routes are compatibility redirects to the owning Part and scroll target.

- `CompendiumIndex.partReadingOutline(partId)` кэширует неизменяемый поток `CompendiumPartItem` и карту `targetId → itemIndex` для каждой части. Порядок повторяет Web `buildPartReadingOutline()`: раздел, подраздел, цитаты, темы, подзаголовки и вопросы в канонической последовательности units. Все четыре потока вместе содержат 598 вопросов ровно по одному разу.
- Технические `unit`, `intro`, `group` и диапазоны вопросов не становятся заголовками. `CompendiumGroup` и `CompendiumNavNode` остаются производным индексом для разрешения старых ссылок и контекста.
- Исходная метка `chapterLabel = "ГЛАВА ПЕРШАЯ"` остаётся в данных. UI показывает мужские формы через `compendiumSubsectionLabel`, например `ПАДРАЗДЗЕЛ ПЕРШЫ`.
- `CompendiumPartScreen` строит длинный список лениво через `ScrollablePositionedList.builder`. Заголовки не интерактивны; каждый вопрос использует `CompendiumQuestionRow`. Индексная прокрутка учитывает переменную высоту строк и масштаб текста.
- Обычные маршруты: `/prayers/compendium`, `/prayers/compendium/part/:partId`, `/prayers/compendium/question/:number`. Ссылки `/node/:nodeId` и `/topic/:topicId` переадресуют на часть с `?target=<stable id>`. Техническая группа направляет к первому вопросу своей группы. Асинхронная загрузка не мешает cold deep link.
- Reader вопроса сохраняет канонические prev/next. Центральная кнопка `Да часткі` открывает часть с якорем текущего вопроса. Контекст показывает только реальные заголовки источника.

## Offline и обновления

Кампендый — обычный контент приложения (`docs/data-loading-architecture.md`):

- в пакете: `assets/content/compendium.json.gz` (27 разделов) и
  `assets/content/compendiumMeta.json.gz` (`current`: meta и `parts`);
  отдельного `assets/compendium/compendium.json.gz` больше нет (остались
  только поисковые синонимы `compendium_search_aliases.json`);
- `CompendiumRepository.load()` при первом открытии берёт документы из
  `ContentStore`, собирает их `compendiumFromDocuments` и проверяет
  `validateCompendiumDataset` (вне UI isolate); невалидный набор не
  показывается («Не атрымалася адкрыць Кампендый»);
- исправление приходит общим патчем манифеста: изменённые разделы и meta
  включаются одним поколением (`ContentStore.commit`), смешанный набор не
  читается; пересборка Кампендыя (больше четверти разделов) приходит с новой
  версией приложения;
- бывшая скачанная копия (Hive `compendium`) удаляется миграцией.

Firestore: `compendium/{unitId}` (27 документов) + `compendiumMeta/current`
(meta + `parts` + `importedAt`); импорт — MyBrev `npm run db:import-compendium`,
затем публикация манифеста (`npm run content:manifest`).

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
| `/prayers/compendium` | 4 части и глобальный поиск |
| `/prayers/compendium/part/:partId` | Вся часть: inline заголовки, цитаты и все вопросы |
| `/prayers/compendium/question/:number` | Reader одного вопроса с prev/next и `Да часткі` |
| `/prayers/compendium/node/:nodeId`, `/topic/:topicId` | Совместимость: переход в часть к соответствующему заголовку или вопросу |
| `/prayers/catechism` | Redirect на `/prayers/compendium` |

`AmbientWash`, `FloatingTopActions`, `GlassTokens`, `ReadingScaffold`, `ReaderScaffold`, `TextScaleControl` и нижний dock сохраняют платформенный вид Android Ambient / iOS Glass. Навигация не создаёт второй dock.

### Постоянный поиск

- Каждый экран Кампендыя (корень, часть, reader вопроса и compatibility/loading state) обёрнут в `CompendiumSearchHost`
  (`lib/widgets/compendium/compendium_search_host.dart`): он регистрирует
  contextual bottom slot маршрута (`AppRouteEntryScope.showContextualBottomBar`,
  dock приложения скрывается, как в Спеўніку и каталоге малітваў) и ставит
  общий `PrayerSearchDock` (без фильтра) на `floatingOverlayBottom`.
- Состояние одно: `compendiumSearchQueryProvider`; каждый dock показывает тот
  же глобальный запрос, поиск всегда по всему Кампендыю (тот же локальный
  индекс, номера, алиасы только для matching).
- Поиск, начатый на вложенном экране, показывает глобальные результаты
  поверх экрана (контент остаётся смонтированным offstage, скролл
  сохраняется) в визуальном языке корня (`compendiumSearchResultItems`: номер,
  белорусский вопрос, контекст из реальных заголовков). Результат открывает
  обычный reader вопроса; Back возвращает к результатам, следующий Back (или
  очистка запроса) закрывает поиск и восстанавливает исходный экран. Корень
  рисует результаты inline, как раньше.
- Readers: host поднимает `MediaQuery.padding.bottom` до высоты dock'а
  (эта же padding — резерв app dock'а в `extendBody`), поэтому
  `ReaderContentSurface` (ответ, pager, «Крыніца») и кнопка «уверх»
  прокручиваются над dock'ом при home indicator, gesture и 3-button
  навигации. В полноэкранном режиме reader'а dock скрывается вместе с chrome
  (если поиск не активен).
- «Крыніца: Кампендый Катэхізіса Каталіцкага Касцёла, Catholic.by» + copyright
  на всех экранах; ссылка открывается `url_launcher` во внешнем браузере.
