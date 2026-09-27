# Executive verdict

Исходный source audit выполнен на `b1537419add43e21ab83cd8559eca9130585d049`. Детерминированная проверка ниже начата на актуальном `main`, HEAD `8ed5b75`, 2026-09-27. Production layout refactor не выполнялся; добавлены только test infrastructure, testability scope для шрифтов и стабильные Keys без visual behavior change.

**Статус: source audit и deterministic Flutter layout matrix завершены; Android Emulator остаётся отдельным infrastructure blocker.** Результаты Layout Lab ниже заменяют прежние расчётные гипотезы там, где указаны `CONFIRMED`, `REJECTED` или `PARTIAL`.

Нынешняя система имеет три разных источника geometry: shell dock использует `viewPadding`; Prayer search использует максимум локальных `padding/viewPadding` с Android floor 48 dp; Bible/Readings helper использует максимум четырёх показателей с floor 56 dp. Локальный `padding` может уже включать app dock. Поэтому имя «system clearance» не гарантирует системный характер значения.

P1 overlap не обнаружен в измеренной матрице. P2 подтверждён: независимые floors 48/56 dp дают лишний gesture gap; Readings складывает shared reader padding и selection reserve; Bible использует другую reserve policy. Prayerbook baseline и Full/Compact/Hidden dock reserve работают корректно.

# Deterministic Layout Lab

Harness: `test/layout/android_layout_lab_test.dart`. Он использует `TargetPlatform.android`, production `PrayersScreen`, `PrayerCatalogScreen`, `ReadingsScreen`, `BibleChapterScreen`, `ReaderScaffold`, `ReaderContentSurface` и `AppNavigationDock`. Данные подаются локальными Riverpod/Hive fixtures; Firebase, сеть, Android SDK runtime, Emulator и ADB не используются. `ReaderTypographyScope` заменяет только загружаемые Google Fonts на bundled Flutter test font; production без этого scope не меняется.

Матрица задаёт через Flutter test view `physicalSize`, DPR 1, `padding`, `viewPadding`, `systemGestureInsets` и `viewInsets`: 390×840 и 320×720 dp, system visual inset 48 dp для измеренной 3-button конфигурации и 24 dp для измеренной gesture конфигурации. Эти значения — audit fixtures, не универсальные Android constants.

## Window inset и app dock reserve

| Viewport | Mode | Root View inset | Descendant viewPadding | Descendant padding | Dock top | Last item bottom | Gap | Scroll extent | Verdict |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| 390×840 | 3-button | 48 | 0 | 126 | 720 | 690 | 30 | 134 | CORRECT |
| 390×840 | gesture | 24 | 0 | 102 | 744 | 714 | 30 | 110 | CORRECT |
| 320×720 | 3-button | 48 | 0 | 126 | 600 | 570 | 30 | 346 | CORRECT |
| 320×720 | gesture | 24 | 0 | 102 | 624 | 594 | 30 | 322 | CORRECT |

30 dp = 24 dp intentional list breathing room + 6 dp top inset контейнера dock. `CONFIRMED`: внутри `Scaffold.extendBody` descendant `MediaQuery.padding.bottom` действительно равен app dock reserve (78 + system inset), а descendant `viewPadding.bottom` уже равен нулю. Прямой root `View.viewPadding` продолжает сообщать 24/48 dp. Поэтому эти величины нельзя использовать как взаимозаменяемые.

## Prayer search

| Mode | Keyboard closed gap | Keyboard open gap to IME | Classification |
|---|---:|---:|---|
| 3-button | 12 | 12 | CORRECT |
| gesture | 36 | 12 | TOO LOOSE closed; CORRECT with IME |

Результаты одинаковы на 390×840 и 320×720, dock остаётся внутри viewport. `CONFIRMED`: Android floor 48 создаёт лишние 24 dp в измеренной gesture конфигурации. `REJECTED` для tested tree: при открытой клавиатуре surface не поднимается дважды; `Scaffold` resize и bottom 12 дают ровно 12 dp над IME в обоих modes.

