# iBreviaryBy — Design Concept vNext: consolidated review

Статус: **audit / rationale / historical design review**, редакция 2 октября 2026.
Это документационная консолидация; production-код и assets не менялись.

Ежедневный канон: [DESIGN_CONCEPT](design/DESIGN_CONCEPT.md) — каким ощущается
продукт; [DESIGN_SYSTEM](design/DESIGN_SYSTEM.md) — практические роли, компоненты
и критерии приёмки. Этот обзор объясняет решения и порядок миграции, но не
дублирует таблицы токенов и каталог литургических элементов.

## 1. База и границы проверки

Первоначальный аудит: `origin/main @ 1540a7d`, 29 сентября 2026.
Повторная проверка: после `git fetch origin main`,
`origin/main @ 1ac450d9c184e63561e3fcb0b80ae94353d44f7b`.
Рабочий checkout: `feature/liturgy-visual-unification @ 7d48807`, на два коммита
впереди main (`20cf1b4`, `7d48807`). Их изменения отмечены отдельно; они не
считаются исправлениями main. Локальные пользовательские вложения не затронуты.

Первоначальный документ прочитан полностью. Повторно сверены тема Ora,
FloatingTopActions, ReaderScaffold, dock, Mass/Bible bars, Compendium,
Songbook, настройки, загрузка шрифтов, манифесты и связанные спецификации.
Это проверка исходников и истории Git, без нового запуска приложения,
скриншотного аудита или accessibility/device QA. Старые изображения из
`audit-evidence/android-runtime/` иллюстрируют прежний срез, а не current main.
Числа вроде «16 радиусов / 14 uppercase-файлов» из старого аудита не выдаются
за повторно измеренную статистику. Полная исходная редакция сохранена в Git
(`6cf6a0f:docs/DESIGN_CONCEPT_VNEXT.md`).

## 2. Что сохраняем и почему

iBreviaryBy — **литургическая книга дня**. Літургія гадзін и Чытанні — ядро;
Малітоўнік, Імша, Спеўнік, Катэхізіс и Біблія — другие книги той же экосистемы.
Формула «Адкрыў — і ўжо на патрэбнай старонцы» важнее расширения каталога.

Сильные стороны исходного решения остаются основой: непрозрачная страница,
Literata и рубрикация, нейтральная ivory/charcoal палитра, четыре независимые
ветки, return token Ora → Чытанні, контекст дня перед текстом, локальный выбор
альтернатив и платформенная граница chrome. Путь — **refine → unify → simplify
→ elevate**, без перестройки работающей архитектуры ради нового вида.

«Ціхая кніга / Quiet Book» объединяет Page, Chrome/frame и Liturgical ribbon.
Текст имеет наибольший вес; рамка помогает ориентироваться; цвет сообщает
литургический контекст. Спокойствие не означает стирание католической
идентичности, уменьшение доступного размера текста или запрет значимых символов.

## 3. Закрытые решения и редакционные изменения

| Тема | Окончательное направление | Что изменено относительно первого аудита |
| --- | --- | --- |
| Гарнитуры | Cormorant Garamond — крупный титул L1/L2; Literata — голос документа, включая его заголовки; System — интерфейс | Устранено пересечение `book` и `display` в page titles; Cormorant не переносится внутрь документа |
| Uppercase | Не основной способ иерархии; sentence case, размер, вес и интервалы предпочтительны | Абсолютный запрет снят; короткие оправданные метки и аббревиатуры допустимы |
| Aa | Ориентир базы 17, минимум около 85%, цель до 180%; независимый системный TextScaler | Автоматический потолок 160% снят; доступность определяет композицию |
| Нижняя зона | `BottomSlot`: один владелец, максимум один floating layer | `ReaderBottomBar` принят архитектурно; конкретная горизонтальная капсула — гипотеза, проверяются 2–3 варианта |
| Литургический цвет | Нейтральный chrome и primary; цвет в ограниченной области контекста | «Ribbon only» заменён смысловым бюджетом: marker, tint, hour icon, лёгкий ambient допустимы |
| Tokens | Семантические роли и повторяемая геометрия через `IbTokens` / ThemeExtension | Запрет каждого числового литерала отменён; уникальная layout-геометрия может быть локальной |
| Branding | Отдельный design track, не блокирующий систему | «Книга + ribbon» — один кандидат, не утверждённый знак; сдержанная католическая семантика допустима |
| Платформы | One design system, two platform expressions | Общая иерархия вместо обещания «пиксель в пиксель»; материал и нативное поведение различаются |
| Документация | Два коротких уровня канона + существующие специализированные specs | Большой аудит перестаёт быть единственным source of truth |

