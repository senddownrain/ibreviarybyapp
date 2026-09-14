# Executive verdict

Аудируемый source HEAD: `b1537419add43e21ab83cd8559eca9130585d049`, ветка `main`, 2026-09-14. Аудит read-only: implementation не выполнялся.

**Статус: аудит исходников завершён, обязательная visual matrix пока не подтверждена.** Не считать этот документ разрешением на implementation без парных Android прогонов. Наблюдения, расчёты из кода и непроверенные гипотезы явно разделены ниже.

Нынешняя система имеет три разных источника geometry: shell dock использует `viewPadding`; Prayer search использует максимум локальных `padding/viewPadding` с Android floor 48 dp; Bible/Readings helper использует максимум четырёх показателей с floor 56 dp. Локальный `padding` может уже включать app dock. Поэтому имя «system clearance» не гарантирует системный характер значения.

P1 overlap не подтверждён. P2: независимые floors 48/56 dp и смешение dock reserve с system inset. Величина реального пользовательского gap требует визуального прогона.

# Android navigation modes tested

Среда: AVD `Pixel_5_API_34`, `sdk_gphone64_x86_64`, Android API 34, x86_64. Flutter 3.41.4 / Dart 3.11.1. Собран debug APK текущих исходников и установлен через `adb install -r`, пользовательские данные не очищались.

SDK при сборке использовал локально разрешённые версии зависимостей, отличающиеся от HEAD lockfile. Diff сохранён в `audit-evidence/android-layout/build-dependency-resolution.diff`; lockfile восстановлен к состоянию до сборки. Поэтому это source-HEAD build с указанным отличием зависимостей, а не воспроизводимая сборка точного lockfile.

Настроен viewport 780 × 1680 physical px при density 320: 390 × 840 dp. Исходная конфигурация — 1080 × 2340, density 440.

`3-button`: реально включён системный overlay `com.android.internal.systemui.navbar.threebutton`; Back/Home/Recents видны на сохранённых кадрах. WindowManager сообщил navigation bar frame `[0,1584][780,1680]`: 96 physical px = 48 dp. Это измерение ОС, не Flutter runtime metrics.

`gesture`: реально включён через Android Settings → Navigation mode. Overlay `com.android.internal.systemui.navbar.gestural` активен, `threebutton` отключён; radio selection сохранён в `navigation-mode-confirm-gesture.png`. В foreground окне приложения WindowManager сообщил bar frame `[0,1632][780,1680]`: 48 physical px = **24 dp**. Gesture handle виден в `final-attempt-gesture.png`. Старые windows в том же dumpsys ещё содержали frame 96 px; они не использованы как gesture measurement.

Приложение оставалось на splash; Android Settings и System UI также выдавали ANR. Выполнены reboot и cold boot без snapshot с software GPU, проблема повторилась. Кадры splash/Settings/ANR — evidence режима ОС и состояния среды, **не evidence работоспособности экранов**. Причина зависания приложения не установлена; не приписывать её inset helper или Firebase без диагностики.

| Обязательный case | 3-button | gesture |
|---|---|---|
| Prayerbook root, самый низ | Не проверено визуально | Не проверено |
| All Prayers, search, results, keyboard closed/open | Не проверено визуально | Не проверено |
| Prayer detail, My Prayers FAB | Не проверено визуально | Не проверено |
| Readings normal/bottom/palette/options/manual cycle | Не проверено визуально | Не проверено |
| Bible normal/bottom/palette | Не проверено визуально | Не проверено |
| Hours root, Ora long document, Full/Compact/Hidden | Не проверено визуально | Не проверено |
| Settings bottom/input | Не проверено визуально | Не проверено |
| 320 × ~720 dp, Light/Dark | Не проверено | Не проверено |
| 390 × ~840 dp, Light/Dark | Размер ОС установлен; visual QA не пройден | Не проверено |

# 3-button findings

**Наблюдение ОС:** system bar 48 dp в выбранной конфигурации. Оно не доказывает, что nested Flutter context сообщает тот же inset.

**Расчёт, не screenshot measurement:** при full-window overlay anchor и reported inset 48 dp Prayer search bottom offset = 60 dp, gap над bar = 12 dp. Палитры при reported максимум 48 dp имеют bottom offset 64 dp, gap = 16 dp (8 dp intentional + 8 dp floor). Если body уже заканчивается над system bar, такой расчёт неприменим: manual inset повторно поднимет control.

