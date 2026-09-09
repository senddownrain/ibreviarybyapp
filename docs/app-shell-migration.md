# AppShell migration — Stage 2 technical specification

Дата: 2026-09-09.

Статус: техническая спецификация для реализации Sol High. UX утверждён. Этот документ не вводит новый redesign и не означает, что описанная архитектура уже реализована.

> Update 2026-09-09: Stage 2 AppShell реализован, а Stage 3 Hours root завершён.
> Текущий disposition и следующий migration boundary описаны в
> [hours-root-migration.md](hours-root-migration.md).
>
> Update 2026-09-09: Stage 4 Readings root также завершён. Реализация и
> сохранённые compatibility boundaries описаны в
> [readings-root-migration.md](readings-root-migration.md).
>
> Update 2026-09-09: Stage 5 Prayerbook также завершён. Новый root, единый
> каталог/категории, shared Prayer Detail и compatibility disposition описаны
> в [prayerbook-migration.md](prayerbook-migration.md).
>
> Update 2026-09-09: Stage 6 Bible завершён. Last-location root, production
> navigation/search/highlights и shared neutral Reader описаны в
> [bible-migration.md](bible-migration.md).

Stage 2 меняет навигационный каркас. Stage 3+ мигрируют содержимое branches по одному. Обязательное промежуточное состояние: новая Ora и немигрированные Readings / Prayer / Bible работают под одним Shell.

## Источники и исходное состояние

- [UX handoff](ibreviary-ux-handoff.md).
- [Финальный прототип](../prototypes/ux-architecture/README.md), [refinement](../prototypes/ux-architecture/REFINEMENT.md), [QA](../prototypes/ux-architecture/QA.md), `model.js`, `app.js`, `refinement.js`.
- [Stage 1 Reader foundation](reader-foundation.md).
- `lib/router/router.dart`, `lib/widgets/app_shell.dart`, `lib/widgets/navigation_drawer.dart`, `lib/widgets/bottom_nav.dart`.
- `lib/widgets/reader/reader_scaffold.dart`, `lib/widgets/reader/reader_navigation.dart`, `lib/widgets/reading_scaffold.dart`.
- Текущие Home / HoraPicker / Ora / Readings / ReadingDetail / Prayers / PrayerDetail / Bible / BibleChapter, calendar picker и settings.

В `pubspec.lock` установлен `go_router 14.8.1`. Проверен также его локальный исходник: `StatefulShellRoute.indexedStack` сохраняет посещённые branch Navigator, `goBranch` восстанавливает match list, неактивные branches используют `Offstage` и отключённый `TickerMode`.

Сейчас используется один обычный `ShellRoute`; reader-маршруты вынесены за его пределы. Нижняя навигация управляет датой. AppShell и Readings имеют собственное scroll auto-hide. `selectedDateProvider` глобальный. BibleScreen выполняет post-frame redirect в последнюю главу. Reader foundation уже предоставляет Full / Compact / Hidden, controller и scope, но полноценное владение со стороны Shell ещё не подключено.

## 1. Recommended router structure

Использовать один `StatefulShellRoute.indexedStack` и четыре постоянных `StatefulShellBranch` в порядке:

1. Гадзіны — `hours`.
2. Чытанні — `readings`.
3. Малітоўнік — `prayerbook`.
4. Біблія — `bible`.

У каждого branch стабильный `navigatorKey`. Один root Navigator обслуживает приложение и глобальные вторичные страницы. AppShell получает `StatefulNavigationShell`; активный tab определяется через `currentIndex`, обычный tab switch выполняется через `goBranch(index)`.

Reader-маршруты принадлежат branch Navigator, а не root Navigator. Settings / About открываются поверх Shell через root Navigator push.

Ограничения:

