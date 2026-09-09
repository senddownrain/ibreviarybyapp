# Hours root migration — Stage 3

Дата: 2026-09-09. Статус: реализовано в `feature/mobile-ux-migration`.

## Новый ежедневный flow

Корень branch `Гадзіны` теперь сразу показывает нажимаемую дату, выбранное
литургическое празднование, действие alternatives (только когда они есть) и
реально доступные часы. Основной путь сокращён до:

`Гадзіны → час → Ora`.

`HoraPickerScreen` больше не входит в обычный primary flow. Его файл,
`/hours/hora/:date/:dayId` и alias `/hora/:date/:dayId` сохранены для
совместимости, fallback и старых deep links. Статус: **KEEP / DEPRECATE /
REMOVE LATER**; cleanup не входит в Stage 3.

## Primary, alternatives и state

`resolvePrimaryLiturgicalOption` в
`lib/utils/hours_liturgical_options.dart` является маленькой временной
границей policy/UI. Он безопасно берёт первый элемент уже отсортированного
production-списка `LiturgicalContentService`. Пустой список обрабатывается
явно. TODO рядом с функцией фиксирует будущую замену на усиленный precedence
resolver; UI не выбирает `.first` самостоятельно.

Остальные элементы считаются alternatives. Adaptive sheet сохраняет реальные
группы `period`, `dynamic`, `fixed`, `officeForDead`, показывает preview и
доступные `DayTemplate`. Выбор сразу обновляет preview, часы и seasonal accent;
sheet остаётся открыт до действия «Вярнуцца да гадзін», как в финальном
prototype. Ручной `dayId` хранится в session-state с ключом даты. Поэтому он не
переносится на другой день, но восстанавливается при возврате на прежнюю дату в
текущей сессии.

## Дата и advanced flow

Нажатие на дату открывает упрощённый adaptive sheet: сегодня, предыдущий день,
следующий день, platform-adaptive calendar и отдельный вход в полный
`LiturgicalPickerScreen`. На иной дате корень показывает one-tap «Сёння»; на
сегодняшней это действие скрыто. Изменяется только `selectedDateProvider`
Hours branch. Независимый `readingsBranchStateProvider` не затрагивается.

## Ora и визуальный язык

Доступность каждой строки вычисляется по существующим `HoraItem.checkFields`.
Нажатие строит canonical `/hours/ora/:date/:dayId/:type`, включая выбранный
template `dayId`, и открывает migrated Ora Stage 1. AppShell Stage 2 продолжает
владеть Full/Compact/Hidden dock и branch stacks.

Корень остаётся content-first: без собственного app bar, нижней навигации,
гигантской date-card или card вокруг каждой строки. Production
`liturgicalColorForDay` задаёт ambient wash, тонкий celebration marker и малые
semantic accents, включая Ordinary, Advent, Christmas, Lent, Easter, red,
Marian, solemnity и requiem rules. Android content использует обычные
непрозрачные Material surfaces; adaptive glass/tonal material ограничен
вторичным sheet/chrome.

## Проверки и legacy

Добавлены unit/widget tests для primary/empty, количества alternatives,
ручного выбора и templates, отсутствия пустого control, availability,
canonical Ora parameters, one-tap Today, независимости дат и 200% text scale.
Существующие suites продолжают покрывать branch preservation, contextual
Ora → Readings → Ora, compatibility/deep links и iOS/Android date surfaces.

Legacy после Stage 3: `HoraPickerScreen`, compatibility aliases, старый chrome
advanced Liturgical Picker и немигрированные roots Readings, Prayerbook и
Bible. Рекомендуемый следующий этап — отдельная миграция **Readings root**, без
изменения его production resolver и без автоматического начала в этом commit.
