# Executive verdict

Аудит: 13 сентября 2026. Репозиторий `senddownrain/ibreviarybyapp`, актуальный `main`.

**READY AFTER SMALL FIXES. P0: 0; P1: 2; P2: 3.** Это разрешение продолжать подготовку релиза после перечисленных локальных исправлений, а не native/device sign-off.

После merge приложение стало лучше по проверяемым признакам: 202 штатных теста проходят, оба анализатора чистые, обе mobile web platform сборки и native Android debug APK собираются. Доработаны восстановление shell, читательская типографика, явный цикл чтений, Prayerbook, загрузка и offline sync. Основные экраны выглядят частью одного продукта; новый redesign не обоснован.

Но не все новые взаимодействия улучшили migration. Связывание Hours/Readings теряет признак ручного выбора для связанных наборов. Fullscreen получил скрытый жест вместо доступного явного выхода; общий Listener реагирует и на касания дочерних действий. Эти две регрессии исправить до следующего релиза. Choir полезен как вторичная возможность, но его постоянная интерактивность требует доводки.

Production-код, штатные тесты, данные и app assets не исправлялись. Созданы только этот документ и воспроизводимые audit artifacts в `docs/audit-evidence/`. Implementation не начат.

# Baseline and changes reviewed

| Проверка | Результат |
| --- | --- |
| `git fetch origin` | Выполнен |
| Ветка / начало working tree | `main`, чистое дерево |
| HEAD = origin/main | `7597469f76c9902f91b05d8bb7e26a89e319896d` |
| Migration merge baseline | `5f885676` |
| Diff | `5f885676..7597469`, 125 файлов, +7998 / −2442 строк, включая assets и generated cleanup |
| SHA из задания | `14219e1` присутствует в истории; не является текущим HEAD |
| Runtime | Flutter 3.41.4; Dart 3.11.1; Windows |

Изучены handoff, Stage 7/8/10, final Liturgical Reader review и последующий `offline-sync.md`. Stage 7 findings, уже закрытые Stage 8/10, не выданы повторно как новые дефекты. Проверялся post-merge diff и вызывающий его текущий код, а не многомесячный diff всего проекта.

Основные изменения:

| Commits | Проверенная область |
| --- | --- |
| `bf8fa3a`, `29f56c1` | Category/navigation coverage, choir, HTML и alternatives |
| `3a05873`, `612606c`, `14219e1` | Theme, общие даты, swipe, reader controls, поиск, Markdown, place labels |
| `506a930`, `c05359c`, `2069e7a` | Введение и последующее удаление hyphenation; оценён конечный renderer |
| `29b85bc` | Insets, padding, dock |
| `e3df1ea` | Foreground date loading, background window, sync plans, Hive и lazy Bible |
| `1e27683`, `f2251d2` | Active branch и отложенные notifications/provider writes |
| `9ed3682`, `19016da` | Беларуская Біблія Чарняўскага 2017, 73 книги, mapping переводов |
| `5d970c0` | Белые области Marian emblem в Dark; отдельно проверены launcher assets |
| `a9da651`, `87f4737`, `7597469` | Generated cleanup, dependency lock, merge актуального main |

## Evidence and automated quality

Обозначения: **CODE** — конкретный код/diff; **TEST** — штатная проверка; **PROBE** — отдельное воспроизведение в audit artifacts; **LIVE WEB** — работающая сборка через браузер. Последнее не подтверждает native gestures, производительность iPhone или VoiceOver/TalkBack.

| Gate | Результат | Evidence |
| --- | --- | --- |
| `flutter analyze` | PASS, 0 issues | [log](audit-evidence/flutter-analyze.log) |
| `dart analyze` | PASS, 0 issues | [log](audit-evidence/dart-analyze.log) |
| `flutter test --reporter expanded` | PASS, **202 tests** | [log](audit-evidence/flutter-test.log) |
| Android web platform path | PASS, 152.0 s | [log](audit-evidence/build-android.log) |
| iOS web platform path | PASS, 98.1 s | [log](audit-evidence/build-ios.log) |
| `flutter build apk --debug --no-pub` | PASS, 106.5 s | [log](audit-evidence/build-apk.log) |
| Native iOS | NOT RUN: Windows, Xcode отсутствует | Не равнозначно падению сборки проекта |
| Audit widget/provider probes | PASS, **5 дополнительных проверок** | [3 probes](audit-evidence/regression-probes.log), [2 probes](audit-evidence/readings-host-probe.log) |
| Счётчик cache, VM / dart2js | VM: 12345; JS: 0 при одинаковом вводе | [VM](audit-evidence/cache-bound-vm.log), [JS](audit-evidence/cache-bound-web.log) |

Команды web build: `flutter build web --dart-define=IBREVIARY_PLATFORM=android --output=build/audit-android` и `flutter build web --no-pub --no-wasm-dry-run --dart-define=IBREVIARY_PLATFORM=ios --output=build/audit-ios`.

