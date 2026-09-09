# Stage 7 Migration Audit

Дата: 2026-09-09. Репозиторий: `senddownrain/ibreviarybyapp`.
Audited branch: `feature/mobile-ux-migration`; commit: `991cfe4`.
Статус: read-only audit и спецификация Stage 8; production code, tests и assets не изменены.

## Executive verdict

**Утверждённая архитектура достаточна для завершения migration. Архитектурная переработка не обоснована. В main сейчас не рекомендовано: сначала устранить P1 и закрыть QA gates.**

Четыре раздела уже имеют общую навигационную модель и родственные readers. Hours ведёт непосредственно к часу, Readings открывает текст, Prayerbook выдвигает избранное, Bible сохраняет быстрые производственные взаимодействия. Наиболее заметная незавершённость находится в согласовании shell с вложенными маршрутами, доступности Bible, визуальном фоне dock и вторичных legacy surfaces.

Подтверждённые findings: **P0 — 0; P1 — 5; P2 — 11**. P3 не входит в объём завершения migration. Отсутствие обнаруженного P0 не означает отсутствие дефектов в непроверенных сценариях.

Документ пригоден для запуска финального Sol cleanup stage. Это **не полный visual/device sign-off**: матрица имеет явно обозначенные пробелы, прежде всего system text 150–200%, iOS вне Bible/Settings, жесты, экранные дикторы, клавиатура и аварийные состояния. Их нельзя превращать в PASS на основании сборки или widget tests.

### Prerequisite и источники

Перед review выполнены `git fetch`, переключение на целевую ветку, проверка чистого working tree. На момент аудита локальная ветка на один commit впереди tracking branch. Все стадии присутствуют:

| Stage | Commit | Содержание |
| --- | --- | --- |
| 1 | `9dea9c0` | Reader foundation / Ora |
| 2 | `6a6b958` | Shell / branch navigation |
| 3 | `1e65747` | Hours |
| 4 | `07731f6` | Readings |
| 5 | `62512de` | Prayerbook |
| 6 | `991cfe4` | Bible |

Нормативные источники: `docs/ibreviary-ux-handoff.md`, `app-shell-migration.md`, `reader-foundation.md`, `hours-root-migration.md`, `readings-root-migration.md`, `prayerbook-migration.md`, `bible-migration.md`, `platform-design.md`; prototype `prototypes/ux-architecture/{README.md,REFINEMENT.md,QA.md,index.html,styles.css,app.js,model.js,refinement.js}`. Prototype исследован как спецификация структуры, состояний и взаимодействий, без требования pixel-perfect HTML. Исторические `mobile-ui-audit-2026-09-07.md` и `docs/design/` использованы как контекст. При конфликте приоритет у final handoff/refinement: четыре tabs, нейтральный reader, chrome отдельно от content, Aa только для размера, календарная сетка, сохранение production Bible interactions. Старые рекомендации о glass content и bottom date navigation не переносить в Stage 8.

### Метод и воспроизводимость

Flutter 3.41.4 / Dart 3.11.1. Выполнены две release web сборки:

```text
flutter build web --dart-define=IBREVIARY_PLATFORM=android --output=C:/Users/User/AppData/Local/Temp/ibreviary-stage7-android
flutter build web --no-wasm-dry-run --dart-define=IBREVIARY_PLATFORM=ios --output=C:/Users/User/AppData/Local/Temp/ibreviary-stage7-ios
flutter test --reporter compact
```

Обе сборки успешны; **109 tests passed**. Лог: `C:/Users/User/AppData/Local/Temp/ibreviary-stage7-tests.log` (временный, не versioned artifact). Браузерное исследование выполнялось через локальные HTTP origins `127.0.0.1:48731` (Android) и `127.0.0.1:48732` (iOS), screenshots и accessibility tree. Старая страница с service worker на другом origin исключена из evidence. Скриншоты исследованы в сессии; отдельный screenshot bundle в репозиторий не добавлялся.

Обычная ширина: 390×844 logical px. Узкая: 320×720 для iOS Bible/Settings. iOS Bible также осмотрен при ширине 1280. Android узкая ширина отдельно не закрыта. Встроенный Aa проверен 100→130% в iOS Bible; **это не системный масштаб 130%**. Полная визуальная проверка system text 150/200% не выполнена.

Доступны Windows/Chrome/Edge; attached Android emulator/device и iPhone/simulator отсутствуют. Оба mobile platform paths реально собраны и открыты, но не являются native builds. iOS review проверяет Flutter platform expression, **не настоящий system Liquid Glass**.

Evidence labels ниже: **LIVE** — наблюдалось в работающей сборке; **CODE** — вывод из конкретной реализации; **TEST** — существующие автоматические проверки; **NOT VERIFIED** — сценарий не пройден. CODE не подменяет визуальную проверку на всех платформах.

## What works well

- **GOOD PRODUCTION DEVIATION:** Bible сохраняет переключение перевода, chapter picker и контекстную подсветку. Не заменять их универсальным reader toolbar ради внешней одинаковости.
- **GOOD PRODUCTION DEVIATION:** route/branch state позволяет вернуться из Prayer Detail к поиску; из Readings, открытых из Ora, — к исходной Ora и дате. Эти рабочие пути сохранить.
- **ACCEPTABLE DIFFERENCE:** Full dock у Readings root и Compact у вложенных readers оправданы их ролью. Даты Hours и Readings не обязаны быть глобально синхронизированы.
- **ACCEPTABLE DIFFERENCE:** структура стиха Bible и HTML молитвы требуют разных внутренних отступов и заголовков. Нужны общие роли и согласованный ритм, а не идентичная разметка.
- В основных readers текст уже не заключён в набор glass cards. Rubrics отделены от основного текста; длинный документ сохраняет нейтральную поверхность.
- Prayerbook с Favorites first, общими категориями и одним All Prayers entry ощущается быстрее прежнего каталога. Пустое избранное не блокирует доступ к молитвам.
- Alternatives допускают изучение групп, preview и templates до явного завершения; выбор не закрывает sheet преждевременно.
- Contextual verse palette заменяет dock. Focus в Prayer Detail скрывает chrome и имеет работающий выход. Не ломать эти решения при исправлении accessibility.
- Android использует Material controls/selection, iOS — Cupertino-подобные controls и blur chrome. Основные content surfaces не нужно вновь оборачивать в платформенный декор.

