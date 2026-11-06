# Марыйная тэма Flutter

Ветка `feat/marian-theme`, база актуального `main` — `6b74fbe07f949ad5ecc9027cc284471c26e43578`.
Работа началась на `7abba85`; принятый во время работы PR #64
включён fast-forward без конфликтов и без переписывания календарной навигации.
Web-референс: [MyBrev #191](https://github.com/senddownrain/mybrev/pull/191),
merge `3aa7ba0f5cd186922d67e4e5e18a980e287a030c`.
Проверены `src/constants/appearance.js`, `docs/marian-theme-visual-audit.md`
и утверждённые PNG `docs/marian-theme/audit/after/` этого коммита.

## Реализация

`AppThemePreference` отделяет выбор пользователя от Flutter `ThemeMode`:
«Сістэма», «Светлая», «Цёмная», «Марыйная». Последняя отображается через
`ThemeMode.light`; оба theme-slot содержат Марииную палитру. System сохраняет
разные light/dark slots и продолжает реагировать на яркость ОС.

В Hive сохранён существующий ключ `themeMode` и строковые значения. Старые
`system/light/dark` читаются напрямую: нет миграционной записи, нового адаптера,
удаления или пересоздания box. Неизвестное значение даёт System. Новый setter
сразу обновляет состояние и общий notifier, затем ожидает `put` и `flush`.
Только явный setter пишет тему; сохранение избранного или другого параметра
через устаревший ProviderContainer не может вернуть старую тему. Переключение
темы не сохраняет заново шрифты, категории или псалмодию.

`IbColors.marian` установлен как `ThemeExtension` вместе с `ColorScheme`.
`forBrightness()` остался fallback для чужого ThemeData, но больше не выбирает
production-палитру при сборке Марииной темы. `buildAppTheme` — прежняя фабрика
из `main.dart`, поднятая из вложенной функции без изменения геометрии компонентов;
её используют приложение и проверки. `ReaderTheme`, glass/chrome и остальные
виджеты получают цвета из темы, а не из глобальной настройки.

| Роль | Marian |
| --- | --- |
| Внешний фон | `#F4F8FC` |
| Непрозрачная бумага чтения | `#FBFDFF` |
| Обычная / поднятая поверхность | `#FFFFFF` |
| Вспомогательная / floating | `#E2EFF9` |
| Primary / secondary | `#244D78` / `#477DAA` |
| Ambient | `#A8CBE6` |
| Основной / вспомогательный текст | `#202D39` / `#52687A` |
| Рубрики | `#9B302A`, как в обычной светлой |

Белый на secondary даёт только 4,39:1: использован чёрный `onSecondary`, как в
Web. Для Marian `outline` непрозрачен для читаемости границ контролов.
Цвета литургических периодов, праздников и выделений стихов не изменялись.

## Градиенты и чтение

Сохранены `AmbientBackdrop`, `AmbientWash`, `GlassSurface`,
`AdaptiveChromeSurface` и функциональная защита краёв `ReaderEdgeProtection`.
Одна новая `ThemeExtension<GlassDecoration>` управляет интенсивностью через
существующие `GlassTokens`, без Marian-условий в отдельных виджетах.

| Токен | Light | Dark | Marian |
| --- | --- | --- | --- |
| Backdrop | 0,09 | 0,11 | 0,06 |
| Ambient strong | 0,11 | 0,15 | 0,0495 |
| Ambient mid / card | 0,045 | 0,06 | 0,02025 |
| Ambient soft | 0,055 | 0,07 | 0,02475 |
| Ambient pill | 0,065 | 0,08 | 0,02925 |

Это существующая Flutter-композиция с ослабленными заливками. CSS-градиенты,
веб-круги, размеры и формы Web не копировались. Android оставляет непрозрачные
тональные поверхности, iOS — существующее стекло с белой основой и blur.

`ReaderContentSurface` уже рисовал непрозрачный `ColoredBox` по всей ширине,
включая нижний резерв. `SliverFillRemaining` продолжает бумагу в конце.
`ReaderTheme.surface` теперь получает Marian paper из расширения;
верхний и нижний защитные градиенты переходят в тот же цвет. Сам reader layout,
литургические тексты, порядок секций, интервалы и типографика не изменены.

## Состояние и платформы

Удалён зависящий от темы `ValueKey` у `MaterialApp.router`. Постоянная граница
сохраняет существующий router, stateful branches, состояние чтения и открытые
панели. Production widget test проверяет тот же экземпляр OraScreen,
маршрут, scroll offset и открытую панель при всех четырёх переключениях.

Корневой `AnnotatedRegion<SystemUiOverlayStyle>` использует существующий стиль
активной темы и покрывает также экраны с плавающей навигацией без настоящего
AppBar. У Marian тёмные Android status/navigation icons и светлая iOS
status-bar brightness. Реальная работа системных панелей требует native smoke.

## Пересечения с открытыми PR

При начале работы просмотрены открытые PR, в том числе #62 (псалмодия),
#65 (источники и документы), #60 (литургический паритет). Код незавершённых
веток не переносился. База темы остаётся актуальным `main`.

Потенциальное текстовое пересечение с #62: `SettingsState`, `_load`, `_save`,
конструктор и `copyWith` в `settings_provider.dart`. При будущем объединении
сохранить новый `themePreference` и его отдельную запись `themeMode`, а также
новую модель и отдельные записи псалмодии из #62. Эта ветка не реализует и не
откатывает три новых режима #62: текущие на main `psalmVerseLayout` и
`psalmMarkerBreakMode`, их UI и данные оставлены без изменений.

## Проверки и ограничения

Результаты, снимки и воспроизведение — в
[визуальном отчёте](marian-theme-visual-audit.md) и
[`audit-evidence/marian-theme`](../audit-evidence/marian-theme/).

Firebase, production Firestore, content bundle, календарные алгоритмы,
навигационные маршруты и зависимости не менялись. Ни слияние PR, ни публикация приложения,
ни установка релизной сборки не выполнялись.

## Проверка потребителей темы

Поиск по `lib`, `test`, `integration_test` и `tool` охватил `ThemeMode`,
`Brightness`, `ColorScheme`, `ThemeExtension`, `IbColors` и прямые цвета.

| Область | Решение |
| --- | --- |
| Settings / controller / MaterialApp | Типизированный preference; Flutter brightness получается только на границе приложения |
| ReaderTheme, ReaderContentSurface, ReaderScaffold, header, footer | Семантический IbColors из расширения; начала, середины и концы на одной бумаге |
| Home / LiturgicalDayHeader / календарь | Chrome читает ColorScheme, литургические маркеры остаются от прежнего источника |
| Glass / AdaptiveChromeSurface | Общая интенсивность через расширение, прежнее разделение Material/Cupertino |
| Bible / Readings highlights и selection alpha | Яркость берётся из активной темы; Marian корректно считается светлой |
| Прямые цвета | Литургические палитры, rubric, выделения стихов, белый specular и чёрные тени сохранены по назначению; пропавшее чтение использует прежний нейтральный серый значок |
| Старые smoke-hosts | Явный выбор Light/Dark продолжает работать через совместимый `setThemeMode`; Marian проверяется новым production-app host |
| Нативные integration tests | Прямые обращения к общему контроллеру переведены на AppThemePreference; их запуск на устройствах не заявляется |

Снимок прежних ColorScheme/IbColors получен с `7abba85`; между ним и финальной
базой `6b74fbe` эти файлы, основной theme factory и reader не менялись.