- Не пересоздавать router, branches и navigator keys при изменении даты, темы или chrome.
- Не включать preload всех branches без измеренной необходимости.
- Не создавать четыре отдельных GoRouter.
- Не помещать старый AppShell внутрь нового: сохраняются screen widgets, Shell один.
- Не обновлять go_router только ради этой миграции: необходимые возможности есть в 14.8.1.
- Собственный navigator container не нужен без отдельной необходимости анимации переключения tabs.

Справка: [StatefulShellRoute](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html). Документация latest может содержать API, отсутствующие в 14.8.1; реализацию сверять с установленной версией.

## 2. Branch tree

Canonical locations — техническая организация URL, без изменения утверждённого UX.

```text
Root Navigator
├─ StatefulShellRoute.indexedStack → AppShell
│  ├─ hours
│  │  └─ /hours
│  │     ├─ ora/:date/:dayId/:type
│  │     ├─ picker
│  │     │  └─ options
│  │     └─ hora/:date/:dayId       [временный HoraPicker]
│  ├─ readings
│  │  └─ /readings
│  │     ├─ reading/:readingId
│  │     └─ picker
│  │        └─ options
│  ├─ prayerbook
│  │  └─ /prayers
│  │     ├─ favorites
│  │     ├─ my
│  │     ├─ all                    [по мере миграции]
│  │     ├─ category/:id           [по мере миграции]
│  │     ├─ prayer/add
│  │     ├─ prayer/:id
│  │     └─ prayer/:id/edit
│  └─ bible
│     └─ /bible                   [сама открытая глава]
├─ /settings
└─ /about
```

| Branch | Собственный контекст |
| --- | --- |
| Hours | Дата, выбранное празднование/template |
| Readings | Дата либо liturgical key, dayId, группа/цикл, auto/manual |
| Prayerbook | Поиск, фильтры, категория, состояние списков |
| Bible | Перевод, книга, глава, позиция/стих |

Readings root получает explicit context через query: `/readings?date=2026-09-09&dayId=…`. Для liturgical mode использовать альтернативный явно обозначенный набор параметров; не смешивать его с date mode.

Bible root: `/bible?version=…&book=…&chapter=…&verse=…`.

### Bible root

Tab сразу показывает последнее место. Небольшой `BibleBranchHost` непосредственно отображает существующий `BibleChapterScreen`. Нельзя оставлять под главой текущий redirect-only BibleScreen: Back может открыть spinner или повторно запустить redirect.

Следующая/предыдущая глава и смена перевода обновляют текущую location без накопления глав в stack. Визуальная миграция Bible reader выполняется позднее.

## 3. Shell state contract

Ввести единый типизированный контракт, условно `BranchShellState`. Существующий `ReaderChromeMode` сохранить.

| Поле/часть | Владелец | Назначение |
| --- | --- | --- |
| branchId, Navigator stack | Router | Идентичность и история branch |
| routeEntryId | Route adapter | Конкретный экземпляр страницы |
| documentKey | Экран / route adapter | Идентичность содержимого |
| defaultChromeMode | Route descriptor | Full / Compact при входе |
| Chrome override | Shell controller, привязка к route entry | Focus, раскрытие dock, начало чтения |
| effectiveChromeMode | Shell controller | Единственный режим Shell и Reader |
| topChromeOwner | Route descriptor | Shell, Reader или legacy screen |
| Dock occupancy / insets | AppShell | Фактически занятое место |
| Date / search / content state | Branch state | Контекст раздела отдельно от chrome |

Один controller на branch, но запрос режима принадлежит конкретной странице. Одного общего ValueNotifier на весь stack недостаточно: Hidden молитвы не должен оставаться после её закрытия.

Route descriptors объявляются рядом с route factories. Использовать собственные типизированные descriptors и Page / route-entry registry; не рассчитывать на metadata API новых версий go_router. Не определять режим через URI, route-name checks или runtimeType по проекту.

Жизненный цикл:

1. Route adapter регистрирует descriptor и route entry.
2. Observer branch Navigator сообщает верхнюю страницу.
3. Controller вычисляет режим этой страницы.
4. AppShell слушает controller активного branch.
5. ReaderScaffold получает тот же resolved mode через scope.
6. Pop удаляет состояние закрытой страницы и восстанавливает предыдущую.
7. Callback от закрытой или покрытой страницы не изменяет активный chrome.