## Readings и Bible palettes

| Surface, 390×840 | Mode | Gap над system-safe top | Selection reserve | Gap от last meaningful content до palette top | Scroll extent | Classification |
|---|---|---:|---:|---:|---:|---|
| Readings | 3-button | 16 | 136 (`80 + 56`) | 96.4 | 1092 | DOUBLE RESERVE |
| Readings | gesture | 40 | 136 (`80 + 56`) | 72.4 | 1068 | DOUBLE RESERVE |
| Bible | 3-button | 16 | 72 | 32.4 | 4202.6 | INCONSISTENT |
| Bible | gesture | 40 | 72 | 8.4 | 4154.6 | INCONSISTENT |

Обе production palettes помещаются на 320×720 без horizontal overflow и сохраняют те же 16/40 dp safe gaps. `CONFIRMED`: общий floor 56 не различает navigation modes, поэтому gesture получает лишние 24 dp. `CONFIRMED`: Readings добавляет 136 dp selection reserve поверх shared `ReaderContentSurface` padding и создаёт измеримый двойной хвост. `CONFIRMED`: Bible не повторяет эту сумму, но fixed 72 даёт разные фактические хвосты 32.4/8.4 dp; policy между экранами и modes непоследовательна.

## Reader dock modes

| Mode | Descendant content padding | Last item bottom | Scroll extent | Verdict |
|---|---:|---:|---:|---|
| Full | 102 | 696 | 1105 | CORRECT |
| Compact | 94 | 704 | 1097 | CORRECT |
| Hidden | 0 | 798 | 943 | CORRECT |

`REJECTED`: Hidden не сохраняет reserve Full/Compact dock. Root View по-прежнему содержит 24 dp system inset, но nested reader body получает нулевой app dock padding, что и требуется для разделения понятий.

## Visual verdicts

Evidence хранится в `audit-evidence/layout-lab/`: paired search/readings/bible palette PNG, `dock-light.png`, `dock-dark.png`, `cycle-current.png` и `cycle-dark.png`.

- Dock: **SUBTLE SUPPORTING SURFACE**. Light и Dark подтверждают, что окрашена только system navigation strip; непосредственно за floating composition остаётся page background. Добавлять тяжёлый NavigationBar не нужно; cosmetic surface должен быть независим от geometry reserve.
- Cycle: **TEXTUALIZE**. В Light и Dark pill fill, radius и padding придают `Цыкл B` control-like вес, хотя это passive editorial metadata. Production appearance в этой задаче не изменялся.

## Доказанный production implementation plan

1. Ввести root-derived `systemBottomInset` (root `View` + gesture exclusion по `max`, без Android floors 48/56 и без descendant dock padding) и regression equivalence для старых production inputs.
2. Ввести единый `floatingControlAnchor`: 8–12 dp intentional gap над system/IME obstruction; Prayer search, Readings и Bible должны использовать один coordinate boundary без double lift.
3. Отделить `dockContentReserve` от system inset и сохранить уже доказанные значения/переходы Full, Compact и Hidden.
4. Заменить Readings `80 + helper` и Bible fixed `72` на reserve от реальной высоты active overlay за вычетом уже consumed viewport reserve; проверить последний meaningful element и scroll extent.
5. Отдельным cosmetic pass добавить subtle supporting surface за dock и textualize cycle metadata; geometry в этом шаге не менять.

# Android navigation modes tested

Этот раздел сохраняет историю hardware/emulator попытки. Таблица «не проверено визуально» ниже относится только к AVD runtime; deterministic Flutter evidence теперь приведён выше и не должно интерпретироваться как успешный emulator run.

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

**Deterministic measurement:** Prayer search gap = 12 dp, Readings/Bible palette gap = 16 dp. Prayerbook final item gap до dock surface = 30 dp. Overlap отсутствует в обеих ширинах. `CONFIRMED` для текущего widget tree.

