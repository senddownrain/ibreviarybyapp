# Contextual Discovery — Этап 0: baseline

Только документация и evidence. Код приложения, Web/PWA, литургические данные и resolver не менялись. UI подсказок не добавлялся.

**Решение: `READY` для этапа 1 по навигации и коду, с оговоркой — Android native не проверен (NOT TESTED, см. ниже).**

## Версии и SHA

| Параметр | Значение |
|---|---|
| Репозиторий | senddownrain/ibreviarybyapp (Flutter) |
| `origin/main` = BASE SHA | `24f8d94ae29c66ae999abaf2990a5fa6ce566c5f` |
| Flutter / Dart | 3.41.4 (ff37bef603) / Dart 3.11.1 (`/Users/gleb/.cache/flutter-3.41.4/bin`) |
| `pubspec.yaml` | `sdk: ^3.11.1`, `flutter: >=3.41.4 <4.0.0`, version 1.0.0+6 |
| Состояние | Riverpod, Hive, go_router (без изменений) |
| iOS | iPhone 16 Simulator, iOS 18.6, debug |
| Android | AVD `MyBrev_Test_API34` (Android 14): **NOT TESTED** |

## Команды и результаты

Логи: `evidence/stage0/`.

| Команда | Результат |
|---|---|
| `flutter pub get --enforce-lockfile` | exit 0 |
| `dart format --output=none --set-exit-if-changed lib test` | **exit 1** — 10 файлов не отформатированы на чистом `main` (первый: `test/prayerbook_stage5_test.dart`). Существующее расхождение, не от этого PR; в этом PR форматирование не правилось, чтобы не смешивать с этапом. |
| `flutter analyze --no-fatal-infos` | exit 0, 12 info (`prefer_interpolation_to_compose_strings` в `lib/utils/pastors_hymn.dart`, `prefer_initializing_formals`, `unnecessary_string_interpolations`), 0 error / 0 warning |
| `flutter test --concurrency=1` (весь набор) | **exit 0: 1485 passed, 9 skipped, 0 failed** (`flutter-test-full.log`) |
| `flutter build ios --simulator --debug` | exit 0 |
| `flutter build apk --debug` | exit 0 (APK собран; установка и прогон не завершены, см. Android) |

Исторические «три падения» из PR #31 на этом HEAD **не воспроизвелись** (0 падений). Это не отменяет проверку на каждом следующем этапе.

### Запуск без production

Для debug-запуска нужен и `PRIEST_USE_EMULATORS=true`, и `FIREBASE_EMULATOR_HOST` (`localhost` для iOS Simulator, `10.0.2.2` для Android). Без хоста `lib/main.dart:36` бросает `StateError` и приложение остаётся на заставке (проверено: так и было при первой iOS-сборке). Эмулятор Firestore не требуется для открытия экранов.

