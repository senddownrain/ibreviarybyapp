# Phase 3A — Top Chrome audit

Срез: `main @ ad437ff1ad4cf0fa6ef22968480e16156671d12e`, 2 октября 2026.
Аудит сделан в отдельной ветке `codex/phase3a-top-chrome`. Параллельная
`codex/phase2b-bottom-controls` изменяет нижнюю зону; эти изменения не входят
в текущий срез. Источники нормы: [Quiet Book](DESIGN_CONCEPT.md),
[Design System](DESIGN_SYSTEM.md), [consolidated review](../DESIGN_CONCEPT_VNEXT.md)
и [Liturgy visual spec](../LITURGY_CONTENT_VISUAL_SPEC.md). Фактическое поведение
ниже сверено по `lib/router/router.dart` и экранам `lib/screens/`.

## Текущее устройство и проблемы

`AppRouteDescriptor.topChromeOwner` различает `shell`, `reader`, `legacy`.
`AppShell` рисует только левое меню для `shell`; правая кнопка и title принадлежат
самому экрану. `ReaderScaffold` рисует `ReaderChrome` поверх прокрутки.
`legacy` означает самостоятельный `AdaptiveAppBar`, `FloatingTopActions` или
обычный `AppBar`. Это учет владельца, но пока не общий смысловой контракт.

Три конкурирующие геометрии: 52 dp у `FloatingTopActions`, 48 dp у
`ReaderChrome`/`AdaptiveAppBar`, обычный `AppBar` у utility/editor. Root
Літургіі/Малітоўніка вручную откладывают контент на `padding.top + 78`, reader
использует `padding.top + 76`, часть collection — `padding.top + 90`.
Некоторые экраны одновременно зависят от shell menu и собственного правого
action. На 320 dp и 200% системного текста это нельзя считать доказанным
контрактом. `ReaderContextHeader` уже удачно разделяет документ и chrome, но
его текущий `title` использует локальный `headlineSmall`, а каноническая
Cormorant-роль пока реализована не везде.

В таблице «—» означает отсутствие действия; `flow` — прокручивается вместе с
контентом; `overlay` — верхние кнопки остаются над ним. Названия role приведены
в следующем разделе. `secondary` включает menu/overflow и действия внутри
контекстного заголовка; это не утверждение, что все они находятся в top row.

