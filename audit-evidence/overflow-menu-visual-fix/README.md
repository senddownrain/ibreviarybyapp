# Меню: визуальная проверка Flutter

13 октября 2026. Снимки получены рендером настоящих Flutter-виджетов на Windows. Это Android/iOS styling, а не физические устройства или нативный iOS Simulator. Для UI в тестах загружен Roboto из Flutter SDK; им также заменены недоступные на Windows Apple UI faces. Книжный шрифт применяется только к тексту документа.

[До исправления: Android styling, 320 dp, 200%](before/android-dark-320-200-off-off.png). Здесь UI уже sans-serif: воспроизводится разрыв «Інфармац / ыя».

| Styling | Тема | Экран / system scale | Меню | Меню | Нижняя панель |
|---|---|---|---|---|---|
| android | dark | 320 dp / 100% | [OFF/OFF](after/android-dark-320-100-off-off.png) | [ON/ON](after/android-dark-320-100-on-on.png) | [Шрыфт](after/android-dark-320-100-font.png) |
| android | dark | 320 dp / 200% | [OFF/OFF](after/android-dark-320-200-off-off.png) | [ON/ON](after/android-dark-320-200-on-on.png) | [Шрыфт](after/android-dark-320-200-font.png) |
| android | dark | 390 dp / 100% | [OFF/OFF](after/android-dark-390-100-off-off.png) | [ON/ON](after/android-dark-390-100-on-on.png) | [Шрыфт](after/android-dark-390-100-font.png) |
| android | light | 390 dp / 100% | [OFF/OFF](after/android-light-390-100-off-off.png) | [ON/ON](after/android-light-390-100-on-on.png) | [Шрыфт](after/android-light-390-100-font.png) |
| iOS | dark | 320 dp / 100% | [OFF/OFF](after/iOS-dark-320-100-off-off.png) | [ON/ON](after/iOS-dark-320-100-on-on.png) | [Шрыфт](after/iOS-dark-320-100-font.png) |
| iOS | dark | 320 dp / 200% | [OFF/OFF](after/iOS-dark-320-200-off-off.png) | [ON/ON](after/iOS-dark-320-200-on-on.png) | [Шрыфт](after/iOS-dark-320-200-font.png) |
| iOS | dark | 390 dp / 100% | [OFF/OFF](after/iOS-dark-390-100-off-off.png) | [ON/ON](after/iOS-dark-390-100-on-on.png) | [Шрыфт](after/iOS-dark-390-100-font.png) |
| iOS | light | 390 dp / 100% | [OFF/OFF](after/iOS-light-390-100-off-off.png) | [ON/ON](after/iOS-light-390-100-on-on.png) | [Шрыфт](after/iOS-light-390-100-font.png) |

[186 widget/regression tests](widget-tests.log) · [flutter analyze](analyze.log)

Повторение снимков:

```powershell
$env:OVERFLOW_MENU_IMAGES='1'
$env:OVERFLOW_VISUAL_STAGE='after'
flutter test --no-pub test/menu_visual_preview_test.dart
```

Для baseline before-теста использовался прежний AppOverflowMenu; текущий after-тест проверяет, что каждый целый токен подписи занимает одну строку, а при 100% вся подпись занимает одну строку. System text scaler не отключается.