## P0 blockers

**None observed.** В пройденных обычных flows не обнаружен полностью недоступный reader или необратимая потеря навигации. Missing/corrupt content, destructive actions и system 200% не получили полного live coverage.

## P1 before merge

### P1-01 — Shell не уведомляет о смене descriptor при Full → Full

- **Screen / platform:** Prayerbook → All Prayers; LIVE Android Light/Dark; общий shell-код затрагивает оба paths.
- **Classification:** REGRESSION.
- **Problem:** сразу после открытия All Prayers shell menu остаётся поверх legacy Back. Accessibility tree содержит обе кнопки. После перехода в Compact Detail и обратно Full ситуация может исправиться, что делает поведение зависимым от истории.
- **Cause / files:** `lib/navigation/app_navigation.dart`, `BranchShellController.activate/reveal/remove`, `_publishResolvedMode` (около строк 63–123); `lib/widgets/app_shell.dart`; descriptors в `lib/router/router.dart`. Активный descriptor изменяется, но ValueNotifier уведомляет только при смене enum chrome mode. Shell при этом использует также owner и top inset.
- **Why:** визуально скрытый Back нарушает понятный выход и создаёт двойной chrome на ежедневном пути. Это локальный lifecycle defect, не основание менять router architecture.
- **Recommended change:** публиковать значимые изменения active entry/descriptor/chrome ownership и occupancy даже при прежнем mode; сохранить изоляцию branch overrides.
- **Acceptance:** root Full → nested Full → Back обновляет menu/Back/top inset без промежуточного Compact, дополнительных taps и зависания старого owner. Проверить также advanced picker и возврат из secondary routes через production router.

### P1-02 — Текст стихов Bible игнорирует system text scaling

- **Screen / platform:** Bible Chapter, оба paths по общему коду; CODE, не live system-200 reproduction.
- **Classification:** REGRESSION / accessibility.
- **Problem:** `_VerseRow` использует `RichText` без `textScaler` (`lib/screens/bible_chapter_screen.dart`, около строки 687). В используемом Flutter default — `TextScaler.noScaling`. Отдельный номер стиха через Text наследует масштаб, а тело стиха — нет. Aa меняет fontSize и работает; это другая настройка.
- **Why:** пользователь системного крупного текста получает непропорционально мелкую основную информацию. Проверка только отсутствия overflow не обнаружит проблему.
- **Recommended change:** наследовать актуальный `MediaQuery.textScaler` в rich text, сохранив размер Aa и поддерживаемое Flutter поведение scaling; не вводить самодельный фиксированный множитель вместо системной модели.
- **Acceptance:** фактические размеры стихов и номеров корректны при system 100/150/200%, Aa 100/130/180%, ширине 320/390; текст не обрезается и доступен до последнего стиха. Проверять layout/семантику, а не только `takeException()`.

### P1-03 — Verse palette недоступна без распознавания цвета

- **Screen / platform:** Bible selection; LIVE Android accessibility tree + CODE обоих paths.
- **Classification:** REGRESSION / accessibility.
- **Problem:** четыре цветовые кнопки представлены без имён; swatches имеют 32×32 layout, нет достаточного явно заданного touch target и семантического выбранного состояния. Выделенный стих передаёт состояние преимущественно рамкой/цветом.
- **Files:** `lib/screens/bible_chapter_screen.dart`, `_colorBar` (около 356–405), `_VerseRow`.
- **Why:** screen reader не объясняет результат действия; маленькие цели затрудняют выбор.
- **Recommended change:** локализованные имена цветов/действий и selected state, достаточная интерактивная область (44 pt iOS / 48 dp Android), доступные erase/cancel и safe-area placement. Сохранить существующие цвета, ключи и данные highlights.
- **Acceptance:** четыре различимые действия в semantics; выбор, применение, очистка и отмена доступны с TalkBack/VoiceOver; palette помещается на 320 и не сосуществует с dock. Не считать Web AX полноценной проверкой диктора.

### P1-04 — Ручная смена группы Readings выглядит автоматической

- **Screen / platform:** Readings options, LIVE Android Light на 2026-09-08; CODE общий.
- **Classification:** REGRESSION.
- **Reproduction:** открыть Marian readings 8 сентября → `Варыянты` → обычная группа дня. Текст изменяется, но маркер ручного выбора отсутствует.
- **Cause / files:** `lib/screens/readings_screen.dart`: `_selectCelebrationGroup` (около 151) изменяет group и сбрасывает `_manualCycle`; `manualLabel` зависит от cycle; `Па календары` сбрасывает cycle, а не исходный автоматический group.
- **Why:** интерфейс неверно сообщает происхождение выбранного результата, хотя сами тексты доступны. Это UX состояния, не найденная ошибка литургического resolver.
- **Recommended change:** учитывать ручной override группы отдельно от cycle; показывать ручной статус при любом departure и дать возврат к исходному календарному результату существующего resolver. При смене даты очистить соответствующий override.
- **Acceptance:** group-only, cycle-only и совместный override ясно различимы; auto восстанавливает исходную группу/cycle. Даты веток остаются независимыми.

### P1-05 — Под floating dock видна белая full-width полоса в Dark

