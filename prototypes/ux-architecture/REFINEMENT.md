# Refinement: решения и audit controls

IA сохранена, изменён только прототип. Дополнительных UX-решений, блокирующих просмотр, нет. Нативные материалы и production content resolver — инженерная проверка следующего этапа.

## Floating chrome и navigation

Верхний ряд не повторяет `iBreviary`/название раздела; название находится в content. Только отдельные floating menu/back, search, Aa и необходимый overflow. Нет общей full-width surface. У внешнего контейнера bottom dock убраны gradient/fill. Вокруг дока виден page background. iOS: glass-имитация; Android: opaque tonal, собственные shapes и selection capsule.

| Контекст | Auto |
| --- | --- |
| Hours, Prayerbook, категории, All Prayers | Full |
| Readings при входе | Full |
| Длинные Readings после начала чтения | Compact, текст не перерисовывается |
| Ora, Prayer Detail, Bible Chapter | Compact |
| Focus | Hidden с доступным выходом |
| Выбор библейских стихов | Dock заменяется contextual palette |

Studio Navigation позволяет принудительно сравнить Full/Compact/Hidden. Compact раскрывается одним tap. Нет общего Android scroll auto-hide или новых swipe-жестов по тексту.

## Alternatives: исследование и выбранный flow

Реальные `LiturgicalOptionSource`: **period, dynamic, fixed, officeForDead**. Внутри fixed celebration сервис создаёт `DayTemplate` по `_currentVersion`/`_templates`. `_place` определяет локальность, rank различает торжество/праздник/память/необязательную память. Локальный день не объявлен новым enum. У Петра Клявэра реально есть `pastors` и `works-of-mercy`.

| Подход | Вывод |
| --- | --- |
| Плоский sheet | Подходит для пары одинаковых сущностей, теряет различие local/office/template |
| Grouped sheet | Выбран: семантика видна без дополнительных screens |
| Сегменты между группами | Не нужны при текущей плотности, скрывают соседние варианты |
| Preview + previous/next | Добавлен в тот же sheet для быстрого сравнения |

Поток: **Іншыя варыянты → Святкаванні дня / Мясцовы каляндар / Іншы афіцый → выбор обновляет preview, sheet остаётся открыт → templates внутри celebration → Вярнуцца да гадзін**. Соседние варианты пропускают недоступные. Primary отмечен, ручной выбор не пересортировывает данные. Advanced calendar picker сюда не добавлен.

Текстовые варианты отдельных частей Ora не являются календарными празднованиями. Сборка псалтыря/общих текстов и Первые/Вторые Нешпары остаются production logic, новый resolver на час не создаётся.

## Calendar и advanced Liturgical Picker

Calendar: месячная сетка, выбранный день, месяц, год, Apply. iOS — нижний sheet, Android — Material-style dialog. Bounds **2019–2030** из `constants/liturgical.dart`.

Advanced: **Перыяды / Святы і святыя**, год, period/week/day, поиск названия/даты, fixed/dynamic filters. Сохранены production особенности:

- Ordinary 34 недели; Advent 3 плюс 17–24 декабря; Lent 5 плюс четыре дня от Пепельной среды; Holy Week 1 с понедельника; Easter 7.
- Christmas — точные даты от 25 декабря до Крещения Господня.
- Пропущенные Ordinary weeks и отсутствующие yearOptions дают явное отсутствие даты.
- Динамические даты следуют configured Ascension/Corpus Christi или существующему fallback. В fixture yearOptions 2026 этих overrides нет. Новый нормативный расчёт не введён.

Источники: `lib/screens/liturgical_picker_screen.dart`, `lib/utils/liturgical_calendar.dart`, `mybrev/src/utils/liturgicalCalendar.js`, `mybrev/src/stores/calendar.js`, `test/liturgical_calendar_test.dart`. Воспроизводимый экспорт — `extract-calendar.mjs`. Ограничение годовых данных 2026 явно обозначено; UI не сокращён до списка трёх mock dates.

## Малітоўнік, Settings, Bible