Не менять controller в build. Не сбрасывать его безусловно в dispose: поздний dispose старой страницы может затереть состояние новой.

### Независимость дат

На переходный период `selectedDateProvider` допустимо оставить compatibility-владельцем только Hours. Для Readings нужен отдельный branch state.

- Обычный tab switch не читает дату соседнего branch.
- Отсутствие даты при первом входе и команда «Сёння» — разные события.
- Explicit URL context применяется один раз на navigation event, а не при каждом rebuild.
- Изменение даты сбрасывает ручной выбор прежнего дня.
- Полночь не подменяет открытый документ.
- Сортировка primary, календарная логика, группы/циклы и fallback остаются существующими.

## 4. Reader chrome contract

| Экран / состояние | Режим |
| --- | --- |
| Hours, Prayerbook, категории, All Prayers | Full |
| Readings при входе | Full |
| Длинные Readings после начала чтения | Compact |
| Ora, Reading Detail, Prayer Detail | Compact |
| Bible root с открытой главой | Compact |
| Явный focus | Hidden |

- Full: floating dock четырёх разделов.
- Compact: уменьшенный dock текущего раздела с действием раскрытия всех tabs, как в финальном прототипе.
- Hidden: dock и обычный reader chrome скрыты; доступный выход из focus остаётся.

Tap по Compact раскрывает Full. Это не repeat active tab и не возврат к root.

Reader отправляет команды: запросить Compact, раскрыть навигацию, войти/выйти из focus. Reader не выбирает платформенный материал и не создаёт собственный primary dock.

Для Readings начало чтения определяется локально по основному документу. Порог прототипа — 180 px; в Flutter закрепить одной константой в логических пикселях. Восстановление scroll, программный переход, прокрутка sheet и выделение текста не должны запускать событие. Переход Full → Compact выполняется один раз для документа. Явное раскрытие пользователем имеет приоритет. Общего Android scroll auto-hide нет.

Loading / empty / error получают descriptor от route adapter: режим не зависит от успешного построения ReaderScaffold.

### Обязательная адаптация Ora Stage 1

Сейчас focus в Ora меняет локальный `_chromeMode`, тогда как ReaderScaffold предпочитает scoped controller. После подключения Shell scope этот локальный запрос будет перекрыт. Все команды Ora должны проходить через общий контракт. Локальное состояние допустимо только как standalone fallback без Shell.

### Материал и layout

- iOS: floating glass-like dock через существующую платформенную границу.
- Android: floating tonal / Ambient dock через ту же границу.
- `AdaptiveChromeSurface` сохранить; Flutter blur не обозначать как системный Liquid Glass.
- Внешний контейнер dock прозрачный; вокруг виден фон. Full-width bottom surface не возвращать.
- Обычный reader content остаётся нейтральным и непрозрачным.

Shell публикует фактическую нижнюю область перекрытия: dock, зазор и safe area. Reader резервирует её в конце документа ровно один раз. Текущих `42 + bottomSafeArea` в ReaderContentSurface недостаточно. Legacy adapter обеспечивает аналогичную защиту старым экранам.

Переключение режима не пересоздаёт документ или scroll controller и не сдвигает читаемую строку. Один явный topChromeOwner предотвращает двойное меню и двойной top inset.

Для Bible selection предусмотреть отдельное владение нижним слотом: contextual palette заменяет dock. Это не четвёртый navigation mode. Клавиатура учитывается как временное перекрытие, не записывая Hidden в reader state.

## 5. Deep-link behavior

Достаточные параметры документа находятся в URL. `extra` не может быть единственным источником даты, ID или координат главы.

