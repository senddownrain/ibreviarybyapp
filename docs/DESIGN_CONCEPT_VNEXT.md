# iBreviaryBy — Design Concept vNext

Статус: дизайн-концепция и аудит, 29 сентября 2026 года. Production-код не
изменялся. Документ служит основой для отдельных задач реализации.

База: `origin/main` @ `1540a7d` («Revise color palette and typography»), ветка
`docs/design-concept-vnext`.

> **Приоритет документов.** Предлагается принять этот документ как
> **канонический верхний уровень** дизайн-системы. Он не отменяет
> технические спецификации миграций (`app-shell-migration.md`,
> `reader-foundation.md`, `hours-/readings-root-migration.md`,
> `prayerbook-migration.md`, `bible-migration.md`, `songbook.md`,
> `compendium.md`), но заменяет противоречащие друг другу визуальные решения
> из `docs/design/ibreviary-mobile-design-language.md` (1.1),
> `docs/platform-design.md` и частично `docs/design/reader-typography-vnext.md`.
> Точный перечень расхождений и решения по ним — в §3.4 и Приложении A.

## Источники и метод

Изучено:

- вся документация `docs/` и `docs/design/` (Design Language 1.1, token JSON,
  Library, Reader Typography VNext, UX handoff, отчёты Stage 2–10, аудиты
  2026-09-07 и Stage 7, liturgical reader final review, Android runtime visual
  check, songbook, compendium, offline-sync, quality-followups);
- тема: `lib/theme/app_theme.dart` (`AppPalette`), `glass.dart`
  (`GlassTokens`, `AmbientBackdrop`, `AmbientWash`, `GlassSurface`),
  `platform_design.dart` (`AdaptiveChromeSurface`), `reader.dart`
  (`ReaderTheme`, `ReaderFontFamily`), `lib/utils/liturgical_theme.dart`,
  `ThemeData` в `lib/main.dart`;
- оболочка и навигация: `app_shell.dart`, `app_navigation_dock.dart`,
  `lib/navigation/app_navigation.dart` (`AppRouteDescriptor`,
  `BranchShellController`, contextual bottom slot), `lib/router/router.dart`,
  `floating_top_actions.dart`, `adaptive_app_bar.dart`,
  `navigation_drawer.dart`, `utils/system_insets.dart`;
- reader: `widgets/reader/reader_scaffold.dart` (`ReaderScaffold`,
  `ReaderChrome`, `ReaderContextHeader`, `ReaderContentSurface`,
  `ReaderEdgeProtection`, `showReaderChoiceSheet`), `reading_scaffold.dart`,
  `alternative_text.dart`, `text_scale_control.dart`, `psalm_choir_html.dart`;
- все 21 экран `lib/screens/*`, включая Святую Імшу в
  `prayer_detail_screen.dart` (`_MassNavigatorBar`, `_MassSectionsSheet`),
  Спеўнік, Кампендый, заглушку Сакрамэнтаў, legacy Favorites/My Prayers/Form,
  Settings, Bible + Bible Search, Hours/Ora, Readings;
- брендинг: иконки iOS/Android/web, `assets/logo.png`, launch screens,
  `web/manifest.json`, `web/index.html`, названия в `Info.plist` и
  `AndroidManifest.xml`;
- визуальная проверка: реальные скриншоты Android-эмулятора из
  `audit-evidence/android-runtime/` (HEAD `224aa18`, за один commit до
  изменения палитры; геометрия и композиция актуальны, оттенки — чуть
  устаревшие).

Нативные сборки iOS в этой задаче не запускались; утверждения о
Liquid Glass, VoiceOver и производительности blur — на уровне кода и
документации, не устройства.

---

## 1. Executive Summary

**Что это за продукт.** iBreviaryBy — это не «приложение с разделами», а
**одна литургическая книга, которая знает, какой сегодня день**: Літургія
гадзін и Чытанні на выбранную дату — сердце; Малітоўнік, Імша, Спеўнік,
Катэхізіс и Біблія — библиотека, из которой берут тексты по мере нужды.

**Где продукт сейчас.** Архитектурная работа последних месяцев сделана хорошо:
четыре независимых ветки `StatefulShellRoute`, общий `ReaderScaffold` с
непрозрачной страницей, разведение платформенного chrome через
`AdaptiveChromeSurface`, Literata в теле текста, красные рубрики, тихая
графитово-ивори палитра. Длинный текст на экране уже **выглядит как хорошо
набранная книга**. Это главное достижение, и его нужно защитить.

**Главная проблема — не отдельные экраны, а отсутствие единого источника
правды.** Пять дизайн-документов принимают противоположные решения (три
раздела + SectionSwitcher против четырёх табов; «Aa только размер» против
выбора гарнитуры; обязательный mist-indigo ambient против нейтрального), а
код не использует ни один набор токенов: 16 разных радиусов, 4 разных
размера круглых кнопок, 7 «магических» верхних отступов, 4 независимых
HTML style-map. Каждый новый раздел (Спеўнік, Кампендый, Імша) добавлял свой
floating-элемент и свою геометрию — и внизу экрана теперь иногда живут два
навигационных слоя сразу.

**Пять системных проблем:**

1. **Нет токенов и нет единой документации** — дизайн существует в
   литералах и в конфликтующих документах.
2. **Литургический цвет протекает в интерфейс**: `OraScreen` подменяет
   `ColorScheme.primary`, `seasonColor` передаётся в каждую chrome-поверхность,
   Налады окрашиваются сезоном, цвет вычисляется эвристикой по словам
   «мучан»/«апостал».
3. **Конкуренция в нижнем слоте**: глобальный dock + локальные панели
   (`_MassNavigatorBar`, `_ChapterNavBar`, search dock, scroll-to-top)
   размещаются независимо, каждая со своими отступами.
4. **Три типографические системы вокруг одной книги**: Cormorant на корнях
   Літургіі/Чытанняў, системный bold на Малітоўніку/Спеўніку/Кампендыі,
   uppercase-микроподписи с трекингом, четыре разных HTML-рендеринга ролей;
   шрифты грузятся из сети.
5. **Размытая граница «материал vs контент» и бренд**: `GlassSurface`
   напрямую на Android (search dock) и в legacy-экранах, модальный контент в
   стекле; три имени продукта (iBreviary / Mybrev / Малітоўнік), иллюстративная
   коричневая иконка, не связанная с интерфейсом, web-иконка Flutter по
   умолчанию.

**Направление vNext — «Ціхая кніга» (Quiet Book).** Refine → unify →
simplify → elevate:

- **Страница** — непрозрачная, тёплая, почти нейтральная; все тексты — по
  одной книжной типографической шкале.
- **Рамка** — нейтральная и тихая; никакого сезона в chrome.
- **Лента-закладка** — единственный носитель литургического цвета: тонкий
  вертикальный маркер у названия дня/празднования (он уже есть в
  `hours-celebration-accent`) и его производные. Это реальный элемент
  литургической книги, а не декор.
- **Один нижний слот** — в каждый момент внизу ровно один плавающий
  элемент: dock разделов, либо reader bar (локальная навигация документа с
  «ручкой» к разделам), либо поиск, либо палитра выделения.
- **Одна система, два выражения** — iOS: тонкий материал и лёгкие
  контролы; Android: tonal Material 3 Expressive. Геометрия, типографика,
  семантика и иконки — общие.
- **Токены как код** — `ThemeExtension`-набор `IbTokens`, из которого
  читают все компоненты; JSON-спецификация генерируется из него, а не наоборот.

---

## 2. Product Identity

### 2.1 Роли продукта

| Роль | Где в коде | Вес |
| --- | --- | --- |
| Литургический инструмент дня (Часы + Чытанні по дате, варианты празднований, циклы) | `HomeScreen`, `OraScreen`, `ReadingsScreen`, `LiturgicalContentService`, `liturgical_*` utils | **Центр** |
| Молитвенник (избранные, категории, личные молитвы) | `PrayersScreen`, `PrayerDetailScreen`, `local_prayers_provider` | Опора |
| Служебная книга Імшы (Ordo Missae BE/LA/EN) | `PrayerDetailScreen` + `_MassDocument`, `mass_ritual_data.dart` | Опора (особенно для священников и служащих) |
| Библиотека текстов (Біблія, Спеўнік, Кампендый, будущие Сакрамэнты) | `BibleChapterScreen`, `SongbookScreen`, `CompendiumScreen` | Справочная |
| Ежедневный духовный спутник | нет отдельной функции — возникает из «сегодня» по умолчанию | Эффект, не функция |

**Центральная роль:** *литургическая книга дня*. Не «dashboard», не
«контент-платформа» и не «каталог». Всё остальное — книги на той же полке.

Формула продукта: **«Адкрыў — і ўжо на патрэбнай старонцы»**.

### 2.2 Пользователи

- **Мирянин с регулярной молитвой** — утро/вечер, Laudes/Vesperae,
  Completorium, чтения дня, избранные молитвы.
- **Священник / монашествующий** — полный официй, выбор празднования и
  местного календаря, Імша на нескольких языках, быстрая смена часа.
- **Служащий/певчий на богослужении** — Імша, Спеўнік с аккордами,
  транспонирование, крупный текст, экран не гаснет.
- **Изучающий** — Кампендый, Біблія, поиск.

### 2.3 Сценарии

**Primary (ежедневно, должны занимать ≤1–2 касания):**

1. Утро/вечер: открыть приложение → *Літургія* → нужный час → молиться.
   Сейчас: 1 касание от корня (`Гадзіны → час → Ora`). Сохранить.
2. Открыть чтения дня (самостоятельно или из часа через «Чытанні»).
3. Во время Імшы: открыть Парадак Імшы, переключить язык, перейти к разделу.
4. Вернуться к избранной молитве (Малітоўнік → Абраныя → текст).
5. Продолжить чтение с того же места после перерыва (последний раздел,
   сохранённый scroll).

**Secondary (еженедельно/по случаю):**

6. Сменить дату, выбрать другое празднование/местный календарь, шаблон.
7. Найти молитву/песню по названию или тексту.
8. Спеўнік на богослужении: аккорды, транспонирование.
9. Біблія: продолжить чтение, найти место, выделить стих.
10. Кампендый: найти вопрос по теме или номеру.

**Редкие / служебные:**

11. Синхронизация и диагностика кэша.
12. Личные молитвы и категории (создание/редактирование).
13. Advanced liturgical picker (период/свята), HoraPicker (legacy).
14. Настройки внешнего вида, стартовый раздел, «Інфармацыя».

**Вывод для иерархии.** Визуальный вес должен падать строго в этом порядке:
текст документа > контекст дня > выбор часа > библиотека > поиск >
настройки. Сейчас нарушения: заглушка «Сакрамэнты» имеет такой же вес, как
Імша; Налады — одна огромная карточка с диагностикой; раздел «Раздзелы»
Малітоўніка использует самый тяжёлый визуальный паттерн приложения (плитки с
иконкой в квадрате) для четырёх вторичных книг.

### 2.4 Имя и бренд

Сейчас продукт называется по-разному:

| Место | Имя |
| --- | --- |
| Документация, классы (`ibreviary-app`, `IBREVIARY_PLATFORM`) | iBreviary |
| Запрос владельца | iBreviaryBy |
| `MaterialApp.title`, `web/manifest.json`, `<title>` | Mybrev / «Mybrev — Малітоўнік» |
| `CFBundleDisplayName`, `android:label` | Малітоўнік |
| `pubspec.yaml` | `mybrev_flutter`, «Малітоўнік — беларускі каталіцкі малітвоўнік» (с опечаткой) |
| Вкладка dock | Малітоўнік (совпадает с именем приложения на рабочем столе) |

Имя на рабочем столе совпадает с названием одного из четырёх разделов —
пользователь открывает «Малітоўнік», а попадает в «Літургію». Это
**решение владельца продукта**; рекомендация: одно имя приложения
(например, «iBreviary» / «Брэвіярый»), отличное от имени раздела, и
единая строка во всех манифестах.

---

## 3. Current Design Assessment

### 3.1 Strengths — что уже получилось

1. **Непрозрачная книжная страница.** `ReaderContentSurface` —
   `#FDFCF9`/`#171917`, без blur, без карточки, без сезонного оттенка.
   Скриншоты Readings/Bible показывают спокойный, «бумажный» текст.
2. **Literata как голос книги.** Хороший экранный serif с полной
   белорусской кириллицей; межстрочный 1.68 и ширина колонки ≤700 дают
   ровный ритм.
3. **Рубрикация.** Отдельный `rubric` (`#9B302A` / `#EF9188`), не
   совпадающий с primary; литургический цвет не окрашивает текст.
4. **Спокойная ахроматическая палитра** последнего commit: графит, ivory,
   тёплые серые. Ни банковского синего, ни церковного золота.
5. **Архитектура оболочки.** 4 ветки со своими стеками, `Full/Compact/Hidden`
   режимы chrome по `AppRouteDescriptor`, contextual bottom slot,
   Ora → Readings → Back с return token. Это зрелая основа для любой
   дальнейшей навигационной работы.
