# iBreviaryBy — Design System

Статус: **каноническая целевая спецификация**, 2 октября 2026.
Основа: [Quiet Book](DESIGN_CONCEPT.md). Реализация мигрирует поэтапно;
состояние main и рабочей ветки зафиксировано в [review](../DESIGN_CONCEPT_VNEXT.md).
Имена будущих компонентов ниже обозначают ответственность, не наличие класса.

## 1. Статусы решений

**Invariant** — принятый контракт. **Baseline** — стартовые значения для
прототипа/реализации; корректируются по измерениям в этом документе.
**Hypothesis** — композиция, которую нельзя тиражировать до проверки.

Инварианты: Page/Chrome/Ribbon, Cormorant/Literata/System, нейтральный chrome,
один BottomSlot, независимый TextScaler и единые смысловые роли на iOS/Android.
Размеры ниже — logical px до системного TextScaler; высоты chrome — минимумы,
не жёсткие ограничения при крупном тексте.

## 2. Typography roles

| Роль | Гарнитура | Baseline | Область |
| --- | --- | --- | --- |
| `type.pageTitle` | Cormorant Garamond, 600–700 | 32–34 / 1.12 | Крупные титулы L1/L2, одинаковая роль во всех разделах |
| `reader.docTitle` | Cormorant Garamond 700 | По роли page title | Титул документа в context header, если это содержательный page title |
| `reader.docSubtitle` | Literata | 17 / 1.40 | Название празднования/подзаголовок документа |
| `reader.body` | Literata 400 | B / 1.68 | Prayer, Scripture, Catechism, Mass, song text |
| `reader.majorHeading` | Cormorant Garamond 700 | `blockHeading × 1.12` / 1.12, rubric | Крупные части внутри документа |
| `reader.blockHeading` | Cormorant Garamond 700 | max(1.42B, 22) / 1.12, rubric | Смысловой заголовок раздела; `ReaderTheme.blockHeading` |
| `reader.reference` | Literata 500–600 | max(.88B, 14) / 1.40 | Библейские ссылки; цвет по semantic role |
| `reader.rubric` | Literata | max(.90B, 14) / 1.48 | Служебный литургический текст; не UI metadata |
| `type.ui.sectionTitle` | System 500–600 | 20 / 1.30 | Секции коллекции/настроек |
| `type.ui.title` | System 500–600 | 17–18 / 1.33 | Navigation rows, sheet title |
| `type.ui.body` | System 400 | 16–17 / 1.50 | Контролы, settings, search, пояснения |
| `type.ui.metadata` | System 400–600 | 14–15 / 1.42 | Дата, источник, служебные подписи |
| `type.ui.overline` | System 600 | 13 / 1.30 | Краткая контекстная метка, обычно sentence case |
| `type.ui.dockLabel` | System 500–600 | 12 / 1.20 | Подписи глобальных веток |
| `reader.chord` | Monospace | По song layout | Только аккорды; основной текст песни остаётся Literata |

`type.pageTitle` не входит в System UI-гарнитуру. Root-reader Чытанні может
иметь Cormorant-титул страницы и Cormorant-заголовки разделов чтений внутри неё.
Празднование — контекст книги, не второй большой display-title.

Пользовательские Source Serif 4 / System остаются override reader-family
длительного текста, не новой identity. Cormorant-заголовки разделов не
наследуют этот выбор; UI metadata не наследует reader-family. Cormorant
не становится гарнитурой body.

`ReaderTheme.blockHeading` уже реализует этот content-heading token в Hours,
Readings, Prayer и Mass. В Compendium навигационные строки остаются UI;
содержательные заголовки в `CompendiumPartScreen` (`_PartHeader` и `_PartItem`)
ещё используют локальные Material styles. Их перевод на общий token — отдельная
миграция reader без изменения иерархии вопросов и маршрутов.

Uppercase не основной источник иерархии. Сократить большие CAPS и повторные
eyebrows; короткие language codes, аббревиатуры и оправданные типографические
метки допускаются. Отображение названий из данных нормализуется только при
проверяемом сохранении смысла; source text не переписывается.

