# Quiet Book — визуальная полировка, 10–11 октября 2026

Рабочая ветка `main`; существующие изменения доступа священников сохранены. При продолжении 11 октября визуальные изменения уже находились в HEAD `76d9b07` (`Refine quiet book reader and Ordo layout`). В этом продолжении уточняется Android-проверка и завершается отчёт.

## Изменения

- **A — reader:** `HourSwitcherPill` измеряет нижний край большого титула через прежний scroll controller и anchor. Это одно состояние управляет компактным названием и `ReaderEdgeProtection`. В начале верхняя защита прозрачна; после ухода титула за статусную область появляется название 17 px / 600 и защита цвета reader. Переход 200 мс, при disableAnimations — без анимации. Гистерезис 6 dp предотвращает переключения на границе. Название центрировано по экрану; высота вычисляется с system TextScaler и переносами. Скрытое управление исключено из hit testing и semantics. Прокручиваемый текст обрезается только в системной статусной области; геометрия прокрутки сохраняется.
- **Переход к молитве:** градиент позади contextual header плавно приходит к непрозрачному reader. Он не накладывается на текст. Начальный отступ текста часа уменьшен с 25 до 16 dp.
- **B — главные страницы:** общая дата 18 px / 600, нейтральный контраст; «Іншыя варыянты» 15 px / 600, touch target 48 dp. Сокращены интервалы; повторная мелкая метка «Літургія гадзінаў» над часами удалена. Выразительный день недели сохранён.
- **C — ORDO:** «Іншыя святкаванні дня» появляется только при других допустимых вариантах. Подавленные святкавания и коммеморации доступны внутри свёрнутых замечаний. Книги и сведения об Office свёрнуты. Пустые указания/замечания скрыты; повторный ранг «Нядзеля» убран у основного воскресенья. Действия «Літургія»/«Чытанні» имеют минимум 48 dp. Уменьшены промежутки между раскрываемыми разделами.
- **D — календарь:** выбранная дата получает более уверенную нейтральную тональную заливку и границу; сегодня вне выбора — тонкий второстепенный контур без заливки. При совпадении используется единая композиция выбранной даты. Цветные литургические маркеры сохранены.
- **E — регрессии:** селекторы, календарь по дате, общие диоцезии, маршруты и конец reader проверены существующими тестами. Смена часа заново вычисляет состояние заголовка.

## Библейская ссылка

В `assets/content/readings.json.gz`, документ `ordinary-w28-d1--A`, действительно записано `Мк 22, 1–10`. Заголовок того же Gospel: «Чытанне святога Евангелля паводле Мацвея»; текст — притча о свадебном пире. Это подтверждённое противоречие исходного документа, а не неверно прочитанный скриншот.

`ParsedReading.fromMap` исправляет только сочетание `Мк 22` и явного заголовка «паводле Мацвея» в поле Gospel. Диапазон стихов и текст сохраняются. Эта общая проекция используется Чтениями и `ReadingReferenceIndex`, поэтому ORDO получает `Мц 22, 1–10`. Исходный JSON сохраняется вместе со своими публикационными хешами. Правильные ссылки Марка остаются прежними.

Регрессионный тест проверяет исходную опечатку, правильный результат в четырёх диоцезиях, неизменность текста, порядок reading1/psalm/reading2/gospel и сохранение полного/краткого диапазона. На реальном ORDO проверены подписи «1 чыт.», «Пс», «2 чыт.», «Ев.» без повторного «Пс Пс».

## Файлы

Production:

- `lib/widgets/reader/hour_switcher_pill.dart`
- `lib/widgets/reader/reader_scaffold.dart`
- `lib/widgets/liturgical_day_header.dart`
- `lib/widgets/ordo/liturgical_month_calendar.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/ordo_screen.dart`
- `lib/models/parsed_reading.dart`

Проверки: `test/reader_foundation_test.dart`, `test/psalmody_navigation_test.dart`, `test/ordo_screen_test.dart`, `test/ordo_day_flow_test.dart`, `test/quiet_book_references_test.dart`, `integration_test/quiet_book_polish_test.dart`, `test_driver/quiet_book_driver.dart`, `test_driver/quiet_book_native_capture.py`.

## Проверки

Flutter 3.41.4 / Dart 3.11.1 соответствуют pubspec. Эмулятор `Pixel7_LiturgicalFinal`, Android 14 / API 34, `emulator-5654`, 720×1600, трёхкнопочная навигация.