6. **Разделение platform chrome.** `AdaptiveChromeSurface` +
   `usesCupertinoGlass(context)` через `Theme.platform`, preview-флаг
   `IBREVIARY_PLATFORM`. Экранные деревья не дублируются.
7. **Контент-первый корень Часов**: дата → празднование с маркером →
   альтернативы → часы. Лаконично, без dashboard.
8. **Варианты текстов**: краткий trigger + sheet, связанные антифоны,
   циклы чтений во вторичном sheet. Это правильная progressive disclosure.
9. **Доступность в тестах**: 320 px, 200% system text, Aa 70–180%.
10. **Малая плотность иконок и отсутствие религиозного декора** в UI:
    ни крестов в заголовках, ни золотых рамок.

### 3.2 Weaknesses

#### Visual identity

- **Характер сильный внутри документа и слабый снаружи.** Корни
  Малітоўніка/Спеўніка/Кампендыя (системный bold 32, серые круглые кнопки,
  серый фон) визуально ближе к generic Material template, чем к книге;
  корни Літургіі/Чытанняў с Cormorant 36–38 — к журналу. Это ощущается
  как два приложения.
- **Иконка приложения** — коричневый иллюстративный круг с голубем,
  лучами, крестом и книгой; белый squircle с полями «запечён» в PNG
  (iOS наложит свою маску поверх — двойное скругление и уменьшенный
  знак). Стилистически это «церковный клипарт», противоположный тихому
  интерфейсу. Неиспользуемый `assets/logo.png` — ещё один вариант (жёлтый
  круг на синем). Web использует иконку Flutter по умолчанию,
  `theme_color: #3A5FA0` — цвет, которого нет в палитре. Splash — шаблон
  Flutter (белый на iOS, без знака).
- **Визуальный шум в chrome**: у каждой круглой кнопки обводка 0.8 +
  тень + заливка + сезонный оттенок; на тёмной теме кнопки стоят поверх
  текста (скриншот `dark-dock.png`: «Раслаўлены» текст проходит под
  круглыми кнопками, fade защищает слабо).

#### Типографика

- **Можно ли воспринимать приложение как хорошо свёрстанную литургическую
  книгу?** *Внутри документа — почти да. Вокруг документа — нет.* Тело
  текста, рубрики и ритм уже книжные. Но: заголовок документа в
  `ReaderContextHeader` набран системным шрифтом 27 (sans title над
  serif-телом); eyebrow — uppercase с accent-цветом («СТАРЫ ЗАПАВЕТ»,
  «СПЕЎНІК», «ПЫТАННЕ 42»); section labels на корнях — uppercase `w800`
  `letterSpacing 0.8–1.05` («ЛІТУРГІЯ ГАДЗІН», «ШАБЛОН СВЯТКАВАННЯ»); список
  песен смешивает CAPS и Sentence case из данных. Книга так не
  набирается — в ней одна гарнитура для заголовков и текста, капитель
  вместо uppercase, и порядок, а не крик.
- **Четыре рендеринга ролей.** Ora (`_renderHtml`), Readings
  (`readings_screen.dart` ≈1323), Prayer/Імша (`_buildContent`, свои
  множители `h2 ×1.2`, `h3 ×1.1`, `p margin 10`), Reading Detail — каждый
  строит свой `Map<String, Style>`. `ReaderTheme` задаёт роли, но HTML-карты
  дублируют и расходятся с ними.
- **Шрифты не упакованы.** `google_fonts` загружает Literata/Cormorant/
  Source Serif по сети; `pubspec.yaml` не содержит font assets. Первое
  открытие офлайн = fallback-гарнитура. Это противоречит инварианту «после
  синхронизации всё работает без сети» (DL 1.1 §0.2.6, token policy
  `runtimeFontDownload`).
- **Размер по умолчанию 16** (`kDefaultReaderFontSize`) при Aa 70–180%;
  Design Language 1.1 определял 18 при 85–160%. Для длительного чтения
  Literata 16 на телефоне мелковат, а 70% (11.2 pt) — уже микротекст.
- **Решение по гарнитуре меняется**: Stage 7/9 — «Aa только размер,
  гарнитура фиксирована», commit `1540a7d` — снова выбор из трёх
  гарнитур в Наладах и Aa. Сам выбор разумный (см. §6.1), но решение не
  зафиксировано в каноне.

#### Цвет

- **Литургический цвет используется как тема, а не как метка.**
  - `OraScreen._buildForDay` оборачивает reader в `Theme` с
    `primary: seasonColor` — все кнопки, InkWell, Slider в Aa становятся
    зелёными/фиолетовыми. Прямое нарушение DL 1.1 инварианта 2.
  - `AdaptiveChromeSurface(seasonColor:)` на Android подмешивает 5.5%
    сезона в каждую кнопку; на iOS `GlassSurface` — 6.5%. `FloatingTopActions`
    по умолчанию берёт `liturgicalSeasonColorProvider` на любом экране.
  - `SettingsScreen` обёрнут в `AmbientWash(seasonColor: liturgical)`.
  - `ReaderScaffold` рисует `AmbientWash.hero` сезона над страницей.
- **Цвет по эвристике текста** (`liturgicalColorForDay`: «мучан»,
  «апостал», «сэрц»+«езус»), Марыйны синий `#5E9EC5` как квази-литургический
  цвет. DL 1.1 §2.2 прямо это запрещал; миграция на
  `LiturgicalContextVisual` не выполнена.
- **Семантическая путаница**: «сердце» избранного окрашено `cs.error`
  (красный ошибки); Малітоўнік использует `cs.tertiary` («devotional» серый)
  как псевдо-сезонный цвет; `primaryContainer`/`tertiaryContainer` строятся
  через alpha поверх — непрозрачные роли DL не реализованы.
- **`ReaderTheme` хардкодит свои цвета** (`muted #62645F`), почти
  совпадающие с `AppPalette.lightOnSurfaceVariant #5F625C`: два источника
  одной роли.

#### Формы и компоненты

- **Радиусы**: в `lib/` 16 разных значений `circular()` — 2, 8, 10, 12, 14,
  15, 16, 17, 18, 20, 22, 24, 28, 30, 99, 999. Самые частые — 28 (18 раз),
  22, 18, 24, 16.
- **Круглые кнопки chrome — 4 реализации и 2 размера**:
  `_FloatingMenuButton` (52, AppShell), `_FloatingTopButton` (52,
  FloatingTopActions), `_ReaderChromeButton` (48, ReaderChrome),
  `AdaptiveAppBar` leading (48), плюс `_ChromeAction` в Bible и
  `IconButton.filledTonal` для «сердца» в Prayer Detail (другая форма
  рядом с Back).
- **Три реализации верхней панели**: `FloatingTopActions` (списки),
  `ReaderChrome` (readers), `AdaptiveAppBar` (legacy, loading/error states).
  Отступы: 14/10 против 12/8.
- **Карточки**: `CardTheme` (radius 20, alpha 0.92), `GlassSurface.card`
  (22), `_NeutralContentSurface` (28, Settings), `PrayerbookSectionTile`
  (22 + иконка в квадрате 14), `SelectionOptionCard` (18), `CompendiumBadge`
  (14). Для 6 назначений — 6 форм.
- **Sheets**: `showReaderChoiceSheet` (Material sheet на обеих
  платформах, ветки различаются только фоном), `AlternativeText` sheet
  (свой), Hours date/alternatives (контент в `AdaptiveChromeSurface` =
  стекло на iOS), Aa (`showCupertinoModalPopup`/Material), Mass sections,
  Song settings, Prayer tags. Модальный контент то непрозрачный, то стеклянный.
- **Списки**: `_HourRow` (иконка 23 + divider indent 54), `PrayerListRow`
  (heart + chevron, minHeight 62), `_CategoryRow` (folder icon),
  `_DestinationRow`, `CompendiumListRow` (uppercase eyebrow),
  песни (heart + chevron). Chevron из Material (`chevron_right_rounded`),
  на Hours — Phosphor `caretRight`.
- **Иконки**: Phosphor Regular для предметов (хорошо), но Material
  `Icons.*` в reader chrome (`arrow_back_ios_new`, `more_horiz_rounded`,
  `keyboard_arrow_up_rounded`), в search dock (`search_rounded`,
  `tune_rounded`), в строках (`chevron_right_rounded`,
  `location_on_outlined`). Размеры иконок: 16, 17, 18, 19, 20, 21, 22, 23, 24,
  28 — без правила.

#### Навигация

- **Глобальная навигация хорошая** (4 таба, ветки, repeat-tab → root).
- **Локальная навигация добавлялась снизу, не согласуясь с глобальной**:
  - Імша: compact dock **и** `_MassNavigatorBar` (раздел + BE/LA/EN) над ним —
    два плавающих капсульных слоя.
  - Біблія: `_ChapterNavBar` (‹ Роду 1 ›) **и** full dock под ним
    (`dark-dock.png`).
  - Кампендый: `CompendiumPager` (текстовые кнопки prev/next) внутри
    документа + swipe + compact dock.
  - Songbook/Prayer search/Compendium: search dock заменяет app dock
    (правильно), но с отличающимися от dock отступами (P2 в runtime check:
    +48 dp над клавиатурой, 104/128/152 магических bottom padding).
  - `_ReaderScrollToTopControl` — ещё одна плавающая кнопка в правом нижнем углу.
- **Swipe смены даты** включён на корне Часов и в reader Чытанняў, хотя
  UX handoff это исключал: жест конфликтует с выделением текста и Back-edge.
- **Double-tap fullscreen** на всём документе (`_ReaderFullscreenGestureSurface`)
  без видимого входа — follow-up P1-02 в `quality-followups.md` открыт.
- **Верхняя «кнопка меню»** на корнях открывает вторичное меню
  (`showSecondaryMenu`), визуально идентичное кнопке «Назад» по форме и месту —
  пользователь не различает уровень.

#### Платформы

- Разделение chrome реализовано, но **нарушается точечно**: `PrayerSearchDock`
  использует `GlassSurface` без проверки платформы (на Android — blur-стекло,
  видно на `songbook-search-closed.png`); legacy `favorites_screen`,
  `my_prayers_screen`, `prayer_form_screen`, `liturgical_picker_screen`,
  `liturgical_day_options_screen`, `hora_picker_screen` используют
  `GlassSurface` для контента без platform-ветки.
- Android получает iOS-подобную композицию «круглые плавающие кнопки по
  углам» с тенью и обводкой; Material 3 Expressive даёт для этого
  floating toolbar/tonal button без обводки.
- Переходы: branch routes используют `_ShellFadePage` — одинаковый fade на
  обеих ОС (Stage 7 P2-11 открыт).

### 3.3 Design Debt Map

#### Systemic design debt

| # | Долг | Проявление (файлы) | Почему системно | Лечение (§) |
| --- | --- | --- | --- | --- |
| S1 | Нет токенов в коде | 16 радиусов, 4 размера кнопок, 10 размеров иконок, 7 top insets (`+76`, `+78`, `+90`), bottom padding `104/116/120/128/152` | Любой новый экран изобретает свои числа | §11, Phase 1 |
| S2 | Нет канонического документа; решения противоречат друг другу | DL 1.1 ↔ UX handoff ↔ Reader VNext ↔ Stage 7 | Исполнители реализуют разные «правды» | §3.4, Приложение A |
| S3 | Литургический цвет как тема | `OraScreen` primary override, `seasonColor` во всех chrome, `AmbientWash` в Settings, эвристики в `liturgical_theme.dart` | Нарушает смысл цвета и спокойствие | §6.2, Phase 1 |
| S4 | Нет арбитра нижнего слота | Mass bar + dock, Bible chapter bar + dock, scroll-to-top, search dock со своими gap | Каждая новая функция добавляет слой | §8.3, Phase 2 |
| S5 | Три типографические системы + четыре HTML-карты | `displayTitle(38/36)` vs `headlineLarge w700` vs `ReaderContextHeader 27`; style maps в Ora/Readings/Prayer/ReadingDetail | Корни и документы выглядят как разные продукты | §6.1, Phase 1/4 |
| S6 | Граница материал/контент размыта | `GlassSurface` в search dock и legacy; модальный контент в `AdaptiveChromeSurface` | Две ОС получают не то, что обещано | §9, Phase 2/5 |
| S7 | Дублирующие компоненты chrome | `FloatingTopActions` / `ReaderChrome` / `AdaptiveAppBar`; 5 круглых кнопок | Расхождения неизбежны при каждом изменении | §10 |
| S8 | Шрифты из сети | `google_fonts` без assets | Офлайн-книга без своей гарнитуры | Phase 1 |
| S9 | Бренд не является частью системы | Три имени, иконка-иллюстрация, web Flutter-icon, шаблонный splash | Первое впечатление противоречит интерфейсу | §6.8, Phase 6 |
| S10 | Жестовая модель не определена | swipe даты, swipe глав, double-tap fullscreen, edge-back | Конфликты с выделением и системными жестами | §8.6 |

