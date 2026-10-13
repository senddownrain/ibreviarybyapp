# Выборочная интеграция брендинга в Flutter main

Дата: 13 октября 2026. Репозиторий: `senddownrain/ibreviarybyapp`.

## Основание и границы

Начальная база интеграции: `origin/main`
`e2643a4b43a3ed86e64b922224b730e156f65404`.
Во время проверки `main` обновился до
`4872f04f5d1d81235bcffa7c7533b5a8ba481dac` (обновления Lektionary/Ordo,
контента и тестов). Его изменения включаются обычным merge из `origin/main`
в интеграционную ветку, без переписывания опубликованной истории.
Merge commit интеграционной ветки: `326f6db6b4f714c114c0e212005ab46554803cd3`.
Проверки итогового дерева повторены; результаты ниже отличены от начальных.
Источник выбранных файлов: `origin/codex/malitounik-brand-icons`,
`b7e4f3ea531722e20cd9e1de3dcfd4b8bbd10ba3`.
Ветка: `codex/integrate-malitounik-brand`; отдельный managed worktree.
Исходная рабочая ветка владельца не переключалась и не очищалась.
Merge исходной ветки и cherry-pick её коммитов не применялись.

Классификация до переноса:

- **Брендовые:** Android launcher/adaptive/monochrome и launch resources;
  iOS AppIcon/LaunchImage/LaunchBackground/storyboard; Flutter Web runner
  icons/manifest/HTML; исходник, экспорты, генераторы и компактные свидетельства.
- **Посторонние, исключены:** priest access, Firebase Spark, backup rules,
  эмуляторные Firebase-конфигурации, Dart-код и контент, молитвы, Ordo,
  зависимости, release workflow и чужие документация/тесты.
- **Проверены отдельно:** изменения AndroidManifest/Gradle относятся к
  Firebase/backup и не требуются для иконки; они исключены. Splash-фоны
  совпадают с текущим `IbColors.page`. iOS workflow изолирован; его триггеры
  дополнены PR/main/integration branch, без доступа к секретам и release jobs.
  Web metadata меняет только брендовые названия и цвета внутри Flutter repo.

Полный перечень файлов diff: [integration-files.txt](integration-files.txt).
Native `MyBrev Test`, app IDs, signing, версии, Firebase configs,
литургическая цветовая система и пользовательская функциональность сохранены.

## Оригинал и ресурсы

Канонический `branding/source/approved-icon.png`, 1254×1254:
SHA256 `fa8ac6990b67f4a48e5907d00c86aa7306fb44921f079dd5bc92c7bba682a294`.
Байты исходника совпадают с исходной брендовой веткой. Перерисовки нет.

`tools/audit_brand_assets.py`: проверены 38 PNG экспортов, 19 слотов AppIcon
(15 PNG файлов), RGB без alpha, XML/JSON/SVG подключений, adaptive foreground 432×432 с bbox
`(86,86,346,346)` внутри safe zone, прозрачные monochrome cutouts и maskable
safe zone. Детерминированная регенерация resvg 2.6.2 + Pillow 11.3.0
оставила все SHA256 экспортов и manifest неизменными, включая совпадение
с исходной веткой. Размеры 32/48/60 px и themed silhouette визуально
проверены в `export-preview.png`; рисунок не менялся.

## Начальные проверки интеграционной ветки (база e2643a4)

- `flutter pub get`: успешно; lockfile и зависимости не изменены.
- `flutter analyze --no-pub`: успешно, No issues found.
- `flutter test --no-pub test/app_theme_test.dart test/color_foundations_test.dart
  test/reader_theme_test.dart test/platform_design_test.dart --reporter expanded`:
  **21 тест прошёл**.
- `flutter build apk --debug --no-pub`: успешно, Gradle assembleDebug 363.8 s.
  APK SHA256 `71b9ce289c28cab5973a3bb3c922e1bb968c8c71a90b76b9afcd6d54cc24cc91`.
  `aapt dump badging` подтвердил `by.mybrev.playtest2026`, `MyBrev Test`,
  versionCode 6, versionName 1.0.0, adaptive icon v33. Проверены точные пиксели
  foreground, monochrome, splash внутри готового APK. JSON ниже фиксирует
  последний APK после обновления main.