### Aa, TextScaler и миграция

`reader.bodyDefault ≈ 17`, `scaleMin = .85`, `scaleMax = 1.80`, `scaleStep = .05`.
Для нового baseline это 14.45…30.6 до system scale. Верх 180% — целевой
контракт, подтверждаемый layout/accessibility tests; 160% не становится
запасным потолком при тесной панели. Сначала адаптировать layout.

`B = bodyDefault × Aa`; затем применяется системный `TextScaler`, включая
его нелинейное поведение. Aa меняет reader-роли от B; page titles и UI
используют только system scale. `docTitle/docSubtitle` также system-scaled,
внутренние заголовки документа масштабируются с B. Не применять system scale
дважды, не отключать его и не зажимать до 1.3 ради панели.

Сохранённый абсолютный fontSize в новом допустимом диапазоне сохраняется.
Значения ниже нового min требуют отдельного migration UX: объяснить переход
к доступному минимуму, не применять скрытое увеличение всей базы.
Смена Aa/гарнитуры сохраняет смысловой anchor чтения, не только pixel offset.

Локально поставлять реально используемые начертания и белорусские глифы
(`І і Ў ў Ё ё`, апострофы, латиница, ℣ ℟ † *). Уже bundled базовые faces
сохраняются. Настоящие italic/semibold faces добавлять по потребности ролей;
не полагаться молча на синтез. Проверить cold offline launch и отключить
runtime fetching после покрытия всех запрашиваемых вариантов.

### Reader rhythm и специализированные роли

Колонка — ориентир ≤36 em с верхней границей около 660; это baseline для
проверки против текущих 700, а не причина сжимать крупный текст. Ширина не
превышает доступную область минус поля. Выравнивание тела влево, без justify;
source-обоснованное центрирование metadata/verse structures допускается.

Точный mapping псалмов, антифонов, рефренов, рубрик, cadence markers и
интервалов живёт в [LITURGY_CONTENT_VISUAL_SPEC](../LITURGY_CONTENT_VISUAL_SPEC.md).
Не копировать Master Catalog сюда и не заменять смысловые разрывы одним
generic paragraph margin. Ритм body 1.68 сохраняет текущую основу; 1.64 из
первого аудита не является обязательной новой миграцией. Source structure
имеет значение: hymn, responsory и psalm не обязаны иметь одинаковый rhythm.

## 3. Color roles и surfaces

| Роль | Light baseline | Dark baseline | Смысл |
| --- | --- | --- | --- |
| `colors.page` | #F2F1EE | #0F110F | Нейтральное поле корней/коллекций |
| `colors.reader` | #FDFCF9 | #171917 | Непрозрачная страница |
| `colors.surface` | #F8F8F5 | #171917 | Группа списка, opaque sheet |
| `colors.surfaceRaised` | #FEFDFB | #20231F | Редкая выделенная группа |
| `colors.floating` | #E6E5E0 | #292C28 | Android chrome |
| `colors.ink` | #20211F | #E9ECE7 | Основной текст |
| `colors.inkMuted` | #5F625C | #AEB3AB | Читаемая вторичная информация |
| `colors.accent` | #242522 | #E8EBE6 | Нейтральный primary/action |
| `colors.onAccent` | #FFFFFF | #191B18 | Текст/глиф на accent |
| `colors.rubric` | #9B302A | #EF9188 | Литургическая рубрика |
| `colors.error` | #A52F2F | #FFB4AB | Ошибка, не избранное |

Не вводить `inkFaint` для значимых номеров стихов без проверки контраста.
Separators, scrim, outlines и state layers — семантические роли с проверкой
итоговой композиции, а не случайная alpha от текста. Favorite = заполненный
глиф + selected/toggled semantics; error red для него не нужен.