#### Cosmetic issues

- Подписи dock `10.5` при DL-минимуме 12.
- `'· · ·'` с `letterSpacing: 6` как окончание часа — уместный книжный жест,
  но стоит заменить на типографский «колофон» из токенов.
- `Divider indent 54` в списке часов при иконке 44 + gap 6 = 50.
- Stage 7 P2-01: `БЕЛ/РУС` на Android `SegmentedButton` переносятся.
- Разные подписи одной сущности: таб «Літургія», корень «Літургія
  гадзін», кнопка закрытия alternatives sheet «Літургія», стартовый раздел
  «Літургія», в документах — «Гадзіны».
- В `_PrayerListPage` subtitle без стиля (`TextStyle(color:)`), в соседних
  экранах — `bodyMedium`.
- `SegmentedButton` БЕЛ/РУС в Bible header на сером page-фоне, а текст — на
  ivory reader; видимая граница цвета между header и страницей
  (`bible-palette.png`).
- В Songbook uppercase-названия из данных соседствуют с Sentence case.
- Плитка «Сакрамэнты · Хутка» с полноценным визуальным весом.
- Строка Bible: первый стих центрирован иначе, чем последующие
  (`bible-palette.png`).

### 3.4 Документация дизайн-системы: состояние

#### Хорошо задокументировано

- Платформенная граница chrome (`platform-design.md`), роли поверхностей и
  инварианты чтения (DL 1.1 §0.2, §3, §5).
- Семантика литургического текста: роли, psalm/antiphon/responsory, PWA
  parity (`liturgical-reader-final-review.md`).
- Навигационная архитектура и Back (`app-shell-migration.md`).
- Модель данных и поведение Спеўніка/Кампендыя, offline-sync.
- Литургические семейства цветов marker/ink/tint (DL 1.1 §2.2) и контраст
  (verify-mobile-design-tokens.mjs, 100 проверок).

#### Существует только неявно в коде

- Шкала радиусов, размеры кнопок chrome, отступы корней (20/22/24),
  top/bottom insets.
- UI type scale корней и списков (`headlineLarge w700`, `titleLarge w700`
  для секций, uppercase labelSmall).
- Правила Full/Compact/Hidden для каждого маршрута (`AppRouteDescriptor` в
  `router.dart`) — описаны в Stage 2, но актуальная таблица есть только в коде.
- Contextual bottom slot (`requestContextualBottomSlot`) — механизм есть,
  правила владения нет.
- Swipe-навигация, scroll-to-top, double-tap.
- Цвет «сердца», акцент Малітоўніка (`cs.tertiary`).
- Мова Імшы и навигатор разделов (кратко в `prayerbook-migration.md`).

#### Расхождения документации и реализации

| Тема | Документ | Реализация | Решение vNext |
| --- | --- | --- | --- |
| Корневая навигация | DL 1.1: 3 раздела через SectionSwitcher + LiturgicalNavigationDock | 4 таба в `AppNavigationDock` (по UX handoff) | 4 таба — канон; SectionSwitcher и LiturgicalNavigationDock из DL 1.1 **отменены** |
| Ambient | DL 1.1: обязательный mist-indigo `#706FA8/#7166CB`, alpha 0.16/0.24 | `AmbientBackdrop` нейтрально-серый `#C8CAC3`, alpha 0.09/0.11 + сезонный `AmbientWash` | Нейтральный тёплый ambient — канон; mist-indigo отменён; сезонный wash только в зоне контекста дня (§6.2) |
| Seasonal wash | DL 1.1: «исключён» | `AmbientWash` сезона на Hours root, Ora, Readings, Settings | Разрешён только Hours root + Ora context header |
| `ColorScheme.primary` | DL 1.1 инвариант 2: сезон не меняет primary | `OraScreen` делает `primary: seasonColor` | Убрать |
| Цвет по эвристике текста | DL 1.1 §2.2: запрещено | `liturgicalColorForDay` по словам | `LiturgicalContextVisual` (Phase 1) |
| Reader body | DL 1.1: 18/1.60, Aa 0.85–1.60 | 16/1.68, Aa 0.7–1.8 | 17/1.64, Aa 0.85–1.60 (с миграцией, §6.1) |
| Выбор гарнитуры | Stage 7/9: убрать, только размер; DL 1.1: «Кніжны/Сістэмны» | 3 гарнитуры: Literata, System, Source Serif 4 | Сохранить 3 варианта в Aa sheet; канонизировать |
| Шрифты offline | DL 1.1 и token policy: bundle, без runtime download | `google_fonts` из сети | Bundle (Phase 1) |
| `blockHeader` | DL: System 14 semibold rubric | `ReaderTheme.blockHeading`: serif 1.10B min 18 rubric | Serif 1.0B 600 rubric (§6.1) |
| Uppercase | DL §1.1: «текст не переводится в uppercase» | uppercase eyebrow/labels в 14 файлах | Sentence case + малый кегль |
| Glass на Android | `platform-design.md`: GlassSurface не для chrome, Android без glass | `PrayerSearchDock`, legacy screens | Только через `ChromeSurface` |
| Модальный контент | DL §4.11: opaque content | Hours date/alternatives sheets в `AdaptiveChromeSurface` | `AppSheet` opaque |
| Radius | DL §1.4: 8/12/16/20/20/28 | 16 значений | §6.5 |
| Top bar | DL: iOS 56 / Android 64 min, Back + ≤2 actions | 48-высота ряда, кнопки 48/52 | §6.4, §8.2 |
| Dock labels | DL: 12 | 10.5 | 12 |
| Swipe | DL §4.4a + handoff: не нужен swipe по тексту для смены дня | Readings root reader, Hours root | Только для последовательных документов (§8.6) |
| `platform-design.md` | «AppBottomNav, ReadingsBottomNav» | Таких классов нет (удалены в Stage 8) | Документ архивировать/переписать |
| Tokens JSON | «handoff data, не импортируется» | Ни одного `ThemeExtension` | Код — источник; JSON генерируется (§11) |
| Bible в Малітоўніку (library-design) | Крупный вход в Біблію внутри библиотеки | Біблія — отдельный таб | library-design.md архивировать |
| Имена | Документы: «Гадзіны» | Таб «Літургія» | Выбрать одно (рекомендуется «Літургія», корень «Літургія гадзін» → см. §8.1) |

#### Где экраны фактически следуют разным дизайн-системам

| Система | Экраны | Признаки |
| --- | --- | --- |
| **A. «Книга» (Stage 3–6)** | Hours root, Ora, Readings, Bible, Prayer Detail, Song Detail, Compendium readers | `ReaderScaffold`, Cormorant/Literata, ivory surface, `ReaderChrome` |
| **B. «Каталог» (Stage 5 + Songbook/Compendium)** | Prayerbook root, All/Category/Search, Songbook, Compendium root/part, Sacraments placeholder | `AmbientWash(cs.tertiary)` + `ListView` + `FloatingTopActions` 52, системный `headlineLarge w700`, search dock с `GlassSurface` |
| **C. «Legacy glass»** | Favorites, My Prayers, Prayer Form, Liturgical Picker, Day Options, Hora Picker, Settings, About | `AdaptiveAppBar`, `GlassSurface`/`_NeutralContentSurface` карточки, Dropdown/ExpansionTile |

vNext сводит A и B в одну систему («страница» + «рамка») и выводит C из
употребления.

---

## 4. UX Architecture

### 4.1 Информационная архитектура

```text
iBreviary
├─ Літургія (branch: hours)                 ← центр продукта
│  ├─ Контекст дня: дата ▾ · празднаванне · варыянты · шаблон
│  ├─ Гадзіны: Invit · Officium · Laudes · Tertia · Sexta · Nona · Vesperae · Completorium · Morning
│  │  └─ Reader: Ora  (→ «Чытанні дня» с переносом даты)
│  └─ Дадаткова: Пошук дня/свята (LiturgicalPicker), календар
├─ Чытанні (branch: readings)                ← root = reader
│  ├─ Контекст: дата ▾ · набор · цыкл (Варыянты)
│  └─ Документ: I чытанне · Псальм · II чытанне · Акламацыя · Евангелле
├─ Малітоўнік (branch: prayerbook)           ← полка книг
│  ├─ Абраныя (малітвы; позже — любые документы)
│  ├─ Кнігі: Святая Імша · Спеўнік · Катэхізіс · (Сакрамэнты)
│  ├─ Катэгорыі → спіс → малітва
│  ├─ Усе малітвы / Пошук
│  └─ Мае малітвы (секундарна)
├─ Біблія (branch: bible)                    ← root = последнее место
│  └─ Кніга/раздзел ▾ · пераклад · пошук · вылучэнні
└─ Вторичное меню (корни): Налады · Сінхранізацыя · Інфармацыя
```

### 4.2 Уровни

| Уровень | Что это | Top chrome | Нижний слот |
| --- | --- | --- | --- |
| L0 Shell | 4 ветки | — | Dock (Full) |
| L1 Root | Корень ветки | Меню слева, ≤2 действия справа | Dock Full (Readings/Bible → Compact при чтении) |
| L2 Collection | Спеўнік, Кампендый, категория, все молитвы, поиск | Back, ≤1 действие | Search dock **или** Dock Full |
| L3 Document | Ora, Reading, Prayer, Імша, Song, Question, Chapter | Back, ≤2 действия + Aa + overflow | Reader bar (Compact dock + локальная навигация) |
| L4 Task | Sheets, picker, настройки | Системная presentation | — |

**Правило роста:** новая функция добавляется как *книга* (строка на
полке L1 Малітоўніка) или как *действие документа* (overflow/sheet на L3).
Новый таб, новая постоянная панель или новый floating-элемент требуют
отдельного дизайнерского решения и пересмотра этого документа.

### 4.3 Связи между ветками

- **Ora → Чытанні дня**: существующий return token — канон.
- **Чытанні → Парадак Імшы** (новое, рекомендуется): context action в
  header Чытанняў «Парадак Імшы» открывает Імшу в ветке Малітоўніка.
  Імша и чтения дня используются вместе; перекрёстная ссылка лучше, чем
  новый таб.
- **Імша → Чытанні дня** (обратная ссылка из раздела «Літургія слова»):
  опционально, Phase 4.
- Перекрёстные переходы — только явные подписанные действия; никаких
  неявных соответствий.

---

## 5. Design Principles

1. **Страница важнее рамки (Page over chrome).** Текст всегда на
   непрозрачной книжной странице; всё, что не текст, — тоньше, тише и
   исчезает при чтении.
2. **Цвет — это закладка, а не краска (Color as ribbon).** Литургический
   цвет существует только как маркер контекста; интерфейс нейтрален.
   Рубрика — единственный постоянный цвет внутри текста.
3. **Типографика и есть интерфейс (Typography is the interface).**
   Иерархия создаётся кеглем, весом, интервалом и одной книжной гарнитурой,
   а не карточками, иконками в квадратах и uppercase.
4. **Одно место — одна роль (One slot, one owner).** Внизу — один
   плавающий элемент; вверху — одна полоса chrome; у каждой зоны один
   владелец отступов.
5. **Сегодня — по умолчанию, всё остальное — на шаг глубже (Today first,
   depth on demand).** Даты, празднования, циклы, языки, шаблоны — во
   вторичных sheets с видимым состоянием «зменена/па календары».
6. **Одна система, два выражения (One system, two expressions).**
   Геометрия, шкалы, семантика и иконки — общие; материал, жесты,
   presentation и системные контролы — платформенные.
7. **Тишина как качество (Quiet by default).** Нет постоянной анимации,
   бейджей, счётчиков, ярких состояний offline; нет религиозного декора.
   Каждый визуальный элемент должен объяснять, зачем он.
8. **Книга всегда с собой (Offline is normal).** Установленный текст и
   его гарнитуры работают без сети и не сопровождаются предупреждениями.

---

## 6. Visual Language

### 6.1 Typography

#### Гарнитуры

| Роль | Гарнитура | Где |
| --- | --- | --- |
| `book` | **Literata** (default), варианты: Source Serif 4, системный | Текст документа, заголовки документа, заголовки страниц |
| `display` | **Cormorant Garamond** 600 | Только заголовок страницы уровня L1/L2 (≥30) и титул празднования на корне Літургіі |
| `ui` | Системная (SF Pro / Roboto/Google Sans по ОС) | Контролы, списки, метаданные, dock, sheets |
| `mono` | системный monospace | Только аккорды Спеўніка |

Правила:

- **Литература и Cormorant упаковываются в assets** (Regular, Italic,
  SemiBold, SemiBold Italic; Cormorant — SemiBold/Bold), `google_fonts`
  переводится в режим `allowRuntimeFetching = false`. Проверочная строка
  глифов из `reader-typography-vnext.md` остаётся.
- Выбор гарнитуры документа (`ReaderFontFamily`) остаётся в Aa-sheet и
  Наладах — три варианта, не больше. Он меняет только `book`, не
  `display` и не UI.
