# Спеўнік

Раздел песенника внутри branch `Малітоўнік`. Reference-реализация по данным и
поведению — MyBrev (`src/utils/songChords.js`, `src/services/songService.js`,
`src/constants/songTags.js`); архитектура — нативная Riverpod/Hive/go_router.

## Структура root `Малітоўнік`

`Абраныя → Раздзелы (2 × 2) → Катэгорыі → Усе малітвы → Мае малітвы`.

Плитки (`lib/widgets/prayerbook_section_tiles.dart`): iOS — `GlassSurface`,
Android — tonal Material surface, одинаковая структура (иконка Phosphor,
название, короткая подпись). Высота не фиксирована: плитки ряда делят высоту
через `IntrinsicHeight`; при системном тексте ≥160% или ширине < 300 dp сетка
становится одной колонкой.

| Плитка | Действие | Иконка |
| --- | --- | --- |
| Святая Імша | прежний `/prayers/prayer/<_kMassOrderPrayerId>` + прежний snackbar синхронизации | `church` |
| Спеўнік | `/prayers/songs` | `playlist` (строки текста с нотой — сборник песен, а не «воспроизведение») |
| Катэхізіс | `/prayers/compendium` — Кампендый (см. `docs/compendium.md`); `/prayers/catechism` — redirect | `bookOpenText` |
| Сакрамэнты | `/prayers/sacraments` — заглушка | `cross` |

Заглушка Сакрамэнтаў — `PrayerbookPlaceholderScreen` («Раздзел у
распрацоўцы»). Route стабилен: будущий модуль заменяет только widget в
`router.dart`.

## Модель и Firestore

`Song` (`lib/models/song.dart`): `id`, `title`, `text`, `chord`, `tag`
(числовые ID категорий), `tags` (свободные тэги), `source`. Firestore:
публичная read-only коллекция `songs` (`createdAt`/`updatedAt` игнорируются).
`Song.fromMap` = MyBrev `normalizeSong`: trim, CRLF/CR → LF, отсутствующий
`chord`, `tag` как массив, число или строка `'2,3,4'`, дедупликация тэгов.

Категории 1–10 (`kSongCategories`) — bundled canonical definitions.
MyBrev-коллекция `songCategories` дублирует их и в приложении не читается,
поэтому второго SyncTarget нет. `Song.displayTags` = названия категорий +
custom `tags` без дубликатов; они используются и для отображения, и для
поиска/фильтра.

## Bundled seed и слияние

`assets/songs_seed.json` — копия MyBrev `src/data/songs.json` (447 песен).
Он парсится лениво (`songSeedProvider`) при первом открытии Спеўніка и не
входит в startup path. `SongRepository.merge`: сохранённый документ с тем же
ID перекрывает bundled версию по полям (`{...seed, ...doc}`), новые серверные
песни добавляются. Документы без названия отбрасываются. Если seed не
прочитан, но есть синхронизированные песни, показываются они.

## Hive и синхронизация

Box `songs` (открывается в `HiveService.init`, пустой box дешёв).
`SyncTarget.songs` (`automatic: false`) использует общий постраничный
`_syncCollection`: страницы по 50 с `Source.server`, запись по мере прихода,
удаление устаревших ключей только после успешного конца, отметка
`lastSync_songs`, размер в `bytes_songs`, прогресс/отмена/ошибки — общие.

- Settings → Сінхранізацыя: отдельная группа «Спеўнік» (`sync-songs`) с
  количеством документов, размером и датой синхронизации.
- «Загрузіць усю базу» (`SyncTarget.values`) включает песни.
- Автоматическое фоновое окно после bootstrap использует
  `kAutomaticSyncTargets` и песни **не** загружает.
- При открытии списка (`songbookRefreshProvider`), если сеть есть и песни не
  синхронизировались больше суток, ставится в очередь фоновая отменяемая
  синхронизация только `songs` (`forceRefresh: false`). Bundled песни видны
  сразу.

## Избранное и настройки

`songPreferencesProvider`, Hive box `settings`, только на устройстве:
`favoriteSongIds` (JSON; отдельно от молитвенных `favoriteIds`),
`songShowChords` (по умолчанию выкл.), `songChordLayout` (`above`/`right`,
по умолчанию `above`). Отдельных настроек Спеўніка (sheet, кнопка в списке,
overflow на странице песни) нет: всё управление аккордами — на Song Detail.