Обычный `flutter analyze` выполнил dependency resolution и обновил четыре SDK-related transitive зависимости (`characters`, `matcher`, `material_color_utilities`, `test_api`). Проверки относятся к разрешённому установленным SDK графу, а не к неизменному lock graph. [Точный diff](audit-evidence/dependency-resolution.diff) сохранён; `pubspec.lock` восстановлен из исходного HEAD. Это не оставленная dependency migration.

Audit probes — characterization: они проверяют наблюдаемое поведение, в том числе дефектное. Их зелёный результат не означает исправление. Первоначальная гипотеза о сбросе route state при смене theme key была экспериментально опровергнута; итоговая проверка подтверждает сохранение state при стабильном GoRouter. Падение исследовательской гипотезы не является падением штатного quality gate.

## Visual coverage

Два независимых origins: Android `127.0.0.1:48744`, iOS `127.0.0.1:48745`. Проверены реальные загруженные тексты, не макеты. Фоновая синхронизация приложения выполнялась штатно; серверные данные не редактировались. Screenshots и AX осматривались в сессии; отдельного native screenshot bundle нет.

| Область | Фактически проверено | Ограничение |
| --- | --- | --- |
| Android Light, 390×844 | Hours, Laudes opening/длинный псалом/choir, Readings и варианты | Один календарный день |
| Android Dark, 390×844 | Settings, ручной Readings context после theme change, Prayerbook, search/detail/Back | Не полная seasonal matrix |
| Android Dark, 320×720 | Bible body, перевод control, selection palette | System text 100% live |
| iOS Light, 390×844 | Prayerbook, Hours; Invitatorium, Office, Sexta, Vespers, Compline; contextual return | Flutter platform path |
| iOS Dark | Краткая дополнительная visual проверка в ходе аудита | Не native material/gesture sign-off |
| 200% system text | Штатные widget tests Bible/dock/Prayerbook/alternatives и scaling | Полный live sweep всех readers не выполнен |

Android emulator `emulator-5554` обнаружен ([devices](audit-evidence/devices.log)); APK собран, но не установлен поверх пользовательского приложения в рамках read-only этапа. Native UI automation в этой сессии не использовалась. iPhone отсутствует. Predictive Back, edge swipe, notch/home indicator, аппаратная клавиатура и экранные дикторы остаются device QA.

# What improved after merge

| Поведение | Классификация | Почему |
| --- | --- | --- |
| Немедленная theme change и persistence | **KEEP** | Dark применился сразу; ручной набор Readings сохранился при закрытии Settings |
| Deferred shell notifications / restoration writes | **KEEP** | Устраняют уведомление предков во время build; regression suite зелёная |
| Date command + двусторонний sync | **QUESTIONABLE COMPLEXITY**, с конкретной **REGRESSION P1-01** | Два источника состояния, propagation guard и rekey; явная команда не нуждается во всех скрытых обратных связях |
| Swipe по датам Hours | **KEEP, BUT POLISH** | Дополнительный быстрый путь, date sheet остаётся; не нужен новый постоянный dock |
| Bible chapter swipe при отсутствии selection | **KEEP** | Есть guard `_selected.isEmpty`; не меняет выбранные стихи во время работы с palette |
| Readings swipe и double-tap | **KEEP, BUT POLISH / P1-02** | Нет защиты sentence selection, fullscreen перекрывает обычную работу с текстом |
| Psalm metadata, cadence, HTML-safe heading cleanup | **KEEP** | Сохраняются Stage 10 semantics и тесты на lossless normalization |
| Choir tap | **KEEP, BUT POLISH** | Небольшой локальный state, но плохо объяснён и постоянно включён |
| Prayerbook root, поиск и place labels | **KEEP** | Root остался быстрым; query/details/Back работают; управление вынесено вторично |
| Markdown toolbar/preview, внутренние prayer links | **KEEP, BUT POLISH** | Доступно без знания синтаксиса; search должен понимать видимый текст |
| Holy Mass section navigation | **KEEP** | Прыжки по headings полезны в длинном документе; root не превращён в редактор |
| Lazy Bible + полный bel corpus | **KEEP** | 73 книги; прежние 66 book IDs сохранены, добавлены 7 |
| Offline sync plans, pagination, cancellation | **KEEP** | Есть meaningful tests частичных ошибок, очереди, coverage и index updates |
| Новая графика иконки | **KEEP, BUT POLISH / REFINE** | Узнаваемая книга есть; деталей слишком много для малого размера |
| Новая IA / общий redesign / новый resolver | **FUTURE**, не следующий batch | Текущих данных аудита недостаточно для такой цены и риска |

# Regressions

## P0

**0 подтверждено.** Crash, необратимая потеря пользовательских данных или полностью недоступный основной контент в проверенных сценариях не обнаружены. Это не утверждение о всех возможных данных/устройствах.

## P1

### P1-01 — Связанный выбор Readings становится «автоматическим» после синхронизации с Hours

**CODE + PROBE; оба platform paths.** [Readings host probe](audit-evidence/readings_host_probe_test.dart) использует production `ReadingsBranchHost`, sync provider и `ReadingsScreen`, с двумя synthetic связанными документами.