```
flutter build ios --simulator --debug --dart-define=PRIEST_USE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=localhost
flutter build apk --debug --dart-define=PRIEST_USE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

## Навигационная схема (по `lib/router/router.dart`)

`StatefulShellRoute.indexedStack`, 4 ветки:

| Вкладка | Корень | Подмаршруты |
|---|---|---|
| Літургія | `/hours` | `picker` → `options`, `ordo` → `month`, `hora/:date/:dayId`, `ora/:date/:dayId/:type` |
| Чытанні | `/readings` | `reading/:readingId`, `picker` → `options`; `:dateStr` и `liturgical/...` — redirect на `/readings?...` |
| Малітоўнік | `/prayers` | `all`, `search`, `categories`, `songs` (`/prayers/songs`, `:id`), `compendium` (`part`/`node`/`topic`/`question`), `catechism`, `sacraments`, `prayer/...` |
| Біблія | `/bible` | `search` → `result`; `/bible/:version/:book/:chapter` |

Вне shell: `/settings`, `/about`, `/picker`, `/favorites`, `/my`.

## Реальные элементы и ключи (якоря для этапов 3–4)

| Элемент | Где | Ключ / текст |
|---|---|---|
| Календарь в Часах (иконка) | `app_shell.dart` | `hours-calendar-action` |
| Лист календаря | `liturgical_calendar_sheet.dart` | `compact-liturgical-calendar`, `liturgical-calendar-today`, `liturgical-calendar-picker` |
| Іншыя варыянты (Чытанні) | `readings_screen.dart` | `readings-options-action`, лист `readings-options-sheet` |
| Календарь внутри листа | `readings_screen.dart` | `readings-calendar-disclosure`, `readings-calendar-picker`, `readings-calendar-today` |
| Цикл A/B/C, I/II | `readings_screen.dart` | `readings-cycle-$cycle`, `readings-cycle-automatic`, `readings-cycle-metadata` |
| Варианты празднования | `readings_screen.dart` | `readings-celebration-<key>`, `readings-group-<key>` |
| Шрыфт (меню «…» → `Шрыфт`) | `app_overflow_menu.dart`, `text_scale_control.dart` | `text-scale-open` и др. |
| Чип `Перанос * †` | `text_scale_control.dart:238` | `text-scale-psalm-marker-break` |
| Чип `Па левым краі` | `text_scale_control.dart:258` | `text-scale-psalm-aligned-left` |

Важно для якорей: чипы псалмов (секция «Псальмодыя») есть в панели шрифта **только в экранах часов** (`showPsalmody`); в «Чытанні» панель шрифта содержит только размер.

## Реальный прогон на iOS Simulator (iPhone 16, iOS 18.6, debug, base `24f8d94`, дата устройства 31.10.2026)

Статус: **iOS PASS по сценарию этапа 0** (светлая тема; тёмная тема **не проверялась**).

| # | Действие | Результат | Снимок |
|---|---|---|---|
| 1 | Запуск → `Літургія гадзінаў`, 31 кастрычніка 2026 | экран открыт, подсказок нет | — |
| 2 | Иконка календаря → экран `Літургічны дзень` | открылся | `ios-02-hours-picker-today.png` |
| 3 | Дата → лист `Каляндар` → тап 28 | дата сменилась на 28 кастрычніка 2026, лист остался открыт | `ios-03-calendar-sheet.png` |
| 4 | `Гатова` → Back | экран с 28.10 (Св. Сымона і Юды), затем Часы с **той же датой 28.10** | `ios-04-picker-28oct-after-done.png`, `ios-14-back-to-hours.png` |
| 5 | Вкладка `Чытанні` | дата 28.10 сохранена, Эф 2, 19–22 | — |
| 6 | `Іншыя варыянты` → `Каляндар` | лист открыт, раскрывается календарь, выбор 28 подсвечен; для даты «іншых набораў чытанняў няма» | `ios-05-readings-options-sheet.png`, `ios-06-readings-calendar.png` |
| 7 | `Гатова` | возврат на Чытанні с той же датой | — |
| 8 | «…» → `Шрыфт` в Чытанні | панель: 100%, слайдер, **без** чипов псалмов | `ios-09-readings-font-panel.png` |
| 9 | Часы → `Ютрань` → «…» → `Шрыфт` | секция «Псальмодыя», видны оба чипа `Перанос * †` и `Па левым краі` | `ios-11-hour-overflow-menu.png`, `ios-12-hours-font-panel-chips.png` |
| 10 | Тап `Перанос * †` | чип выбран, `Па левым краі` остался невыбранным (независимы); затем возвращён | `ios-13-chip-break-on.png` |
| 11 | Закрыть панель → Back | Часы, дата 28.10 | `ios-14-back-to-hours.png` |

Замечания: (а) инструмент снимков показывает кадр с задержкой; тап по вкладке в одном кейсе сработал, а кадр был старым — это артефакт инструмента, не приложения. (б) Не проверено: смена епархии (по умолчанию показано «Дыяцэзіі · Мінск · Гродна»), переключение года A/B/C/I/II (на 28.10 циклов нет), персистентность чипов после перезапуска — это относится к этапам 1 и 4. (в) Тест «Back» выполнялся экранной кнопкой, жест свайпа не проверялся.

## Android — NOT TESTED

- `flutter build apk --debug` (с `FIREBASE_EMULATOR_HOST=10.0.2.2`) собрался успешно: `evidence/stage0/build-android.log`.
- Две более ранние попытки сборки упали из-за заполненного диска хоста (`build-android-attempt1-FAILED.log`, `build-android-attempt2-FAILED-disk-full.log`) — окружение, не код.
- `adb install`/`adb shell` на AVD `MyBrev_Test_API34` (emulator-5554) зависают без ответа (эмулятор виден как `device`, qemu запущен давно и грузит CPU, рядом работает второй AVD `analytics_test`). Приложение на Android **не запускалось**, снимков нет.
- Эмулятор принадлежит общему окружению нескольких сессий; перезапуск не выполнялся без согласования. Android должен быть проверен до этапа 7; для этапа 1 (документальный аудит) Android не блокирует.

## Конфликтующие и смежные PR

Открыты (на момент проверки): #49 (`claude/cd-stage1-audit`, этап 1 этого же пакета, только docs), #48/#47/#42 (QA seasonal Commons, docs/тесты), #28 (docs: запрет AI-текстов), #23, #21. Ни один из открытых PR не меняет `text_scale_control.dart`, `liturgical_calendar_sheet.dart`, `readings_screen.dart`, `router.dart` (проверка по `gh pr list … files`). PR #14/#19/#20/#26 слиты в `main`. Якоря этапов 3–4 строить на стабильном `main` можно.

## Доказанные блокеры

Нет. Нестабильности навигации, исчезающих/зависающих панелей или сброса даты/епархии на iOS не найдено. Единственный открытый пробел — Android native (NOT TESTED, причина — зависший эмулятор).

## Зависимости/риски для следующих этапов

| Что | Статус |
|---|---|
| Хук для якоря шрифта/чипов | `READY` (ключи выше); учесть, что чипы только в часах |
| Якорь «Іншыя варыянты»/календарь в Чытанні | `READY` |
| Android native QA | `NOT TESTED` — до этапа 7 |
| Форматирование (10 файлов) | pre-existing, отдельным PR |