Выбор Source Serif 4 / системной гарнитуры сохраняется как существующая
пользовательская настройка чтения, а не третья продуктовая концепция. По
умолчанию документ и его заголовки — Literata; пользовательский override
книжного слоя не меняет Cormorant page titles и системный chrome.

## 4. Реестр актуальности: проверенный main

`CURRENT` — долг сохраняется; `PARTIALLY FIXED` — часть исправлена, остаток
назван явно; `HISTORICAL` — старое утверждение уже не описывает main.
Статусы относятся к факту реализации, а не к результату нового runtime-теста.

| Пункт исходного аудита | Статус на `1ac450d` | Доказательство и остаток |
| --- | --- | --- |
| Ora окрашивает primary сезоном | CURRENT | `lib/screens/ora_screen.dart`, `_buildForDay`: `primary: seasonColor` сохраняется |
| Сезонный chrome и Settings | CURRENT | `floating_top_actions.dart` берёт seasonal provider; `app_navigation_dock.dart`, `platform_design.dart`, `ReaderScaffold` передают tint; `settings_screen.dart` использует `AmbientWash` |
| Mass bar одновременно с глобальным dock | HISTORICAL | `router.dart`: `massReaderRoute.showsNavigationDock: false`, выделенный маршрут принят после `4bcb853`; не требовать повторного удаления dock |
| Язык Імшы смешан с нижней навигацией | HISTORICAL | `920f530`: `_MassLanguageControl` в верхних actions; `_MassNavigatorBar` показывает полный раздел и позицию; layout/insets покрыты `0887c71` |
| Общий BottomSlot для всех readers | PARTIALLY FIXED | Mass уже владеет нижней зоной; contextual suppression есть для поиска/выделения. `_ChapterNavBar`, inline `CompendiumPager` и `_ReaderScrollToTopControl` остаются отдельными механизмами. Inline pager не является вторым floating layer, но дублирует навигацию |
| Одиночная иконка сдвинута в круге | HISTORICAL | `5194808`: `FloatingTopActions` центрирует единственный action в 52 dp, есть widget regression test |
| Размеры/реализации chrome едины | CURRENT | Исправление центра не унифицировало 52 dp FloatingTopActions и 48 dp reader controls; dock label всё ещё 10.5 |
| Шрифтов вообще нет в assets | HISTORICAL | `c4fb160`: Literata Regular, Source Serif 4 Regular, Cormorant Garamond Bold, лицензии, `assets/google_fonts/` в pubspec и `test/bundled_fonts_test.dart` |
| Полный offline-font контракт | PARTIALLY FIXED | Assets базовых faces есть; явного `GoogleFonts.config.allowRuntimeFetching = false` в production `lib/` нет. Настоящие italic/semibold варианты целевой системы и отсутствие сетевых запросов ещё надо проверить; тест наличия трёх файлов не заменяет эту проверку |
| База 16 / Aa 70–180% | CURRENT | `settings_provider.dart`: `kDefaultReaderFontSize = 16`, min 0.7, max 1.8. Переход на базу 17 и min 0.85 — будущая миграция |
| Четыре отдельные HTML style maps | CURRENT | На main Ora, Readings, Prayer/Імша и ReadingDetail ещё строят локальные карты; `lib/theme/liturgical_document.dart` на main отсутствует |
| Compendium как неизменившаяся старая иерархия | HISTORICAL | `8ae00a8`, `dfddb91`, `7af9466`, `77c7570`: source navigation отделена от reading groups, drill-down node screens и persistent search уже описаны в main `docs/compendium.md` |
| Compendium pager и плотность chrome | CURRENT | На main `compendium_reader_screens.dart` сохраняет `CompendiumPager`; новые правила общей системы не означают отказа от реальной структуры источника |
| Songbook: аккорды только в настройках / нужна compact list | HISTORICAL | `9b8c079`, `6447c9a`, `d0bac4c`: compact rows, inline chord/transpose controls, стабильная раскладка при транспонировании уже реализованы |
| Songbook search и визуальная унификация | PARTIALLY FIXED | `songbook_screen.dart`: `PrayerSearchDock`, сохранение query/filters через provider, контекстное подавление dock. Общая поверхность поиска, insets, trailing и регистр названий требуют консолидации; не создавать поиск заново |
| Glass в поиске на Android | CURRENT | `lib/screens/prayers_screen.dart`, `PrayerSearchDock`: прямой `GlassSurface`, высота 58 и radius 30 без platform branch; заменить поверхность через общий chrome contract |
| Налады: версия и данные в старой композиции | PARTIALLY FIXED | На main есть `PackageInfo.fromPlatform()` и отдельный data-settings flow (`ffb493e`); большая `_NeutralContentSurface`, dropdowns и seasonal wash сохраняются |
| Старые loading/shimmer замечания Ora/Readings | PARTIALLY FIXED | `44c01c4`, `f138209`: cache-first и общий `DataLoadingNotice`; старый тезис «везде spinner/shimmer» неверен. Унификация каркаса всех состояний ещё отдельная задача |
| Имена, icon pipeline, splash, web | CURRENT | В main сохраняются Mybrev в web manifest, Малітоўнік в native labels, несогласованные manifest colors. Брендовые assets не менялись после исходной базы; circular-icon fix касается UI, а не app icon |
| Старая документация согласована | CURRENT → закрыто этой редакцией | DL 1.1, platform-design и library-design содержали конкурирующие верхнеуровневые правила; теперь явно перенаправляют к двум каноническим документам |