Воспроизведение: исходная группа `ordinary` → открыть `Варыянты` → выбрать группу `feast`, у которой есть совпадающий Hours dayId. Текст меняется на feast; Hours selection тоже становится feast; `readings-manual-cycle-marker` отсутствует.

Причина: `ReadingsScreen._selectCelebrationGroup` вызывает `selectDay` ([screen](../lib/screens/readings_screen.dart), строка 260). Host подписан на Hours dayId и включает его в key ([host](../lib/widgets/branch_hosts.dart), 113–126). Новый screen и `_load` принимают новый набор за `_automaticGroupKey` (screen, 152). Теряется происхождение выбора; `_manualCycle` и session state этого instance также не переживают rekey.

Это regression ранее правильного Stage 8 manual-group behavior. Отдельный тест `ReadingsScreen` без host её не ловит. LIVE WEB группа 13 сентября без подходящего связанного Hours ID сохранила manual marker; дефект **условный, не каждый выбор группы**.

Дополнительно sync provider намеренно распространяет Readings date обратно в Hours; AppShell теперь восстанавливает одну общую дату вместо двух. Это подтверждённая смена контракта independent contexts, а не случайная трактовка commit message. Новые tests прямо ожидают общую дату. Поэтому не предлагать механический откат всей feature: сохранить explicit Ora navigation и согласовать границу синхронизации. Независимость stacks сама по себе сохранилась.

**Локальное исправление:** не превращать пользовательский выбор в automatic при обновлении связанной ветки; разделить origin/automatic baseline и explicit navigation; исключить ненужный rekey reader. Если общая дата остаётся принятым продуктовым решением, сохранить этот выбор, но исправить provenance и перенос состояния.

**Acceptance:** linked и unlinked group, group+cycle, Hours alternative, явный Ora → Readings, обычные tab switches; manual marker остаётся честным, календарный default восстановим, scroll/reset происходит только при явной смене документа. Не менять resolver precedence.

### P1-02 — Fullscreen потерял явный доступный выход и конфликтует с дочерними действиями

**CODE + PROBE, визуальное подтверждение отсутствия controls.** [ReaderScaffold](../lib/widgets/reader/reader_scaffold.dart): 334–364 (`Listener`), 429–430 (Hidden → shrink); [dock](../lib/widgets/app_navigation_dock.dart): Hidden → shrink. Видимый restore control удалён; обычный reader overflow больше не предоставляет прежний explicit fullscreen action.

Два быстрых pointer-up с расстоянием до 48 px переключают fullscreen, даже если касания обработал дочерний button/link. [Probe](audit-evidence/regression_probes_test.dart) дважды нажимает TextButton внутри production ReaderScaffold: action исполняется два раза **и** chrome становится Hidden; restore button отсутствует. Listener не участвует в gesture arena как конкурент и не исключает selection/choir/дочерние actions.

Пользователь может получить fullscreen при двойном касании текста; видимого и семантического способа вернуть controls нет. Нельзя считать повторный недокументированный жест эквивалентом доступной кнопки. Bible исключён из общего Listener, но использует собственный verse `onDoubleTap`; явный общий выход нужен и там. Native screen-reader trapping не воспроизводился и не утверждается.

**Локальное исправление:** вернуть доступный entry/exit в Full/Compact/Hidden; ограничить shortcut так, чтобы он не срабатывал вместе с дочерним действием/selection. Не удалять полезный focus mode целиком.

**Acceptance:** keyboard/semantics activation выхода; plain text selection; быстрые taps choir/verse; modal open/close; обычный Back и contextual Ora return при Hidden; последний текст доступен. Device жесты проверить отдельно.

## P2

### P2-01 — Choir работает, но не объясняет своё действие и размечает весь псалом ссылками

**LIVE WEB + CODE.** [PsalmChoirHtml](../lib/widgets/psalm_choir_html.dart), [HTML preparation](../lib/utils/liturgical_html.dart), [Ora integration](../lib/screens/ora_screen.dart): 1589. По tap одна группа строф остаётся контрастной, другая приглушается; повторный tap возвращает neutral. Исходный текст и markers остаются на месте.

Однако feature автоматически применяется к каждому `isPsalm`. Нет отдельного opt-in/plain mode, названия «хор 1/2», выбранного semantic state или подсказки выхода. AX видит отдельные ссылки на части строф и на `*`/`†`; ссылка сообщает текст, а не действие. Пользователю трудно понять случайное изменение контраста.

**Polish:** secondary reader action с понятным состоянием; neutral по умолчанию; при включении — доступные имена и reset. Не добавлять постоянный крупный toolbar над каждым псалмом и не переписывать текст.

### P2-02 — Поиск не находит видимую Markdown-фразу через границу выделения

**PROBE + CODE.** [prayers_provider.dart](../lib/providers/prayers_provider.dart), 169–212. Поиск strips HTML, но не переводит Markdown в searchable visible text. Для `**Ойча** наш` запрос `Ойча` находит prayer, `Ойча наш` — нет. [Воспроизведение](audit-evidence/readings_host_probe_test.dart).