| Вход | Результат |
| --- | --- |
| Ora | Hours active; Hours root → Ora |
| Readings на дату | Readings active; context применяется к текстовому root |
| Reading Detail | Readings active; root → detail |
| Prayer Detail | Prayerbook active; root → detail |
| Bible Chapter | Bible active; указанная глава — root document |

- Ora deep link задаёт Hours context из URL до загрузки root. Back возвращает в Hours с той же датой.
- Reading ID сам по себе не доказывает дату. Без date context использовать сохранённый/default Readings root, не Hours date.
- Explicit Bible coordinates приоритетнее сохранённого места.
- `verse` применять после появления текста; новый запрос стиха должен работать и внутри уже открытой главы.
- Cold start строит нужный branch stack без обязательного предварительного посещения Hours.
- Warm deep link сохраняет остальные branches; целевой получает canonical stack входящего адреса.
- Некорректные параметры дают понятную ошибку в соответствующем branch. Не заменять неверную дату молча сегодняшней.
- Bootstrap локальных данных должен работать при прямом входе в reader. Сохранить единственного общего владельца WarmupBootstrap выше соответствующих маршрутов.
- Доставка Universal Links / App Links операционной системой проверяется отдельно: конфигурация go_router сама по себе её не подтверждает.

### Ora → Readings → Ora

Это отдельная команда navigation coordinator, не обычный push между branches.

1. Зафиксировать ссылку на текущий Ora route entry.
2. Передать дату и явный dayId Ora.
3. Активировать Readings root с этим контекстом, убрав прежние дочерние страницы Readings.
4. Использовать production-логику: связанная группа при наличии, иначе default/fallback даты.
5. Сохранить одноразовый return token к исходной Ora.

Template и выбранные части Ora сохраняются в Hours state; они не становятся новым правилом выбора чтений. Соответствие по названию часа не вводится.

Back из Readings root потребляет token и восстанавливает Hours branch. Ora не реконструируется по строке URL: сохраняются scroll и локальные варианты.

Lifecycle return token:

- Сохраняется при открытии/закрытии дочернего Reading Detail и вторичных sheets.
- Отменяется после ручного tab switch, repeat active tab, нового external deep link или явной смены даты Readings.
- Не восстанавливается после перезапуска процесса.
- Проверяет существование исходного Ora entry перед возвратом.

## 6. Back behavior

Порядок:

1. Закрыть верхний dialog / sheet / drawer; клавиатура и локальные transient-состояния обрабатываются своим владельцем.
2. Закрыть contextual selection, если активен.
3. Выйти из focus, оставаясь в документе.
4. Pop внутри активного branch, если есть дочерняя страница.
5. В Readings root выполнить действительный возврат к Ora.
6. На обычном branch root передать Back платформе.

Обычные tabs не создают межвкладочную Back-history. Back из Prayerbook root не ведёт автоматически в Hours.

- Android root Back — системный выход из приложения.
- На iOS обычный root не имеет фиктивной кнопки Back.
- Bible chapter — root: Back не открывает spinner и не отправляет в Hours.
- Settings / About открываются root Navigator push и закрываются к прежнему branch и позиции.
- При cold deep link в Settings / About без предыдущей страницы явное закрытие ведёт в настроенный стартовый branch.
- App bar Back и системный Back используют одинаковую политику.
- Проверить согласование iOS gesture / Android predictive Back с PopScope и router. Не добавлять WillPopScope поверх всего приложения.

## 7. Active-tab repeat behavior

На Full dock:

- Другой tab → `goBranch(index)` и восстановление последнего места.
- Активный tab → root этого branch.
- Уже открытый root → без дополнительного действия.

Возврат к root удаляет дочерние страницы, сбрасывает transient focus / раскрытие chrome и Ora return token. Сохраняются дата, root scroll, фильтры и выбранный контент root. Нет автоматического Today и дополнительного scroll-to-top.

`goBranch(index, initialLocation: true)` подходит при двух условиях: initial location действительно root, а отсутствие query восстанавливает branch context. В Bible root host восстанавливает текущую главу без redirect chain.