- **Uppercase запрещён** для текстов, которые создаёт приложение.
  Вместо uppercase-eyebrow — `ui.overline`: 13, w600, letterSpacing 0.2,
  Sentence case, цвет `inkMuted` или `liturgical.ink`.
- Данные с CAPS (названия песен) нормализуются только в отображении
  списка, если это не аббревиатура — решение для Phase 4, с тестами.

#### Шкала UI (системный шрифт)

| Token | iOS | Android | Применение |
| --- | --- | --- | --- |
| `ui.pageTitle` | display 34/1.10 (Cormorant 600) | display 32/1.12 | Заголовок L1/L2 в контенте: «Малітоўнік», «Спеўнік», «Літургія гадзін» |
| `ui.sectionTitle` | 20/1.25 w600 | 20/1.30 w500 | «Абраныя», «Кнігі», «Катэгорыі» |
| `ui.title` | 17/1.29 w600 | 18/1.33 w500 | Строка списка первого уровня, заголовок sheet |
| `ui.body` | 17/1.41 w400 | 16/1.50 w400 | Обычные строки, описания |
| `ui.secondary` | 15/1.33 w400 | 14/1.43 w400 | Подпись строки, метаданные |
| `ui.overline` | 13/1.30 w600 | 12/1.33 w600 | Над заголовком: дата, коллекция |
| `ui.dockLabel` | 12/1.0 w500/600 sel | 12/1.0 w500/700 sel | Подписи dock |
| `ui.caption` | 12/1.33 | 12/1.33 | Источник, copyright |

Все UI-размеры проходят системный `TextScaler`; Aa на них не влияет.

#### Шкала чтения (Literata; `B` = пользовательский body)

Default `B = 17` (было 16). Aa: 0.85–1.60 × 17 ≈ 14.5–27.2, шаг 0.05.
Миграция: сохранённые абсолютные `fontSize` остаются как есть (не
увеличивать текст скрыто); новые установки получают 17. Контроль Aa
показывает процент от 17.

| Роль | Размер | Высота | Вес / стиль | Цвет | Интервалы (до/после, в B) |
| --- | --- | --- | --- | --- | --- |
| `reader.docTitle` | 26 (system-scaled, не Aa) | 1.20 | Literata 600 | ink | — / 0.4 |
| `reader.docSubtitle` | 17 | 1.40 | Literata 400 italic | inkMuted | — |
| `reader.majorHeading` (час внутри Morning, R1/R2, «Літургія слова») | 1.15B | 1.28 | 600 | ink | 1.6 / 0.6 |
| `reader.blockHeading` (Гімн, Псалмодыя, Просьбы, Малітва) | 1.00B | 1.30 | 600 | rubric | 1.4 / 0.5 |
| `reader.body` | B | 1.64 | 400 | ink | абзац 0.65 |
| `reader.psalm` | B | 1.64 | 400, hanging indent 0.85B | ink | строфа 0.85 |
| `reader.hymn` | B | 1.70 | 400 | ink | строфа 0.9 |
| `reader.antiphon` | B | 1.60 | 600 | ink, label rubric | 0.8 / 0.9 |
| `reader.response` (℟, Н.) | B | 1.64 | 600 | ink, маркер rubric | — |
| `reader.rubric` | 0.90B | 1.48 | 400 italic | rubric | 0.6 / 0.6 |
| `reader.rubricInline` | = текст строки | = | italic | rubric | — |
| `reader.reference` | 0.88B | 1.40 | 600 | inkMuted | 0.2 / 0.5 |
| `reader.metadata` | ui.secondary | 1.42 | ui | inkMuted | — |
| `reader.verseNumber` (Біблія) | 0.62B, superscript | — | 600 | inkFaint | — |
| `reader.colophon` (конец часа) | 0.9B | — | «✝» или «· · ·» | inkFaint | 2.0 / 0 |

Правила ритма:

- Соседние интервалы схлопываются до максимума (collapse), не суммируются.
- Ширина текстовой колонки: **≤ 36 em** (≈ 612 при B=17, 660 максимум);
  `ReaderScaffold.maxContentWidth` → вычисляемая от B, а не фиксированные 700.
- Поля: 20 на телефоне ≥360, 16 <360, 24+ на планшете.
- Выключка — только влево, без justify и без hyphenation.
- Минимумы ролей (`clamp`) применяются до TextScaler — как сейчас в
  `ReaderTheme`, но от одной таблицы.

**Ответ на вопрос брифа.** Приложение станет «почти хорошо свёрстанной
литургической книгой», когда: (1) заголовок документа будет набран той же
Literata, что и текст; (2) uppercase-метки заменятся спокойными
overline; (3) все четыре HTML-рендерера будут брать роли из одной
`ReaderTextStyles`; (4) корни будут начинаться с одного «титула» страницы
одной гарнитурой; (5) шрифты станут локальными.

### 6.2 Color

#### Нейтральная основа (значения — палитра commit `1540a7d`, упорядоченная)

| Token | Light | Dark | Сейчас в коде |
| --- | --- | --- | --- |
| `color.page` | #F2F1EE | #0F110F | `AppPalette.*Background` |
| `color.reader` | #FDFCF9 | #171917 | `ReaderTheme.surface` |
| `color.surface` (группа списка, sheet) | #F8F8F5 | #171917 | `*Surface` |
| `color.surfaceRaised` (tile, выделенный блок) | #FEFDFB | #20231F | `*SurfaceBright` |
| `color.floating` (chrome Android, dock) | #E6E5E0 | #292C28 | `*SurfaceVariant` |
| `color.ink` | #20211F | #E9ECE7 | `*OnSurface` |
| `color.inkMuted` | #5F625C | #AEB3AB | `*OnSurfaceVariant` / `ReaderTheme.muted` (слить) |
| `color.inkFaint` (номера стихов, disabled icon, колофон) | #8A8C86 | #7C8179 | нет — сейчас alpha |
| `color.separator` | ink α0.10 | ink α0.14 | `outlineVariant` α0.22 от muted |
| `color.outline` (поля ввода, фокус) | #8A8C86 | #8E948C | α0.55 от muted |
| `color.accent` (primary action, выбранный таб) | #242522 | #E8EBE6 | `*Primary` |
| `color.onAccent` | #FFFFFF | #191B18 | `*OnPrimary` |
| `color.rubric` | #9B302A | #EF9188 | `*Rubric` |
| `color.rubricTint` | #F6ECEA | #2E2220 | `ReaderTheme.rubricSoft` (alpha) |
| `color.error` | #A52F2F | #FFB4AB | `0xFFBA1A1A` M3 default |
| `color.scrim` | black α0.32 | black α0.48 | M3 default |

Правила:

- Secondary/faint — **непрозрачные** цвета, не `withValues(alpha:)`
  от ink (кроме separator).
- `ReaderTheme` перестаёт хранить свои hex; читает `IbColors`.
- `primaryContainer`, `secondaryContainer`, `tertiaryContainer`
  заполняются непрозрачными значениями (`surfaceRaised` / `floating`), а не
  alpha-смешениями.
- `tertiary`/`devotional` удаляется как «акцент Малітоўніка»; нейтральные
  ветки используют `accent`.
- **Избранное** = заполненная иконка (heart или bookmark) цвета `ink`;
  красный `error` для избранного не используется.
- Dynamic color Android — выключен (как и сейчас).

#### Литургический цвет — «лента-закладка»

Источник — доменный `LiturgicalContextVisual(colorKey, label)` (DL 1.1
§2.2), а не `liturgicalColorForDay` с поиском по словам. Семейства и
значения marker/ink/tint берутся из DL 1.1 §2.2 без изменений: `green`,
`violet`, `whiteGold`, `red`, `rose`, `neutral`. Requiem/office for the dead
(сейчас `#67546B`) — отдельное решение владельца: `violet` или `neutral` с
подписью.

Бюджет (жёсткий):

| Разрешено | Где |
| --- | --- |
| `marker` — вертикальная лента 3×(высота блока), radius pill | Слева от празднования на корне Літургіі (`hours-celebration-accent`), слева от eyebrow в `ReaderContextHeader` Ora и Чытанняў |
| `ink` — одна короткая подпись | Период/ранг над названием празднования |
| `tint` — мягкий фон | Только выбранная строка в alternatives sheet |
| Сезонный ambient wash | Только корень Літургіі и context header Ora; alpha ≤0.08 light / ≤0.10 dark; не под текстом документа |
| Иконки часов | `ink` семейства — допустимо, т.к. это «иконка контекста на overview» |

Запрещено (с конкретными местами для исправления):

- `OraScreen._buildForDay` → `Theme(primary: seasonColor)` — удалить.
- `AdaptiveChromeSurface.seasonColor`, `GlassSurface.seasonColor`,
  `FloatingTopActions.seasonColor`, `AppNavigationDock.seasonColor` —
  удалить параметр; chrome всегда нейтрален.
- `AmbientWash` в `SettingsScreen`, Малітоўнік, Спеўнік, Кампендый,
  Біблія — удалить (остаётся нейтральный `AmbientBackdrop` оболочки).
- `ReaderScaffold.showAmbient` → по умолчанию `false`; включается только Ora.
- Марыйны синий как литургический цвет — только если владелец явно
  решит, что это локальная традиция; иначе `whiteGold`.

#### Dark mode

- Мягкий green-neutral charcoal (как сейчас), без pure black.
- Разница поверхностей — тоном, не тенью: тени chrome в dark ≤ α0.20,
  без двойной тени.
- `ReaderEdgeProtection`: верхний fade 40 (не 58) и только при Compact;
  нижний — убрать, когда внизу нет reader bar (Hidden). Главный способ
  защиты — непрозрачная полоса под chrome на iOS (scroll edge), тон
  `floating` на Android.
- Рубрика `#EF9188` на `#171917` — 7.6:1; `#9B302A` на `#FDFCF9` — 7.2:1;
  body `#20211F` на `#FDFCF9` — 15.8:1. Сохранить.

### 6.3 Surfaces и depth

Иерархия (одинакова на обеих ОС по ролям):

```text
page (ambient, нейтральный)      ← фон корней и коллекций
 └─ reader (opaque, radius 0)    ← документ; всегда edge-to-edge по ширине колонки
 └─ surface (group)              ← одна группа списка / sheet; radius 16/28
     └─ surfaceRaised (tile)     ← редкий выделенный блок; radius 22; без тени
floating (chrome)                ← dock, top buttons, reader bar, search dock; pill
modal (sheet/dialog)             ← opaque surface; radius 28 top
```

Правила:

- **Одна поверхность на смысловую группу.** Список — одна группа или
  plain-rows на page; карточка вокруг каждой строки запрещена.
- **Card (surfaceRaised)** — только для навигационных «книг» на полке
  Малітоўніка и выделенного блока «Працягнуць» (если появится). Без
  обводки в light (разница тона), hairline в dark.
- **Тени**: только у `floating`. L2: `0,4 / 16 / −4`, α 0.10 light / 0.20
  dark. Обводка floating на Android убирается (tonal separation), на iOS —
  hairline 0.5.
- **Glass**: только iOS, только `floating`, только через `ChromeSurface`.
  Модальный контент, списки и плитки — непрозрачны на обеих платформах.
- Максимум 2 blur-группы на экране (верх + низ).

### 6.4 Spacing

Шкала: **4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 64**.

| Token | Значение | Назначение |
| --- | --- | --- |
| `space.xxs` | 4 | иконка ↔ подпись в dock, связанные метки |
| `space.xs` | 8 | элементы внутри группы контролов, eyebrow ↔ title |
| `space.sm` | 12 | padding контрола, gap иконка ↔ текст в строке |
| `space.md` | 16 | вертикальный padding строки, поля <360 |
| `space.lg` | 20 | поле страницы ≥360, отступ секций внутри корня |
| `space.xl` | 24 | padding sheet, заголовок страницы → первая секция |
| `space.2xl` | 32 | между секциями корня |
| `space.3xl` | 40–48 | конец документа, пустые состояния |

**Владелец отступов — `ChromeInsets`** (новый InheritedWidget в оболочке):

- `top = safeTop + topChromeHeight` (56 + 8 gap), доступно как
  `ChromeInsets.of(context).top`;
- `bottom = safeBottom + bottomSlotHeight + gap`, пересчитывается при смене
  владельца слота и клавиатуре;
- экран никогда не прибавляет `76/78/90/104/116/120/128/152` вручную.

### 6.5 Radius

| Token | Значение | Использование | Заменяет |
| --- | --- | --- | --- |
| `radius.none` | 0 | reader, page | — |
| `radius.xs` | 4 | skeleton, подсветка стиха | 2 |
| `radius.sm` | 10 | chip внутренний, inline-выделение, CompendiumBadge | 8, 10, 12, 14, 15 |
| `radius.md` | 16 | строка/группа списка, InkWell строки, selection | 16, 17, 18 |
| `radius.lg` | 22 | tile/card, поле ввода в форме | 20, 22, 24 |
| `radius.xl` | 28 | sheet top corners, dialog | 28, 30 |
| `radius.pill` | height/2 | все floating: кнопки chrome, dock, reader bar, search, chips | 24/28/30/32 для капсул, 99, 999, `StadiumBorder` |