Это gap новой editor feature на существующем search path, а не потеря сохранённого текста. Подготовить поисковую строку через тот же Markdown subset → HTML → plain text, сохранив apostrophe/space normalization. Не менять persisted source. Проверить bold/italic/links/list boundaries и literal escaping.

### P2-03 — Web показывает нулевой размер реально заполненного cache

**LIVE WEB + compiled PROBE.** Settings после штатной загрузки: 22.2 МБ downloaded, 146 Bible documents, другие коллекции заполнены, но сохранённый размер каждой группы `0 Б`.

В [HiveService](../lib/services/hive_service.dart), 89/100, верхняя граница `clamp` — `1 << 53`. [Точный arithmetic probe](audit-evidence/cache_bound_probe.dart) даёт VM `bound=9007199254740992; cached=12345`, dart2js `bound=0; cached=0`. Поэтому web учёт размера обнуляется. **Это не доказательство потери cache и не native Android data bug.**

Заменить неподходящую для web arithmetic bound и пересчитать уже записанные нулевые totals из имеющихся payloads. Приложение может читать offline данные; severity P2 относится к ложной диагностике. Проверить VM + compiled web, не ограничиваться VM unit test на concurrent writes.

# Navigation/state

Четыре indexed branches, отдельные Navigator stacks и отдельные chrome controllers сохранены. Repeated active tab сбрасывает override и возвращает branch root; простой switch сохраняет stack. Штатные controller/route tests проходят. Prayer search → Detail → Back LIVE сохраняет `Ойча` и отфильтрованный список.

Contextual Compline → Readings передал `date=2026-09-13&dayId=ordinary-w24-d1`; `Вярнуцца да Ora` вернул Compline той же даты. Ненынешняя дата покрыта кодом/передачей параметров и существующими tests, но отдельного нового live прогона нет.

Нельзя теперь описывать Hours/Readings как независимые **date contexts**: `liturgicalNavigationSyncProvider` слушает обе стороны, а `LiturgicalNavigationController` пишет обе. Сценарий «читать другой день в Readings, затем вернуться к прежнему дню Hours» больше не сохраняет оба корневых контекста. Это deliberate implementation change; его tradeoff следует явно принять, а P1-01 исправить независимо от выбора продукта.

Restoration test добавлен, но не имитирует весь native process death. Один `hours-date` restoration key вместо двух — CODE факт. Полный restore глубоких stacks, ручного cycle, scroll и dialog focus после уничтожения процесса — remaining device QA.

# Swipe navigation

| Где | Текущее поведение | Рекомендация |
| --- | --- | --- |
| Hours root | HorizontalSwipeNavigation поверх root; previous/next date | Оставить как shortcut; date sheet сохранять |
| Ora | `onSwipePrevious/onSwipeNext` не передаются | Не включать глобально; нельзя утверждать, что там уже есть date swipe |
| Readings | Swipe по дате активен и при sentence selection | Ограничить при selection, проверить edge/back; date sheet — доступная альтернатива |
| Bible | Swipe главы только когда `_selected.isEmpty` | Сохранить guard и существующие chapter controls |
| Prayer Detail | Horizontal callbacks не передаются | Не добавлять ради одинаковости |

Distance 72 / velocity 500 отсекают часть случайных движений; короткий медленный drag покрыт тестом. Эти thresholds не доказывают отсутствие diagonal/edge gesture conflicts. На iOS нет явного edge exclusion в generic widget. Android predictive Back и iOS interactive back требуют native теста; Flutter Web не подтверждает их совместимость.

Modal routes находятся выше reader, поэтому обычный swipe внутри blocking sheet не должен менять underlying document; полной gesture matrix для sheets/segmented controls нет. `LiturgicalDayTransition` делает короткий slide/fade, сохраняя outgoing subtree на время анимации: наблюдать lifecycle при быстрых successive changes, но отдельный production defect не подтверждён.

**Ответ:** swipe полезен на Hours/Bible в названных границах. На Readings его следует ограничить при выделении. Скрытый глобальный double-tap требует исправления P1-02; это отдельное взаимодействие, не повод удалять все swipes.

# Liturgical Reader

Stage 10 normalization gates остаются зелёными: mixed red не уменьшает spoken paragraph; literal/named/decimal/hex `*`/`†` сохраняются; embedded antiphon снимается только с известным совпадающим external context; reading label cleanup не удаляет body; structured packages не flatten; references и meaningful breaks сохранены.

Post-merge DOM-based `stripLeadingReadingHeading` лучше прежнего regex для encoded spaces/вложенных span. Явная `liturgical-rubric` не переопределяется leading metadata. Удалённый позже hyphenation не выдан за работающую текущую feature. Нормализация не должна дописывать/изменять литургический текст.