Литургические семейства: green, violet, whiteGold, red, rose, neutral;
каждое имеет marker/ink/tint. Исходные swatches доступны в историческом
[DL 1.1 §2.2](ibreviary-mobile-design-language.md), окончательный контраст
проверяется на новых surfaces. Ключ приходит из доменного контекста, не из
угадывания по словам имени святого. Политика Marian/Requiem — отдельное
доменное решение, не побочный эффект refactoring темы.

**Color budget:** ribbon/celebration marker + короткая подпись, contextual
selection tint, hour icon; допустим лёгкий ambient в ограниченном day context.
Начальный предел ambient alpha .08 light / .10 dark — верхняя проба, не цель
добавить столько на каждый элемент. Оценивать суммарную насыщенность.
Нет сезонного primary, общей окраски dock, Settings, поиска, всего листа или
reader body. Пользователь чувствует контекст, но интерфейс не перекрашен.

Page и reader не стеклянные. Одна поверхность на смысловую группу; каждый
абзац/ряд не требует card. Modal content opaque. Glass/material допустим
в iOS floating chrome через platform boundary; Android использует tonal
Material. Reduce Transparency переводит chrome в непрозрачную поверхность.

## 4. Geometry и tokens

| Группа | Baseline | Правило |
| --- | --- | --- |
| `space` | 4, 8, 12, 16, 20, 24, 32, 40, 48, 64 | Использовать именованную роль только для повторяемого ритма |
| `space.gutter` | <360: 16; 360–599: 20; ≥600: 24 | Общие поля; reader ограничивает также measure |
| `radius` | none 0; sm 10; md 16; lg 22; sheet 28; pill height/2 | Page/reader без рамки; единые роли групп и chrome |
| `chrome` | target/button ≥48; top ≥56; edge/gap 12; groupGap 8 | Реальная высота растёт при text scaling |
| `chrome.bottom` | dock ≥60; readerBar ≥52; search ≥56 | Минимумы для прототипа, не утверждённая геометрия ReaderBottomBar |
| `reader` | base ≈17; Aa .85–1.80; measure ≈36em | Ритм и роль отдельно от UI |
| `motion` | disclosure 180ms; chrome/context 200ms | Системные transitions имеют приоритет |

`IbTokens` / ThemeExtension объединяет **colors, space, radius, type, chrome,
motion, liturgical, reader**. Theme-dependent значения получают через тему;
общие const-spacing/radius допустимы без усложнения доступа. Не создавать
отдельный token для каждого уникального отступа или идентичные параллельные
таблицы в AppPalette, ReaderTheme и JSON.

Токен обязателен для canonical gutters, стандартных radius, размеров/минимумов
chrome, typography roles, reader rhythm и семантических цветов. Уникальный
layout literal допустим, если не дублирует роль и рядом объяснена причина.
Пример: поправка для конкретного source glyph или расчёт chord layout.

**Lint:** проверять применение уже принятых ролей и новые дубликаты в
мигрированных компонентах. Узкие исключения — с причиной; legacy debt
учитывается отдельно. Не запрещать каждый `EdgeInsets`/`fontSize` числовым
grep по всему проекту. Критерий — semantic consistency, не ноль литералов.

После появления Dart tokens JSON может стать generated export. Сейчас
`mobile-design-tokens.json` — legacy handoff 1.1, не актуальный runtime source.
Его verifier проверяет тот набор, не сертифицирует новые surfaces автоматически.

## 5. Components и reader anatomy

| Ответственность | Основа / целевой компонент | Контракт |
| --- | --- | --- |
| Страница/список | AppPage, PageHeader, ListGroup, NavRow, ItemRow | Общие поля, title roles, рост высоты строк, одна группа на смысл |
| Верхняя рамка | TopChrome, ChromeIconButton, ChromeActionGroup | Root menu отличим от Back; primary actions по ширине, остальные в overflow |
| Поверхность управления | ChromeSurface на основе AdaptiveChromeSurface | Нейтральный материал по платформе, без seasonColor |
| Нижняя зона | BottomSlot, ReaderBottomBar, AppSearchDock, SelectionPalette | Один владелец, общий расчёт insets |
| Day context | DayContextHeader, LiturgicalRibbon, chooser sheets | Дата/празднование явно подписаны, варианты на шаг глубже |
| Reader | ReaderScaffold, ReaderContextHeader, ReaderContentSurface | Непрерывная opaque page: context → документ → доступный конец |
| Роли документа | ReaderTheme + общая HTML factory | Использовать `liturgicalDocumentStyles` после интеграции ветки; сохранять source semantics |
| Sheets/presentation | Appearance, Outline, Choice; platform presenter | Opaque content, selected state, focus return, предсказуемый Back |
| Состояния | ContentStateView и существующий DataLoadingNotice | Те же поверхности и доступные действия, без смены identity |