Floating-элементы всегда pill — на обеих ОС. Вложенный радиус
`inner = outer − inset`.

### 6.6 Iconography

- **Предметные иконки** — Phosphor Regular (выбранное/сохранённое
  состояние — Fill). Не смешивать с Material в одной группе.
- **Системные глифы** (Back, overflow, chevron, close, check, search) —
  через `AppIcons` resolver:
  iOS — `CupertinoIcons.back`, `ellipsis`, `chevron_right`, `xmark`;
  Android — `Icons.arrow_back`, `more_vert`, `chevron_right`, `close`.
  Сейчас overflow в reader — `more_horiz_rounded` на обеих ОС.
- **Размеры**: `icon.chrome 22`, `icon.row 20`, `icon.inline 16`,
  `icon.empty 40`. Target всегда ≥48.
- **Иконки в квадратах/кругах-подложках** (`PrayerbookSectionTile` 40×40
  radius 14) — убрать: иконка стоит на поверхности сама.
- Иконки часов (`kHoraItems`) — сохранить, это удачная система (солнце,
  луна и т.д.).
- Крест `PhosphorIconsRegular.cross` у Сакрамэнтаў — единственный
  религиозный символ в UI; допустим как предметная иконка, не как декор.

### 6.7 Motion

| Событие | Длительность / кривая | Примечание |
| --- | --- | --- |
| Push/pop документа | Платформенный (Cupertino / predictive back) | Заменить `_ShellFadePage` для не-root маршрутов |
| Смена таба | без анимации содержимого (IndexedStack) | Dock: индикатор 180 ms easeOutCubic |
| Full ↔ Compact dock | 200 ms easeOutCubic, cross-fade + ширина | Без изменения scroll geometry |
| Смена даты на корне | `LiturgicalDayTransition` ≤200 ms fade/slide 12 px | При reduce motion — мгновенно |
| Sheet | Системный | Custom fallback 280 ms |
| Нажатие | системный ripple/highlight | iOS без splash (как сейчас) |
| Избранное | смена Regular→Fill без масштабирования | один `selectionClick` |
| Aa | без анимации текста | сохранить anchor |

`AmbientWash` `AnimatedContainer 700 ms` — сократить до 200 ms или убрать.
`reduceMotion || disableAnimations` отключают всё кастомное движение и
`TileShimmer`.

### 6.8 Brand, иконка, splash

- **Знак**: минималистичный — раскрытая страница (ivory) и одна вертикальная
  лента-закладка цвета `rubric` на графитовом или ivory поле. Без голубя,
  лучей, креста, иллюстративной фактуры. Лента связывает знак с
  интерфейсом (§6.2).
- **iOS**: full-bleed 1024 без собственного squircle и полей (маску делает
  система). Отдельные варианты Dark и Tinted (iOS 18+).
- **Android**: adaptive icon (foreground + background layers) и monochrome
  layer для themed icons; не PNG со встроенной формой.
- **Splash**: `color.page` (light) / `color.page` dark + знак 96 dp;
  Android 12+ SplashScreen API; iOS LaunchScreen c тем же цветом. Нет
  белой вспышки в тёмной теме.
- **Web**: заменить Flutter-иконки; `theme_color` = `color.page`,
  `background_color` = `color.page`; единое имя.
- `assets/logo.png` (жёлтый/синий) и `assets/mary.png` — не
  использовать как бренд; `mary.png` может остаться в «Інфармацыі» как
  контентная иллюстрация, если владелец так решит.

---

## 7. Content Reading System

Все длинные тексты — Ora, Чытанні, Малітва, Імша, Песня, Пытанне/Тэма
Кампендыя, Раздзел Бібліі — строятся из одного набора зон.

### 7.1 Анатомия

```text
┌──────────────────────────────────────────┐
│ [‹]                        [★] [Aa] [⋯]  │  TopChrome (reader): Back + ≤2 actions + Aa + overflow
│                                          │
│ ▌ 29 верасня · Звычайны перыяд           │  ReaderContextHeader: ribbon + overline
│   Ютрань  ▾                              │  docTitle (Literata 600, tap = HourChooser / BookPicker)
│   Св. арханёлаў Міхала, Габрыэля…        │  docSubtitle
│   Тыдзень псалтыра II · Свята            │  metadata (ui.secondary)
│   [Чытанні дня]  [BE ▾]                  │  context actions (≤2, text buttons)
├──────────────────────────────────────────┤
│                                          │
│   Гімн                                   │  blockHeading (rubric)
│   Варыянт 1 з 3 ▾                        │  AlternativeSelector
│   Тэкст гімна…                           │  body / hymn
│   …                                      │  ReaderContentSurface (opaque)
│                   ✝                      │  colophon
├──────────────────────────────────────────┤
│   ( ▣ )  ‹  Ютрань · Псалмодыя ▾  ›      │  ReaderBottomBar: branch handle + local nav
└──────────────────────────────────────────┘
```

### 7.2 Зоны и владельцы

| Зона | Компонент | Правила |
| --- | --- | --- |
| Top chrome | `TopChrome.reader` (замена `ReaderChrome`) | Back (платформенный глиф) слева; справа — одна `ChromeActionGroup` (капсула), в ней ≤2 документных действия + Aa; overflow — отдельная кнопка. Кнопки 48, группа pill. При скролле вниз (Compact) остаётся та же полоса — не прятать Back |
| Compact title | в TopChrome, между Back и группой | Появляется, когда `docTitle` ушёл за верх; `ui.title`, 1 строка |
| Context header | `ReaderContextHeader` | Не часть документа, но на той же `reader`-поверхности (устраняет границу серый/ivory Bible header). Ширина = ширина колонки текста, выравнивание по левому краю колонки (Stage 7 P2-02) |
| Document | `ReaderContentSurface` + `LiturgicalTextRenderer` | Одна таблица ролей §6.1; `Html` style map строится одной фабрикой `ReaderHtmlStyles.of(context, B, family)` |
| Bottom | `ReaderBottomBar` в нижнем слоте оболочки | §7.3 |
| Sheets | `ReaderAppearanceSheet`, `ReaderOutlineSheet`, `ReaderChoiceSheet` | Opaque, radius 28, системная presentation |

### 7.3 Reader bottom bar — объединение локальной навигации с compact dock

Сейчас внизу документа могут одновременно быть: compact dock,
`_MassNavigatorBar`, `_ChapterNavBar`, `_ReaderScrollToTopControl`,
`CompendiumPager`. vNext: **одна капсула**.

```text
( ▣ │ ‹ │  Уводзіны · Пакаянны акт  ▾ │ › )
  │    │              │                 │
  │    │              │                 └ следующий раздел / глава / вопрос (если есть последовательность)
  │    │              └ текущий раздел документа → ReaderOutlineSheet
  │    └ предыдущий
  └ «ручка» ветки: иконка активного таба; tap → раскрыть Full dock (как `_CompactDock` сейчас)
```

- Компонент: `ReaderBottomBar(branch, outline?, onPrevious?, onNext?)`.
  Без `outline` и последовательности — это просто текущий `_CompactDock`.
- Глобальная и локальная навигация визуально различаются: «ручка» — только
  иконка ветки в круге `accent`-тона; локальная часть — текст документа.
  Никаких четырёх иконок одновременно с разделами документа.
- В `Hidden` (фокус) скрывается вместе с top chrome; остаётся одна
  видимая кнопка «Паказаць панэлі» (как сейчас в Prayer Detail).
- Scroll-to-top удаляется: «Да пачатку» — первый пункт `ReaderOutlineSheet`;
  iOS — tap по status bar.

### 7.4 Специализация по типам документа

| Документ | Top actions | Context actions | Bottom bar | Outline sheet | Особое |
| --- | --- | --- | --- | --- | --- |
| **Ora** | Aa | «Чытанні дня» | ‹ час › (соседний час того же дня) + текущий блок ▾ | Блоки часа (Гімн, Псалмодыя, Кароткае чытанне…) | Title ▾ = HourChooser; biography свёрнута до 3 строк (Stage 7 P2-04) |
| **Чытанні (root)** | Aa | Дата ▾, «Варыянты» (набор/цыкл, «зменены»), «Парадак Імшы» | Раздел ▾ (I чытанне, Псальм, …); без ‹ › по датам | Разделы чтений | Swipe даты удалить; дата меняется через header |
| **Малітва** | ★, Aa | — | Только ручка | Нет (короткий текст) | Edit local — overflow |
| **Святая Імша** | ★, Aa | **Мова: BE ▾** (или сегментированный BE/LA/EN в header) | ‹ раздел › + текущий раздел ▾ | Иерархия разделов (`_MassSectionsSheet`) | Язык переходит в header — это свойство документа, а не навигация; `_MassNavigatorBar` удаляется |
| **Песня** | ★, Aa | Акорды on/off, транспонирование в header (только если акорды есть) | Ручка | Нет | Налады спеўніка — overflow; mono для аккордов |
| **Кампендый: пытанне/тэма** | Aa | «Уся тэма» | ‹ пытанне › + № ▾ | Вопросы темы | `CompendiumPager` удалить из документа |
| **Біблія: раздзел** | Пошук, Aa | Пераклад BEL/RUS (сегмент), кніга ▾ | ‹ раздзел › + «Роду 1 ▾» | Book/Chapter picker | Selection palette заменяет bar (как сейчас заменяет dock) |

### 7.5 Aa — «Выгляд тэксту»

`ReaderAppearanceSheet` (переименование/расширение `TextScaleControl`
sheet): 1) размер (− slider +, % от 17, «Стандартны памер»); 2) гарнитура
(Кніжны · Literata / Source Serif 4 / Сістэмны) с живым превью на реальном
абзаце; 3) ссылка «Тэма…» в Налады. Live preference, Close только
закрывает. Не добавлять сюда язык Імшы и настройки аккордов.

### 7.6 Поиск внутри документа, закладки, избранное

- Поиск по тексту документа — не вводить до реального запроса
  пользователей (сейчас есть только Bible text-in-book). Outline sheet
  решает большую часть навигационной задачи.
- **Избранное** — единый `FavoriteToggle` (★/heart Fill + ink) для любых
  документов, где оно определено (молитвы, песни; позже — Імша как
  закреплённая, вопрос Кампендыя). Раздел «Абраныя» на корне Малітоўніка
  со временем показывает разнотипные документы с overline-типом («Спеў»,
  «Пытанне 42»).
- **Место чтения** — ключ документа + section/paragraph anchor (DL 1.1 §5.5);
  не pixel offset. Aa и смена гарнитуры сохраняют anchor.

### 7.7 Состояния

| Состояние | Представление |
| --- | --- |
| Loading (>200 ms) | Skeleton документа в той же колонке, без card shimmer; context header уже виден |
| Missing locally | `ContentStateView`: иконка 40, `ui.title`, пояснение, действие «Сінхранізаваць» |
| Not in corpus | Предметное сообщение + «Іншы варыянт» |
| Error | Кратко, без технической строки в UI (сейчас `OraScreen._errorState` показывает `e.toString()`) |
| Offline + ready | Без индикаторов |

Все состояния — внутри того же `ReaderScaffold` (сейчас loading/error Ora
используют `AdaptiveAppBar` + `AmbientWash` — другой chrome).

---

## 8. Navigation System

### 8.1 Глобальная

- 4 таба — **канон**: Літургія · Чытанні · Малітоўнік · Біблія. Подписи
  12, иконки Phosphor (Fill при выборе). Не добавлять пятый таб.
- Имена: таб «Літургія»; заголовок корня — «Літургія гадзін» (display).
  Во всех прочих местах (стартовый раздел, кнопка «Готова» в alternatives
  sheet — сейчас она подписана «Літургія») — единообразно. Кнопку
  закрытия alternatives sheet подписать «Гатова».
- Корни показывают **кнопку меню** слева. Чтобы она не выглядела как
  Back: глиф `list` + отсутствие обводки; на Android — tonal icon button,
  на iOS — plain glyph без капсулы (как nav-bar item). Back всегда в
  капсуле/круге.
- Вторичное меню: Налады · Сінхранізацыя · Інфармацыя — оставить sheet.

### 8.2 Top chrome

| Контекст | Слева | Центр | Справа |
| --- | --- | --- | --- |
| Root (Літургія, Малітоўнік) | Меню | — | ≤1 действие (Пошук) |
| Root-reader (Чытанні, Біблія) | Меню | compact title после скролла | Пошук?, Aa (группа) |
| Collection (L2) | Back | compact title после скролла | ≤1 (Фільтр) |
| Document (L3) | Back | compact title после скролла | Группа (★, Aa) + overflow |

Один компонент `TopChrome` с вариантами `root/collection/reader`
заменяет `FloatingTopActions`, `ReaderChrome` и `AdaptiveAppBar`. Высота
полосы 56 (+safe area), кнопки 48, gap между группами 8, боковые поля 12.