LIVE: Laudes 13 сентября — длинный Psalm 118, antiphon repeat, markers, neutral → selected choir → neutral; iOS Invitatorium — Psalm 24 и compact selector; Office/Sexta/Vespers/Compline — настоящие opening texts и hour sheet. Compline появился после загрузки отдельной collection, а не через фиктивное заполнение полей дня.

| Состав | Evidence |
| --- | --- |
| Invitatorium, opening/repeated antiphon | CODE + LIVE opening; полный всех-variants live sweep не выполнен |
| Office of Readings | CODE + LIVE opening; heading/normalization TEST |
| Laudes | CODE + LIVE opening/long psalm/choir/antiphon repeat |
| Tertia / Sexta / Nona | Общая composition CODE; Sexta LIVE; Tertia/Nona отдельно live не пройдены |
| Vespers | CODE + LIVE opening, текущий I-Vespers source path |
| Compline | CODE + TEST adapter + LIVE текст/alternative trigger |
| Combined Morning | CODE isolation + TEST связанных alternatives; live не пройден |

Vespers на этой дате показал I Нешпары завтрашнего праздника. Выбор tomorrow/first-vespers rank существовал до рассматриваемого diff; это не новый navigation regression. Нормативную правильность precedence этим аудитом не утверждаю и resolver не переоткрываю.

PWA parity здесь подтверждается сохранением Stage 10 контрактов и fixtures, **не новым полным сравнением deployed PWA/live corpus**. Полная seasonal matrix, все structured alternatives и все тексты каждого часа остаются отдельным bounded QA.

Длительное чтение: спокойная нейтральная поверхность, serif body и текстовые antiphons дают хороший результат. Чувство интерфейса сильнее всего возвращают скрытые реакции текста на tap и постоянно интерактивный choir; новый визуальный язык для решения этого не нужен.

# Psalm choir

**KEEP, BUT POLISH; исполнение упростить до secondary opt-in.** Текущая модель чередует уже сформированные строфы odd/even; она не анализирует заново смысл псалма и не должна выдаваться за универсальное определение хоров для любого источника.

`selectedChoir` локален одному widget, сбрасывается при смене HTML. Plain neutral state сохраняет полный контраст и все строфы; live возврат назад работает. На длинном псалме dimming понятен после объяснения. В default UI объяснения нет, поэтому P2-01.

Не переносить selected state между разными псалмами и alternative source. Не привязывать antiphon selection к choir. Для structured alternative проверить одновременно полный package, internal repeat и choir parity; fixture есть, отдельного live sign-off этого сочетания нет.

# Readings

Immediate text, reference, Psalm, refrain, Gospel и cycle badge сохранены. На 13 сентября текущий ordinary набор показал cycle A, альтернативный unlinked набор — честный manual marker. Переключение Dark сохранило marker и текст.

Сохранить исправление заголовка по cycle отображаемого документа (`f9e554c`), available cycles и отдельную group/cycle модель. Не возвращать misleading year из общего title. P1-01 касается **linked group через host**, а не общего default resolver.

Readings sentence highlighting хранится по reading ID, palette имеет names/clear/cancel. Отсутствует Bible-подобный selection guard у swipe. Это interaction risk для следующего небольшого batch, без утверждения о native потере highlights.

# Prayerbook / Markdown

Root сохранил `Абраныя → Святая Імша → Катэгорыі → Усе малітвы`, с отдельным My Prayers и вторичным editor. Наблюдаемый root быстрый; не выглядит административным каталогом. Поиск фокусируется, фильтрует body, сохраняет query при Detail/Back. Тесты покрывают category create/rename/delete, tags/explicit membership, favorite state и long root при 200%.

Новые prayer links используют только поддержанные относительные canonical routes; malformed/absolute URLs не исполняются как произвольная навигация. Markdown escapes HTML. Поддерживается небольшой subset: h2–h6, bold/italic, списки, rubric, ссылки. Не обещать полный CommonMark (таблицы, вложенные блоки, code fences и т.п.).

Старые записи без `textFormat` по-прежнему читаются; destructive storage migration не обнаружена. Legacy HTML при редактировании распознаётся и сохраняет прежний format. Новый текст сохраняет `mybrev-markdown`; обычный legacy plain text при Save тоже получает этот format. Поэтому строки с literal Markdown punctuation следует отдельно проверить: source не удаляется, но интерпретация может измениться. Полного live create/save/restart/reopen round trip пользовательских записей здесь нет; существующие editor tests проверяют toolbar/preview и доступ к edit.

P2-02 закрывает реально воспроизведённый search gap. Unsupported Markdown должен деградировать в безопасный читаемый текст; raw HTML в Markdown не является permission исполнять HTML. External Markdown links сейчас могут выглядеть как ссылки, но не иметь поддержанного destination — явно определить поддержанный subset в editor help.

Holy Mass section navigation основана на существующих headings, без новой entity. Share action удалён намеренно вместе с тестовым ожиданием «without sharing»; не выдаю это за случайную поломку и не возвращаю его автоматически. Полезность восстановления sharing — отдельное продуктовое решение, не release gate.

# Bible