| Экран / branch / route | Owner | Leading | Title/context | Actions; secondary | Scroll; проблема → роль |
| --- | --- | --- | --- | --- | --- |
| Hours root · Літургія · `/hours` | shell | меню | «Літургія гадзін», выбранная дата, празднование | выбор даты/альтернатив внутри страницы | меню overlay, день flow; ручной inset, отдельная иерархия заголовка → BranchRoot |
| Hora picker · Літургія · `/hours/hora/:date/:dayId` | legacy | Back через `AdaptiveAppBar` | «Літургія гадзін», часы дня | выбор часа; — | app bar фиксирован; 48 dp бар отличается от shell → Collection |
| Liturgical picker · Літургія · `/hours/picker` | legacy | локальный Back | дата/варианты | Today, calendar/options в содержимом | собственная верхняя зона; повторяется в Readings → Collection |
| Ora reader · Літургія · `/hours/ora/:date/:dayId/:type` | reader | Back | дата, день и час в `ReaderContextHeader`; title меняет час | Aa; переход к Чытанням в header | overlay + full/compact/hidden; контекст и действия требуют ясного разделения → Reader |
| Readings root · Чытанні · `/readings` | reader | меню через `leading` | дата, литургический контекст и циклы в reader header | Aa; дата/Today/варианты в header | reader overlay; это root и длинное чтение одновременно, не обычный collection → BranchRoot + Reader |
| Readings picker · Чытанні · `/readings/picker` | legacy | локальный Back | дата/литургический выбор | options внутри flow | отдельная копия picker chrome → Collection |
| Reading detail · Чытанні · `/readings/reading/:readingId` | legacy | Back через `AdaptiveAppBar` | название чтения в bar | HTML toggle и Share | фиксированный bar + flow; две service-actions теснят title, Aa нет → Reader |
| Prayerbook root · Малітоўнік · `/prayers` | shell | меню | полка, избранное, разделы | Search отдельно через `FloatingTopActions` | обе кнопки overlay; root title системный, поиск пока prayer-only → BranchRoot |
| Prayer list/search · Малітоўнік · `/prayers/all`, `/prayers/search`, `/prayers/category/:id` | legacy | Back через `FloatingTopActions` | категория/список в flow | search/filter dock; другие controls локально | top overlay + нижний search owner; Phase 2B touchpoint → Collection/Search |
| Prayer detail · Малітоўнік · `/prayers/prayer/:id` | reader | Back | title/tags в `ReaderContextHeader` | Favorite, Aa; Edit local в overflow | overlay, reader flow; два actions и overflow при крупном тексте → Reader |
| Holy Mass · Малітоўнік · тот же route, Mass descriptor | reader | Back | title документа, разделы | Language, Aa; section selector отдельно | overlay и собственная нижняя навигация; язык обязателен, секции не дублировать → Reader (Mass composition) |
| Songbook · Малітоўнік · `/prayers/songs` | legacy | Back через `FloatingTopActions` | название/filters в flow | search/filter dock | overlay + dock; search ownership меняется в Phase 2B → Collection/Search |
| Song detail · Малітоўнік · `/prayers/songs/:id` | reader | Back | title/tags в reader header | Favorite, Aa; chords/layout/transpose в header details | overlay; песенные настройки не должны занять общую top row → Reader |
| Compendium root · Малітоўнік · `/prayers/compendium` | legacy | Back через `FloatingTopActions` | title и Part list | `CompendiumSearchHost` | overlay + search; отдельная система поиска → Collection/Search |
| Compendium Part · Малітоўнік · `/prayers/compendium/part/:partId` | legacy | Back | Part title/outline | `CompendiumSearchHost` | overlay, прокрутка по индексам; длинный контекст нельзя втиснуть в кнопки → Collection |
| Compendium node · Малітоўнік · `/prayers/compendium/node/:nodeId` | legacy | — в переходном экране | после загрузки открывает Part через `pushReplacement`, иначе error state | search host в fallback | compatibility route, отдельный header не нужен → Collection parent |
| Compendium question · Малітоўнік · `/prayers/compendium/question/:number` | reader | Back | номер, вопрос и trail в reader header | Aa; поиск через `CompendiumSearchHost` | overlay; trail должен оставаться документным, без нового bottom prev/next → Reader |
| Bible root · Біблія · `/bible` | reader | меню через `leading` | последняя позиция, книга и глава в reader header | Search, Aa; translation в header | overlay; root фактически последняя глава, нет отдельного списка-корня → BranchRoot + Reader |
| Bible chapter · Біблія · `/bible` с query `version/book/chapter` | reader | меню на branch root | книга/глава, picker по title | Search, Aa; translation в header | overlay; picker и нижняя chapter navigation должны вести в один flow → Reader |
| Bible search · Біблія · `/bible/search` | legacy | Back через `AdaptiveAppBar` | поисковая область/текущая книга | поле запроса | app bar + IME; порядок Back при фокусе явно не централизован → Search |
| Bible search result · Біблія · `/bible/search/result` | reader | Back/возврат к поиску по стеку | книга/глава и verse target | Search, Aa; translation | overlay; контекст возврата к выдаче сохранить → Reader |
| Bible selection state · Біблія · в главе | reader + palette | меню/Back как в главе | тот же документ | actions главы; выделение и палитра | верх остаётся, нижний contextual owner меняется; проверить пересечения фокуса → Reader state |
| Settings · utility · `/settings` | `SecondaryPageScaffold` | Close/Back | «Налады» в обычном `AppBar` | локальные settings controls | bar фиксирован; допустимая utility-роль, иной материал → Utility |
| About · utility · `/about` | `SecondaryPageScaffold` | Close/Back | «Інфармацыя» | — | как Settings → Utility |
| Favorites · Малітоўнік · `/prayers/favorites` | legacy | `AdaptiveAppBar` Back | «Абраныя малітвы» | favorite rows | bar фиксирован; collection без Aa → Collection |
| My prayers · Малітоўнік · `/prayers/my` | legacy | `AdaptiveAppBar` Back | «Мае малітвы» | create/edit в content | bar фиксирован → Collection |
| Create/edit prayer · Малітоўнік · `/prayers/prayer/add`, `/:id/edit` | legacy | `AdaptiveAppBar` Back | create/edit title | Save; Delete при edit | bar фиксирован; destructive action отделить от primary Save → Editor |

Дополнительные `/hours/picker/options`, `/readings/picker/options` — дочерние
collection states с Back. `/prayers/categories` — collection; вложенный
редактор категорий использует локальный `AppBar` и относится к Editor.
`/prayers/sacraments` пока placeholder с `FloatingTopActions(showBack: true)`;
он не задаёт отдельную роль. `CompendiumTopicScreen` также reader-shell, но
question — показательный сценарий для контракта.

## Шесть устойчивых ролей

1. **BranchRoot** — одна из четырёх веток; leading = Menu, page title в
   контенте. Может одновременно быть reader (Чытанні, Біблія).
2. **Collection** — parent shelf/list/picker; leading = Back, UI list title и
   местные фильтры. Нет Aa без длинного документа.
3. **Reader** — документ с page title/context header; leading = Back, кроме
   reader на корне ветки, где Menu. Aa принадлежит этому уровню.
