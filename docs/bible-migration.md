# Bible migration — Stage 6

Дата: 2026-09-09.

Статус: production migration завершена в `feature/mobile-ux-migration`.

## Итоговый flow

- Tab `Біблія` сразу открывает последнюю сохранённую книгу и главу текущего
  перевода. При первом запуске используется первая доступная книга, глава 1.
- Chapter является root-документом Bible branch и стартует в Compact chrome.
  Full возвращается через dock, Hidden включается через reader overflow и
  возвращается одной кнопкой или platform Back.
- BEL / RUS остаются постоянно видимым segmented control. Каноническая книга и
  глава сохраняются при наличии соответствия; для несовпадающих книг работает
  сохранённый production fallback соответствующего перевода.
- Нажатие названия книги открывает один adaptive combined picker: Завет → поиск
  книги → сетка глав. Previous / next переходят также через границы книг.
- Search сохраняет исходную семантику: названия по всем книгам выбранного
  перевода, текст только в текущей книге. Search живёт в собственном route;
  результат открывает нужную главу/стих, Back возвращает прежний запрос и список.
- Нажатие стиха сохраняет множественный selection. Contextual platform chrome
  предлагает четыре цвета, удаление подсветки и отмену; highlights остаются в
  существующих Hive keys и читают legacy numeric values.

## Reader integration и persistence

`BibleChapterScreen` использует общий `ReaderScaffold`, `ReaderContentSurface`,
`ReaderContextHeader`, `ReaderChromeModeScope` и общий `Aa`. Verse renderer
остаётся Bible-specific, поэтому selection не зависит от HTML reader Ora.

Bible отключает литургический ambient внутри reader: документ непрозрачный и
нейтральный. iOS chrome использует adaptive glass, Android — непрозрачный tonal
Material. Book/chapter navigation и contextual highlight bar также используют
platform chrome boundary вместо прямого `GlassSurface`.

Сохраняются translation, last book/chapter, highlights и отдельный scroll offset
для каждой пары translation/book/chapter. StatefulShell сохраняет Bible branch
при переключении на Prayerbook и обратно. Query `verse` используется для
позиционирования результата поиска и deep link.

## Routes

- Canonical branch: `/bible?version=:version&book=:book&chapter=:chapter`.
- Search: `/bible/search?version=:version&book=:book`.
- Search result stack: `/bible/search/result?...`.
- Compatibility alias `/bible/:version/:book/:chapter` сохранён и нормализуется
  в canonical branch route. Alias поддерживает query `verse`.

## Data failures

`BibleRepository` больше не трактует неизвестный version id как русский и
безопасно пропускает повреждённые books/chapters/verses. Неверная сохранённая
книга использует first-book fallback, глава ограничивается реальным диапазоном;
полностью отсутствующие данные показывают явное graceful state.

## Legacy disposition

- `BibleScreen`: **KEEP / DEPRECATE / REMOVE LATER**. Production router его уже
  не использует, но файл остаётся compatibility reference до cleanup.
- `ReadingScaffold`: **DEPRECATE LATER**. Пока даёт общую persisted typography;
  layout/chrome уже принадлежат `ReaderScaffold`.
- Bible seed, Firestore collections, version ids и highlight keys: **KEEP**.

## Проверка

`test/bible_stage6_test.dart` покрывает first-run/last-location resolution,
translation mapping и fallback, combined picker, chapter boundaries, search и
возврат state, verse selection, add/remove persistence, `Aa`, scroll restore,
Compact/Hidden, iOS/Android chrome, 200% text и corrupt data. Router tests
проверяют canonical branch и compatibility alias.

## Следующий cleanup

После завершения всех migration stages можно удалить неиспользуемый
`BibleScreen`, окончательно вывести `ReadingScaffold`, ревизовать legacy aliases
и объединить общие storage adapters. Эти действия намеренно не входят в Stage 6.