## 8. Compatibility strategy

Stage 2 один раз меняет владельцев маршрутов, сохраняя screen widgets через adapters. Canonical locations вводятся централизованно; старые URL остаются aliases.

| Старый адрес | Назначение |
| --- | --- |
| `/` | `/hours` |
| `/ora/:date/:dayId/:type` | Hours → Ora |
| `/hora/:date/:dayId` | Временный HoraPicker внутри Hours |
| `/readings/:dateStr` | Readings root с date/dayId |
| `/readings/liturgical/:period/:week/:day` | Readings root в liturgical mode |
| `/reading/:readingId` | Readings → Reading Detail |
| `/prayer/:id` | Prayerbook → Prayer Detail |
| `/prayer/add` | Prayerbook → форма |
| `/prayer/edit/:id` | Prayerbook → редактирование |
| `/my-prayers` | `/prayers/my` |
| `/prayers/favorites` | Сохраняется внутри Prayerbook |
| `/bible/:version/:book/:chapter` | Bible root с координатами, включая verse |
| `/picker?mode=…` | Picker соответствующего branch |
| `/picker/options?...` | Options соответствующего branch с сохранением параметров |
| `/settings`, `/about` | Сохраняются |

Для старого picker/options без mode оставить прежний Hours default. Новые вызовы из Readings передают принадлежность и год явно: текущие picker/options зависят от глобального selectedDateProvider.

Aliases нормализуют адрес, не рисуют дополнительный экран и не добавляют redirect page в stack. Специфические пути вроде add разрешаются раньше динамических ID. Все query-параметры и encoded IDs сохраняются.

### Минимальные integration-изменения старых экранов

Через LegacyRouteAdapter и небольшие параметры:

- Убрать внутренний primary/date dock Readings во всех состояниях.
- Заменить доступ к датам на date sheet / сохранённый advanced picker.
- Убрать дублирование drawer / menu и top insets.
- Передать Back, navigation commands и нижний inset.
- Защитить scroll state.
- Исправить межветочные вызовы: redirect сам по себе не придаёт старому push семантику tab switch.

Содержимое, resolver, text rendering и ReadingScaffold остаются до миграции соответствующего branch. Не требовать переписи всех экранов в ReaderScaffold в Stage 2.

### Drawer, Settings / About / Sync

Drawer становится вторичным меню. Settings, About и Sync остаются там. Sync ведёт к существующему разделу синхронизации Settings; отдельный top-level branch не нужен.

Временные shortcuts на Святую Імшу, избранное, личные молитвы и категории допустимы до переноса всех входов в Prayerbook. Они используют coordinator и не сбрасывают branch обычным context.go. Не удалять единственный доступ к функции. Четыре основных раздела доступны через dock независимо от drawer.

## 9. Migration risks и сохранение состояния

| Риск в текущем коде | Требование |
| --- | --- |
| `_onScroll` в AppShell и Readings скрывает панели | Удалить из управления primary navigation |
| Ora local mode конфликтует со scope | Единый путь chrome commands |
| Ora `_dayFuture` — late final, нет didUpdateWidget | Новый document identity обновляет State или загрузку |
| context.replace может сохранять page identity | Разделить routeEntryId и documentKey; проверить смену часа |
| BibleScreen post-frame redirect | Непосредственный root host |
| Bible Back ведёт в `/` | Branch/root Back policy |
| Legacy scrollables без явных keys/controllers | Стабильные ключи для восстановления |
| Глобальный liturgical provider распространяет Hours context | Независимые даты; Prayerbook/Bible chrome нейтральный |
| Nested Scaffold и прежние top paddings | Один topChromeOwner и владелец inset |
| Удержание branches сохраняет listeners/futures | Guard async callbacks, UI-эффекты только видимого branch |
| Постоянный красный offline banner старого Shell | Offline с доступным текстом штатен; sync status вторичен |

### Session state

IndexedStack сохраняет mounted pages при tab switch. Это не гарантия восстановления после удаления страницы или завершения процесса.