4. **Search** — query, scope, results и IME; leading возвращает к parent
   после закрытия активного search/focus layer. Search может быть режимом
   Collection, не обязательным новым route.
5. **Editor** — Back/Cancel, Save, локальные destructive действия;
   пользовательский ввод и клавиатура имеют приоритет.
6. **Utility** — Settings/About и прочие глобальные экраны с Close/Back,
   обычной предсказуемой навигацией.

Top contract — композиция маленьких `ChromeIconButton`, `ChromeActionGroup`,
контекстной подписи и `PageHeader`, а не один widget с десятками bool. У каждой
route ровно один top owner. Контекст дня, title и hierarchy trail живут в page
или `ReaderContextHeader`; top row хранит только навигацию и быстрые действия.
На root не показывать Back. На child Back идёт к parent collection/branch; при
cold deep link fallback определяется route stack, не догадкой по иконке.
Ora → Чытанні сохраняет существующий return token. В Search системный Back
сначала закрывает IME/активный режим, затем route; это целевой контракт для
Phase 3B, потому что сейчас единая обработка не доказана.

## Приоритет действий и плотность

| Контекст | Виден прежде всего | Следом, если помещается | Overflow / inline |
| --- | --- | --- | --- |
| Root | Menu; Search у библиотечной/библейской ветки | редкое контекстное действие | варианты дня и shelves в странице |
| Обычный reader | Back/Menu; Aa | Favorite у молитвы/песни, Search у Бібліі | Edit, Share, прочее |
| Ora | Back; Aa | переход к Чытанням остаётся в context header | варианты часа через title chooser |
| Mass | Back; Aa, Language | только если хватает ширины | section navigation отдельно, Share в overflow |
| Song | Back; Aa, Favorite | — | chords/transpose в song-specific inline details |
| Compendium question | Back; Aa | Search как отдельный scope | hierarchy trail в page |
| Editor | Back/Cancel; Save | — | Delete отделён от Save |

На 320 dp сохранять leading, Aa у reader и один overflow; значимые скрытые
действия получают текстовые labels. Если Language обязательна для Mass, она
первой выходит из overflow при доступной ширине. Нельзя уменьшать targets ниже
48 dp или зажимать системный TextScaler. Варианты A/B/C в lab проверяют именно
композицию, не три конкурирующие системы.

## Preserve / Refine / Unify / Replace later

| Preserve | Refine | Unify | Replace later |
| --- | --- | --- | --- |
| `ReaderContextHeader` отделяет документ от controls; Ora title chooser и shortcut Чытанняў; Bible picker по title; Prayerbook shelf tiles | Cormorant для содержательных titles, title/context rhythm, длинные labels, selection/focus; Mass Language и song chord details оставить локальными | 48 dp минимум, neutral chrome, semantic action priority, safe-area owner и page title across roots | ручные `top + 78/90`, параллельные верхние системы после миграции, redundant actions |
| `FloatingTopActions` и `AdaptiveAppBar` уже имеют platform surface и Back; `ReaderChrome` держит Aa/overflow | согласовать 52/48, порядок действий и отсутствие второго top owner | общие primitives и role compositions с iOS/Android expression | старые wrappers только после переноса всех callers |

## Платформы, safe area, доступность

Одинаковы роли, parent/back semantics, приоритет, labels и порядок фокуса.
iOS выражает controls лёгким glass/Cupertino spacing и нативным Back; Android
использует tonal Material surface, ripple и системный predictive back. Glass
не применяется к читаемой странице. В обеих системах status inset входит в
верхнюю зону один раз; высота controls измеряется по содержимому, а первый
абзац не прячется за overlay. Скрытый reader chrome имеет видимый и озвученный
способ восстановления. Порядок screen reader: leading → быстрые действия →
overflow → контекст страницы → документ. Selected/toggled состояния объявлены.

Проверка: ширины 320/360/390/700, system 100/150/200%, длинный белорусский
title, одновременно Aa/Favorite/Search/Language/Overflow; клавиатура, selection,
полноэкранный reader, dark/high contrast и reduce transparency. Lab моделирует
layout и platform style; native predictive back и accessibility service нужно
проверять в Phase 3B на устройстве.

## Риски и merge touchpoints

Phase 2B может изменить `lib/router/router.dart`, `lib/widgets/app_shell.dart`,
`lib/navigation/app_navigation.dart`, `lib/screens/bible_chapter_screen.dart`,
`lib/screens/ora_screen.dart`, `lib/screens/prayers_screen.dart`, search hosts и
bottom inset API. Phase 3A добавляет в router только compile-time lab route.
Перед Phase 3B повторить inventory этих участков, прежде чем переносить top
ownership. Mass bottom navigation, Bible chapter navigation, search docks,
Library Search и Ora scroll-to-top не мигрировать по этому срезу.