### Отдельно: изменения рабочей ветки поверх main

`20cf1b4` вводит `liturgicalDocumentStyles` / `LiturgicalSpacing`, унифицирует
часть ролей и семантики Hours/Readings/ReadingDetail, затрагивает Mass.
Это **PARTIALLY FIXED в рабочей ветке**, но ещё CURRENT-долг main. Использовать
существующую фабрику как основу после интеграции, не строить конкурирующую.
Её `ReaderTheme.blockHeading` использует Cormorant внутри документа — это
расхождение с принятым здесь правилом Literata. Целевой `SECTION_TITLE` в
[liturgical spec](LITURGY_CONTENT_VISUAL_SPEC.md) согласован документально;
реализация не менялась.

`7d48807` меняет Compendium на root → Part с плоским планом и отдельным
question reader; node/topic routes становятся compatibility redirects.
На main ещё drill-down. Рабочая `docs/compendium.md` описывает именно новую
ветку, поэтому нельзя по её тексту датировать внедрение на main. Ветка также
обновляет Songbook filters. Эти изменения сохраняются; Quiet Book определяет
визуальные роли и владение слотами, не отменяет доменную навигацию.

## 5. Обоснования, которые важно не потерять

### Типографика

Два книжных голоса имеют разные задачи: Cormorant обозначает титул страницы,
Literata ведёт длительное чтение. Системный шрифт обслуживает управление.
Стремление к одной гарнитуре везде стирало эту границу; три случайных системы
по разделам — другая крайность. Роли общие для всех книг.

Большие CAPS в «ЛІТУРГІЯ ГАДЗІН», «СТАРЫ ЗАПАВЕТ», «ПЫТАННЕ 42» обычно
уступают sentence case и ясному ритму. Короткое обозначение языка BE/LA/EN,
аббревиатура или обоснованный small-caps-приём не нарушают систему.
Исходный религиозный текст нельзя массово менять ради оформления.

Верх Aa 180% уже существует. Регресс до 160% ради узкой панели не оправдан.
Сначала адаптируется chrome; system scale не отменяется и не зажимается
ради макета. База 17 — ориентир калибровки, а не разрешение автоматически
увеличить сохранённый абсолютный размер у всех пользователей.

### Нижняя навигация

Mass уже доказывает, что локальная панель может быть единственным владельцем.
Следующий шаг — общий контракт, не обязательное слияние всех кнопок в ряд.
Первая гипотеза `(branch | ‹ | current section ▾ | ›)` сравнивается с более
короткой панелью и с адаптивной двухстрочной композицией внутри одного слоя.
Ширины 320/360/390, длинные белорусские названия, Aa 180% и system 200%
должны влиять на решение до миграции всех экранов.

### Цвет и материалы

Маркер без подписи недостаточен; сезон, празднование и выбранный контекст
должны быть понятны также без различения цвета. Контекстный tint, иконка часа
и очень лёгкий ambient у заголовка допустимы, если вместе остаются тише
текста. Настройки и глобальная навигация не становятся зелёными/фиолетовыми.
Рубрика — самостоятельная текстовая семантика, не сезонная краска.

### Branding

Первый аудит слишком рано предложил окончательный знак и исключил крест.
«Книга + ribbon» остаётся одним эскизным направлением. Отдельная branding task
должна проверить узнаваемость католической литургической книги, малые размеры,
light/dark и платформенные маски. Сдержанный крест или иной содержательный
католический мотив допустим; клипарт и перегрузка не являются требованием.
Финальное имя и знак выбирает владелец. Pipeline, adaptive/monochrome layers,
splash, manifest и источник строки имени можно готовить независимо, сохраняя
временный утверждённый asset до выбора нового.

## 6. Документационная архитектура