Сохранить два языка, chapter/book picker, search по текущей книге, selected verses и palette вместо dock. LIVE 320 px Dark: body не обрезан, `БЕЛ/РУС` читаются в одну строку, шесть palette actions доступны. Swipe блокируется при selected verses. System TextScaler остаётся в RichText; соответствующий meaningful test проходит.

Bundled bel corpus вырос с 66 до 73 books; сравнение IDs с baseline не обнаружило удалённых прежних IDs. Добавлены `tob,jdt,1mac,2mac,wis,sir,bar`. Canonical translation mapping заменяет fragile index matching; tests проходят. Last location/highlight keys сохраняются. Эквивалентность verse numbering между текстовыми редакциями целиком не проверена: сохранность ключа сама по себе не доказывает филологическое соответствие всех highlights.

`BibleRepository.ensureVersion` предпочитает полностью синхронизированный Hive cache. Sync всё ещё может заменить bel corpus серверной коллекцией. Поэтому в release data QA сверить серверную версию/атрибуцию с bundled Чернявским; наличие wrong server corpus не утверждается. LIVE первая глава соответствовала показанному новому переводу.

Native selection/edge gestures/translation reload и cold-start offline остаются device QA. Не выдавать debug APK build за успешный запуск на устройстве.

# Theme / Insets

Theme: Hive остаётся persisted source; settings обновляет ValueNotifier для немедленного применения. Оба theme slots используют explicit выбранную brightness. LIVE Dark переключается сразу, Settings закрывается, ручной Readings context сохраняется; контрольный stable-router probe это поддерживает. Второй notifier — maintenance risk, а не автоматически «двойной theme owner bug».

`extendBody` + padding содержимого теперь резервируют dock. В осмотренных Dark экранах белая full-width полоса Stage 7 не вернулась. Palette располагается отдельно от dock, сохраняются минимальные targets. Full/Compact работают; Hidden ограничен P1-02.

`readerSystemBottomClearance` берёт maximum нескольких inset sources плюс Android fallback 56. Это защитный workaround для устройств с неверными inset reports. На web/gesture-navigation может давать лишнее пространство; не увеличивать fallback дальше без device evidence. Проверить 3-button Android и home indicator, не исправлять «пустой хвост» по desktop screenshot.

Keyboard/form/save button, notch, native modal safe area и 200% на каждом screen не получили полного live sign-off. Оставить короткий целевой device checklist, не менять все padding constants заново.

Визуальная целостность: reader roles согласованы; Prayerbook sans title и liturgical serif title выглядят как различие функции. Settings и editor плотнее и технически подробнее, но находятся вторично. Заметного «экрана другого приложения», требующего redesign, в пройденных основных flows нет.

# Accessibility

Положительное: Aa names, Back/menu labels, 48-sized palette targets, selected semantics Bible, доступные date/variant sheets. Existing tests проверяют реальный system scaling Bible и узкие layouts; большой текст не заменять увеличением browser zoom.

Подтверждённое: P1-02 убрал доступный fullscreen exit; P2-01 делает semantic tree псалма набором links без explanation/selected choir. Контраст приглушённого choir дополнительно проверить в обеих темах, особенно markers. Формальную contrast certification всего приложения не выполняли.

Device QA: VoiceOver/TalkBack read order, focus restore после alternatives/date sheet, управление fullscreen без spatial double-tap, крупный текст 200% при 320/390, keyboard в формах, последний абзац над dock/palette. Web AX позволяет увидеть плохое именование, но не доказывает реальное произношение/жесты диктора.

# Complexity / technical risks

| Область | Риск | Сейчас или позже |
| --- | --- | --- |
| Date controller + bilateral listeners + shared host key | Циклическая propagation, скрытые state resets, утрата origin | **Сейчас**, локальный P1-01; без router rewrite |
| Theme provider + global ValueNotifier + MaterialApp key | Несогласованное обновление из будущего нового caller | Оставить; stable router probe/live state green; добавить сценарий при следующем theme change |
| Deferred observer/controller callbacks | Stale callback после быстрого route change/dispose | Guards есть; сохранить regression tests, не переписывать lifecycle без bug |
| AnimatedSwitcher outgoing reader | Два живых subtree в transition window | Bounded rapid-navigation QA; не отдельный подтверждённый дефект |
| Foreground warmup + background sync + category stream | Несколько путей записи/cache invalidation | Сохранить queue/coverage tests; отдельно cold offline/cancel; не объединять всё в новую архитектуру |
| `_meta` byte accounting | VM-only test скрывает web numeric difference | **Сейчас/next**, P2-03 и compiled web probe |
| Markdown preview/detail/search | Три интерпретации одного source | **Next**, использовать общий visible-text adapter для поиска |
| Stateless normalizer + per-psalm HTML reconstruction | Потенциальная стоимость на длинном тексте | Измерять на device до оптимизации; benchmark не проводился |

Offline улучшение реально полезно: успешные страницы сохраняются, obsolete entries удаляются после завершения collection; partial failures не объявляются полным coverage; queued manual requests не теряются. Полный download всех коллекций вручную не запускался. Нет основания для production architecture rewrite.