- **Screen / platform:** LIVE Android Dark Bible/Prayerbook/All Prayers; iOS Dark Bible при 320 и 1280. На Light тоже заметно отделение области dock, но наиболее сильный дефект — Dark.
- **Classification:** REGRESSION / visual coherence.
- **Problem:** тёмный reader обрывается над белой полосой высотой примерно 70 px вокруг тёмного dock. Нижняя область выглядит отдельной системной панелью, а не частью общего ambient background.
- **Files / likely cause:** `lib/widgets/app_shell.dart`: прозрачный Scaffold, AmbientBackdrop в body, bottomNavigationBar вне его; проверить также web host/theme background. Окончательная локализация причины требует проверки исправления; native reproduction ещё не выполнено.
- **Why:** дефект постоянно заметен и разрушает Dark composition во всех разделах с этим shell.
- **Recommended change:** обеспечить непрерывный непрозрачный theme/ambient фон всего shell, включая область вокруг dock, сохранив зарезервированную высоту и floating отступы.
- **Acceptance:** Full и Compact имеют правильный окружающий фон Light/Dark на обоих paths; Hidden и palette не оставляют белой полосы. Повторить на native перед merge.

## P2 polish

Каждый ID ниже — один finding; связанные симптомы сгруппированы, чтобы не раздувать severity count.

### P2-01 — Android translation selector ломает короткие подписи

**Screen/platform/evidence:** Bible, Android Light, LIVE 390 px. **Classification:** POLISH ISSUE. Selected Material segment переносит `БЕЛ` / `РУС` на две строки; checkmark конкурирует за фиксированные 154 px. iOS на 320 сохраняет подписи. **Impact:** постоянно видимый control выглядит сломанным. **Change:** адаптировать ширину/минимумы/selection indicator, не убирать быстрый перевод. **Files:** `lib/screens/bible_chapter_screen.dart`, `_translationSelector`. **Acceptance:** обе подписи читаются целиком на 320/390 при system scaling, выбранное состояние остаётся очевидным.

### P2-02 — Context header меняет ширину и горизонтальную привязку

**Screen/platform/evidence:** Bible и Readings, LIVE Android; iOS Bible тоже показывает узкий центрированный header. **Classification:** POLISH ISSUE. `Align(topCenter)` + только maxWidth позволяет короткому header сжиматься, тогда как текст занимает широкую колонку. В Readings loading → длинный loaded title меняется и выравнивание. **Impact:** нестабильная иерархия и визуальный скачок. **Change:** стабильная адаптивная ширина header/content column, согласованные anchors. **Files:** `lib/widgets/reader/reader_scaffold.dart`, `ReaderContextHeader`, screens Readings/Bible. **Acceptance:** короткий/длинный title и loading используют один осмысленный anchor, без требования одинаковой семантики заголовков.

### P2-03 — Между roots и readers расходятся typography и spacing roles

**Screen/platform/evidence:** Hours/Readings/Prayerbook/Prayer/Ora/Bible, LIVE частично + CODE обоих paths. **Classification:** POLISH ISSUE. Hours/Readings имеют display serif около 38/36, Prayerbook — sans bold около 32; вложенные context titles около 27. Внешние поля 20/22/24 и дополнительные reader insets 8 создают разные границы; local bottom paddings 116/120 сочетаются с shell occupancy. **Impact:** видны границы отдельных migration stages, лишний хвост после коротких списков. **Change:** согласовать роли root title/context title/metadata/row и ownership отступов, не делать все размеры одинаковыми. **Files:** `lib/theme/reader.dart`, shared scaffold, `home_screen.dart`, `prayers_screen.dart`, остальные readers. **Acceptance:** сравнительный review 320/390, короткий/длинный документ, Full/Compact/Hidden без двойного нижнего резерва и без перекрытия последней строки.

### P2-04 — Биография в Ora оттесняет саму молитву

**Screen/platform/evidence:** Ora, Android Light, LIVE Peter Claver 2026-09-09. **Classification:** POLISH ISSUE. Полный feast comment в context занимает большую часть первого экрана; начало молитвы около y=500. **Impact:** ежедневный reader стартует длинной справкой, тогда как Hours уже показывает краткое описание. **Change:** краткое summary с доступным раскрытием полного текста; не удалять информацию и не менять liturgical content. **Files:** `lib/screens/ora_screen.dart`, context header. **Acceptance:** час и начало молитвы доступны без чрезмерного вводного блока, biography по-прежнему читается полностью при большом тексте.

### P2-05 — Seasonal context расходится между Hours и Readings и протекает в dock

**Screen/platform/evidence:** LIVE Marian 2026-09-08 Hours blue → связанные Readings gold; CODE глобального dock tint. **Classification:** REGRESSION в presentation. Readings выводит цвет из другого набора metadata; shell использует Hours season provider и на Prayerbook/Bible. Alternatives может удерживать переданный при открытии цвет после смены выбора. **Impact:** один праздник меняет атмосферу по пути, нерелевантные ветки получают литургический акцент. **Change:** согласовать presentation context и приоритет Marian/solemnity по утверждённой модели; нейтрализовать нерелевантный branch chrome, обновлять sheet accent вместе с выбранным preview. **Files:** `home_screen.dart`, `ora_screen.dart`, `readings_screen.dart`, `app_shell.dart`, соответствующие color providers. **Acceptance:** один Marian контекст согласован в Hours/Ora/Readings; обычные Prayerbook/Bible нейтральны. Не переписывать resolver, календарь и независимые даты.

### P2-06 — Видимые secondary routes сохраняют старый visual language

