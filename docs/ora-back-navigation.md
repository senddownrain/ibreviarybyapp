# PR #22 — контракт Back при смене часа

## Причина

Стек списка дня не исчезал. Список открывает читалку через `push`, а выбор
«Змяніць гадзіну» открывает modal sheet на root Navigator. После закрытия
sheet root Navigator сообщает `NavigationNotification(canHandlePop: false)`.
Прежний `context.replace` сохранял ключ страницы часа: branch Navigator
переиспользовал маршрут и не восстанавливал итоговый флаг обработки Back.
Android переставал передавать Back Flutter и открывал Launcher, хотя
`hoursNavigatorKey.currentState.canPop()` оставался true.

Это воспроизведено адресным widget-тестом до исправления: обычный вызов
`handlePopRoute` проходил, но проверка последнего `canHandlePop` давала false.
Именно поэтому тест одного `pop` не обнаруживает дефект Android.

## Изменение и контракт

`OraScreen._openHour` использует существующий `pushReplacement`: другой час
получает новый ключ страницы, branch Navigator обновляет доступность Back.
Список дня остаётся под текущим часом. Новые экраны, роутеры, ручные вызовы
`SystemNavigator` и обработчики, специфичные для святого/Common, не добавлены.

В `BranchShellController.remove` удаление уже неактивной старой страницы
только очищает её состояние. Оно не активирует прежний root поверх нового
часа: при замене Navigator сначала добавляет новую страницу, затем удаляет
старую. Адресный тест закрепляет этот порядок и сохранение панели читалки.

Смена часа — **замена**, без истории посещённых часов. Системный Back и
экранная «Назад» выполняют один pop к списку выбранного дня. После любого
числа смен стек содержит две страницы: список и текущий час.
Существующее раскрытие скрытых элементов читалки при Back не меняется.

Для прямой ссылки `HoursDateContext` получает не только дату, но и dayId /
диоцез из маршрута. Читалка и родительский список теперь используют один
выбранный контекст даже без предыдущего посещения списка. Настройки
пользователя при этом не перезаписываются.

Common assembly, Proper/Psalter, тексты, ранг, набор часов, picker, Firestore
и content manifest не изменены.

## Проверки

- `test/ora_back_navigation_test.dart`: 12 адресных widget/navigation случаев
  на production router и локальном bundle. Прямой вход и замены, несколько
  последовательных смен, оба Back, прямые URL без предыдущего посещения,
  Common и query context, настройки, глубина стека и финальный флаг
  `NavigationNotification` для Android. Два контекста: 19.10.2026 / Павел
  Креста religious / Минск-Могилёв и 20.10.2026 / будний день / Пинск.
- Итоговый последовательный прогон — **54 теста прошли**: 12 адресных,
  7 shell state (включая новый тест удаления неактивной страницы), 35
  регрессионных: reader routes, StatefulShell, архитектура router,
  восстановление shell, Hours root, Common/date/diocese/cache.
- `dart format`; полный `flutter analyze --no-pub` — No issues found;
  после последней правки shell повторный анализ всех пяти затронутых Dart
  файлов — No issues found. Debug build — успешно (114.1 s).

Команда итогового тестового прогона:

```powershell
flutter test --no-pub --concurrency=1 --timeout 2m test/ora_back_navigation_test.dart test/app_shell_state_test.dart test/reader_navigation_test.dart test/stateful_shell_navigation_test.dart test/router_architecture_test.dart test/app_shell_restoration_test.dart test/hours_root_test.dart test/common_office_test.dart
```

## Повторный Android native smoke — прошёл

Использован существующий `MyBrev_Test_API34`, новых AVD не создавали.
Дождались полного boot, установили окончательный `lib/main.dart` debug APK
через `adb install -r`. SHA-256:
`6849e3c3f80228ef5f3597a8b0db96a62281ccdddf0626f2f5b8f1114bbabb19`.

Проверены 19.10.2026 / Павел Креста / «Пра законнікаў», без сети:

1. Список → Ютрань → `adb shell input keyevent 4` → тот же список дня.
2. Список → Агульная гадзіна → Нешпары через picker → тот же ADB Back →
   список 19 октября; top resumed Activity осталась MyBrev, не Launcher.
3. Список → Ютрань → Нешпары → ADB Back → тот же список.
4. Список → Ютрань → Нешпары → Гадзіна чытанняў → Ютрань → экранная
   «Назад» → тот же список одним шагом. История часов не накапливается.
5. Picker после возврата подтвердил checked religious. Настройки сохранили
   тёмную тему и 180%; у новой читалки нет лишней панели списка дня.

Прямой URL и второй контекст даты/диоцеза проверены адресными widget-тестами,
не объявляются отдельным native deep-link smoke. При полном старте эмулятора
был ANR Android System UI; он перезапущен до навигационных проверок.
`am start -W` на прогреве дал timeout; фактическую готовность приложения
подтвердили стабильным UIAutomator-экраном. В сохранённом AndroidRuntime/flutter
error log ошибок приложения нет. После проверок выполнен `adb emu kill`,
`adb devices` пуст; AVD сохранён и остаётся в `emulator -list-avds`.

Три настоящих PNG просмотрены:

- [Нешпары после замены часа](../audit-evidence/ora-back-navigation/android-01-switched-vespers.png).
- [Список выбранного дня после системного Back](../audit-evidence/ora-back-navigation/android-02-system-back-day.png).
- [Сохранённый Common после обоих Back](../audit-evidence/ora-back-navigation/android-03-common-retained.png).

UI evidence и параметры APK: `android-*.xml`, `android-result.json`.
Это повторный проход только навигации; исходные проверки литургических
текстов и обновления старого APK сохранены в предыдущем отчёте.

## Chrome visual smoke изменённой навигации — прошёл

После `flutter devices` запущен один Google Chrome через
`flutter run -d chrome -t tool/common_office_smoke.dart --web-port 5238`.
Точная вкладка `http://localhost:5238/` проверена через CDP именно этого
экземпляра (отдельный профиль Flutter, порт CDP 49736). CDP-сессия сохранялась
на время действий; включена эмуляция фокуса для occluded вкладки и viewport
411×915. Иначе Windows скрывал вкладку и приостанавливал её кадры.

На production screens/router и локальном bundle без Firebase проверены:
Павел Креста religious → Ютрань → picker → Нешпары → экранная Back → тот же
день; светлая тема 100%; тёмная 180%, прокрутка и возврат вверх; ссылка
«Чытанні» → «Вярнуцца да Ora» → Back к дню с сохранением контекста.
Настоящие `chrome-01…04*.png` сохранены и просмотрены: мобильный список,
светлая утреня, вечерня после замены и тёмная утреня с крупным шрифтом при
прокрутке. Переносы текста и доступность контролов проверены визуально.

Этот проход закрывает Chrome smoke **навигационной правки**. Он не объявляет
завершённой всю прежнюю визуальную матрицу Common (три варианта × все часы).
Браузерный Back не выдаётся за системный Android Back: последний проверен
отдельно ADB на нативном APK. iOS/release/store smoke не выполнялся.

Логи и повторный visual/native smoke: `audit-evidence/ora-back-navigation/`.
