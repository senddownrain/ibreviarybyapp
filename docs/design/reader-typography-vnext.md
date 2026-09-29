# Reader / Typography VNext

Статус: решение для поэтапного внедрения, 29 сентября 2026 года.

## Позиция

Одна книга, платформенная оболочка. Длинный литургический текст имеет одну
спокойную идентичность на Android и iOS. `ReaderContentSurface` — непрозрачная
страница документа; Material Ambient и Liquid Glass принадлежат chrome.

MyBrev здесь — контроль читабельности, а не визуальный шаблон. Из него полезны
разделение UI/reader/display-ролей, устойчивый ритм длинного текста и полные
названия альтернатив. Коричневая палитра, карточки и web-композиция не
переносятся.

## 1. Аудит текущей реализации

### Что уже хорошо

- `ReaderScaffold` уже отделяет `ReaderContextHeader`, chrome и непрозрачный
  `ReaderContentSurface`; документ не является `GlassSurface`.
- `AdaptiveChromeSurface` действительно разводит Android tonal Material и iOS
  glass, не дублируя screen tree.
- Рубрики имеют отдельный semantic red, а литургический цвет не подменяет
  основной текст.
- Readings уже держит дату, celebration/group и cycle в context header/sheet,
  оставляя в документе только краткий indicator.
- Размер текста хранится отдельно и работает во всех основных reader через
  `ReadingScaffold`.
- Имеются widget-тесты 320 px / 180% и light/dark/platform branches.

### Где Flutter слабее MyBrev как reader

- Роли шрифтов заявлены, но не проведены сквозь код. `ReaderTheme.body()`
  считает `Сістэмны` синонимом Literata, а `ReadingScaffold` вообще не передаёт
  сохранённый `fontFamily`. Пользовательская настройка фактически не работает.
- UI всего приложения принудительно набран Source Sans 3; это ослабляет
  платформенную идентичность и iOS, и Android.
- Body rhythm распался на 1.65, 1.70, 1.72, 1.75 и 1.78. Различия следуют из
  renderer-а, а не из семантики текста.
- `ReaderScaffold.maxContentWidth = 760` вместе с внутренними padding даёт
  слишком длинную строку на планшете при базовых 16 px.
- Alternatives sheet хорош по сохранности текста, но trigger иногда выводит
  полное длинное имя прямо в документе; две реализации choice sheet частично
  дублируются.

### Где Flutter уже сильнее MyBrev

- Platform chrome — отдельный слой, а не web-стиль, одинаковый для обеих ОС.
- Document surface непрозрачен и непрерывен; не нужно переносить mybrev cards,
  brown tint или вложенные reader-панели.
- Cycle/celebration readings уже концептуально вынесены из текста.
- Нативные Back/transitions, touch targets и app-level navigation лучше
  соответствуют мобильному приложению.

### Причины проблем

**Typography.** Несогласованный font contract и line-height; HTML renderers
перезаписывают базовый стиль собственными числами. Display Cormorant уместен
только для редких больших заголовков, не как вариант длительного чтения.

**Palette.** Светлая палитра почти ахроматична, но главная проблема — слабое
разделение соседних `background/surface/variant`, а не отсутствие brown hue.
Reader `#FCFBF8` уже слегка тёплый; его следует сохранить почти нейтральным и
усилить separation вокруг него.

**Effects.** В dark mode одновременно видны ambient hero, top/bottom reader
fades, тёмные полупрозрачные chrome fills, specular gradient и глубокие shadows.
Каждый слой слабый, но сумма создаёт ощущение отражающей панели. Особенно
заметен bottom fade высотой до 96 px поверх прокручиваемого текста.

**Interaction.** Document-level readings controls уже размещены правильно.
Локальные alternatives правильно живут рядом с блоком, но trigger должен
сообщать тип и позицию, а не пытаться показать длинное имя. Полное имя живёт в
sheet. Invitatorium selector остаётся локальным: он меняет конкретный текст
псалма приглашения, а не весь документ.

### Что оставить

- IA, Riverpod/GoRouter/Hive, liturgical resolution и порядок контента.
- `ReaderScaffold`, `ReaderContentSurface`, `ReaderContextHeader`,
  `AdaptiveChromeSurface`, `TextScaleControl` как базовые границы.
- Literata как default book face и Cormorant Garamond для редких display titles.
- Semantic rubric/season colours, fullscreen contract и platform transitions.
- Текущую модель readings options: indicator в header, выбор в sheet.