**Screen/platform/evidence:** Settings LIVE Light/Dark обоих paths; About/calendar/advanced picker/Favorites/My Prayers/form — CODE. **Classification:** POLISH ISSUE. Settings помещает большой объём content в GlassSurface; аналогичные legacy cards есть на secondary screens, Android calendar использует прямой GlassSurface. Advanced picker не имеет собственного очевидного Back при legacy chrome ownership; live-проверка выхода ещё нужна. **Impact:** основной продукт современный, административные и календарные пути выглядят отдельным старым приложением. **Change:** заменить именно content glass на нейтральные/tonal surfaces, согласовать secondary chrome и видимый выход из advanced picker. iOS chrome blur сохранять. Final calendar — month grid; wheel-only вариант не считать целевым решением. **Files:** `settings_screen.dart`, `about_screen.dart`, `ambient_date_picker.dart`, `liturgical_picker_screen.dart`, `my_prayers_screen.dart`, `prayer_form_screen.dart`, secondary scaffold. **Acceptance:** вторичные пути доступны Back/close, Android content без glass, keyboard/large text не обрезают управление. Не удалять живые маршруты ради уборки файлов.

### P2-07 — Settings не завершены относительно final handoff

**Screen/platform/evidence:** Settings обоих paths, LIVE + CODE. **Classification:** REGRESSION / POLISH ISSUE. Видимый font-family control сохраняет прежнюю модель; отсутствует настройка стартового раздела, router стартует Hours; category management продублирован, version label hardcoded. **Impact:** настройки не соответствуют утверждённым preferences и содержат migration leftovers. **Change:** выполнить KEEP/MOVE/REMOVE inventory ниже, реализовать только уже согласованный start preference, получать version из package info. **Files:** `settings_screen.dart`, `settings_provider.dart`, `router/router.dart`, category management, About. **Acceptance:** Aa остаётся size-only, preferences сохраняются, старые stored font values не уничтожаются, начальный маршрут валиден.

### P2-08 — При повторном входе All Prayers query не соответствует результатам

**Screen/platform/evidence:** Android Light/Dark, LIVE. **Classification:** REGRESSION. После поиска `Ойча`, Detail → Back корректен; при новом входе в All Prayers поле сохраняет `Ойча`, но список показывает весь каталог. **Cause:** `PrayerCatalog` init post-frame очищает filters, одновременно инициализируя TextEditingController и `_searching` старым query. **Impact:** пользователь не понимает, какие результаты отфильтрованы. **Change:** единая политика входа и синхронизация query UI/provider; не ломать рабочее сохранение поиска при Detail → Back. Убрать лишнее отдельное search action, когда поле уже открыто, только если оно не даёт дополнительного действия. **Files:** `lib/screens/prayers_screen.dart`, prayer filters provider. **Acceptance:** repeat entry, tab return и Detail Back показывают одинаковый query и соответствующие результаты.

### P2-09 — Modal sheets имеют разную область блокировки shell

**Screen/platform/evidence:** alternatives/date/Bible picker LIVE Android, Aa LIVE iOS; CODE. **Classification:** POLISH ISSUE. Branch bottom sheets затемняют body, оставляя shell controls/dock за пределами scrim; iOS Aa root popup перекрывает dock. **Impact:** разная визуальная модальность; неясно, доступна ли смена раздела под picker. Фактический switch-through-modal не подтверждён. **Change:** определить ownership каждого modal и согласовать navigator/scrim/focus, не вводя обязательный универсальный sheet. Проверить Bible picker высотой 88% при keyboard, alternatives preview вне scrollable области при 200%, palette bottom safe area. **Files:** modal callers в Hours/Readings/Bible, `text_scale_control`, shell/navigation. **Acceptance:** закрытие/Back возвращает исходный контекст; modal не оставляет активного неожиданного chrome; keyboard и крупный текст не скрывают Done/результат. Непроверенные keyboard риски не считать отдельными дефектами.

### P2-10 — Пустой Bible corpus может оставить бесконечный loading

**Screen/platform/evidence:** Bible root, CODE, без live повреждения хранилища. **Classification:** REGRESSION / state handling. `BibleBranchHost` при пустом books и отсутствии explicit version возвращает spinner; пустой конечный результат не отличён от загрузки. Для explicit invalid version есть ошибка. **Impact:** при недоступном/default corpus пользователь не получает объяснения и retry. **Change:** различать pending и завершившийся empty/error, дать спокойное actionable состояние с retry; сохранить seed loader и location fallback. **Files:** `lib/widgets/branch_hosts.dart`, `lib/navigation/bible_navigation.dart`, существующие repository/loading state. **Acceptance:** default empty, saved invalid version, explicit invalid version и нормальный cached corpus завершаются определённым состоянием. Не исправлять подменой всех ошибок пустым reader.

### P2-11 — Platform transition policy не доходит до branch pages

**Screen/platform/evidence:** router, CODE; native gestures NOT VERIFIED. **Classification:** POLISH ISSUE. Branch routes используют `_ShellFadePage`; общая platform transition theme сама по себе не делает эти переходы платформенными. **Impact:** secondary navigation может ощущаться одинаковым fade на обеих платформах, несмотря на адаптированные controls. **Change:** проверить ожидаемые route transitions и Back semantics, затем минимально согласовать page implementation с platform policy. **Files:** `lib/router/router.dart`, platform theme. **Acceptance:** native iOS back swipe и Android predictive/system Back проходят device QA. По одному наличию fade не утверждать, что жесты уже сломаны; архитектуру branches сохранять.

## P3 future

Исследование настоящих system material effects и дальнейшая настройка анимаций за пределами подтверждённого parity — future work. Новый dashboard, новая IA, новый reader, новый Bible concept и новый liturgical resolver не входят в Stage 8.

## Cross-platform audit

Один продукт уже читается через общий dock и reader foundation. iOS имеет округлые layered controls, компактный translation segment и Cupertino Aa popup. Android даёт Material selection/tonal expression; это больше, чем простое отключение blur. Но Android сохраняет Apple-like композицию в capsule-heavy floating chrome и особенно в прямых legacy GlassSurface calendar/settings. Коррекция нужна в surfaces и плотности, а не в смене архитектуры.