# High-value next improvements

| Улучшение | Value | Effort | Risk | Recommendation |
| --- | --- | --- | --- | --- |
| Linked group provenance + ограничить date propagation | HIGH | M | MEDIUM | **DO NOW** |
| Явный accessible fullscreen entry/exit, безопасный shortcut | HIGH | S–M | LOW | **DO NOW** |
| Readings selection guard и native edge/back smoke | HIGH | S | LOW | **DO NOW** |
| Secondary choir mode + доступные names/state/reset | MEDIUM | M | LOW | **NEXT** |
| Markdown visible-text search | HIGH | S | LOW | **NEXT** |
| Web cache byte totals + repair existing totals | MEDIUM | S | LOW | **NEXT** |
| Короткий device release matrix: 200%, offline, theme restart, keyboard | HIGH | M | LOW | **DO NOW** |
| Упрощение app icon и platform packaging | MEDIUM | M | LOW | **LATER**, после принятия направления |

Это восемь работ, включая regression fixes; не восемь дополнительных features. Новый глобальный renderer/router, широкая переделка Prayerbook и редизайн бренд-системы — **SKIP** для ближайшего релиза.

# Release readiness

**READY AFTER SMALL FIXES.** Исправить P1-01/P1-02 и выполнить ограниченный native acceptance pass. P2 не требуют останавливать разработку; их можно взять небольшим follow-up. Иконка не повод для HOLD.

Automated green подтверждает исполнимость проверенной версии; не означает полного native release validation. Debug APK не заменяет release signing/build, iOS web не заменяет Xcode build. Не назначать P1 проекту только за отсутствие Xcode на Windows. Если native release build в соответствующей среде действительно падает, это самостоятельный P1 gate.

# App Icon Audit

## Current icon verdict

**REFINE.** Книга и мягкая светлая подложка — рабочая основа. Нет необходимости менять название, IA, типографику или color system приложения.

Визуально исследованы current iOS 1024 asset и Android xxxhdpi 192 asset; [контекстный preview существующего asset](audit-evidence/icon-context.html) позволяет сравнить 180/48/24 px на светлой и тёмной подложке. Новые PNG/SVG не создавались.

Состав: светлая плитка с заранее нарисованными округлениями, коричневый круг, раскрытая книга, голубь, крест на странице, лучи, строки и мелкая обводка/фактура. Это дружелюбный христианский образ; основная масса узнаваема. Но книга+голубь+крест+лучи конкурируют, а ассоциация ближе к общей Bible/devotional app, чем к ежедневной Литургии часов.

| Критерий | Оценка |
| --- | --- |
| Home-screen recognition | Крупная светлая книга читается; уникального силуэта iBreviary пока мало |
| 1024 px | Детали различимы, но виден иллюстративный характер/фактура |
| 180 px | Символы понятны; перегруженная композиция ещё приемлема |
| 48 px | Общий круг/книга остаются, строки и лучи превращаются в шум |
| 24 px / notification-like | Не следует ожидать читаемого креста/голубя/страниц одновременно; нужен отдельный простой glyph, не этот launcher raster |
| Religious identity | Христианская узнаваемость есть; католический/liturgical смысл не уникален |
| Calm prayer identity | Тёплый тон подходит молитвенному продукту; эмблематичность сильнее нужного |
| Соответствие UI | Сдержанному типографическому reader подходит более простая графика; менять UI под коричневую иллюстрацию не нужно |
| Light / dark wallpaper | Светлая плитка заметна на обоих; на тёмном фоне подчёркивает двойную рамку «плитка + круг» |
| Android adaptive suitability | В `res` только legacy mipmap PNG; adaptive foreground/background и monochrome XML не обнаружены. Текущий pre-rounded raster не даёт контроля системных masks |
| iOS suitability | Набор размеров есть; уже нарисованные скругления/внутренний отступ следует проверить под системной mask. В asset catalog не обнаружены отдельные appearance variants |

Не называю изображение AI-generated: происхождение не установлено. Но следующая версия должна избегать иллюстративного religious collage и работать как простой app symbol.

## Concept A — «Псалтырь с закладкой»

**Центральный символ:** одна открытая книга; закладка — часть силуэта книги, не второй значок поверх неё. Никакого текста/монограммы.

**Geometry:** симметричная низкая раскрытая книга из двух крупных цельных плоскостей, мягкий центральный сгиб; один широкий хвост закладки внизу. Без строк, тонких страниц, голубя, лучей и отдельного гербового круга. Силуэт занимает примерно две трети поля; детали не зависят от hairline strokes.

**Background:** flat near-charcoal или светлый тёплый нейтральный фон; ivory symbol. Допустим один небольшой приглушённый rubric-red участок самой ленты. Без бумажной текстуры, объёма и glossy border.

**Liturgical association:** ежедневное возвращение к отмеченному месту в молитвенной книге/псалтыри. Ассоциация подходит и часам, и чтениям, и личной молитве.

