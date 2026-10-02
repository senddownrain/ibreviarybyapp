# Phase 2A — Bottom Ownership Audit

## Phase 2B corrective pass — current production decision

After reviewing Phase 2B in the app, Bible is again a global branch with its
global dock visible on the chapter reader. The fixed floating chapter bar was
removed. The top reader context opens the existing full book/chapter picker;
horizontal swipes still use `BibleNavigation.relative()` across book boundaries.
Canonical full book names remain in the data, reader context and picker.
Verse selection temporarily suppresses the global dock for its palette; closing
selection restores the global dock.

Prayerbook root is one continuous scroll: shelf and categories, then an inline
Library Browser. There is no Search tile or Search entity in the shelf. The
top search action scrolls to the inline field. Browser scopes are `Малітвы`,
`Спеўнік`, and `Катэхізіс`; only the active scope builds rows. Empty query
means browse all prayers, all songs, or the Compendium parts. A nonempty query
uses each domain's existing search function. Query persists across scope
changes. The global dock remains on the root; focused search temporarily
suppresses it while the keyboard is active. Back dismisses focus in place.
The standalone `/prayers/library-search` route remains for existing links.

Current decisions: Mass = its existing local selector; Bible = global dock +
top picker + swipe; Ora = global dock + scroll-to-top; Prayerbook root = shelf
+ continuous Library Browser; Search is a temporary mode, not a separate
Prayerbook entity. The Phase 2B description below records the earlier state
and is superseded by this corrective section where it differs.

## Phase 2B — принятые решения и реализация

Phase 2B развивается на ветке Phase 2A (`bc92f01`); `main` на момент старта
оставался на чистом Color Foundations commit `ad437ff`. Prototype lab остаётся
исследовательским экраном и не используется как production-компонент.

Принята модель **разные функции, одна визуальная и геометрическая семья**.
Mass сохраняет существующий selector, active section tracking, `n/5`, section
sheet, управление языком сверху и измеренный inset. Стрелки в Mass не
добавляются. Bible использует floating `previous | current | next`,
`BibleNavigation.relative()` и один существующий picker с двумя входами:
верхним title и центром bar. Палитра выделения заменяет Bible bar.

Ora не получает последовательную навигацию часов: выбор остаётся в верхнем
контексте, а после длинной прокрутки появляется существующая reader-кнопка
«Да пачатку». Обычная молитва и песня не получают previous/next. Search
в Prayer catalog, Songbook и Compendium остаётся contextual bottom owner,
подавляющим global dock. Search dock разделяет `AdaptiveChromeSurface`,
safe-area anchor и `BottomControlGeometry`: iOS glass, Android neutral tonal.

Library Search Mode доступен в конце полки Малітоўніка и через действия
в Prayerbook, Songbook и Compendium. Начальная область определяется входом:
`Малітвы`, `Спеўнік`, `Катэхізіс` соответственно. Query принадлежит одному
экрану и сохраняется при переключении scope. Каждая область использует свою
существующую функцию поиска, данные и result row; chips входят в search UI,
не образуют второй bottom bar. Маршрут: `/prayers/library-search`, с
`?scope=songs` или `?scope=compendium` для контекстного входа. При входе из
Songbook или Compendium текущий query передаётся в режим через параметр `q`.

Текущий production bottom owner после Phase 2B: root ветки — global;
Mass — local selector; Bible chapter — local chapter bar, при выделении —
selection; Ora, prayer detail, song detail — существующий compact global
dock без локального prev/next; каталоги с поиском и Library Search — search.
Compendium question пока сохраняет search dock и inline pager. Общий typed
`BottomOwner` не вводился: route descriptor и contextual slot покрывают эти
переходы. Дальнейшую архитектурную миграцию следует решать отдельно после
проверки Compendium search/reader и Bible search/IME.

Разделы ниже фиксируют аудит и гипотезы **Phase 2A**. Там, где они предлагают
иной результат (в частности, локальный Hours navigator или общий
`ReaderBottomBar`), решение Phase 2B выше имеет приоритет.

Проверено по production-коду после чистого merge Color Foundations Phase 1
(ad437ff). Phase 2A не переносит production navigation на новый компонент.
FOUNDATIONS_POST_MERGE_AUDIT.md отсутствовал в main после этого merge.

## Иерархия

1. Global branches: Літургія, Чытанні, Малітоўнік, Біблія. На корнях и
   коллекциях глобальный dock остаётся способом сменить ветку.
2. Entities внутри Малітоўніка: Малітвы, Святая Імша, Спеўнік, Кампендый и
   другие книги выбираются на полке, без второго постоянного tab bar.