# Gesture-navigation findings

Визуального verdict controls нет. **Измеренное различие ОС:** visual nav region 24 dp в gesture против 48 dp в 3-button. При full-window body Prayer search и локальном reported ≤48 сохраняет gap `60 − S`; палитры при всех reported значениях ниже 56 сохраняют gap `64 − S`. Для измеренного visual `S = 24 dp` это даёт **расчётные**, не наблюдённые gaps 36 и 40 dp. Root Flutter gesture input exclusion может отличаться от visual bar и не измерен. Floor не различает navigation modes, поэтому overcompensation присутствует в формуле независимо от модели устройства.

# Why current inset behavior diverges

1. `lib/utils/system_insets.dart:10`: максимум `MediaQuery.padding`, `viewPadding`, `systemGestureInsets` и прямого `View.viewPadding / DPR`, затем `max(..., 56)`. Это максимум, **не сумма**: сам helper не складывает четыре insets.
2. `lib/widgets/app_shell.dart:134`: `Scaffold.extendBody: true`. В локальном Flutter SDK `_BodyBuilder` устанавливает body padding bottom как максимум исходного padding и `bottomWidgetsHeight`. Следовательно, `MediaQuery.padding.bottom` внутри shell — потенциальный **dock reserve**, не только system inset.
3. `lib/screens/prayers_screen.dart:805`: независимый helper, floor 48, без прямого View и gesture metrics. Дублирование policy с другой константой.
4. `SafeArea` физически сдвигает ребёнка и меняет MediaQuery descendants. Поэтому нулевой локальный padding не означает отсутствие system UI. Прямой View даёт window geometry, но не сообщает, сколько родитель уже зарезервировал.
5. Nested Scaffold может менять доступную высоту, padding и IME consumption. Добавлять raw window inset к координатам уже ограниченного body нельзя без проверки boundary.