Dark review выявил общий дефект подложки dock. iOS Bible на 320 при Aa 130% остаётся читаемым, но большой текст занимает больше высоты; это не доказательство доступности Full dock при system 200%. Native status bars, cutouts, home indicator, blur performance и реальные system gestures не проверены.

## Shell / Dock и floating inventory

| Screen | Top left | Top right / local context | Bottom / mode | Решение |
| --- | --- | --- | --- | --- |
| Hours | Menu | Date/today в контексте; alternatives | Full | Сохранить; исправить фон и ownership |
| Ora | Back | Aa, Чытанні, change hour/overflow | Compact; focus Hidden | Не убирать contextual readings; проверить плотность на 320/200 |
| Readings root | Menu | Aa / options и date context | Full → Compact при чтении; focus | Сохранить dual role root/reader; live long-scroll переход не закрыт |
| Prayerbook | Menu | Управление в соответствующих sections | Full | Favorites/category/all hierarchy сохранить |
| All Prayers/category | Back по локальному scaffold | Search/filter | Full | Устранить menu поверх Back; query sync |
| Prayer Detail | Back | Favorite, Aa, overflow/focus | Compact / Hidden | LIVE focus и выход работают |
| Bible Chapter | Menu на root | Search, Aa, overflow; book/translation в context | Compact; palette заменяет dock | Сохранить локальный picker/перевод |
| Settings/secondary | Back | Действия конкретного экрана | Вне основного reading flow | Убрать legacy decorative content surfaces |

Full имеет labels и selected state; менять набор tabs не нужно. White band нарушает floating impression. Compact сообщает активную ветку и имеет expand affordance, не требует увеличения до обычной navigation bar. Hidden в Prayer Detail реально освобождает пространство и позволяет вернуться; все остальные readers ещё требуют live выхода на узком экране. Проверка safe areas и нижней последней строки обязательна для каждого mode.

Обоснованно устраняемые постоянные controls: лишний menu поверх Back (P1-01), отдельная search кнопка при уже открытом поле без нового действия (P2-08). Доказанного дублирования Aa в двух местах на migrated reader не обнаружено. Previous/next chapter и tabs — разные задачи; их не удалять как «двойную навигацию».

## Hours

LIVE Android Light: обычный день 9 сентября, выбор Peter Claver, templates (включая works of mercy), preview и Done; прямой переход в Laudes/Ora. Группировка alternatives понятна, sheet позволяет изучать варианты. Большая metadata не должна превращаться в dashboard card.

Date sheet: переход на 8 сентября, Marian celebration и возврат одной командой `Сёння` на 9 сентября пройдены. Постоянная старая bottom date navigation не вернулась. Календарь и advanced picker требуют отдельного live прохода; code review показывает legacy surface/Back concern, описанные в P2-06. Не вводить новые fixtures или resolver ради seasonal QA.

## Ora

LIVE Android Light: загружены тексты Peter Claver и Marian дня; основной текст и rubrics читаются, нейтральный документ сохранён. Самый заметный density issue — длинная biography перед молитвой. Back → Hours и contextual Readings → Back → та же Ora 8 сентября пройдены. URL связанного Readings сохраняет date/dayId. Точное восстановление pixel scroll offset не измерялось.

Change-hour полный перебор, Ora focus на обоих paths, длинные rubrics при system 200% и keyboard/screen-reader focus order остаются NOT VERIFIED. Не считать успешный Prayer Detail focus доказательством всех Ora interactions.

## Readings

Результат действительно первичен: root открывает текст, cycles находятся в options. LIVE Marian → ordinary group подтвердил P1-04, а сопоставление с Hours — P2-05. Options не нужно выносить на главный экран. CODE поддерживает reader mode, однако Full→Compact на длинном scroll live не закрыт.

Путь Ora → contextual Readings → Back сохраняет исходный литургический контекст. Отдельные Today Readings, независимость дат после нескольких чередований tabs, cycle override/auto и точное восстановление scroll требуют QA. Эти проверки не заменять синхронизацией двух дат.

## Prayerbook и Prayer Detail

LIVE: пустое избранное, затем добавление существующей молитвы в Favorites; категории после загрузки, каталог из 116 prayers, поиск `Ойча`, Detail и Back с сохранённым query; Hidden/focus и выход. В Dark осмотрены root, избранное и All Prayers. Последующий новый вход выявил отдельный stale-query дефект.

Favorites first работает; не возвращать admin/catalog root. Текущий Detail родственен Ora через typography/Aa, но не нуждается в искусственных liturgical metadata. Category → Detail → Back, длинный Favorites list, reorder/category management и полный user prayer create/edit/delete flow не пройдены live. Save/delete handlers и маршруты исследованы по коду; реальные пользовательские молитвы не удалялись. Destructive actions должны оставаться явными и отменяемыми, cancel формы — без сохранения.

## Bible

LIVE Android: tab сразу открывает Genesis 1; BEL → RUS сохраняет книгу/главу; picker открывает chapter 2; выбор стиха показывает palette вместо dock, применение цвета возвращает dock; уход/возврат и повторное открытие сохраняют RUS/chapter 2. Это важные рабочие production decisions.

LIVE iOS: Genesis 1 на 390 и 320, корректные короткие translation labels; Aa 100→130% увеличивает текст; закрытие modal работает. Dark на 320 подтверждает P1-05 и P2-02. Текст не заключён в verse cards.

Bible search, previous/next boundaries, переход к найденному стиху, persisted highlight после полной перезагрузки, точный scroll restoration и все сочетания selection/focus/tab return остаются NOT VERIFIED live. Код и существующие tests дают частичное покрытие; не объявлять эти flows сломанными без воспроизведения. Empty/corrupt root concern выделен отдельно как CODE finding.

## Shared Readers

Таблица сравнивает implementation и наблюдавшиеся состояния; не является полной платформенной PASS-матрицей.