# Gesture-navigation findings

**Deterministic measurement:** Prayer search gap = 36 dp, Readings/Bible palette gap = 40 dp при fixture system inset 24. Это `TOO LOOSE` и подтверждает overcompensation floors 48/56. Keyboard-open Prayer search остаётся на 12 dp над IME и не получает двойной подъём.

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
| Prayerbook root | `padding.bottom + 24` | CORRECT: 30 dp до dock surface на 320/390 и в обоих modes (24 content + 6 dock inset) |
| Hours root | `116 + viewPadding.bottom` | INCONSISTENT: fixed reserve независимо от dock mode |
| All Prayers/search | `104 + viewPadding.bottom` | INCONSISTENT: reserve не связан с measured search height |
| Category list без search dock | `120 + viewPadding.bottom` | INCONSISTENT: другой fixed reserve |
| Shared reader, Prayer detail, Ora, normal Bible/Readings | `ReaderContentSurface`: `42 + padding.bottom` | Использует shell reserve, но nested Scaffold boundary требует проверки |
| Readings selected | Дополнительно `80 + helper` внутри общего content padding | DOUBLE RESERVE подтверждён: 136 dp selection reserve, tail 96.4/72.4 dp |
| Bible selected | Дополнительно 72 внутри общего content padding | INCONSISTENT подтверждён: tail 32.4/8.4 dp |
| My Prayers list | `padding.bottom + 88`; FAB `padding.bottom` + Scaffold placement | Возможный повторный reserve; проверить последний row и FAB вместе |
| Settings | ListView padding 12, root `SecondaryPageScaffold` | Нет shell dock; system clearance требует runtime проверки |

42/72/80/88/104/116/120 не все ошибочны: среди них есть editorial breathing space, control height и reserve. Ошибка policy — отсутствие явного различия между этими ролями.

# Floating overlays

`ReaderScrollToTopControl` использует `padding.bottom + 16`, то есть потенциальный anchor над dock. Палитры используют helper + 8, Prayer search отдельный helper + 12. Это разные policies при одной задаче safe placement.

Palettes имеют horizontal margins 4 dp при width ≤340, иначе 12. Проверка 320 dp должна включать все color actions, close/clear и touch targets; отсутствие overflow нельзя вывести из одного screenshot другого размера.

# Prayer search

`_PrayerCatalogScreenState` запрашивает contextual bottom slot после первого frame; shell suppresses dock. Search доступен и в All Prayers. Это не отдельная permanent app navigation.

Keyboard closed: `max(local padding, local viewPadding, Android floor 48) + 12`. Keyboard open: bottom offset 12, manual system inset выключен; обычный Scaffold resize остаётся ответственным за IME. Search initially requests focus, поэтому закрытую клавиатуру нужно проверить отдельно.

Verdict: **hardcoded overcompensation + отдельная formula — CONFIRMED**. Closed gaps 12/36 dp. Keyboard-open double lift — `REJECTED` в tested tree: оба modes дают 12 dp над IME. Старый overlap до фикса по-прежнему не проверен.

Для парных screenshots записать system-nav top Y, search surface bottom Y, gap=(navTop−overlayBottom)/DPR, IME top Y, body bottom Y и root/local metrics. Сейчас фактический gap control не измерен ни в одном режиме.

# Readings palette

Bottom = helper + 8. Selection suppresses dock через `showContextualBottomBar`. После стабилизации должен остаться system anchor, но helper может видеть старый dock padding в переходе; transient jump — гипотеза, не finding runtime.

Selected content добавляет `80 + helper` поверх shared `42 + padding.bottom`. `DOUBLE RESERVE CONFIRMED`: selection reserve 136 dp и measured tail 96.4/72.4 dp. Options sheet не входил в этот Layout Lab и остаётся `PARTIAL`.

# Bible palette

