# Phase 3B — безопасная миграция верхней зоны

Статус: план production changes после merge Phase 2B. Основан на
[Top Chrome audit](TOP_CHROME_AUDIT.md), [root system](ROOT_SCREEN_SYSTEM.md)
и `main @ ad437ff` от 2 октября 2026. Лаборатория Phase 3A — средство выбора
композиции, не production component.

## Входной gate после Phase 2B

1. Обновить базу с merged Phase 2B и повторно сверить route descriptors,
   `AppShell`, `ReaderScaffold`, Bible chapter, Ora, Prayerbook search и
   Search/Selection bottom owners. Отметить изменения относительно таблицы
   аудита; не переносить в код старые числовые bottom insets.
2. В lab выбрать A или B для normal width и правило C для тесной ширины.
   Проверить iOS/Android на 320/360/390/700 и 100/150/200% text scale,
   long title, Aa 180% вместе с system 200%. Зафиксировать screenshots и
   доступность ведущего action/overflow. Без этого gate не тиражировать
   композицию по экранам.
3. Убедиться, что одноимённые действия имеют один destination: Bible title и
   нижний chapter picker, Hora title chooser, Mass language, Library Search.

## Малые commits

| Commit | Изменение интерфейса и поведения | Проверка |
| --- | --- | --- |
| **3B.1 — primitives** | Ввести внутренние `TopChromeSpec` (role, leading intent, primary/secondary actions), `ChromeIconButton`, `ChromeActionGroup`, `PageHeader` и единый расчет верхнего safe inset. `TopChromeOwner` оставить совместимым на переходе; actions передавать с текстовым label и callback. Не добавлять giant optional widget. | Widget matrix: 320/360/390/700 × 100/150/200%, порядок focus/semantics, min target 48, iOS/Android surface; unit test выбора visible/overflow actions. |
| **3B.2 — roots** | Перевести Літургію и Малітоўнік на общий PageHeader/ритм, затем Чытанні и Біблію как root-reader compositions. Route/branch state не менять. Дата, варианты, return token, last Bible location и shelf destinations используют прежние handlers. | Golden/visual review четырёх roots; smoke тесты открытия часа, чтений, полки, последней главы, смены веток и сохранения позиции. |
| **3B.3 — readers** | По одному семейству за commit: Ora/Readings, Prayer/Mass/Song, Bible, Compendium. Перенести только верхние actions/контекст на role compositions; Aa preferences и body typography не менять. Mass language остаётся наверху, song chords inline, Bible title/bottom picker — один flow. | Тест Back и cold deep link fallback, Ora → Чытанні → Ora, favorite, Aa, Mass language, Bible search/result/selection и chapter picker; проверить последний абзац после смены chrome mode. |
| **3B.4 — collections/search/editor** | Перенести pickers, prayer/song/Compendium lists, Bible search, Favorites/My prayers и prayer editor. Сохранить scope и владельца поиска Phase 2B; закрытие IME/активного search mode предшествует route Back. Save primary, Delete отделён. | Search с IME, query/filter restore, Back layering, editor save/delete, 200% text scale и screen reader labels. |
| **3B.5 — cleanup** | После нуля production callers удалить лишние wrappers и ручные top reserves `+76/+78/+90`; оставить адаптивную поверхность под платформу и зафиксировать ownership в route descriptors. Lab сохранить как regression harness или удалить отдельным решением после приёмки. | `flutter analyze`, полный релевантный test suite, ручной Android/iOS smoke, diff review на отсутствие изменений bottom logic/data loading. |

Каждый commit собирается самостоятельно и не требует одновременно переводить
все экраны. Пока конкретный route не мигрирован, его текущий `shell/reader/legacy`
owner остаётся без изменений. Миграция одного route атомарно меняет owner,
top reserve и actions; нельзя на время оставить две ведущие кнопки.

## Семантический API и ошибки

`TopChromeSpec` — внутреннее описание, не публичный navigation API. Его
минимальные поля: роль из шести типов аудита; `leadingIntent` (`menu`, `back`,
`close`); список actions с стабильным ID, label, icon, callback и priority;
необязательная краткая context label. Page title передаётся `PageHeader` или
reader context, а не копируется в floating controls. Secondary actions
открываются в платформенном menu с теми же labels. Контейнеры получают
измеренную высоту и safe inset от одного владельца. Контракт не владеет
bottom slot, состоянием документа, поисковым индексом или календарём.

Для внешней deep link без parent stack Back возвращает к корню соответствующей
ветки; root показывает Menu. В reader hidden/focus состоянии доступен явный
restore; modal/IME закрываются до pop. На 320 dp обязательные действия не
исчезают: reader Aa остаётся видимым, остальное уходит в подписанный overflow;
Mass Language остаётся доступным на первом уровне menu. Если text scale
увеличивает высоту controls, content reserve измеряется заново, без наложения
на title и первый абзац. Ошибка данных не меняет top owner и сохраняет Back.

## Merge touchpoints и приемка

Вероятные конфликты после Phase 2B: `lib/router/router.dart`,
`lib/navigation/app_navigation.dart`, `lib/widgets/app_shell.dart`,
`lib/widgets/reader/reader_scaffold.dart`, `lib/screens/bible_chapter_screen.dart`,
`lib/screens/ora_screen.dart`, `lib/screens/prayers_screen.dart`,
`lib/screens/songbook_screen.dart`, `lib/widgets/compendium/compendium_search_host.dart`.
При интеграции сверять API нижнего owner и сохранённые сценарии, не брать
числа/ветвления из Phase 3A lab. Особенно проверить Mass bottom navigation,
Bible chapter bar, Library Search scope, search docks и Ora scroll-to-top.

Готовность Phase 3B: на каждом route один top owner; четыре root читаются как
одна система; Menu/Back и action priority предсказуемы; на заданной матрице
нет overflow/перекрытий; все прежние переходы, данные и bottom owners работают;
предиктивный Android Back и iOS gesture проверены на устройстве. После каждого
семейства экранов обновить audit inventory с фактическим статусом миграции.