| Aspect | Ora | Readings | Prayer | Bible |
| --- | --- | --- | --- | --- |
| Content width | Shared max column, внутри HTML дополнительные поля | Shared reader column | Родственная колонка, внешний inset отличается | Shared column + verse inset около 8 |
| Top inset | Reader chrome + длинный context | Root chrome + date/context | Back/actions + title | Root controls + shrink-wrapped context, P2-02 |
| Bottom inset | Shared occupancy + document padding | Mode-dependent occupancy | Compact/Hidden occupancy | Occupancy; selection slot вместо dock |
| Typography | Literata body, HTML rhythm около 1.75 | Literata, scripture/section hierarchy | Literata, HTML rhythm около 1.7 | Literata, verse rhythm около 1.72; system scale bug |
| Heading scale | Context + semantic hour headings | Display root + scripture sections | Prayer title без liturgical обвязки | Book/chapter + testament/reference |
| Aa | Shared size control | Shared size control | Shared size control | Shared control; LIVE 100→130 |
| Back | Возврат к Hours, LIVE | На root menu; contextual Back к Ora, LIVE | К списку/query, LIVE | Root menu; search/secondary Back по маршруту |
| Compact dock | Default reader | Root Full, scroll может Compact | Default reader | Default chapter; expand доступен |
| Focus | Реализация есть, live не закрыт | Реализация есть, live не закрыт | LIVE hide/restore PASS | Реализация есть, полный live цикл не закрыт |
| Scroll restoration | Точный offset NOT VERIFIED | Точный offset NOT VERIFIED | Query/state сохранены; offset не измерен | Location сохранена LIVE; offset NOT VERIFIED |
| Seasonal effect | Context atmosphere, neutral document | Neutral text; Marian context mismatch | Не нужен liturgical tint | Не нужен liturgical tint; shell leak |
| Selection chrome | HTML semantics/content | Scripture content | Prayer content | Verse palette; P1-03; заменяет dock |

Различия line-height и verse layout сами по себе допустимы. Основные точки общей доводки: header anchors, типографические роли и единое владение safe-area/dock padding. `ReadingScaffold` остаётся используемой частью reader chain, не является автоматически мёртвым legacy.

## Seasonal styling

**Neutral content + liturgical atmosphere достигнуто частично.** Длинные тексты нейтральны — это сохранить. На Hours Marian blue заметен и не окрашивает весь документ. Проблема — согласование presentation context в Readings и глобальная окраска dock вне литургических branches.

LIVE покрыты ordinary и Marian. Advent/Lent и red/martyr не проверены визуально как отдельные целостные экраны; наличие цветовых веток в коде не означает PASS. Peter Claver не засчитывается как автоматически проверенный red/martyr. Stage 8 QA должен выбирать реальные доступные даты, сохранить precedence solemnity/gold и Marian tags без нового resolver.

## Typography & spacing

Основной читаемый serif body — сильная сторона. Root titles, metadata и secondary settings пока менее согласованы. Не вводить новый font system: согласовать существующие semantic tokens и убрать случайные локальные значения только там, где видно расхождение.

Особое внимание: чрезмерная Ora biography; Bible header с иной шириной; перенос БЕЛ/РУС; длинные белорусские labels; накопление bottom padding. Reader paragraph/rubric rhythm оценивать на реальном тексте, а не коротком placeholder. Численный contrast ratio не измерялся: вывод «контраст соответствует WCAG» этим audit не выдан. Субъективно видимые текст/rubrics при обычном масштабе читаемы.

## Sheets / dialogs / pickers

| Surface | Evidence | Что сохранить / довести |
| --- | --- | --- |
| Alternatives | LIVE Android Light | Groups, preview, templates, stay-open; large-text height и смена accent требуют проверки |
| Date sheet | LIVE Android Light | Компактный выбор и Today; согласовать modal ownership |
| Calendar | CODE | Final month grid, platform surface; не закреплять legacy wheel/glass как конечный UX |
| Advanced Liturgical Picker | CODE | Сохранить доступный advanced path; проверить явный Back и inset |
| Readings options | LIVE group; cycle CODE | Механизм вторичен; исправить manual/auto marker |
| Prayer search/filter | LIVE query; management CODE | Query/result sync; keyboard на устройстве ещё не проверен |
| Bible book/chapter picker | LIVE Android | Сохранить production selection; keyboard/viewInsets и большой текст проверить |
| Aa | LIVE iOS | Только размер, понятные minus/plus и close; не добавлять font selector |

Не требовать одинакового widget для всех surfaces. Требовать одинаковой ясности: title → выбор → результат → закрытие, доступные цели, корректные safe areas и возврат фокуса. Ни ошибки клавиатуры, ни подтверждённой destructive regression live не обнаружено: соответствующие сценарии не пройдены.

## Settings / Drawer / secondary navigation

| Decision | Элементы | Обоснование / ограничение |
| --- | --- | --- |
| KEEP | Theme, reader size, keep-screen-awake, sync, полезная информация о доступности данных | Реальные preferences и операции; сохранить их persistence |
| KEEP / complete | Утверждённый start section / last-location preference | В final handoff предусмотрен; сейчас отсутствует, P2-07; без новых primary destinations |
| MOVE | Category management | Один canonical пользовательский путь из Prayerbook; не два несовпадающих редактора |
| MOVE | About/version | Компактный secondary маршрут; version брать из package info |
| REMOVE from visible UI | Legacy font-family chooser | Final typography едина; stored preference совместимость не удалять автоматически |
| TECHNICAL/DEBUG ONLY | Raw collection counts/status diagnostics | Пользователю показывать понятное состояние sync/content; технические детали доступны для диагностики |

Primary destinations вынесены в dock; drawer не должен снова дублировать четыре tabs. Settings/About/Sync сохраняют secondary роль. Transitional prayer shortcuts ещё дают доступ к Favorites/My Prayers/управлению; перед удалением shortcut доказать наличие равноценного canonical пути. Удаление дублирующего entry не означает удаление пользовательской функции или данных.