3. Локальная навигация открытой entity оправдана, если «предыдущий /
   текущий / следующий» имеет очевидный порядок внутри книги. Parent и
   Back находятся сверху; global dock появляется после выхода к parent.

Это уточняет старую гипотезу Design Concept/System и VNext о branch button
в ReaderBottomBar: reader control отвечает только за свою entity.

## Матрица владения на старте Phase 2A

Global dock здесь означает фактическое состояние route/chrome. Compact —
глобальный dock с кнопкой раскрытия веток.

| Screen / mode | Parent branch | Global dock сегодня | Local navigation / bottom сегодня | Естественная последовательность | Предполагаемый bottom owner |
| --- | --- | --- | --- | --- | --- |
| Hours root /hours | Літургія | Full | Выбор дня/часа в контенте | Нет для root | Global dock |
| Hora picker | Літургія | Full | Список доступных часов | Нет для коллекции | Global dock |
| Ora | Літургія | Compact | Нажатие title открывает sheet выбора часа | Возможна внутри дня; составной morning и availability требуют правил | Сравнить local pattern в lab; сейчас global dock |
| Readings root /readings | Чытанні | Full | День и чтения в контенте | Нет для root | Global dock |
| Reading detail | Чытанні | Compact | Нет; legacy reader | Не установлена | В будущем none, без искусственного prev/next |
| Prayerbook root /prayers | Малітоўнік | Full | Полка entities | Нет | Global dock |
| Prayer catalog/search | Малітоўнік | Подавлен contextual slot | PrayerSearchDock постоянно | Нет | Search |
| Ordinary prayer detail | Малітоўнік | Compact | Нет; ReaderScaffold.overlay отсутствует | Нет | В будущем none; Back сверху |
| Holy Mass | Малітоўнік | Выключен route descriptor | Floating selector, section sheet, язык сверху | Да, разделы Мессы | Local reader; сохранить selector как valid pattern |
| Songbook list | Малітоўнік | Подавлен contextual slot | Floating PrayerSearchDock с фильтром | Нет для списка | Search |
| Song detail | Малітоўнік | Compact | Нет; аккорды в контексте reader | Нет обязательного порядка песен | В будущем none; Back сверху |
| Compendium root / Part | Малітоўнік | Подавлен contextual slot | Постоянный floating search dock | Нет для root/Part | Search |
| Compendium question | Малітоўнік | Подавлен contextual slot | Search dock + inline CompendiumPager в конце ответа; swipe | Да, номера вопросов | Сейчас search + inline pager; local bar требует решения о search mode |
| Bible chapter /bible | Біблія | Compact | ChapterNavBar inline в конце главы, top picker, swipe | Да, главы через BibleNavigation.relative, включая границы книг | Будущий local reader |
| Bible search route | Біблія | Full | Поле поиска вверху, отдельный result route | Нет | Search/IME требует отдельного ownership решения |
| Bible verse selection | Біблія | Подавлен contextual slot | Floating highlight palette; chapter bar остаётся inline | Временный режим | Selection |

Loading/error Mass не рисует Mass bar, хотя route подавляет dock: фактический
owner тогда none. Bible selection оставляет inline chapter bar в документе,
но не создаёт второй floating layer. Prayer/Songbook/Compendium search владеет
низом даже при пустом query; активность search нельзя приравнять к query text.

## Что сохранить

- AppRouteDescriptor.showsNavigationDock уже отключает dock для Mass.
  BranchShellController.navigationDockSuppressed учитывает route и запрос
  активного entry. Contextual slot очищается при удалении entry.
- AppRouteEntryScope.showContextualBottomBar связывает Bible selection и
  persistent search с active route. AppShell скрывает global dock.
- ReaderScaffold.overlay исчезает вместе с chrome. Mass измеряет bar через
  MassBarHeightReporter и резервирует конец документа через
  floatingOverlayBottom / floatingOverlayContentReserve. Это сильный pattern.
- Bible сохраняет правильные границы книг, combined picker, swipe и
  selection palette. Compendium сохраняет канонический порядок, query и
  возвращение из результатов. Ora title picker учитывает доступность часа.

## Конфликты

- Boolean suppression говорит shell лишь «рисовать dock или нет» и не
  различает reader navigation, search, selection и отсутствие bar.
- Bible root показывает compact global dock и inline prev/current/next.
  Семантика готова, но bottom reader owner пока нет.
- Compendium question имеет inline pager и persistent search dock.
  Перенос pager вниз потребует явного переключения search ↔ reader и
  сохранения query/Back. Сейчас переносить его нельзя.
- Bible search имеет верхнее поле и global dock; IME надо проверить отдельно.
- ReaderScaffold рисует отдельную кнопку scroll-to-top после прокрутки.
  Compendium question включает её рядом с persistent search dock; при
  переносе owner понадобится единая геометрия или действие «Да пачатку» в
  outline/top menu, чтобы control не конкурировал за нижнюю область.