Стабильные scroll keys:

- Ora: date / day / hour, с учётом идентичности документа.
- Readings: date или liturgical key / group / cycle / document.
- Prayer: ID.
- Bible: version / book / chapter.
- Root lists: также query / filter / category.

Один ScrollController не делить между одновременно mounted scrollables. При неизменном документе tab switch сохраняет offset; при смене содержимого нельзя применять offset другого документа.

### Process restoration

Navigator restoration и domain persistence — отдельные задачи. Нужны согласованные restoration IDs router, shell, branches и pages, а также восстановление domain state. Существующие Hive Bible locations / highlights сохраняются. Focus, selection и return token после перезапуска не восстанавливаются.

Справка: [go_router State restoration](https://pub.dev/documentation/go_router/latest/topics/State%20restoration-topic.html). Применимость API и поведение проверять на установленной 14.8.1. Не заявлять process restoration на основании одного IndexedStack.

## 10. Implementation checklist для Sol High

1. Зафиксировать branch IDs, canonical locations, route descriptors, commands и return-token lifecycle.
2. Добавить независимые Hours / Readings branch context и правила применения explicit URL.
3. Собрать четыре branches со стабильными keys и существующими экранами через adapters.
4. Добавить aliases старых маршрутов, сохранив query и encoded IDs.
5. Перевести AppShell на StatefulNavigationShell; удалить URI/runtimeType detection и scroll auto-hide.
6. Реализовать floating Full / Compact / Hidden dock через существующую платформенную границу.
7. Подключить route-aware controllers: default policy, requests, push/pop lifecycle, stale-callback protection.
8. Интегрировать Ora: scope focus, branch Back, Ora → Readings, корректный document identity.
9. Добавить Readings root adapter: default date, explicit context, date sheet/picker, отсутствие старого dock.
10. Добавить Bible root host без redirect-root и Back в Hours.
11. Подключить legacy screens к chrome/inset/navigation adapters с сохранением функций.
12. Сделать drawer вторичным меню, сохранив необходимые временные shortcuts.
13. Проверить единственный bootstrap, session persistence и startup/restoration policy.
14. Удалить старый Shell/date navigation из активной композиции после переноса маршрутов.

### Acceptance checks

- [ ] Четыре разных stack и scroll positions сохраняются при последовательном tab switch.
- [ ] Hours и Readings сохраняют разные даты.
- [ ] Ora другой даты → Readings передаёт date/dayId → Back возвращает ту же Ora, варианты и позицию.
- [ ] Ручной tab switch не создаёт возврат к Ora.
- [ ] Cold/warm deep links во все reader destinations выбирают правильный branch.
- [ ] Repeat active tab возвращает root без сброса даты и root scroll.
- [ ] Hidden → Back возвращает chrome; следующий Back выполняет навигацию.
- [ ] Hidden закрытого reader не влияет на root.
- [ ] Bible entry, chapter steps и repeat tab не создают spinner/redirect loop.
- [ ] Старые aliases работают, включая dayId со слешами/пробелами и Bible verse.
- [ ] Loading / error / offline сохраняют доступную навигацию.
- [ ] Последняя строка доступна с Full / Compact, клавиатурой, safe areas и крупным текстом.
- [ ] Смена chrome не пересоздаёт документ и не сбрасывает позицию.
- [ ] iOS gesture и Android Back/predictive Back согласованы с описанной политикой.
- [ ] Новая Ora и немигрированные Readings / Prayer / Bible работают одновременно под одним Shell.
- [ ] Reader foundation/navigation tests и соответствующие domain tests остаются зелёными.

### Definition of done Stage 2

Единый Shell управляет четырьмя независимыми branches, Back и chrome. Миграция любого branch в Stage 3+ не требует повторной смены router architecture или завершения остальных branches в том же PR. Production UX содержимого мигрируется поэтапно; обязательные navigation adapters и устранение дублирующего chrome входят в Stage 2.