## 2. Компактная система VNext

### Typography

| Роль | Гарнитура | Размер/ритм |
| --- | --- | --- |
| Platform UI | системная ОС | `ThemeData` / Cupertino defaults |
| Reader body | Literata по умолчанию | user size, 1.68 |
| Psalm | reader | user size, 1.68; строфы задают spacing |
| Hymn | reader | user size, 1.72; более явный paragraph gap |
| Reference | reader semibold | 0.88 body, 1.40 |
| Rubric | reader medium/italic по смыслу | 0.90 body, 1.48 |
| Metadata | reader | 0.88 body, 1.42 |
| Section heading | reader semibold, rubric | 1.10 body, 1.28 |
| Display title | Cormorant Garamond bold | только крупный reader title, 1.06 |

Reader family choices: `Кніжны · Literata`, `Сістэмны`, `Source Serif 4`.
Трёх вариантов достаточно: один рекомендованный book face, нативный fallback и
одна нейтральная serif-альтернатива. Lora/Merriweather не плохи, но добавляют
выбор без новой роли; Playfair Display исключается как display face.

Legacy `Сістэмны` мигрирует в Literata, потому что именно Literata реально
рендерилась до VNext. Это сохраняет существующий вид и делает новое название
честным. Новое явное `Сістэмны` действительно использует platform font.

Literata и Source Serif 4 в `google_fonts` имеют normal/italic и 400–700 (также
более широкий weight range) и Cyrillic font files. Контрольная строка для QA:
`І і · Ў ў · Ё ё · ’ ' · † · Псальм 118 · Fiat`. Runtime glyph/fallback и
offline delivery всё равно проверяются на release device; bundling fonts —
отдельный release-hardening этап, потому что сейчас проект не содержит font
assets.

### Reader / width / spacing

- `ReaderContentSurface` остаётся flat opaque surface без blur, shadow,
  gradient и tint от liturgical season.
- Максимальная внешняя ширина reader: 700 logical px; внутренний текст около
  656 px. На 320 px сохраняется 18–22 px horizontal inset.
- Paragraph default: 0.55–0.70 body line; hymn 0.85–0.95; section gap 24 px.
- System `TextScaler` продолжает применяться поверх reader Aa; clipping ради
  сохранения композиции запрещён.

### Light

Почти нейтральный warm gray, не beige: background чуть темнее и холоднее
reader; reader близок к neutral ivory с очень низкой насыщенностью. Основной
эффект достигается separation и contrast, не brown tint.

### Dark

Не OLED black: спокойные green-neutral charcoal surfaces. Reader не получает
ambient/season overlay. Edge protection становится короче и слабее; в focus
mode исчезает. Тёмный iOS chrome сохраняет blur, но получает меньше specular и
shadow. Android остаётся opaque tonal.

### Controls и alternatives

- Date, celebration, cycle и global reader settings: context header/chrome +
  native sheet; в документе только краткое состояние.
- Hymn/antiphon/prayer alternatives: рядом с блоком.
- Trigger: `Гімн · 2 з 4`, `Антыфона · 2 з 3`, `Малітва · 2 з 2` + chevron.
  Accessible label включает полное активное имя.
- Sheet показывает полные wrapping titles, position subtitle, check и touch
  target не меньше 48 px. Короткие два варианта можно позже представить inline
  только по явно заданной семантике; длина строки сама по себе не должна менять
  interaction pattern.

## 3. План внедрения

1. Ввести честный reader font contract и системный platform UI font.
2. Провести typography roles через HTML/plain renderers и сузить tablet column.
3. Уточнить light/dark tokens; успокоить reader edge/effect stack.
4. Унифицировать alternatives trigger/sheet.
5. Проверить и при необходимости вынести оставшиеся document-level controls.
6. Bundle selected fonts для гарантированного offline reader.
7. Visual/device QA и accessibility pass.

## 4. Матрица проверки

Android/iOS × Light/Dark: Hours, Readings, Prayer, Bible, multiple/long-name
alternatives, Aa, cycle sheet, длинный заголовок. Для каждого: 320/390/700 px,
system text 100/180/200%, reader Aa min/default/max, fullscreen, wrapping,
bottom sheets и scroll end. Widget tests покрывают структуру и overflow;
blur/specular, реальные glyphs и subjective glare требуют device screenshots.