| Документ | Ответственность |
| --- | --- |
| [DESIGN_CONCEPT](design/DESIGN_CONCEPT.md) | Продукт, ощущения, неизменные принципы и иерархия документов |
| [DESIGN_SYSTEM](design/DESIGN_SYSTEM.md) | Роли, токены, компоненты, состояния, платформы, accessibility и acceptance |
| [LITURGY_CONTENT_VISUAL_SPEC](LITURGY_CONTENT_VISUAL_SPEC.md) | Semantic IDs, visual locators, source structure, CURRENT-срезы и точные TARGET ролей |
| [reader-foundation](reader-foundation.md), [app-shell-migration](app-shell-migration.md) и root migrations | Технические контракты reader, routes, Back, сохранения состояния |
| [songbook](songbook.md), [compendium](compendium.md), [prayerbook-migration](prayerbook-migration.md), [bible-migration](bible-migration.md) | Доменное поведение и ограничения книг |
| [offline-sync](offline-sync.md), [data-loading-architecture](data-loading-architecture.md) | Данные, cache, загрузка и синхронизация |
| Этот документ, DL 1.1, platform-design, library-design, reader-typography-vnext | Аудит, история и причины прежних решений; не конкурирующий визуальный канон |

При конфликте визуального правила приоритет Concept → System → целевые
специализированные роли. Исторический CURRENT не переписывается как TARGET.
Техническая спецификация сохраняет authority над данными, порядком литургии,
маршрутами и sync; общий визуальный документ не меняет их молча. В задаче,
затрагивающей оба слоя, фиксировать конкретный конфликт и согласованное решение.

Новых документов всего два. JSON 1.1 остаётся legacy handoff, не источником
новых Flutter-значений; экспорт из Dart — будущая часть Foundations, а не уже
выполненная генерация. Подробные locators и таблицы источника не копируются.

## 7. Roadmap после консолидации

Ни один этап реализации ниже в этой задаче не запускался.

| Этап | Работа | Выход / gate |
| --- | --- | --- |
| Phase 0 — docs | Эта консолидация и маркировка старых specs | Два канонических входа; история main/ветки разведена; утверждённые принципы не возвращаются владельцу на повторное голосование |
| Phase 1 — Foundations | Минимальный `IbTokens`, роли цветов/типографики/ритма; убрать seasonal primary/chrome; использовать имеющуюся font bundle и общую фабрику после интеграции ветки | Согласованные роли, neutral chrome, offline glyph/face QA, Aa + TextScaler matrix. Сначала решить интеграцию двух коммитов с владельцем ветки в отдельной реализации |
| Phase 2 — BottomSlot & chrome | Прототипы 2–3 композиций, выбор по accessibility; единый арбитр и измеряемые insets; адаптация Mass/Bible/Compendium/search/selection | Один владелец во всех переходах; длинные labels и последний абзац доступны; Mass dock fix сохранён |
| Phase 3 — Корни и коллекции | Cormorant page title; общий header/list rhythm; молитвенник как полка; спокойные Settings | Сравнение 320/360/390 light/dark на обеих платформах без нового dashboard |
| Phase 4 — Readers | Literata document headings, общий role mapping, сохранение anchor, Aa migration; убрать оставшиеся local overrides по роли | Все типы документов проходят единый контракт; source semantics и пользовательские предпочтения сохранены |
| Phase 5 — Platform/accessibility | Нативные переходы, predictive back, scroll edge, reduce motion/transparency, screen readers | Device QA обеих платформ; автоматические layout-тесты не выдаются за него |
| Parallel branding track | Имя, знак, узнаваемая католическая семантика, утверждение вариантов | Отдельное решение владельца; не блокирует Phases 1–4 |
| Pipeline/polish | Согласованные manifest, icon generation/adaptive layers/splash; финальные assets после branding | Нет несвязанных имён и старых placeholder-assets в поставке |

Не включать в новый backlog повторную центровку иконок, первичную упаковку
трёх fonts, удаление Mass dock, перенос Mass language наверх, создание
Songbook chord controls или получение версии из package info: это уже сделано.

## 8. Что ещё требует решения

**Владелец:** окончательное публичное имя, брендовый знак и роль `mary.png`;
политика Марыйного синего/местной традиции и цвета заупокойного контекста;
видимость Сакрамэнтаў до появления контента; судьба swipe даты на Hours root
(рекомендация — явный date picker). Это не блокирует визуальные foundations.

**Прототипирование/QA:** финальная геометрия ReaderBottomBar, место language
selector на узком экране, точная калибровка title/heading размеров и миграция
сохранённых значений ниже нового Aa-min. Это инженерно-дизайнерские проверки,
а не повод заново выбирать Quiet Book или пару Cormorant + Literata.

Рекомендуемый следующий implementation phase — **Foundations**, с отдельным
небольшим scope и проверкой состояния main перед началом. Branding и гипотеза
геометрии нижней панели не должны задерживать принятие семантических ролей.
