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
  `buildCompendiumPartOutline` / `CompendiumIndex.navigation`,
  `answerParagraphs`, `formatCccRefs`.

## Иерархия источника и reading groups

**Иерархия источника и внутренние reading groups — разные понятия; видимыми
узлами навигации становятся только реальные заголовки источника.**

- Источник (Catholic.by) печатает уровни `ЧАСТКА → РАЗДЗЕЛ → ГЛАВА → именованные
  тэмы → пытанні`. `РАЗДЗЕЛ` и `ГЛАВА` — разные уровни; в Dart они называются
  `section`/`chapter`. В продукте уровень `chapter` называется `ПАДРАЗДЗЕЛ`
  (см. «Навигация v2» ниже); канонические данные при этом не меняются.
- `CompendiumGroup` — внутренний кусок чтения (reader-страница, prev/next,
  раскрытые строки, deep links). Группа `CompendiumGroupKind.unit` —
  безымянный lead-in unit'а (например `p1-s1-intro` = вопрос 1); это **не**
  заголовок источника (`hasSourceHeading == false`).
- Навигация строится производным индексом `CompendiumNavNode`
  (`buildCompendiumPartOutline`, кэш `CompendiumIndex.navigation`) из
  канонического датасета, без копирования контента и без изменения схемы:
  узел `part/section/chapter/topic` имеет `directQuestions` и `children`.
  Вопросы lead-in'а — `directQuestions` ближайшего реального заголовка
  (раздела или главы); они всегда идут перед `children` (валидатор
  гарантирует, что вопросы без тэмы предшествуют тэмам). Порядок узлов
  детерминирован и совпадает с каноническим порядком вопросов.
- Прямые вопросы рисуются строками вопроса (номер + текст →
  `CompendiumQuestionScreen`), а не контейнерами «Пытанне 1» / «Пытанні
  25–27». Именованная тэма остаётся строкой с диапазоном как вторичной
  метаинформацией («БОЖАЕ АБ’ЯЎЛЕННЕ / Пытанні 6–10»); `parentTitle` тэмы —
  подзаголовок над ней.
- Контекст (`questionContextTrail`, `groupContextTrail`,
  `compendiumQuestionContext`, `ReaderContextHeader`) — только реальные
  заголовки: для вопроса 1 «ЧАСТКА ПЕРШАЯ · «ВЕРУ» — «ВЕРЫМ»», без третьего
  уровня; внутри тэмы — часть · раздел · глава · тэма.
- Legacy `/prayers/compendium/topic/<unitId>`: lead-in из одного вопроса
  (`compendiumGroupQuestionRedirect`, например `p1-s1-intro`) открывается как
  reader этого вопроса; lead-in из нескольких вопросов (`p1-s1-ch1`, 2–5)
  открывается reader'ом с заголовком ближайшей главы/раздела и диапазоном
  только в metadata. Prev/next и «Уся тэма» не ведут на фиктивные тэмы
  (для lead-in кнопка показывает диапазон или скрыта).

## Навигация v2: всегда спускаемся к ближайшему реальному владельцу

**Правило.** Каждый структурный узел — отдельный экран. Экран показывает
заголовок узла, затем вопросы, которые источник печатает прямо под этим
заголовком (`directQuestions`), затем реальных детей узла как строки-переходы.
Ничего, что лежит ниже ребёнка, на экран не «выплющивается», поэтому каждый
из 598 вопросов перечислен ровно один раз — на экране своего ближайшего
владельца (`CompendiumIndex.ownerOf`).

```text
ЧАСТКА      → только её РАЗДЗЕЛЫ (метка, заголовок, диапазон, chevron)
РАЗДЗЕЛ     → прямые вопросы → ПАДРАЗДЗЕЛЫ и тэмы, принадлежащие разделу
ПАДРАЗДЗЕЛ  → прямые вопросы → именованные тэмы
ТЭМА        → reader (раскрываемые вопросы, `subtopicTitle` — заголовки внутри)
```