Reader anatomy: TopChrome → context header → document roles → один bottom
owner. Header выровнен по текстовой колонке. Системные metadata отделены от
книжного title; biography/длинные пояснения раскрываются по запросу.
Aa остаётся доступным, язык Імшы — свойство документа, аккорды — локальная
настройка песни. Не помещать их в универсальную панель вместе со всем подряд.

Outline и последовательная навигация определяются книгой: час/блок, чтение,
раздел Імшы, глава Бібліі, вопрос Катэхізіса. Короткая молитва/песня может
не иметь outline. Существующие local search/filter scopes сохраняются;
дизайн не обещает глобальный поиск без индекса.

## 6. BottomSlot: invariant и UI hypothesis

**Invariant — One slot, one owner.** В каждый момент нижняя зона принадлежит
одному из `dockFull | readerBar | search | selection | none`.
Один owner может содержать несколько действий/рядов, но не независимые
плавающие панели. При переходе старый owner освобождает место и inset.

Приоритет состояния: modal перекрывает и блокирует underlying actions;
focus скрывает панели с видимым restore; selection заменяет обычный bar;
активный search владеет слотом и IME; иначе действует route default.
Противоречивые selection/search запросы разрешаются явным завершением
предыдущего режима. Back закрывает самый верхний активный режим до route pop,
сохраняя shell return-token контракт. Раскрытый branch chooser закрывается
раньше выхода из документа.

Root defaults: Літургія/Малітоўнік — dock; root-readers — reader/dock по
контексту чтения; коллекции с поиском — search; documents — readerBar;
Hidden — none с доступным восстановлением. Mass уже скрывает глобальный dock:
это исправление сохранить. Scroll-to-top не добавляет второго floating layer;
пункт «Да пачатку» доступен через outline/меню даже без системного жеста.

**Hypothesis — первый прототип:** `(branch | ‹ | current section ▾ | ›)`.
До реализации сравнить:

1. Однорядную капсулу с branch handle и полным/адаптивным section trigger.
2. Короткую панель branch + section trigger; prev/next внутри outline sheet.
3. Адаптивную двухстрочную панель внутри одного owner с растущей высотой.

Все варианты сохраняют branch access, понятный текущий раздел и доступ к
prev/next, если у документа есть последовательность. Сокращение текста не
должно скрывать единственный способ узнать раздел. Выбор фиксируется после
матрицы 320/360/390, длинных titles, Aa 180% и system 200%, включая совместный
максимум. Высота 52 не является ограничением или основанием уменьшать шрифт.

`ChromeInsets` — единственный владелец safe area, измеренной высоты слота и
content reserve. Search располагается над IME + baseline gap 12; system
obstruction учитывается один раз. При клавиатуре прочие bars скрываются.
Последняя строка/строка результата может прокрутиться полностью выше панели.
Уникальные экранные `+104/+128/+152` не заменяют расчёт insets.

## 7. Iconography, motion и платформы

Предметные icons — Phosphor Regular/Fill для state; системные Back, close,
overflow, chevron — platform resolver. Не смешивать стили внутри одной группы.
Baseline glyphs: chrome 22 (платформенная корректировка 20–24 допустима),
row 20, inline 16; target ≥48 независимо от glyph. Центровка single-action
52 dp уже исправлена в main; сохранить при унификации размеров.