### 8.3 Нижний слот — арбитраж

Оболочка уже умеет подавлять dock (`requestContextualBottomSlot`).
Нужно превратить это в явную модель:

```dart
enum BottomSlotContent { dockFull, readerBar, search, selection, none }
```

| Маршрут | Default | Переходы |
| --- | --- | --- |
| Roots Літургія, Малітоўнік | `dockFull` | — |
| Чытанні root | `dockFull` → `readerBar` после начала чтения (порог 180 px, как сейчас) | selection → `selection` |
| Біблія root | `readerBar` | verse tap → `selection` |
| Collection со списком (Спеўнік, Все малітвы, Кампендый) | `search` (поле + фильтр); dock скрыт | back → предыдущий |
| Category, Categories, Sacraments | `dockFull` | — |
| Documents L3 | `readerBar` | focus → `none` + restore button |
| Keyboard открыт | `search` поднимается к IME + 12; прочие — `none` | — |

Правила геометрии: слот начинается на `safeBottom + 12`; высота dock 60,
reader bar 52, search 56, selection 56; `ChromeInsets.bottom` = слот +
12. Устраняет P2 runtime-check (IME +48, songbook tail, Bible tail,
compact/full −4 dp).

### 8.4 Навигация внутри документов

- Оглавление — `ReaderOutlineSheet` (обобщение `_MassSectionsSheet`):
  major/minor разделы, текущий отмечен check + selected, «Да пачатку»
  первым пунктом.
- Последовательности (Biblia chapters, Compendium questions, часы дня,
  разделы Імшы) — стрелками в reader bar.
- Вариант/альтернатива — локально у блока (`AlternativeText`), как сейчас.

### 8.5 Back

Сохраняется порядок `app-shell-migration.md` §6: sheet → selection →
focus → pop branch → return token → platform. Добавить: reader bar
«раскрытый dock» закрывается Back до pop.

### 8.6 Жесты

| Жест | Решение |
| --- | --- |
| Horizontal swipe для смены **даты** (Hours root, Readings root) | Убрать из Readings (текст, выделение). На Hours root оставить (это список, не текст) — или убрать для единообразия; рекомендуется убрать, т.к. date sheet уже даёт «Папярэдні/Наступны» |
| Horizontal swipe для **последовательных документов** (Біблія, Кампендый) | Оставить; дублируется ‹ › в reader bar |
| Double-tap fullscreen на тексте | Убрать; вход — overflow «Чытаць без панэляў», выход — видимая кнопка |
| iOS edge-swipe back / Android predictive back | Обязательны; проверить с `HorizontalSwipeNavigation` (не начинать swipe ближе 24 px к краю) |

### 8.7 Поиск — единый паттерн

- **Коллекции** (Малітвы, Спеўнік, Кампендый, позже Біблія): `AppSearchDock`
  в нижнем слоте — сейчас уже так у трёх коллекций; Біблія Search переводится
  на тот же паттерн (сейчас отдельный legacy-маршрут с другим chrome).
- Корень Малітоўніка: действие «Пошук» сверху → коллекция «Усе малітвы» с
  фокусом в dock (как сейчас `/prayers/search`).
- Результаты разнотипного поиска (молитвы + песни + вопросы) — не
  вводить до появления индекса; не обещать глобальный поиск.

---

## 9. iOS and Android Strategy

### 9.1 Абсолютно общее

Бренд, гарнитуры и шкалы, цветовые роли, литургическая семантика,
spacing/radius токены, иконки предметов (Phosphor), IA и порядок разделов,
состав chrome (какие кнопки где), содержимое sheets, поведение Back,
состояния, копирайтинг.

### 9.2 Platform expression

| Элемент | iOS — «лёгкий материал» | Android — «тональная плоскость» (M3 Expressive) |
| --- | --- | --- |
| Floating chrome | Glass (system material при появлении native bridge; до того `GlassSurface.pill` fallback: sigma 20, opacity 0.82/0.86, hairline 0.5, без specular в dark) | Opaque `color.floating`, без обводки, elevation-тень L2 |
| Кнопка Back | chevron `CupertinoIcons.back` 20 в круге 48 | `arrow_back` 24 в tonal круге 48 |
| Кнопка меню корня | plain glyph без круга | tonal icon button |
| Action group | Капсула с разделителем 0.5 | Капсула tonal, кнопки с ripple |
| Dock | Glass капсула, выбранный — тонкий круг `accent α0.12` | Tonal капсула, выбранный — M3 indicator pill `secondaryContainer`-роль |
| Sheet | `showCupertinoModalPopup`-стиль или системный sheet, opaque content | `ModalBottomSheet` с handle |
| Dialog | `CupertinoAlertDialog` | `AlertDialog` |
| Date picker | Месячная сетка в sheet (wheel — только fallback) | `showDatePicker` |
| Segmented | `CupertinoSlidingSegmentedControl` | `SegmentedButton` без check-иконки при ≤4 коротких сегментах |
| Switch/Slider | `.adaptive` | `.adaptive` |
| Dropdown в Наладах | Список-выбор в push/sheet | Material menu |
| Переходы | Cupertino push, edge back | Predictive back |
| Ripple | Нет (highlight) | InkSparkle |
| Scroll edge | Непрозрачная полоса под верхним chrome при скролле | Tonal «scrolled under» |

### 9.3 Правило

Платформенная ветка допустима только в компонентах слоя `chrome/` и
`presenter/`; экраны и reader не содержат `usesCupertinoGlass`. Сейчас
ветки есть в экранах (`home_screen` через sheet, `bible_chapter_screen`,
`settings_screen`) — вынести в компоненты.

---

## 10. Component System

Канонический набор. Колонка «Источник» — что существующее становится
основой (сохранить → переименовать/объединить).

### 10.1 Foundation

| Компонент | Назначение | Источник |
| --- | --- | --- |
| `IbTokens` (`ThemeExtension`) | Все токены §11 | `AppPalette`, `GlassTokens`, `ReaderTheme`, литералы |
| `LiturgicalContextVisual` + `IbLiturgical` | Семейство цвета из доменных данных | `liturgical_theme.dart` (эвристики удалить) |
| `ReaderTextStyles` | Роли §6.1 для plain и HTML | `ReaderTheme` + 4 style maps |
| `AppIcons` | Платформенные системные глифы | разрозненные `Icons.*` |
| `ChromeInsets` | Владелец top/bottom insets | `kFloatingAppBarContentInset`, `+78/+90`, `FloatingOverlayPositioned` |
| `MotionPolicy` | reduce motion, длительности | нет |

### 10.2 Chrome

| Компонент | Назначение | Источник |
| --- | --- | --- |
| `ChromeSurface` | Платформенный материал floating; **без seasonColor** | `AdaptiveChromeSurface` |
| `ChromeIconButton` | Единая круглая кнопка 48 | `_FloatingMenuButton`, `_FloatingTopButton`, `_ReaderChromeButton`, `_ChromeAction`, leading `AdaptiveAppBar` |
| `ChromeActionGroup` | Капсула 1–3 действий | `FloatingTopActions` surface, `AdaptiveAppBar` actions |
| `TopChrome` (root / collection / reader) | Верхняя полоса | `FloatingTopActions`, `ReaderChrome`, `AdaptiveAppBar` |
| `AppNavigationDock` | Full dock 4 разделов | сохранить; убрать seasonColor, подписи 12 |
| `ReaderBottomBar` | Compact dock + локальная навигация | `_CompactDock`, `_MassNavigatorBar`, `_ChapterNavBar`, `CompendiumPager`, `_ReaderScrollToTopControl` |
| `BottomSlot` | Арбитраж §8.3 | `requestContextualBottomSlot`, `FloatingOverlayPositioned` |
| `AppSearchDock` | Поиск коллекции | `PrayerSearchDock` (перевести на `ChromeSurface`) |
| `SelectionPalette` | Контекстная палитра | Bible `_colorBar`, Readings palette |

### 10.3 Page & lists

| Компонент | Назначение | Источник |
| --- | --- | --- |
| `AppPage` | Каркас L1/L2 списка: backdrop + `TopChrome` + scroll + `ChromeInsets` | повторяющийся `Stack(AmbientWash + ListView + FloatingTopActions)` в prayers/songbook/compendium/placeholder |
| `PageHeader` | `ui.pageTitle` + optional subtitle/overline | `Text(headlineLarge w700)`, `displayTitle(38)` |
| `SectionHeader` | `ui.sectionTitle` + optional action | `_SectionTitle`, uppercase labels Hours |
| `ListGroup` | Одна поверхность группы + separators | нет; Divider indent в `_HoursList` |
| `NavRow` | Строка перехода: [icon] title / subtitle [trailing] › | `_HourRow`, `_CategoryRow`, `_DestinationRow`, `CompendiumListRow`, song row |
| `ItemRow` | Строка документа с `FavoriteToggle` | `PrayerListRow`, song row |
| `FavoriteToggle` | ★/heart Fill, ink, 48 target | 3 реализации (rows, `_PrayerFavoriteControl`, songs) |
| `ShelfTile` | «Книга» на полке Малітоўніка | `PrayerbookSectionTile` (без icon-квадрата, без glass) |
| `ContentStateView` | empty / missing / error / notInCorpus | `_HoursMessage`, `PrayerbookPlaceholderScreen`, empty в Prayer/Ora |
| `ReaderSkeleton` / `ListSkeleton` | Загрузка | `TileShimmer`, `DataLoadingNotice` |

### 10.4 Liturgical context

| Компонент | Назначение | Источник |
| --- | --- | --- |
| `LiturgicalRibbon` | Вертикальный маркер 3 px | `hours-celebration-accent` |
| `DayContextHeader` | Дата ▾ + «Сёння» + празднование | `_DateHeader`, `_Celebration`, readings date header |
| `DateActionsSheet` | Сёння / ± день / календарь / пошук | `_showDateActions` (Hours и Readings) |
| `CelebrationChooser` | Alternatives + шаблон | `_AlternativesSheet`, `liturgical_day_options_screen` |
| `HourChooser` | Смена часа из title Ora | `_changeHour` |
| `AppDatePicker` | Платформенная дата | `ambient_date_picker.dart` (без GlassSurface на Android) |

### 10.5 Reader

| Компонент | Назначение | Источник |
| --- | --- | --- |
| `ReaderScaffold` | Каркас документа | сохранить; убрать `showAmbient` default, double-tap, scroll-to-top |
| `ReaderContextHeader` | Контекст документа | сохранить; title → Literata, eyebrow → overline + ribbon |
| `ReaderContentSurface` | Страница | сохранить; ширина от B |
| `LiturgicalTextRenderer` | HTML/plain → роли | `_renderHtml` Ora, Readings Html, Prayer `_buildContent`, ReadingDetail |
| `AlternativeSelector` | «Гімн · 2 з 4 ▾» | `AlternativeText` |
| `ReaderChoiceSheet` | Выбор (варианты, циклы, часы) | `showReaderChoiceSheet` + sheet в `AlternativeText` (слить) |
| `ReaderOutlineSheet` | Оглавление | `_MassSectionsSheet` |
| `ReaderAppearanceSheet` | Aa | `TextScaleControl` sheet |
| `FocusRestoreButton` | Выход из Hidden | существующий restore control |

### 10.6 Presenter

`AppSheet.show(...)`, `AppDialog.confirm(...)`, `AppPresenter.pickDate(...)` —
единая точка platform presentation (DL 1.1 §4.11); экраны не вызывают
`showModalBottomSheet`/`showCupertinoModalPopup`/`showDialog` напрямую (сейчас — 20 таких вызовов в 13 файлах).

---

## 11. Design Tokens

### 11.1 Архитектура

```text
lib/theme/tokens/
  ib_tokens.dart          // IbTokens extends ThemeExtension<IbTokens>
  ib_colors.dart          // IbColors.light / .dark  (§6.2)
  ib_liturgical.dart      // IbLiturgical families: marker/ink/tint × light/dark
  ib_space.dart           // IbSpace (§6.4) — const
  ib_radius.dart          // IbRadius (§6.5) — const
  ib_type.dart            // IbType.ui(platform) + IbType.reader(B, family)
  ib_chrome.dart          // размеры chrome
  ib_motion.dart          // длительности/кривые + reduce policy
lib/theme/app_theme.dart  // строит ThemeData + ColorScheme ИЗ IbColors
```

Доступ: `context.ib.colors.reader`, `context.ib.space.lg`,
`IbRadius.md`. Константы, не зависящие от темы (space/radius/chrome),
— `abstract final class` с `static const`, чтобы использоваться в
`const`-виджетах.

`docs/design/mobile-design-tokens.json` переходит в статус
**генерируемого артефакта** (скрипт экспорта из Dart) и продолжает
проверяться `verify-mobile-design-tokens.mjs` на контраст.

### 11.2 Словарь токенов