Sync экран/состояния и About изучены по коду; реальная ошибка sync, offline toggle и полное выполнение sync вручную не проверены. Не запускать опасную очистку кэша для визуального audit.

## Error / empty / offline states

| State | Coverage / verdict |
| --- | --- |
| Loading | LIVE Hours/Readings/Prayerbook; загрузка завершается в исследованном dataset; header jump P2-02 |
| Empty favorites | LIVE: не блокирует каталог, понятный путь к молитвам |
| Empty category/search | CODE; полный live empty-state review NOT VERIFIED |
| No text / no readings | CODE; production date с этим состоянием не воспроизведена |
| Prayer not found | CODE / существующие route checks; визуальный sign-off отсутствует |
| Bible missing/corrupt | CODE concern P2-10; хранилище не повреждалось для воспроизведения |
| Sync error | NOT VERIFIED live |
| Offline with valid cache | Контент сохранялся между открытиями; сеть намеренно не отключалась, offline PASS не выдан |

Целевой contract: спокойное сообщение внутри branch/content, одна релевантная retry/action, доступный Back/tab exit. Cached offline reading — обычный режим, без агрессивного warning поверх доступного текста. Не менять repositories/бизнес-правила только ради одинакового рисунка empty state.

## Accessibility

Web позволяет проверить layout, очевидные touch dimensions, AX names и часть focus order. Подтверждённые дефекты — P1-02/P1-03; P1-01 дополнительно создаёт две конкурирующие цели. iOS Aa 130% и width 320 проверены отдельно от system scaling.

Существующий dock test задаёт MediaQuery 320×640 и textScaler 2, но это само по себе не устанавливает реальную test surface width: без настройки view/layout constraints такой тест может фактически раскладывать dock шире 320. Проверки «нет exception» также не доказывают, что RichText масштабируется. В Stage 8 усилить проверки фактического поведения, не добавляя тесты, которые только повторяют implementation.

Нужны: system 100/150/200 на реальной узкой поверхности, увеличенный Aa, именованные icon-only actions, selected semantics, focus return после dialog, minimum touch area, последний абзац над dock/palette, contrast измерение для text/rubrics/disabled/selected в Light/Dark. TalkBack/VoiceOver reading order и native safe areas обязательны отдельно.

## Screen matrix

`PASS` означает только успешный просмотр указанного сценария; `POLISH` — замечания P2; `FIX` — затрагивает P1; `NOT VERIFIED` — нет достаточного visual evidence. Result агрегирует найденные проблемы, **не полноту coverage**. `CODE FIX` в 200% — известный дефект из кода без live системного масштаба. iOS Hours был виден в loading, поэтому готовый экран не засчитан.

| Screen | iOS Light | iOS Dark | Android Light | Android Dark | 200% | Result |
| --- | --- | --- | --- | --- | --- | --- |
| Hours root | NOT VERIFIED | NOT VERIFIED | POLISH | NOT VERIFIED | NOT VERIFIED | POLISH |
| Alternatives | NOT VERIFIED | NOT VERIFIED | POLISH | NOT VERIFIED | NOT VERIFIED | POLISH |
| Ora | NOT VERIFIED | NOT VERIFIED | POLISH | NOT VERIFIED | NOT VERIFIED | POLISH |
| Readings root | NOT VERIFIED | NOT VERIFIED | FIX | NOT VERIFIED | NOT VERIFIED | FIX |
| Prayerbook root | NOT VERIFIED | NOT VERIFIED | POLISH | FIX | NOT VERIFIED | FIX |
| All Prayers | NOT VERIFIED | NOT VERIFIED | FIX | FIX | NOT VERIFIED | FIX |
| Prayer Detail | NOT VERIFIED | NOT VERIFIED | POLISH | NOT VERIFIED | NOT VERIFIED | POLISH |
| Bible Chapter | POLISH | FIX | FIX | FIX | CODE FIX; visual NOT VERIFIED | FIX |
| Settings | POLISH | POLISH | POLISH | POLISH | NOT VERIFIED | POLISH |

## Interaction coverage ledger

| Flow | Evidence / результат |
| --- | --- |
| Hours → alternative → hour → Ora | LIVE Android: пройден |
| Ora → Readings → Back → Ora → Back | LIVE Android 8 сентября: пройден, контекст сохранён |
| Hours other date → Today | LIVE Android: пройден |
| Readings other date → Today / date independence stress | NOT VERIFIED целиком |
| Prayerbook → Search → Detail → Back | LIVE Android: пройден; отдельный repeat-entry bug P2-08 |
| Category → Detail → Back | NOT VERIFIED live |
| Prayer create/edit/delete/cancel | CODE, live NOT VERIFIED |
| Bible → translation → chapter → highlight | LIVE Android: пройден; palette accessibility FIX |
| Bible → other tab → return | LIVE: location сохранена; точный offset/highlight persistence не закрыты |
| Bible search / previous-next boundaries | CODE/TEST, live NOT VERIFIED |
| Все четыре branches туда-обратно с глубоким stack | Частичное live покрытие + tests; полный sweep NOT VERIFIED |

## Legacy cleanup inventory

### Safe to remove after final reference check

- `lib/screens/bible_screen.dart`: старый BibleScreen не является production Bible root; поиск ссылок в `lib`/`test` показывает только собственную декларацию. Удалять отдельным cleanup diff после повторной проверки references/routes.
- `lib/widgets/bottom_nav.dart`: старый widget не используется в найденных production imports. Удалить после проверки полного repo, не затрагивая `app_navigation_dock.dart`.
- Очевидные неиспользуемые imports/dead private helpers — только после analyzer/reference proof в конкретном diff. Не разрешение на широкое удаление compatibility кода.

### Retain compatibility temporarily