| Общая роль | iOS expression | Android expression |
| --- | --- | --- |
| Floating chrome | Лёгкий material/glass, проверенный fallback | Tonal Material 3 / Expressive, state layers |
| Navigation | Cupertino push/edge-back | Predictive back и нативные transitions |
| Actions | Лёгкие system glyphs/highlight | Tonal buttons/ripple |
| Sheet/dialog/selector | Cupertino/system presentation | Material presentation |
| Accessibility | VoiceOver, Reduce Motion/Transparency | TalkBack, system scaling/animations |

Одна screen hierarchy и модель навигации; platform branches внутри компонентов
и presenter. Native material bridge не объявляется готовым без device QA.
Смена Aa без анимации текста и потери anchor. Custom motion короткий и
функциональный; reduce motion/disableAnimations отключает его и shimmer.
Focus mode имеет явный вход и выход; double-tap не единственный способ.
Swipe по тексту не должен конфликтовать с selection и системным Back.

## 8. States и acceptance criteria

Loading использует существующий shared notice в геометрии страницы;
cache-ready остаётся видимым при refresh. Empty search объясняет scope и
даёт изменить фильтр. Missing locally предлагает загрузить контент; not in
corpus предлагает доступный вариант; error — понятное сообщение/повтор,
без raw exception. Offline + ready не требует постоянного предупреждения.

Перед принятием компонента проверить:

- Width **320, 360, 390 и 700**, light/dark, iOS/Android; Aa **85/100/180%**
  × system **100/200%**, включая Aa180 + system200. Длинные белорусские labels,
  Scripture, Mass, song chords, Catechism и все основные liturgical readers.
- Нет overflow, перекрытия текста, недоступных actions и обрезанного конца.
  UI растёт/перестраивается; touch targets ≥48. Отдельно IME, жестовая и
  трёхкнопочная navigation, safe area и переходы owner/mode.
- Приоритеты BottomSlot соблюдены при search, selection, outline, focus,
  branch switch и Back. Семантика текущего состояния и focus return проверены.
- Text contrast ≥4.5:1, large text ≥3:1, значимые icons/focus ≥3:1 на реальном
  composited фоне; значение не передаётся одним цветом. Это критерии проекта,
  не утверждение уже пройденной сертификации.
- Screen reader labels/порядок, selected/toggled, доступность поиска/Aa/выхода
  из focus; Reduce Motion/Transparency; cold offline fonts и все глифы.
- Смена Aa/family сохраняет место и данные; календарь/языки/литургический
  порядок и source text не меняются при переносе ролей.

Проверки выполняются при реализации соответствующего scope. Документационная
редакция сама по себе не подтверждает прохождение матрицы; widget/golden tests
не заменяют device QA. Если макет не проходит 180%, пересмотреть композицию,
зафиксировать дефект; не тихо опускать верх до 160%.

## 9. Карта специализированных specs

- [Liturgical content visual spec](../LITURGY_CONTENT_VISUAL_SPEC.md) — точные
  semantic IDs, locators, role mapping и source-dependent интервалы.
- [Reader foundation](../reader-foundation.md), [App shell](../app-shell-migration.md),
  [Hours root](../hours-root-migration.md), [Readings root](../readings-root-migration.md)
  — технические контракты и миграции, не конкурирующая общая type scale.
- [Prayerbook/Mass](../prayerbook-migration.md), [Bible](../bible-migration.md),
  [Songbook](../songbook.md), [Compendium](../compendium.md) — доменное поведение.
- [Data and offline](../data-loading-architecture.md)
  — данные и состояния загрузки.
- [Consolidated review](../DESIGN_CONCEPT_VNEXT.md) — проверенные CURRENT /
  PARTIALLY FIXED / HISTORICAL, rationale, открытые вопросы и roadmap.

Иерархия — в Concept. Не дублировать эти каталоги в новых MD. Старые DL 1.1,
platform-design, library-design и reader-typography-vnext сохраняют историю;
их противоречащие визуальные рекомендации не применяются к новым задачам.
