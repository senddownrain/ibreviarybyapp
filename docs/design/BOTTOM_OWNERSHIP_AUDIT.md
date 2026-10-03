# Phase 2A — Bottom Ownership Audit

## Current production status after the Phase 2B rollback

Phase 2B's product experiment was rejected after in-app review. Production
behavior was restored to the pre-2B state (`bc92f01`): there is no shared
Library Browser or cross-domain search. Prayer search is prayer-only;
Songbook and Compendium retain their own screens and search systems. Bible
keeps the global app dock and the old inline end-of-chapter navigator, with
the existing full book/chapter picker, swipe, search, and selection palette.

The sole new visible behavior is that the **full** four-branch dock appears at
the top of a Bible chapter and becomes **compact** after a deliberate downward
scroll past the Readings threshold. Mass and Ora retain their pre-2B behavior.

The remainder of this document records the historical Phase 2A audit and
prototypes. Its proposed migrations are not current product decisions.

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

### Следующая production migration после выбора

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