- Mass selector + полный sheet позволяют jump внутри длинного документа.
  Постоянные стрелки могут ускорить соседний шаг, но съедают ширину.
- Порядок kHoraItems содержит составную Агульная гадзіна; blind index ±1
  дублировал бы части службы. Prototype показывает только отдельные часы.

## Минимальный будущий contract

BottomOwnerKind: global, reader, search, selection, none. Route задаёт
default; временные requests привязаны к route-entry ID. Shell/branch
coordinator выбирает один owner активного entry. Reader передаёт локальный
виджет, но не управляет global branch dock.

Приоритет: modal блокирует underlying actions → selection → search/IME →
reader → global → none. Modal — отдельная presentation, не второй owner.
При IME активный search остаётся над клавиатурой; обычные bars уступают ей.
Hidden reader chrome даёт none для обычного bar и видимый top restore.
При route change запрос неактивного entry не рисуется; при dispose
удаляется. Branch switch не переносит owner между ветками. Back закрывает
sheet, затем selection/search, затем восстанавливает chrome, затем pop.
Единый измеренный slot публикует высоту + safe area для конца контента.

В Phase 2A этот contract только документируется: production enum и
компоненты не мигрируют.

## Сравнение и migration после выбора

Lab сравнивает A (одна строка со стрелками), B (Mass-like selector, соседние
шаги через swipe/outline), C (адаптивная одна/две строки). Техническая
рекомендация — C при 320 px и 200% system text. Владелец выбирает UX;
Mass B может остаться отдельным valid pattern даже при выборе C для Bible.

### Как открыть lab

Сборка lab включается compile-time flag, прямой route недоступен в обычной
сборке и не добавлен в меню. В flag-сборке он открывается при запуске;
на вебе его адрес — /#/design/bottom-navigation-lab.

    flutter run -d chrome --dart-define=IBREVIARY_BOTTOM_NAV_LAB=true

Для браузера телефона в той же сети запустить web-server с
--web-hostname=0.0.0.0 и --web-port=8080, затем открыть адрес компьютера
с /#/design/bottom-navigation-lab. Для iOS/Android visual expression веба
добавить --dart-define=IBREVIARY_PLATFORM=ios или android. Эти preview flags
меняют Flutter platform styling, не симулируют нативное устройство.

### Исторический Phase 2A migration plan до решений Phase 2B

1. Записать выбранный A/B/C как default geometry локальной навигации.
   Исключение Mass selector сохраняется, если владелец не выберет для него
   изменение отдельно. Запретить branch button в reader bar.
2. В BranchShellController добавить typed route default и запросы по
   active entry ID. На смене route скрывать запрос прежнего entry, при
   dispose удалять его; AppShell отображает только resolved owner. Сохранить
   существующий Full/Compact/Hidden chrome state и независимые branch stacks.
3. Добавить единые измеренные bottom metrics: высота owner, зазор,
   системный inset и IME. ReaderContentSurface получает ровно один reserve.
   Перенести существующие Mass/Bible расчёты без потери их поведения.
4. Bible первым использует выбранную geometry: вынести inline
   ChapterNavBar в local owner, сохранить BibleNavigation.relative,
   combined picker, swipe, deep links и сохранённую позицию. Selection
   palette временно замещает reader bar; Back сначала снимает selection.
5. Mass регистрирует reader owner, сохраняя section sheet, active-section
   tracking, язык сверху и измеренную высоту. Добавление стрелок не является
   условием миграции.
6. Prayer/Song/Reading detail получают none вместо compact global dock;
   parent/back сверху, включая cold deep link fallback к корню своей ветки.
   Каталоги и четыре branch roots сохраняют global/search owners.
7. Compendium root/Part сохраняют search owner. В question reader default
   становится local только после добавления явного search action: активный
   search замещает bar, сохраняет query/results/return stack, Back закрывает
   search прежде reader. Тогда решить удаление inline pager без дублирования.
8. Ora остаётся с title picker и текущим dock до отдельной проверки порядка
   часов на реальных днях и доступности; составную Агульную гадзіну не
   включать в prev/next по индексу.

Каждый шаг проверяет route/Back/IME, 320–700 px, 100–200% system text,
safe area, глубокие ссылки, последний абзац и screen reader. Phase 2A
этих production шагов не выполняет.

Будущий Library Search Mode внутри Малітоўніка может переключать scopes
Малітвы | Спеўнік | Катэхізіс с одним query. Это отдельная фаза: search
остаётся временным owner, способным заменить global/local bar.