Никаких частных случаев для вопроса 1: то же правило даёт q1 и q218–220,
q357, q434–441, q534 на экранах разделов; q2–5, q79–80, q251, q295, q321,
q535, q557, q567–568 — на экранах подразделов; раздел без глав (`p4-s2`)
показывает свои тэмы напрямую; у `p2-s2` перед подразделами идёт собственная
тэма раздела (q250). Цитата под заголовком главы (`leadCitations`,
`p1-s1-ch1`) показывается на экране подраздела.

**Терминология UI.**

| Данные / Dart | Источник | UI |
| --- | --- | --- |
| `part`, `partLabel` | ЧАСТКА ПЕРШАЯ | ЧАСТКА ПЕРШАЯ (из данных) |
| `section`, `sectionLabel` | РАЗДЗЕЛ ПЕРШЫ | РАЗДЗЕЛ ПЕРШЫ (из данных) |
| `chapter`, `chapterLabel` | ГЛАВА ПЕРШАЯ | ПАДРАЗДЗЕЛ ПЕРШЫ (генерируется) |
| `topic` | заголовок тэмы | реальный заголовок, без родового слова |

`chapterLabel` остаётся «ГЛАВА …» (данные общие с MyBrev и Firestore). UI берёт
метку только из `CompendiumNavNode.displayLabel`; для главы это
`compendiumSubsectionLabel(chapterNumber)` с порядковым числительным мужского
рода (ПЕРШЫ, ДРУГІ, ТРЭЦІ, ЧАЦВЁРТЫ, ПЯТЫ, ШОСТЫ, СЁМЫ, ВОСЬМЫ, ДЗЯВЯТЫ,
ДЗЯСЯТЫ; дальше — «ПАДРАЗДЗЕЛ 11»). Замена слова в строке («ПАДРАЗДЗЕЛ
ПЕРШАЯ») не используется. «ГЛАВА …» как продуктовая метка нигде не выводится.

**Визуальные уровни** (только типографика, отступы и eyebrow; новых цветов
нет; все строки — `CompendiumListRow`):

| Уровень | Виджет | Оформление |
| --- | --- | --- |
| РАЗДЗЕЛ | `CompendiumSectionRow` | accent eyebrow `labelMedium` w800, заголовок `titleLarge` w700, диапазон, отступ 18 |
| ПАДРАЗДЗЕЛ | `CompendiumSubsectionRow` | accent eyebrow `labelSmall`, заголовок `titleMedium` w700, диапазон, отступ 14 |
| Тэма | `CompendiumTopicRow` | заголовок `titleMedium` w500 + «Пытанні N–M», без eyebrow, отступ 10 |
| Пытанне | `CompendiumQuestionRow` | бейдж номера + текст + chevron; один и тот же компонент на экране раздела, подраздела и в результатах поиска |

Заголовок экрана: контекст («ЧАСТКА ПЕРШАЯ · «ВЕРУ» — «ВЕРЫМ»»), метка уровня,
заголовок (`headlineSmall` у части и раздела, `titleLarge` у подраздела),
диапазон вопросов.

**Маршруты.** Один экран `CompendiumNodeScreen`
(`lib/screens/compendium_node_screen.dart`): `part/:partId` —
`CompendiumNodeScreen.part`, `node/:nodeId` — раздел или подраздел по id из
датасета (`p1-s1`, `p1-s1-ch1`). `node/<id тэмы или reading group>` заменяется
на `topic/<id>`; неизвестный id — «Раздзел не знойдзены». Старые ссылки
`part/…`, `topic/…` (включая технические группы, см. выше) и `question/…` не
менялись.

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
| `/prayers/compendium/part/:partId` | Компактный план части: только её раздзелы |
| `/prayers/compendium/node/:nodeId` | Раздзел или падраздзел: прямые вопросы, затем дочерние узлы |
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

### Постоянный поиск

- Каждый экран Кампендыя (корень, часть, раздел, подраздел, reader тэмы, reader вопроса,
  loading/not-found) обёрнут в `CompendiumSearchHost`
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
