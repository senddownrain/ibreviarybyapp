# Адаптивное меню — Flutter widget screenshots

14 октября 2026. Реальные растровые снимки Flutter widget harness, без эмулятора и генерации изображений. Compact использует календарный AdaptiveAppBar и AmbientWash; Ora — ReaderScaffold. Это проверка общего chrome, а не снимки календарных данных. На Windows Roboto подставлен вместо недоступных Apple system fonts; Cupertino switches и проектная GlassSurface настоящие Flutter widgets. Нативный Liquid Glass не используется.

32 снимка: два размера/масштаба, обе темы, Android/iOS styling; для Ora OFF/OFF, ON/ON и отдельная панель Шрыфт.

| Styling / тема | Compact 390 / 100% | Ora 390 / 100% | Compact 320 / 200% | Ora 320 / 200% |
| --- | --- | --- | --- | --- |
| Android light | [Меню](after/compact-android-light-390-100-menu.png) | [Меню](after/ora-android-light-390-100-off-off.png) | [Меню](after/compact-android-light-320-200-menu.png) | [Меню](after/ora-android-light-320-200-off-off.png) |
| Android dark | [Меню](after/compact-android-dark-390-100-menu.png) | [Меню](after/ora-android-dark-390-100-off-off.png) | [Меню](after/compact-android-dark-320-200-menu.png) | [Меню](after/ora-android-dark-320-200-off-off.png) |
| iOS light | [Меню](after/compact-iOS-light-390-100-menu.png) | [Меню](after/ora-iOS-light-390-100-off-off.png) | [Меню](after/compact-iOS-light-320-200-menu.png) | [Меню](after/ora-iOS-light-320-200-off-off.png) |
| iOS dark | [Меню](after/compact-iOS-dark-390-100-menu.png) | [Меню](after/ora-iOS-dark-390-100-off-off.png) | [Меню](after/compact-iOS-dark-320-200-menu.png) | [Меню](after/ora-iOS-dark-320-200-off-off.png) |

Соседние файлы `*-on-on.png` и `*-font.png` показывают включённые независимые переключатели и панель размера. [Все снимки](after).

Повторение: `$env:OVERFLOW_MENU_IMAGES='1'`, затем `flutter test --no-pub --concurrency=1 test/menu_visual_preview_test.dart --reporter expanded`. Результат: `build/overflow-menu-adaptive/after`.

Логи итоговых прогонов: [визуальные](visual-tests.log), [компонент](component-tests.log), [регрессии](regression-tests.log), [анализатор](analyze.log).