**Почему iBreviary:** сохраняет узнаваемую книгу текущей иконки, соединяется с Literata reader и тихими rubrics, не требует менять UI.

**Risks:** без distinctive fold/ribbon silhouette может выглядеть как ebook app. Проверять рядом с Bible/readers; не решать это добавлением ещё трёх символов.

## Concept B — «Молитва дня»

**Центральный символ:** простой латинский крест, нижняя часть которого плавно переходит в одну дугу суточного света. Это единая геометрическая фигура, а не крест поверх картинки рассвета.

**Geometry:** равномерно толстые вертикаль и перекладина, открытая нижняя дуга; одна уверенная negative-space форма. Без солнца-диска, лучей, циферблата, цифр и книги.

**Background:** flat тёмный нейтральный или очень мягкий restrained ambient, ivory symbol. Цвет не закрепляет приложение за одним литургическим сезоном.

**Liturgical association:** освящение времени молитвой, утро/вечер, повторяющийся дневной цикл.

**Почему iBreviary:** отличает продукт от generic Bible book icon; соответствует Hours-first ежедневному сценарию.

**Risks:** крест с дугой может напоминать church logo, sunrise/weather app или могильный крест. Дуга должна быть частью знака времени, без пейзажного горизонта и постамента.

## Concept C — «Сгиб страницы»

**Центральный символ:** один сложенный лист/разворот с крестом в negative space самого сгиба; не отдельный крест-наклейка.

**Geometry:** компактная вертикальная форма из двух широких плоскостей, скруглённые внешние углы, один выраженный внутренний просвет. Никаких букв `IB`, строк и мелких прорезей.

**Background:** flat graphite/ivory; один цвет символа, без фактуры.

**Liturgical association:** молитвенный текст и сакральное чтение, выраженные одной формой.

**Почему iBreviary:** хорошо переносится в monochrome small glyph, дружит со сдержанным UI.

**Risks:** folded page может читаться как notes/documents. Negative-space cross легко исчезает на 24–48 px; не выбирать, если без пояснения он непонятен.

## Finalists

**Finalist A — «Псалтырь с закладкой». Рекомендую первым.** Наиболее безопасное развитие текущей узнаваемости. Design brief: square canvas 1024, flat warm-charcoal field, одна ivory раскрытая книга с глубоким центральным сгибом и широкой короткой rubric-red закладкой; большие плоскости, без контурного рисунка страниц, текста, голубя, лучей, тени и нарисованной внешней mask. Подготовить проверочные представления 180/48/24; силуэт должен читаться без красного акцента.

**Finalist B — «Молитва дня».** Более характерное направление для Hours, с большим риском generic church association. Design brief: square neutral-charcoal field, один ivory знак из латинского креста и связанной с ним открытой нижней дуги; одинаковая визуальная толщина, большие отрицательные пространства, без лучей/циферблата/книги/надписей/пейзажа. Вариант обязан оставаться понятным в одном цвете при 48 px.

Для обоих: 1024 — мастер геометрии, 180 — домашний экран iOS, 48 — Android/малый launcher, 24 — отдельная проверка silhouette, а не обещание использовать full-color raster как notification icon. Android adaptive layers и iOS system mask делать после выбора; не рисовать округлённую платформенную рамку внутри master.

## Recommended direction

Начать с A, B оставить сравнением. Решение **REFINE**, не срочный brand redesign. До выбора сохранить текущую иконку. Не создавать production assets на этом этапе; данный документ содержит только briefs и просмотр уже существующих файлов.

# Recommended next implementation batch

## Batch 1 — confirmed regressions

**Scope:** P1-01 linked context provenance/rekey, P1-02 accessible fullscreen/gesture arbitration; добавить Readings selection guard в тот же небольшой interaction pass. Сохранить четыре stacks, explicit Ora context, Bible guard и текущий resolver.

**Risk:** MEDIUM для дат, LOW для доступного выхода. **Exit:** targeted production-host tests linked/unlinked groups и cycle, child-action/selection tests, native Back/focus smoke. Никакой массовой замены providers/router.

## Batch 2 — highest-value polish

**Scope:** три вещи: secondary choir с semantics, Markdown visible-text search, cross-platform cache size accounting. Дополнительно bounded device QA 320/390 × Light/Dark × 200%, theme restart и offline reopen; это проверка качества, не новая feature.

**Risk:** LOW–MEDIUM. **Exit:** source text/storage не меняется, search соответствует видимому тексту, счётчик одинаково работает VM/web, plain prayer experience остаётся нейтральным.

## Batch 3 — icon, only after direction is accepted

**Scope:** сравнить A/B на домашнем экране, выбрать A либо B, затем изготовить platform assets и проверить masks/small sizes. Не менять остальной бренд.

**Risk:** LOW технически, MEDIUM для узнаваемости. Не задерживает исправление регрессий или обычную разработку.

**Остановка:** аудит завершает только анализ и документацию. Ни один implementation batch этим документом не начат.