Документация подтверждает изменение descendant padding в [SafeArea](https://api.flutter.dev/flutter/widgets/SafeArea-class.html), независимость [viewPadding от клавиатуры](https://api.flutter.dev/flutter/widgets/MediaQueryData/viewPadding.html) и назначение [systemGestureInsets для input gestures](https://api.flutter.dev/flutter/widgets/MediaQueryData/systemGestureInsets.html). Gesture-safe input area и окрашенная system strip — разные geometry.

# Bottom content clearance

Классификации ниже относятся к **статической policy**, а не к наблюдённым последним элементам.

| Экран | Текущая формула | Verdict по коду |
|---|---|---|
| Prayerbook root | `padding.bottom + 24` | Согласуется с shell reserve; CORRECT требует visual QA |
| Hours root | `116 + viewPadding.bottom` | INCONSISTENT: fixed reserve независимо от dock mode |
| All Prayers/search | `104 + viewPadding.bottom` | INCONSISTENT: reserve не связан с measured search height |
| Category list без search dock | `120 + viewPadding.bottom` | INCONSISTENT: другой fixed reserve |
| Shared reader, Prayer detail, Ora, normal Bible/Readings | `ReaderContentSurface`: `42 + padding.bottom` | Использует shell reserve, но nested Scaffold boundary требует проверки |
| Readings selected | Дополнительно `80 + helper` внутри общего content padding | TOO MUCH SPACE — риск cumulative reserve; не называть доказанным DOUBLE INSET |
| Bible selected | Дополнительно 72 внутри общего content padding | INCONSISTENT с Readings и реальной высотой palette |
| My Prayers list | `padding.bottom + 88`; FAB `padding.bottom` + Scaffold placement | Возможный повторный reserve; проверить последний row и FAB вместе |
| Settings | ListView padding 12, root `SecondaryPageScaffold` | Нет shell dock; system clearance требует runtime проверки |

42/72/80/88/104/116/120 не все ошибочны: среди них есть editorial breathing space, control height и reserve. Ошибка policy — отсутствие явного различия между этими ролями.

# Floating overlays

`ReaderScrollToTopControl` использует `padding.bottom + 16`, то есть потенциальный anchor над dock. Палитры используют helper + 8, Prayer search отдельный helper + 12. Это разные policies при одной задаче safe placement.

Palettes имеют horizontal margins 4 dp при width ≤340, иначе 12. Проверка 320 dp должна включать все color actions, close/clear и touch targets; отсутствие overflow нельзя вывести из одного screenshot другого размера.

# Prayer search

`_PrayerCatalogScreenState` запрашивает contextual bottom slot после первого frame; shell suppresses dock. Search доступен и в All Prayers. Это не отдельная permanent app navigation.

Keyboard closed: `max(local padding, local viewPadding, Android floor 48) + 12`. Keyboard open: bottom offset 12, manual system inset выключен; обычный Scaffold resize остаётся ответственным за IME. Search initially requests focus, поэтому закрытую клавиатуру нужно проверить отдельно.

Verdict по коду: **hardcoded overcompensation + отдельная formula**. Double inset возможен только при уже consumed body geometry; пока не воспроизведён. Старый overlap до фикса не проверен: audit текущего HEAD не даёт evidence прежнего состояния.

Для парных screenshots записать system-nav top Y, search surface bottom Y, gap=(navTop−overlayBottom)/DPR, IME top Y, body bottom Y и root/local metrics. Сейчас фактический gap control не измерен ни в одном режиме.

# Readings palette

Bottom = helper + 8. Selection suppresses dock через `showContextualBottomBar`. После стабилизации должен остаться system anchor, но helper может видеть старый dock padding в переходе; transient jump — гипотеза, не finding runtime.

Selected content добавляет `80 + helper` поверх shared `42 + padding.bottom`. Это главный case проверки чрезмерного хвоста в gesture. Options sheet использует `24 + helper` и требует отдельного route-boundary анализа.

# Bible palette

Bottom = helper + 8; policy совпадает с Readings, content reserve отличается: 72 без system inset против `80 + helper`. Одинаковый visual anchor не означает одинаковый доступ к последнему meaningful element.

Проверить normal/search-result route, selection open/close, bottom chapter navigation и предыдущий/следующий chapter. Ни один control не считать accessible только по наличию padding в коде.

# Dock supporting background

Widget tree **содержит strip**: `app-dock-system-navigation-strip`, высота `MediaQuery.viewPadding.bottom`, цвет `colorScheme.surface` с alpha 0.72. Это полоса **только в system inset** внизу Column; floating dock находится выше, в Expanded с padding top 6/bottom 8. Между dock и strip backing не нарисован. В Hidden весь widget исчезает.

Поэтому обещание «background returned» не доказывает наличие supporting surface за dock. Отсутствие отдельной подложки непосредственно за ним объясняется текущим tree; родительский content Scaffold не является доказанной причиной невидимости strip, поскольку dock — отдельный bottomNavigationBar shell.

**Предварительный design verdict: SUBTLE SUPPORTING SURFACE.** Слабое основание за нижним floating composition допустимо отдельно от system-safe geometry. Runtime Light/Dark не получен, поэтому verdict нельзя выдавать за визуально подтверждённый. BUG не установлен: strip предусмотрен и может быть похож на content либо иметь нулевую высоту. Не вводить тяжёлый Material NavigationBar и не компенсировать background большим padding.

# Chips / cycle / metadata language

- `readings-cycle-badge` (Readings header): **TEXTUALIZE**, предварительно по tree. Pill radius 20, tinted fill alpha 0.10, padding 12/6 придаёт вторичной информации самостоятельный control-like вес. Сохранить `Цыкл A/B/C/I/II` спокойной строкой metadata.
- `readings-manual-cycle-marker`: **KEEP**; уже текст, muted labelMedium. Визуально проверить вес w700 и повтор cycle в двух строках; смысл ручного выбора сохранять.
- Legacy `reading_detail_screen.dart:108` Material `Chip`: **TEXTUALIZE**, если route достижим; не объявлять его увиденным на основном reader.
- Bible attribution: **KEEP**, текстовая metadata; translation action остаётся interactive.
- Prayer tag FilterChip: **KEEP** в фильтре, поскольку это выбор; passive tag pills оценивать отдельно после screenshots.

Psalm choir: только consistency/semantics/spacing; новые visible buttons, mode selector и permanent chip не предлагать.

# Visual paradigm inconsistencies

Максимум пять кандидатов, **не screenshot-confirmed findings**:

1. Tinted cycle pill внутри editorial Readings header — TEXTUALIZE, P3.
2. Legacy Material cycle Chip — TEXTUALIZE при достижимости, P3.
3. Prayer search minimum 48 против palette minimum 56 — geometry inconsistency, P2.
4. Selected Readings content reserve против Bible 72 — geometry inconsistency, P2.
5. Ожидаемая supporting surface за dock против strip только в system inset — проверить визуально; предварительно SUBTLE SUPPORTING SURFACE, P3.

# Proposed unified layout rules

Source of truth: минимальная existing boundary **AppShell/root window**, до изменяющих padding Scaffold/SafeArea. Для secondary root routes та же window policy должна быть доступна выше shell, например inherited metrics на app boundary. Не глобальный singleton и не угадывание по nested zero.

Три semantic spacing concepts: `systemBottomInset`, `floatingControlGap`, `dockContentReserve`. Высота текущего control/IME и уже consumed geometry — измерения, не дополнительные spacing constants. Editorial text padding остаётся editorial padding.

## Rule 1 — system inset

Window `View.viewPadding.bottom / devicePixelRatio` — base system visual safe bottom; для interactive overlay дополнительно учесть root bottom gesture input exclusion через максимум, не сумму. Не включать descendant `MediaQuery.padding`, содержащий app dock. Обновлять при смене navigation mode, rotation и window metrics. Нулевой raw inset исследовать как platform issue; не заменять все Android configurations floor 56.

## Rule 2 — floating controls

Intentional gap = 8 dp над безопасным anchor для всех temporary controls, предварительный design target для paired QA. При IME anchor — его верхняя граница. Использовать максимум системной/IME obstruction, не сумму; если Scaffold уже уменьшил body на IME, выразить тот же screen-space anchor в body coordinates и не добавить IME повторно.

## Rule 3 — dock

`dockContentReserve` — расстояние от window bottom до верхней границы реально показанного floating dock. Оно включает system-safe region, gap и измеренную высоту dock ровно один раз. Full и Compact дают разные reserve; Hidden — нулевую добавочную высоту dock. Supporting background не участвует в расчёте reserve.

## Rule 4 — scrollable content

Последний meaningful element должен выводиться выше верхней границы активного bottom obstruction плюс спокойный content gap. Вычислить total reserve по window geometry, затем вычесть уже consumed viewport reserve. Не суммировать системный inset, shell padding и control reserve, если они описывают одну область. Проверить max scroll, а не только middle screen.

## Rule 5 — temporary palettes

Bible, Readings и Prayer search используют один safe anchor из Rule 2. Они заменяют dock в contextual slot. Content reserve рассчитывается по реальной высоте активного control; selection добавляет лишь недостающий reserve относительно уже существующего. Keyboard при palette без input не является обязательным нормальным состоянием: проверить переход из input/search и dismiss IME.

# Exact screens to fix

**Кандидаты для Sol после завершения paired QA:** helper `system_insets.dart`; Prayer search `_bottomSystemInset`/`_PrayerListPage`; Readings selected document и options sheet; Bible selected document; shared ReaderContentSurface и scroll-to-top; Hours root fixed 116; My Prayers FAB/list. Prayerbook root служит baseline shell reserve. Settings — root-boundary verification, не автоматически подтверждённая ошибка.

Косметика отдельно: Readings cycle treatment и dock supporting composition, после Light/Dark evidence. Manual marker, interactive tag filters и choir semantics сохранить.

# Recommended Sol implementation batch

1. Завершить обе системные navigation-mode матрицы на 320/390 dp, сохранить paired screenshots для Prayer search keyboard closed/open, обеих palettes, Prayerbook root bottom и dock area Light/Dark. Записать raw/local metrics и consumed body bounds без изменения production logic.
2. Зафиксировать inherited root metrics и coordinate boundary; заменить независимые floors/локальные system helpers единым rule, проверить contextual slot transition и IME.
3. Подвязать content reserve к измеренной активной нижней surface, проверить последние elements и Full/Compact/Hidden. Cosmetic supporting surface/cycle — отдельная часть после geometry.

Acceptance: оба режима фактически включены; controls доступны, единый gap над safe anchor, нет fixed three-button floor в gesture, нет лишнего selection tail, background решён независимо от padding. Пока нет runtime evidence, не повышать severity до P1 и не отмечать audit complete.