116 уникальных адресных тестов прошли: 95 в `build/quiet-book-regressions.log` и 21 в `build/quiet-book-reader-final.log`. После уточнения отступов/календаря/ранга повторно прошли 76 проверок (`build/quiet-book-final-layout.log`); после обрезки статусной области — 19 reader/psalmody проверок (`build/quiet-book-chrome-verified.log`). Матрица включает Android/iOS, light/dark, узкие экраны и system200/Aa180.

Android integration-прогон завершился `All tests passed` (`build/quiet-book-native-final.log`). Финальный повтор после уточнения длинного названия и календарного сценария также прошёл: `04:25 +2: All tests passed!`, лог `build/quiet-book-native-completion.log`. Сохранены 29 настоящих Android-снимков с системными панелями в `audit-evidence/quiet-book-polish/`, плюс отдельный снимок обычного запуска. Для длинного названия часа при 200% прокрутка определяется по фактическому нижнему краю титула, после чего явно проверяется видимость компактного названия. Исходный system font scale `1.0` восстановлен и проверен через adb.

Визуально просмотрены light/dark: начало Ютрані, переход исчезновения большого титула, режим после прокрутки, селектор часа, конец часа, начало следующего часа, главная часов 11.10, чтения 09.10 и их селектор, ORDO 11.10 и 09.10, календарь с разными сегодня/выбранным днём. При 200% просмотрены календарь, начало/прокрутка/конец Ютрані. Ссылка Catholic.by и кнопка «Далей» доступны над нижним chrome и трёхкнопочной навигацией; наложения двух названий часа не обнаружено. В исходной серии кадров дата устройства — 10.10.2026, выбранная дата — 11.10.2026. При повторе 11 октября календарь выбирает 12 октября, сохраняя различие с «сегодня».

Обычный `flutter run --no-pub -d emulator-5654` успешно собрал и установил `lib/main.dart`, открыл реальный интерфейс главной Литургии часов. Снимок `main-normal-native.png` сделан через adb и визуально просмотрен; это уже интерфейс приложения после загрузки, не splash screen. Лог — `build/quiet-book-normal-run.log`. Повторный `flutter analyze --no-pub` — `No issues found!`, лог `build/quiet-book-analyze-completion.log`.

Просмотрены все пять финальных кадров при 200%. Длинное компактное «Малітва перад поўднем» переносится на три строки, не заходит на Back/Aa; верхняя защита учитывает эту высоту. Текст молитвы ниже остаётся читаемым. Анализ уточнённого integration-теста — `No issues found!` (`build/quiet-book-integration-analyze.log`). Подтверждённых визуальных блокеров в проверенных Android-сценариях не осталось.

Примеры снимков:

- [Начало Ютрані](../audit-evidence/quiet-book-polish/light-laudes-start-native.png), [после прокрутки](../audit-evidence/quiet-book-polish/light-laudes-scrolled-native.png), [граница перехода](../audit-evidence/quiet-book-polish/light-laudes-transition-native.png).
- [ORDO без альтернатив](../audit-evidence/quiet-book-polish/light-ordo-11-native.png), [с альтернативами](../audit-evidence/quiet-book-polish/light-ordo-9-native.png).
- [Конец часа, dark](../audit-evidence/quiet-book-polish/dark-laudes-end-native.png), [конец при 200%](../audit-evidence/quiet-book-polish/large-laudes-end-native.png).
- [Длинное название при 200%](../audit-evidence/quiet-book-polish/large-long-hour-title-native.png), [календарь при 200%](../audit-evidence/quiet-book-polish/large-calendar-today-selected-native.png).
- [Обычный запуск](../audit-evidence/quiet-book-polish/main-normal-native.png).

Для повторной съёмки сначала запустить `python test_driver/quiet_book_native_capture.py`, затем в другом терминале:

```powershell
flutter drive --no-pub -d emulator-5654 --driver=test_driver/quiet_book_driver.dart --target=integration_test/quiet_book_polish_test.dart
```

Захват идёт через `adb exec-out screencap -p` после отрисовки каждого экрана, включая системные панели. Скрипт повышает system font scale до 200% по маркеру теста и восстанавливает исходное значение.

iOS-style device preview отдельно не запускался; платформенная геометрия проверена widget-тестами. Native iOS этим не подтверждён. Во время Android-прогона существующий фоновый updater сообщал `PriestAccessException(SERVICE_UNAVAILABLE)`; готовый локальный литургический текст оставался доступен. Полный набор репозиторных тестов не запускался.

Агент не выполнял PR, commit, push, merge или deploy.
