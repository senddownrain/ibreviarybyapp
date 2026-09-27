# Prayerbook migration — Stage 5

Дата: 2026-09-09. Статус: реализовано в `feature/mobile-ux-migration`.

## Новый основной flow

Корень branch `Малітоўнік` теперь является content-first библиотекой в порядке
`Абраныя → Катэгорыі → Усе малітвы`. Все избранные молитвы показаны прямо на
root без искусственного лимита и открывают Prayer Detail одним нажатием. При
пустом списке вместо большой card используется компактная подсказка, после
которой сразу следуют категории. Поиск вынесен в отдельное floating chrome
action; постоянного нижнего search dock и card вокруг каждой строки больше нет.

`Усе малітвы` — явный отдельный destination `/prayers/all`. Он объединяет
built-in и local/user prayers в полный каталог. `/prayers/search` открывает тот
же catalog contract с полем в фокусе. Query и выбранные tag-фильтры живут в
существующем `prayersFilterProvider`, а живые route state и PageStorage keys
сохраняют query и scroll при Prayer Detail → Back. Фильтры появляются только
после входа в поиск.

## Избранное

`favoritePrayersProvider` строится из единого built-in + local каталога и
единственного persisted `SettingsState.favoriteIds`. Порядок равен текущему
порядку ID в settings и не заменён «недавним использованием». Root, каталог,
поиск, категория, compatibility Favorites и Prayer Detail продолжают менять
один state; возврат на root отражает изменение без refresh.

## Категории и реальная модель

Системные и пользовательские категории представлены на root одинаковыми
строками под одной секцией `Катэгорыі`. Production model остаётся tag-based:
`PrayerMenuCategory.tags` задаёт grouping/filter, а существующий persisted
`prayerCategoryMap` дополняет его явным membership. UI не обещает ordered
collection semantics и Stage 5 не добавляет drag-and-drop ordering.

`/prayers/category/:id` показывает молитвы, совпавшие по tag или явному
membership. `/prayers/categories` является вторичным management destination:
системную категорию можно скрыть/показать, но нельзя удалить; пользовательскую
можно создать, переименовать, изменить её tags/явный состав и удалить.
Удаление категории очищает stale membership, а удаление local prayer очищает
её favorite/category references. Drawer shortcuts теперь используют canonical
category route.

## Prayer Detail и пользовательские молитвы

Prayer Detail мигрирован с отдельного `AdaptiveAppBar`/scroll composition на
общий Stage 1 `ReaderScaffold`, `ReaderContentSurface`, `ReaderContextHeader` и
persisted `TextScaleControl`. Reader нейтральный и использует лишь мягкий
Prayerbook accent, а не сезонную перекраску. Основные действия: Back, favorite
и `Aa`; share, focus mode и edit local prayer находятся в overflow. Built-in
prayer не получает destructive/edit action. Default chrome — Compact, focus —
Hidden с общим доступным restore control.

Создание, изменение и удаление local prayer остаются в существующих
`PrayerFormScreen`/`LocalPrayersNotifier`. `Мае малітвы` оставлен вторичным
destination и compatibility route: это минимально рискованный вариант, пока
формы и их delete-return flow не будут отдельно перенесены на новый chrome.

## Navigation, compatibility и состояния

- Root, All Prayers, Category и category management используют Full dock.
- Prayer Detail использует Compact и может перейти в Hidden.
- StatefulShell branch продолжает сохранять вложенный Prayerbook stack при
  переключении на Bible/другой branch; повторный активный tab возвращает root
  по Stage 2 contract.
- Сохранены `/prayers`, `/prayer/:id`, `/prayer/add`, `/prayer/edit/:id`,
  `/favorites`, `/my`, `/my-prayers`, `/prayers/favorites` и `/prayers/my`.
- Добавлены явные состояния empty favorites, no categories/category error,
  empty category, empty catalog/search и prayer not found. Offline с уже
  доступными локальными данными не получает постоянный warning.
- Floating/adaptive chrome сохраняет iOS glass и Android tonal paths из Stage
  2; дерево данных и экранов общее для платформ.

## Tests и legacy disposition

`prayerbook_stage5_test.dart` покрывает порядок root, непосредственное
избранное и compact empty state, единый каталог, shared favorite state, search
и query, tag + explicit category membership, hide/show системной категории,
create/rename/delete пользовательской категории, shared Reader foundation,
Compact/Hidden, отсутствие edit у built-in prayer и 200% system text.
`router_architecture_test.dart` фиксирует новые canonical destinations и старые
aliases; общие Stage 1/2 suites продолжают покрывать platform chrome и branch
stack restoration.

Legacy `FavoritesScreen`, `MyPrayersScreen` и `PrayerFormScreen`:
**KEEP / DEPRECATE AS PRIMARY / REMOVE OR MIGRATE LATER**. Они не участвуют в
daily root, но нужны старым ссылкам, drawer shortcuts и безопасному сохранению
полной user-prayer функциональности. Следующий рекомендуемый этап — отдельная
миграция **Bible branch**. Она не входит в Stage 5 и автоматически не начата.

## Святая Імша: моўныя варыянты

Імша — адзін рытуал з варыянтамі `be` (існуючая малітва `eMmCtxwyJ75ogmL5rwye`),
`la` (існуючая «Ordo Missae» `zdro66KYVuQ9p2KbqizD`) і `en` (`MCFL.pdf`, убудаваны
`assets/mass/order-of-mass-en.md`, або дакумент `prayers/order-of-mass-en` пасля
сінхранізацыі). Агульныя метаданыя — `assets/mass/order-of-mass.ritual.json` (тая ж
копія, што ў MyBrev); `lib/models/mass_ritual_data.dart` згенераваны з яго, тэст
`test/mass_ritual_test.dart` правярае супадзенне.

- Спасылка `/prayers/prayer/eMmCtxwyJ75ogmL5rwye?lang=la`; ID лацінскай/англійскай
  малітвы адкрывае той жа чытач з адпаведнай мовай.
- Апошняя мова захоўваецца ў Hive `settings` (`massRitualLanguage`).
- Навігацыя: плаваючая панэль «бягучы раздзел ▾ · BE/LA/EN» (Glass на iOS, tonal
  на Android) і ніжні ліст з галоўнымі раздзеламі і падраздзеламі. Пры змене мовы
  чытач пераходзіць да таго ж семантычнага раздзела (або бацькоўскага/суседняга).