```text
color
  page reader surface surfaceRaised floating
  ink inkMuted inkFaint separator outline
  accent onAccent rubric rubricTint error errorTint scrim
liturgical.<green|violet|whiteGold|red|rose|neutral>
  marker ink tint
space
  xxs 4 · xs 8 · sm 12 · md 16 · lg 20 · xl 24 · 2xl 32 · 3xl 40 · 4xl 48 · 5xl 64
  gutter(width): <360 → 16 · <600 → 20 · else 24
radius
  none 0 · xs 4 · sm 10 · md 16 · lg 22 · xl 28 · pill 999
chrome
  target 48 · button 48 · topBar 56 · groupGap 8 · edge 12
  dockHeight 60 · readerBarHeight 52 · searchHeight 56 · slotGap 12
  dockMaxWidth 480 · iconChrome 22 · iconRow 20 · iconInline 16
elevation (floating only)
  light: y4 blur16 spread−4 α0.10 · dark: α0.20
  iosGlass: sigma 20 · opacity 0.82/0.86 · hairline 0.5
type.ui       pageTitle sectionTitle title body secondary overline dockLabel caption
type.reader  docTitle docSubtitle majorHeading blockHeading body psalm hymn antiphon
             response rubric reference metadata verseNumber colophon
reader
  bodyDefault 17 · scaleMin 0.85 · scaleMax 1.60 · scaleStep 0.05
  measureEm 36 · maxWidth 660 · paragraphGap 0.65B · strophe 0.85B · section 1.4B
motion
  press 90 · release 140 · disclosure 180 · chrome 200 · context 200 · sheet 280
  easeEnter easeOutCubic · easeExit easeInCubic
ambient
  neutralAlpha light 0.09 / dark 0.11 · seasonalMax light 0.08 / dark 0.10
```

### 11.3 Правила применения

- В `lib/screens` и `lib/widgets` запрещены: `Color(0x…)`,
  `BorderRadius.circular(<число>)`, `EdgeInsets` с числами вне токенов,
  `fontSize:` литералы. Исключения — внутри `lib/theme/`.
- Проверка — custom lint или простой тест-grep в CI
  (`test/design_tokens_usage_test.dart`), который постепенно ужесточается
  по мере миграции (allowlist файлов уменьшается).

---

## 12. Screen-by-Screen Observations

### Літургія — корень (`HomeScreen`)

+ Правильная композиция: дата ▾, «Сёння» только для другой даты, лента
  празднования, альтернативы с счётчиком, список часов с иконками.
− Два display-заголовка подряд: «Літургія гадзін» Cormorant 38 и название
  празднования Cormorant 29. − Uppercase «ЛІТУРГІЯ ГАДЗІН» над списком
  дублирует заголовок страницы. − Subtitle празднования uppercase w800.
− Date и alternatives sheets — контент внутри `AdaptiveChromeSurface`
  (glass на iOS, сезонный оттенок). − Кнопка закрытия sheet «Літургія».
− Swipe даты. − 116 bottom padding.
**vNext:** page title «Літургія гадзін» (display) → DayContextHeader (дата
`ui.title`, празднование Literata 600 24 + ribbon, overline период ·
ранг в `liturgical.ink`) → «Варыянты · N» → `ListGroup` часов. Убрать
uppercase-label; sheets — `AppSheet` opaque; tint только у выбранной
строки alternatives.

### Ora (`OraScreen`)

+ Непрозрачный документ, семантические роли, HourChooser из title,
  «Чытанні» как context action, `· · ·`-колофон.
− `Theme(primary: seasonColor)`. − Eyebrow даты 16 w700 accent + subtitle
  18 + title 27 + metadata + place + biography — шапка занимает до
  половины первого экрана. − Loading/error — другой chrome
  (`AdaptiveAppBar`, `AmbientWash`), error показывает `e.toString()`.
− Локальный `_chromeMode` параллельно shell-controller.
**vNext:** header: ribbon + overline «29 верасня · Звычайны перыяд»,
docTitle «Ютрань ▾», docSubtitle празднование, одна строка metadata,
biography свёрнута. Reader bar: ‹ час › + блок ▾.

### Чытанні — корень (`ReadingsScreen`)

+ Root сразу даёт текст; варианты/циклы вторичны с «зменены».
− `displayTitle(36)` «Чытанні» внутри reader — корень-журнал над
  документом-книгой. − Дата в `seasonColor` labelLarge w700 + Material
  `calendar_today_rounded`. − Uppercase labels разделов (`letterSpacing 1.05`).
− Swipe даты по тексту. − Своя HTML style map.
**vNext:** page title «Чытанні» display 32/34 (как у всех корней),
DayContextHeader общий с Літургіяй, разделы — `blockHeading`, reference
под ним, action «Парадак Імшы».

### Reading Detail (legacy)

`TopChromeOwner.legacy`, своя style map, `letterSpacing 0.7`.
Перевести на `LiturgicalTextRenderer` или удалить после проверки ссылок.

### Малітоўнік — корень (`PrayersScreen`)

+ Абраныя первыми, пустое состояние компактно, поиск сверху.
− Системный `headlineLarge w700` 32 вместо общего page title. −
  «Раздзелы» 2×2 плитки с иконкой в сером квадрате — самый тяжёлый паттерн
  приложения для вторичных книг; «Сакрамэнты · Хутка» на равных с Імшой.
− Секции `titleLarge w700` почти того же веса, что заголовок. −
  `AmbientWash(cs.tertiary)`. − «Кіраваць» категориями на корне
  (управление рядом с чтением). − «Мае малітвы» — вторичная функция в
  конце, но той же формы, что «Усе малітвы».
**vNext:**
```text
Малітоўнік                                  (display)
Абраныя                                     (sectionTitle)
  Ойча наш                               ★ ›
  …
Кнігі                                        (sectionTitle)
  ┌ Святая Імша ─────┐ ┌ Спеўнік ─────────┐  (ShelfTile, radius 22, без icon-квадрата)
  │ Парадак Імшы     │ │ 447 спеваў       │
  └──────────────────┘ └──────────────────┘
  ┌ Катэхізіс ───────┐
  │ Кампендый · 598  │
  └──────────────────┘
Катэгорыі                                    (NavRow без folder-иконок)
Усе малітвы · 116 ›
Мае малітвы ›                                (ui.secondary строка)
```
Сакрамэнты — не показывать плиткой до наличия содержимого (оставить route).
Управление категориями — из overflow экрана «Катэгорыі», не с корня.

### Усе малітвы / Пошук / Катэгорыя (`PrayerCatalogScreen`, `PrayerCategoryScreen`)

+ Search dock снизу, фильтр по тегам в sheet, сохранение query.
− `GlassSurface` на обеих ОС. − `+90` top, `104/120` bottom. − Stage 7
  P2-08 (query/results после повторного входа) — проверить.
**vNext:** `AppPage` + `AppSearchDock` на `ChromeSurface`, `ItemRow`.

### Прайер Detail (`PrayerDetailScreen`, не Імша)

+ Общий reader, ★ + Aa, edit в overflow.
− `IconButton.filledTonal` для ★ — другая форма рядом с Back. − Heart
  цвета error. − Eyebrow «МАЛІТВА» uppercase. − Своя HTML map (`h2 ×1.2`,
  `p margin 10`, `.prayer-rubric` с левой линией 3).
**vNext:** `ChromeActionGroup(★, Aa)`, overline без uppercase,
`LiturgicalTextRenderer`.

### Святая Імша

+ Одна сущность с тремя языками, переход к тому же разделу при смене
  языка, иерархическое оглавление, сохранённый язык.
− `_MassNavigatorBar` над compact dock — два нижних слоя; язык
  (свойство документа) смешан с навигацией; `cs.tertiary` как акцент;
  `_MassSectionsSheet` с uppercase «СВЯТАЯ ІМША».
**vNext:** язык — сегмент BE/LA/EN в context header (или «BE ▾» в top
group для узких экранов); разделы — в `ReaderBottomBar` (‹ раздел ›,
текущий ▾ → `ReaderOutlineSheet`). Для служащих — keepScreenOn (уже
настраивается) и крупный Aa.

### Спеўнік (`SongbookScreen`, `SongDetailScreen`)

+ Быстрый список 447 песен, фильтр, избранное, аккорды/транспонирование,
  compact mode.
− Heart + chevron на каждой строке (двойной trailing); CAPS/Sentence
  case смешаны; `+90`/`128` отступы; `GlassSurface` в dock на Android;
  eyebrow «СПЕЎНІК».
**vNext:** `ItemRow` (★ только у избранных? — нет: сохранить toggle, но
убрать chevron, строка целиком — переход), `AppSearchDock`; в документе —
аккорды/транспонирование как context actions под header.

### Кампендый (`CompendiumScreen`, readers)

+ Строгая структура (части → разделы → темы → вопросы), поиск с
  паритетом MyBrev, атрибуция источника.
− Три вида навигации в одном reader (swipe, `CompendiumPager` в тексте,
  compact dock). − `CompendiumBadge` radius 14, uppercase eyebrow в строках
  (`letterSpacing 0.6`), «ПЫТАННЕ N».
**vNext:** reader bar ‹ № ›, pager из документа убрать, badge → overline
«Пытанне 42».

### Сакрамэнты (`PrayerbookPlaceholderScreen`)

Заглушка с иконкой 48 и «Раздзел у распрацоўцы». Не показывать вход до
наличия контента; при необходимости — `ContentStateView` с объяснением,
что будет.

### Біблія (`BibleChapterScreen`, `BibleSearchScreen`)

+ Последнее место при входе, BEL/RUS, combined picker, выделения с
  палитрой вместо dock, свой verse renderer.
− Header на `page`-фоне, текст на `reader` — видимый шов. − `_ChapterNavBar`
  + dock. − БЕЛ/РУС Android перенос (P2-01). − Bible Search — legacy chrome.
− Eyebrow «СТАРЫ ЗАПАВЕТ» uppercase + «Раздзел 1» + title «Роду ▾» +
  переводчик + сегмент — пять строк до текста.
**vNext:** header на reader-поверхности: overline «Стары Запавет ·
пераклад Чарняўскага», title «Роду 1 ▾», сегмент BEL/RUS справа от
overline на ≥360; reader bar «‹ Роду 1 ▾ ›»; поиск — `AppSearchDock`.

### Налады (`SettingsScreen`) и Інфармацыя

− Одна большая `_NeutralContentSurface` (radius 28) на всё; сезонный
  `AmbientWash`; Dropdown для гарнитуры и стартового раздела; диагностика
  в той же карточке.
**vNext:** grouped list (iOS inset grouped / Android M3 list) из 4 групп:
*Выгляд* (Тэма, Памер і шрыфт → тот же `ReaderAppearanceSheet`),
*Чытанне* (Не гасіць экран, Стартовы раздзел), *Даныя* (Сінхранізацыя →
push-экран), *Пра праграму* (Інфармацыя, версія из package info,
Дыягностыка). Без сезона.

### Legacy (`FavoritesScreen`, `MyPrayersScreen`, `PrayerFormScreen`, `LiturgicalPickerScreen`, `LiturgicalDayOptionsScreen`, `HoraPickerScreen`)

Все используют `GlassSurface` для контента и `AdaptiveAppBar`.
`LiturgicalPickerScreen` — реальная вторичная функция (сохранить,
перевести на `AppPage` + `ListGroup`); остальные — перевести или удалить
по мере вывода compatibility routes.

### Иконка / splash / web

См. §6.8. Сейчас бренд — единственная часть продукта, совершенно не
связанная с интерфейсом.

---

## 13. What Should Be Preserved

1. Непрозрачная ivory/charcoal страница, Literata, 1.64–1.68 ритм,
   рубрики `#9B302A/#EF9188`.
2. Графитово-нейтральная палитра commit `1540a7d`.
3. 4 ветки `StatefulShellRoute`, независимые даты, return token Ora →
   Чытанні, repeat-tab → root.
4. `Full/Compact/Hidden` и route descriptors.
5. Floating dock-капсула с подписанными разделами и compact-«ручка» —
   узнаваемый элемент приложения.
6. Контент-первые корни: Літургія (дата → празднование → часы), Чытанні
   (сразу текст), Біблія (последнее место).
7. Лента празднования (`hours-celebration-accent`) — основа концепции цвета.
8. Иконки часов и Phosphor как предметная семья.
9. Progressive disclosure: alternatives «Варыянт X з N», циклы, «зменены».
10. Search dock снизу в коллекциях; palette выделения вместо dock.
11. Выбор из трёх гарнитур (как ограниченная, честная настройка).
12. Отсутствие религиозного декора в UI.

## 14. What Should Change

1. Ввести `IbTokens` и запретить литералы (S1).
2. Канонизировать один документ; архивировать противоречащие разделы (S2).
3. Вывести литургический цвет из chrome и `ColorScheme` (S3).
4. Ввести `BottomSlot` и `ReaderBottomBar`; убрать второй нижний слой (S4).
5. Одна page title-роль для всех корней и коллекций; Literata в заголовках
   документов; без uppercase (S5).