Миграции при первом чтении: сохранённый `left` (прежний боковой layout)
читается как `right` и перезаписывается; неизвестное значение → `above`.
Удалённый `songCompactList` игнорируется и удаляется из box. Transpose не
сохраняется.

## Список и поиск

`/prayers/songs` (`SongbookScreen`): поиск в нижнем dock (заменяет app dock
через contextual bottom slot, как в каталоге молитв), фильтр — sheet с
«Толькі абраныя» и multi-select тэгами (OR). Состояние — `songsFilterProvider`.
Поиск без учёта регистра по названию, тексту и тэгам. Сортировка:
избранные выше, затем по белорусскому алфавиту (`compareBelarusianTitles`:
Ё после Е, І после И, Ў после У, кириллица перед латиницей, знаки и цифры
раньше букв — аналог `localeCompare('be', {sensitivity: 'base'})`).
Список всегда компактный (переключателя нет): строка ≥ 48 dp — название,
сердце, chevron; тэги в строках не показываются, но остаются в поиске и
фильтре.

## Страница песни и аккорды

`/prayers/songs/:id` (`SongDetailScreen`) на `ReaderScaffold` +
`ReaderContextHeader` (eyebrow `СПЕЎНІК`, название, тэги) +
`ReaderContentSurface`; actions: Back, favorite, `Aa` (overflow нет).
Footer «Крыніца: …», если source задан.

`lib/utils/song_chords.dart` — порт `songChords.js`: `transposeChord`,
`transposeChordLine`, `songLines`, `filterSongs`. Строка аккордов N ↔ строка
текста N, включая пустые. Поддержаны lowercase minor, `m`/`min`/`-`, `H`,
`♯`/`♭`, slash bass, compact runs (`DGea` → `E A f# b`); слова и знаки в
колонке аккордов (припевы) не меняются. Как и в MyBrev, слово только из
букв аккордов (`Bad`) считается compact run.

### Chord control (`SongChordControl`)

Одна капсула в `ReaderContextHeader.details` (после названия и тэгов, перед
текстом): `[♫] [layout] | [− 0 +]`. Поверхность — `AdaptiveChromeSurface`
(`group`): iOS — Glass, Android — tonal Material, как у остальных reader
controls; иконки Phosphor, кнопки 48 × 48.

- `♫` — показать/скрыть аккорды (`isSelected`, tonal-подсветка tertiary).
- layout — одна кнопка, иконка показывает текущий выбор
  (`alignTopSimple` = над радкамі, `alignRightSimple` = справа); нажатие
  переключает.
- `−` / значение / `+` — transpose −12…+12, шаг 1. Значение имеет
  фиксированную ширину (измеряется по самому широкому `+12`/`-12`), `0`
  приглушён. Ненулевое значение подсвечено tonal-pill; нажатие на него —
  возврат к оригиналу (отдельной кнопки «Арыгінал» нет).

Когда аккорды скрыты, layout и transpose остаются на месте, но disabled —
капсула не меняет размер ни при show/hide, ни при transpose, reset или смене
layout. У песни без аккордов капсулы нет вовсе. Текст внутри капсулы
масштабируется максимум до 160%, при нехватке ширины капсула целиком
`scaleDown`, без overflow.

Transpose −12…+12 — состояние экрана, сбрасывается при открытии другой
песни, меняет только отображение; `song.chord` не изменяется и не сохраняется.

### Layout аккордов

- `above` — строка аккордов над своей строкой текста.
- `right` — текст слева (Expanded, основной), аккорды справа в колонке
  ширины самой широкой (транспонированной) строки аккордов, выровнены по
  baseline первой строки текста.

`SongText.resolveLayout` решает по реальным constraints (`LayoutBuilder`):
`right` используется, если колонка аккордов ≤ 40% ширины и тексту остаётся
≥ 15 em эффективного размера (с учётом `TextScaler`) после отступа 1 em.
Иначе песня временно рендерится как `above`; сохранённый `right` не
меняется и вернётся, когда ширины хватит (поворот, планшет, меньший
текст). Горизонтального скролла нет.

## Отличия от MyBrev (намеренные)

- Нет admin editor, create/edit, Firebase write, auth checks.
- `songCategories` не синхронизируется — категории bundled.
- Скрытые аккорды не добавляют пустых строк из «лишних» строк chord-колонки.
- Тэги в строке списка — текстом через `·`, а не chips.
- Нет навигационной капсулы «Усе спевы»: возврат — стандартный Back.