Bottom = helper + 8; policy совпадает с Readings, content reserve отличается: 72 без system inset против `80 + helper`. Одинаковый visual anchor не означает одинаковый доступ к последнему meaningful element.

Production chapter fixture подтверждает доступность palette и bottom chapter navigation на 320/390. Fixed 72 создаёт tail 32.4 dp в 3-button и 8.4 dp в gesture: `INCONSISTENT`. Search-result route и cross-chapter transition не входили в этот Layout Lab и остаются `PARTIAL`.

# Dock supporting background

Widget tree **содержит strip**: `app-dock-system-navigation-strip`, высота `MediaQuery.viewPadding.bottom`, цвет `colorScheme.surface` с alpha 0.72. Это полоса **только в system inset** внизу Column; floating dock находится выше, в Expanded с padding top 6/bottom 8. Между dock и strip backing не нарисован. В Hidden весь widget исчезает.

Поэтому обещание «background returned» не доказывает наличие supporting surface за dock. Отсутствие отдельной подложки непосредственно за ним объясняется текущим tree; родительский content Scaffold не является доказанной причиной невидимости strip, поскольку dock — отдельный bottomNavigationBar shell.

**Visual verdict: SUBTLE SUPPORTING SURFACE.** Light/Dark golden подтверждают: strip существует только в system inset, а непосредственно за floating composition остаётся page background. BUG geometry не установлен. Не вводить тяжёлый Material NavigationBar и не компенсировать background большим padding.

# Chips / cycle / metadata language

- `readings-cycle-badge` (Readings header): **TEXTUALIZE**, подтверждено Light/Dark evidence. Pill radius 20, tinted fill alpha 0.10, padding 12/6 придаёт вторичной информации самостоятельный control-like вес. Сохранить `Цыкл A/B/C/I/II` спокойной строкой metadata.
- `readings-manual-cycle-marker`: **KEEP**; уже текст, muted labelMedium. Визуально проверить вес w700 и повтор cycle в двух строках; смысл ручного выбора сохранять.
- Legacy `reading_detail_screen.dart:108` Material `Chip`: **TEXTUALIZE**, если route достижим; не объявлять его увиденным на основном reader.
- Bible attribution: **KEEP**, текстовая metadata; translation action остаётся interactive.
- Prayer tag FilterChip: **KEEP** в фильтре, поскольку это выбор; passive tag pills оценивать отдельно после screenshots.

Psalm choir: только consistency/semantics/spacing; новые visible buttons, mode selector и permanent chip не предлагать.

# Visual paradigm inconsistencies

Максимум пять evidence-backed кандидатов:

1. Tinted cycle pill внутри editorial Readings header — TEXTUALIZE, P3, visual-confirmed.
2. Legacy Material cycle Chip — TEXTUALIZE при достижимости, P3.
3. Prayer search minimum 48 против palette minimum 56 — geometry inconsistency, P2.
4. Selected Readings content reserve против Bible 72 — geometry inconsistency, P2.
5. Supporting surface за dock против strip только в system inset — SUBTLE SUPPORTING SURFACE, P3, visual-confirmed.

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

**Подтверждённый batch:** helper `system_insets.dart`; Prayer search `_bottomSystemInset`/`_PrayerListPage`; Readings selected document; Bible selected document; shared ReaderContentSurface coordinate boundary. Prayerbook root служит baseline shell reserve. Options sheet, Hours, My Prayers и Settings остаются отдельными `PARTIAL` cases и не должны автоматически входить в первый refactor.

Косметика отдельно: Readings cycle treatment и dock supporting composition. Manual marker, interactive tag filters и choir semantics сохранить.

# Acceptance для следующего production batch

Deterministic acceptance: controls доступны на 320/390, единый gap над safe anchor, нет fixed three-button floor в gesture, нет лишнего Readings selection tail, Full/Compact/Hidden сохраняют измеренное разделение reserve, а background решается независимо от padding. Физический Android smoke test остаётся желательным после устранения infrastructure blocker, но больше не блокирует geometry implementation plan.