- Android API 34: свежий runtime **не подтверждён**. Новый отдельный AVD
  не удалось инициализировать при доступном месте на диске. Прежний
  одноразовый брендовый AVD на `emulator-5576` загрузился, но произошёл
  системный `DeadSystemException` (Android system/phone/networkstack),
  а установка APK вернула код 1. Приложение этой проверкой не валидировано.
  Эмулятор остановлен. Исторические успешные кадры исходной ветки обозначены
  отдельно; их не выдаём за результат актуального main.
- Android до 12: launch XML и density assets проверены статически;
  runtime на старой ОС пока не выполнялся.
- iOS actool/ibtool: **успешно**, macOS-15, AppIcon/LaunchImage/LaunchBackground
  и static launch storyboard. [Свежий CI 38384065857](https://github.com/senddownrain/ibreviarybyapp/actions/runs/38384065857),
  commit `72b7a3abc33d7b7955cb1d3c01e8d194b2ddec0d`.
  Полный результат: `integration-ios-ci.json`.
  Полная iOS-сборка/Simulator/iPhone не выполнялись на Windows.
- Flutter Web runner: manifest и размеры/opacity/maskable проверены статически;
  Web build/install здесь не запускались.

Старые `android-light-1.png`, `android-dark-1.png`, `android-installed-icon.png`,
`android-content-after-launch.png`, JSON исходных Android/iOS проверок
сохранены как **исторические результаты исходной ветки**, а не тест нового main.
В интеграции сохранены только показательные кадры; остальные доступны в
исходной ветке. Логи, APK, видео и временные данные не коммитятся.

## Итоговые проверки на актуальной базе 4872f04

- `flutter analyze --no-pub`: **No issues found**, 119.6 s.
- Те же четыре профильных файла `flutter test --no-pub`: **21 тест прошёл**.
- `flutter build apk --debug --no-pub`: **успешно**, assembleDebug 102.0 s.
  SHA256 актуального APK:
  `3801deaafcaef80b0098aa1586e0d793a5114387b4030b069002ae8307a75a1e`.
  Foreground, monochrome и splash в APK совпали с экспортами по пикселям.
  `MyBrev Test`, `by.mybrev.playtest2026`, 1.0.0+6 подтверждены через aapt.
  Результат: `integration-apk.json`.
- [macOS CI 38386989504](https://github.com/senddownrain/ibreviarybyapp/actions/runs/38386989504):
  **actool и ibtool успешно** для дерева с обновлённым main.
  Результат: `integration-current-main-ios-ci.json`.
- Diff относительно актуального main не содержит изменений `lib/`,
  `assets/`, `test/`, `docs/`, `reports/`, `scripts/`, pubspec/lock,
  AndroidManifest/Gradle, Info.plist/project.pbxproj и release workflow.
  Параллельная работа по чтениям/Ordo/контенту сохранена байт-в-байт.
- SHA256 исходника и всех 38 экспортов сохранились. После проверяемого
  commit 326f6db менялись только отчёт/README, инвентарь и JSON свидетельств;
  CI финального PR проверяется перед слиянием.
- Свежий Android runtime, runtime Android до 12, полная iOS app/device
  и Flutter Web build/install **не подтверждены**; ограничения не скрыты.

Машиночитаемая сводка: `integration-final-checks.json`.

## GitHub и отдельные последующие задачи

[PR #11](https://github.com/senddownrain/ibreviarybyapp/pull/11) содержит только
брендинг относительно актуального main. Слияние выполняется через этот PR;
фактический статус и merge commit SHA доступны на его странице в GitHub.
Безопасное слияние разрешено владельцем после чистого diff и успешного CI.
Релизный workflow остаётся manual-only; магазинные выпуски и deployment
не выполняются.

Отдельный `senddownrain/mybrev` в этом задании не открывался и не менялся.
Для Web/PWA отдельно требуется выборочно интегрировать уже подготовленную
`codex/malitounik-brand-icons` в его актуальную целевую ветку, проверить
установленную PWA и отдельно решить вопрос deployment. Этот PR охватывает
только Flutter и его необязательный Web runner.