- `hora_picker_screen.dart` и `reading_detail_screen.dart`: compatibility routes ещё существуют. Это не то же самое, что daily root flow; сохранить external/deep links до доказанного migration path.
- `widgets/reading_scaffold.dart`: используется reader chain; сохранить или интегрировать осмысленно, не удалять по имени.
- Favorites/My Prayers/prayer form/category management: реальные пользовательские функции. Сначала canonical access и UX polish, затем лишние shortcuts.
- Route descriptors, branch observers и contextual bottom slot: рабочая основа migration; исправить уведомления, не заменять её новой системой.
- GlassSurface как примитив: не удалять глобально, он нужен iOS chrome. Убирать только подтверждённые legacy content usages.
- SharedPreferences keys, last Bible location, highlights, favorites, local prayers, loader/cache contracts: данные и совместимость сохранить.

### Revisit later

- Исторические audit/design docs оставить как provenance, явно указывать приоритет final handoff.
- Native material effects и transition tuning после device evidence.
- Более крупное объединение reader adapters возможно только при самостоятельной технической необходимости, не как условие визуального единства.

## Device QA still required

1. Android native и iPhone: Light/Dark × 320–360/обычная ширина × system 100/150/200; Aa отдельно 100/130/180. Закрыть NOT VERIFIED cells screen matrix.
2. Full/Compact/Hidden: safe areas, home indicator/cutout, label clipping, последняя строка, expand и выход из focus; palette не перекрывает и не дублирует dock.
3. TalkBack/VoiceOver: порядок заголовков/текстов, names/selected state, modal focus trap/return, verse selection/erase/cancel, Back.
4. Native iOS back swipe, Android system/predictive Back: вложенные routes, sheets, search, nested Full transitions. Flutter Web не подтверждает эти жесты.
5. Keyboard: Bible picker/search, prayer search/form, category editor; scroll к focused field и submit/cancel при крупном тексте.
6. Реальные available даты Ordinary, Lent/Advent, Red/Martyr, Marian: Hours/Ora/Readings, приоритет celebration, смена альтернативы и independent dates.
7. Missing/corrupt/empty/loading/retry и offline cached content на изолированном тестовом профиле; не повреждать пользовательские данные. Sync error без агрессивной перекрывающей reader панели.
8. Полные state restoration flows: все branches, search/category stack, Bible result verse/translation/chapter/scroll/highlight после возврата и relaunch; user prayer edit/delete/cancel с тестовыми данными на QA stage.

## Recommended Stage 8 implementation plan

### Batch A — P1 UX fixes

**Scope:** P1-01–05, без redesign. Исправить shell notifications, Bible system scale и palette semantics/targets, manual group status/auto reset, общий фон dock.

**Files/components:** `navigation/app_navigation.dart`, `widgets/app_shell.dart`, `screens/bible_chapter_screen.dart`, `screens/readings_screen.dart`, точечные regression tests через production router.

**Dependencies:** audited commit как baseline; сначала shell ownership, затем проверка bottom slots/background. **Risks:** двойные rebuilds/потеря branch override, double scaling, изменение highlight keys, непреднамеренная смена liturgical selection. Не трогать repositories/resolver без доказанной необходимости.

**Exit gate:** воспроизводимые P1 сценарии исправлены и проверены; работающие Daily/Prayer/Bible flows сохранены. Сборки обоих paths и релевантные tests проходят.

### Batch B — Shared visual polish

**Scope:** P2-01–09 и доказанная необходимость P2-11: стабильная колонка, типографические роли и padding, компактная biography, seasonal presentation, Android content surfaces, modal ownership, Settings и query sync. Не менять tabs/IA/Bible controls.

**Files/components:** shared reader/theme, migrated screens, secondary scaffold, calendar/sheet callers, settings/provider, route page policy.

**Dependencies:** Batch A ownership/occupancy contract. **Risks:** унификация уничтожает полезные semantic differences; скрытие полезных preferences; локальные padding fixes создают двойной резерв. Менять token/role с проверкой четырёх readers рядом, не набором случайных screen overrides.

**Exit gate:** visual comparison Light/Dark на 320/390, понятные modal/secondary Back, корректные labels, нейтральный Prayerbook/Bible и согласованный Marian контекст.

### Batch C — Legacy cleanup и terminal states

**Scope:** удалить только доказанно мёртвые BibleScreen/bottom nav/imports; сохранить live compatibility routes и данные. Исправить P2-10 terminal empty/error state. После canonical management access убрать только избыточные drawer entries.

**Files/components:** legacy inventory выше, branch hosts, loading/error UI, drawer.

**Dependencies:** A/B не зависят от удаляемого UI; повторный полный reference search перед delete. **Risks:** потеря deep links, user prayer management, cached content, preferences. Не удалять service/storage compatibility в visual cleanup.

**Exit gate:** analyzer/reference checks, route/deep-link tests и empty/cached states; diff не содержит неоговорённой business logic migration.

### Batch D — Tests / device QA / merge gate

**Scope:** meaningful regression tests на реальные defects A–C и полное закрытие device QA списка. Реальный test surface 320, system scaler, text dimensions/semantics; не только отсутствие exceptions. Повторить 109-test baseline и обе platform builds после изменений.

**Files/components:** существующие shell/navigation/reader/Bible/Readings tests; QA evidence и обновлённая screen matrix.

**Dependencies:** стабилизированные A–C; доступ к Android/iPhone для native sign-off. **Risks:** ложный PASS по web scale/эмуляции MediaQuery, незафиксированные остаточные gaps. У каждого NOT VERIFIED должен быть результат либо явное решение владельца merge о допустимом ограничении.

**Merge decision:** после устранения P1, согласованного polish/cleanup и закрытия QA текущая migration architecture достаточна для main. Сейчас готова к финальному Sol cleanup stage, но не к безусловному merge. Stage 8 этим audit не начат.