Root **Абраныя → Катэгорыі → Усе малітвы**. Нет ограничения первыми пятью. Стандартные и пользовательские категории выглядят одинаково. Различие в management: стандартные hide/show/reorder без delete; пользовательские create/rename/membership/delete. All Prayers — отдельный destination, а не только поиск. Фильтры поиска раскрываются по запросу; Back сохраняет query/filter. Реальные личные молитвы не экспортированы; для них применяется тот же list/detail contract.

Aa — только размер **70–180%, шаг 10%** по production settings. Settings: System/Light/Dark, стартовый раздел, размер, категории, sync/data. Font family, line height, paragraph spacing, width, density не выставлены пользователю. Debug platform/navigation/season остаются снаружи телефона.

Из `bible_screen.dart`, `bible_chapter_screen.dart`, `bible_repository.dart` сохранены: direct last place; segmented БЕЛ/РУС; canonical parallel book + clamp/fallback; Старый/Новый Завет; поиск книги; главы в раскрывающемся списке; previous/next через границы книг; поиск текста текущей книги; переход к стиху; выбор нескольких стихов; исходные highlight colors и opacity. Palette: amber `#E2AE34`, rose `#D37074`, sky `#4F9FC1`, leaf `#59A46B`, 30% light / 32% dark. Оба bundled корпуса включены полностью.

## Seasonal и Marian: источник правил

Источник истины **`lib/utils/liturgical_theme.dart`**. Контекст — `liturgicalSeasonColorProvider`. Android chrome tint 5.5% — из `platform_design.dart`.

Порядок сохранён: requiem/office-for-dead `#67546B` → красные Pentecost/Sacred Heart и исходные маркеры мучеников/апостолов/Духа `#B33A3A` → solemnity `#B88719` → непустой rank + `blessed-virgin-mary` **Marian `#5E9EC5`** → feast/memorial/optional `#8F7D52` → период.

Периоды: Ordinary `#4D8A5B`, Advent `#7A57A7`, Lent `#6F4A92`, Holy Week `#5B3B83`, Christmas `#B07A1E`, Easter `#BD8A24`; unknown `#55707C`. Локальность не создаёт отдельный цвет. **Marian solemnity остаётся золотой**, так как это более раннее source rule.

Source hue применяется к marker, мягкому ambient, selection и restrained Android tint. Для семантического текста используется контрастная смесь с ink. Reader остаётся `#FCFBF8` / `#171A18`; Prayerbook/Bible сохраняют нейтральность и mist-indigo.

В изученных Flutter `SettingsState` и MyBrev `stores/settings.js` отдельного переключателя seasonal-style variants нет. Поэтому новые пользовательские варианты не придуманы. Studio selector проверяет исходные состояния; default **«З кантэксту»**.

## Screen-by-screen control audit

| Экран | Ежедневно | Вторично / убрано |
| --- | --- | --- |
| Hours today | Дата, primary, alternatives, часы | Дублирование названия в chrome убрано |
| Hours other date | То же + Today | Нет постоянной date toolbar |
| Alternatives | Группы, preview, templates, next/previous, Done | Без глубоких screens и без calendar |
| Calendar | Месяц/год, дни, Apply | Только через дату |
| Liturgical Picker | Период/праздник, год, координаты | Отдельный advanced entry |
| Ora | Back, Aa, Чытанні, смена часа | Compact; focus в overflow |
| Readings | Текст, дата, manual indicator | Celebration/cycle в sheet |
| Readings options | Применимые группы/циклы, auto | Не все A/B/C/I/II одновременно |
| Prayerbook | Абраныя, единые категории, All Prayers | Убрано деление мои/системные |
| Category | Список, favorite state, search | Management вторично |
| All Prayers | Полный fixture-каталог | Search не заменяет destination |
| Prayer Search | Поле, clear, close, results | Фильтры не раскрыты заранее |
| Prayer Detail | Back, favorite, Aa | Compact, focus вторично |
| Bible | Язык, книга/глава, chapter steps, Aa/search | Убрана content glass card |
| Bible picker | Завет, поиск, главы | Перевод снаружи, доступен сразу |
| Bible search | Названия / текущая книга | Без обещания global full-text |
| Settings | Theme/start/size/categories/sync | Technical controls вынесены |
| Seasonal | Marker и мягкая atmosphere | Нет раскраски документа |
| Marian | Source blue marker/atmosphere | Сохранён приоритет solemnity |