6. Одна `LiturgicalTextRenderer`/`ReaderHtmlStyles` для всех документов (S5).
7. `GlassSurface` только внутри `ChromeSurface` на iOS; модальный контент
   opaque (S6).
8. Один `TopChrome`, один `ChromeIconButton`, один `FavoriteToggle` (S7).
9. Упаковать шрифты (S8).
10. Бренд: имя, знак, splash, web (S9).
11. Жестовая модель: убрать swipe даты по тексту и double-tap (S10).
12. Малітоўнік: «Кнігі» вместо «Раздзелы», без заглушки, управление
    категориями не на корне.
13. Налады: grouped list, без сезона.

---

## 15. Design Concept vNext — «Ціхая кніга»

**Метафора.** Приложение — это одна книга в мягком переплёте, раскрытая
на сегодняшнем дне. Страница (reader) непрозрачна и тёплая; поля (page)
чуть темнее и совсем тихие; закладка-лента показывает литургическое
время; всё управление лежит на полях книги и исчезает, когда начинаешь
читать. Остальные книги (Імша, Спеўнік, Катэхізіс, Біблія) стоят на
той же полке и открываются тем же жестом, той же типографикой.

**Как это ощущается по шагам «успокоиться → сориентироваться → начать
молиться → не отвлекаться»:**

| Шаг | Что делает интерфейс |
| --- | --- |
| Успокоиться | Нейтральное поле без насыщенных цветов, один крупный спокойный титул страницы (Cormorant), много воздуха |
| Сориентироваться | Дата и празднование — первое, что читается; лента цвета слева — единственное цветовое пятно |
| Начать молиться | Час — одно касание; документ начинается с короткой шапки, а не со справки |
| Не отвлекаться | При чтении остаются Back и одна тихая капсула внизу; фокус-режим убирает всё, кроме кнопки возврата |

**Три слоя, три правила:**

1. **Страница** — только типографика. Никаких карточек, фона, цвета
   сезона; одна гарнитура, одна шкала ролей.
2. **Рамка** — только нейтральные поверхности, pill-формы, 48-кнопки.
   Одна полоса сверху, один слот снизу.
3. **Закладка** — только литургический смысл: лента, короткая подпись,
   мягкий tint выбора.

**Композиции-ориентиры (phone 390):**

```text
КОРАНЬ ЛІТУРГІІ                         ДАКУМЕНТ (Ora)
┌──────────────────────────────┐        ┌──────────────────────────────┐
│ ≡                         ⌕  │        │ ‹              Ютрань   (Aa) ⋯│
│                              │        │ ▌ 29 верасня · Свята         │
│ Літургія гадзін              │        │   Ютрань ▾                   │
│                              │        │   Св. арханёлаў…             │
│ Аўторак ▾          29.09.2026│        │   Тыдзень II · [Чытанні дня] │
│ ▌ Свята                      │        │──────────────────────────────│
│ ▌ Св. арханёлаў Міхала,      │        │  Гімн                        │
│ ▌ Габрыэля і Рафаэля         │        │  Варыянт 1 з 3 ▾             │
│ Варыянты · 2                 │        │  Тэкст…                      │
│                              │        │                              │
│ ☼ Заклік                   › │        │  Псалмодыя                   │
│ ☼ Ютрань                   › │        │  1 ант. …                    │
│ ◐ Трэцяя гадзіна           › │        │                              │
│ …                            │        │                              │
│ ( Літ · Чыт · Маліт · Біб )  │        │ ( ▣ ‹  Псалмодыя ▾  › )      │
└──────────────────────────────┘        └──────────────────────────────┘
```

**Platform expression того же экрана:** на iOS верхние кнопки и нижняя
капсула — лёгкое матовое стекло с hairline; на Android — tonal капсулы
без обводки с M3 indicator. Всё остальное — пиксель в пиксель одинаково.

---

## 16. Migration Roadmap

Последовательность скорректирована относительно брифа: перед Foundations
нужен короткий Phase 0 — решения и консолидация, иначе токены будут
кодировать противоречия. Навигационный арбитраж (Phase 2) идёт до
перерисовки корней, т.к. он определяет insets всех экранов.

### Phase 0 — Decisions & docs (0.5–1 день)

- Утвердить этот документ как канон; добавить баннер «superseded by
  DESIGN_CONCEPT_VNEXT» в DL 1.1 §0.1/§4.1–4.2, `platform-design.md`,
  `library-design.md`; `reader-typography-vnext.md` — «принято с изменениями».
- Решения владельца: имя приложения; Марыйны цвет; default B=17; swipe на
  Hours root; судьба `mary.png`.
- **Acceptance:** Приложение A закрыто решениями.

### Phase 1 — Foundations

1. `lib/theme/tokens/*` (`IbTokens`, `IbColors`, `IbSpace`, `IbRadius`,
   `IbChrome`, `IbType`, `IbMotion`); `AppPalette` строит `ColorScheme` из
   `IbColors`; `ReaderTheme` читает `IbColors`.
2. `ReaderTextStyles` + `ReaderHtmlStyles` — одна фабрика ролей;
   подключить Ora, Readings, Prayer/Імша, ReadingDetail (без изменения
   текста/семантики, с golden-сравнением ритма).
3. Bundle Literata, Source Serif 4, Cormorant; отключить runtime fetching.
4. Литургический цвет: удалить `primary`-override в `OraScreen`, параметры
   `seasonColor` из chrome, `AmbientWash` из Settings/Prayerbook/Songbook/
   Compendium; ввести `LiturgicalContextVisual` (с fixtures, без смены
   календарных правил).
5. `AppIcons` resolver; `FavoriteToggle`.
6. Тест-grep на литералы (allowlist).
- **Acceptance:** Ora на Marian/Lent дне — все контролы графитовые;
  офлайн-первый запуск рисует Literata; `flutter test` зелёный; 0 новых
  литералов вне allowlist.

### Phase 2 — Navigation & chrome

1. `ChromeInsets`, `BottomSlot` (`dockFull/readerBar/search/selection/none`).
2. `ChromeSurface`, `ChromeIconButton`, `ChromeActionGroup`, `TopChrome`
   (root/collection/reader) — заменить `FloatingTopActions`, `ReaderChrome`,
   `AdaptiveAppBar`.
3. `ReaderBottomBar` = `_CompactDock` + локальная навигация; перевести
   Імшу (`_MassNavigatorBar` → header язык + bar разделы), Біблію
   (`_ChapterNavBar`), Кампендый (`CompendiumPager`); удалить
   `_ReaderScrollToTopControl`.
4. `AppSearchDock` на `ChromeSurface`; IME gap 12.
5. Жесты: убрать swipe даты в Readings, double-tap fullscreen;
   «Чытаць без панэляў» в overflow.
6. Кнопка меню корня визуально отличима от Back.
- **Acceptance:** на любом экране внизу ≤1 плавающий элемент; runtime-check
  P2 (IME +48, Songbook tail, Bible tail, compact/full gap) закрыты;
  Android не содержит `BackdropFilter` в chrome.

### Phase 3 — Core screens (корни)

1. `AppPage`, `PageHeader`, `SectionHeader`, `ListGroup`, `NavRow`,
   `ItemRow`, `ContentStateView`.
2. Літургія root: один display-заголовок, `DayContextHeader`, без uppercase;
   `AppSheet` для date/alternatives.
3. Чытанні root: общий `DayContextHeader`, page title, «Парадак Імшы».
4. Малітоўнік root: «Кнігі» (`ShelfTile`), без заглушки, управление
   категориями с корня убрать.
5. Налады: grouped list, 4 группы; version из package info.
- **Acceptance:** на 390/320, light/dark, iOS/Android корни имеют одинаковую
  шкалу заголовков и отступов; визуальное сравнение со снимками §15.

### Phase 4 — Content readers

1. `ReaderContextHeader`: Literata title, overline + ribbon, ширина колонки.
2. Ora: компактная шапка, biography collapse, bar ‹ час ›; loading/error
   внутри `ReaderScaffold`.
3. Імша, Песня, Кампендый, Біблія — таблица §7.4; `ReaderOutlineSheet`.
4. `ReaderAppearanceSheet` (размер 17-базис, гарнитура, preview) + миграция
   сохранённого размера.
5. Songbook/Compendium lists: `ItemRow`, нормализация отображения CAPS.
6. Вывести или перевести legacy: ReadingDetail, HoraPicker, Favorites,
   MyPrayers, Form, Picker, DayOptions.
- **Acceptance:** все 7 типов документов проходят одну матрицу (Aa
  min/default/max × system 100/200% × 320/390/700) без ручных отступов;
  `GlassSurface` используется только в `ChromeSurface`.

### Phase 5 — Platform refinement

1. iOS: native material bridge (или подтверждённый fallback), scroll-edge,
   Reduce Transparency, `CupertinoPageTransitions` для branch pages
   (закрыть Stage 7 P2-11), Cupertino списки в Наладах.
2. Android: M3 Expressive floating toolbar-геометрия, predictive back,
   SegmentedButton БЕЛ/РУС (P2-01), themed icon.
- **Acceptance:** device QA из Stage 8/10 на физическом iPhone и Android.

### Phase 6 — Polish & brand

1. Знак-лента, adaptive/monochrome иконки, iOS dark/tinted, splash,
   web manifest; одно имя везде.
2. Motion по §6.7, reduce motion, skeletons.
3. Empty states с предметным текстом; VoiceOver/TalkBack порядок,
   selected/toggled; focus return из sheets.
4. Контрастная проверка итоговых композиций (glass поверх текста).
- **Acceptance:** accessibility-матрица DL 1.1 §7 пройдена; бренд совпадает
  в App Store/Play/web.

---

## 17. Priority Recommendations

| # | Рекомендация | Эффект | Стоимость | Phase |
| --- | --- | --- | --- | --- |
| 1 | Удалить `primary: seasonColor` в `OraScreen` и `seasonColor` из всех chrome | Сразу возвращает спокойствие и корректность цвета | S | 1 |
| 2 | Принять этот документ каноном, пометить superseded | Прекращает «дрейф решений» | S | 0 |
| 3 | `IbTokens` + запрет литералов | Основа всех дальнейших изменений | M | 1 |
| 4 | `ReaderBottomBar` + `BottomSlot` (Імша, Біблія, Кампендый) | Устраняет конкуренцию глобальной/локальной навигации | M | 2 |
| 5 | Bundle шрифтов | Офлайн-книга выглядит как книга всегда | S | 1 |
| 6 | Одна фабрика ролей для HTML | Все документы — одна типографика | M | 1/4 |
| 7 | `PrayerSearchDock` → `ChromeSurface`; модальный контент opaque | Платформенная честность | S | 2 |
| 8 | Один page title и отказ от uppercase | Корни перестают быть «двумя приложениями» | S | 3 |
| 9 | Малітоўнік: «Кнігі» без заглушки; Налады — grouped | Порядок в полке и настройках | M | 3 |
| 10 | Имя + знак-лента + splash + web icon | Первое впечатление = интерфейс | M | 6 |

---

## Приложение A. Открытые решения владельца

| Вопрос | Рекомендация |
| --- | --- |
| Имя приложения на устройстве | Одно имя (iBreviary / Брэвіярый), отличное от раздела «Малітоўнік» |
| Марыйны синий | Не использовать как литургический цвет; при желании — только маркер местной традиции с подписью |
| Базовый размер B | 17 с миграцией без скрытого увеличения |
| Swipe даты на корне Літургіі | Убрать (date sheet покрывает) |
| Сакрамэнты до готовности | Скрыть вход |
| `mary.png` | Только в «Інфармацыі», не бренд |
| Язык Імшы: сегмент в header или «BE ▾» в top group | Сегмент в header на ≥360, иначе top group |

## Приложение B. Инвентарь «магических» значений (для Phase 1)

| Категория | Значения в коде | Токен |
| --- | --- | --- |
| Top inset | `+76` (reader, `kFloatingAppBarContentInset`), `+78` (Hours, Prayerbook, shell), `+90` (списки) | `ChromeInsets.top` |
| Bottom padding | `42+pad` (reader), `104`, `116`, `120`, `128`, `152`, `+24` | `ChromeInsets.bottom` |
| Кнопки chrome | 48, 52 | `chrome.button 48` |
| Dock | full 60/62, compact 54, контейнер 78/72 + safe | `dockHeight 60`, `readerBarHeight 52` |
| Search dock | 58, radius 30 | `searchHeight 56`, pill |
| Радиусы | 2, 8, 10, 12, 14, 15, 16, 17, 18, 20, 22, 24, 28, 30, 99, 999 | §6.5 |
| Иконки | 14, 16, 17, 18, 19, 20, 21, 22, 23, 24, 28, 38, 40, 48, 52, 56 | §6.6 |
| Поля страниц | 20, 22, 24; top chrome 12/14 | `gutter`, `chrome.edge 12` |
| Reader max width | 700 | `measureEm 36` / 660 |
