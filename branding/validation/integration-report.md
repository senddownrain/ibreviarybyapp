# Выборочная интеграция брендинга в Flutter main

Дата: 13 октября 2026. Репозиторий: `senddownrain/ibreviarybyapp`.

## Основание и границы

База интеграции: актуальный `origin/main`
`e2643a4b43a3ed86e64b922224b730e156f65404`.
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

`tools/audit_brand_assets.py`: проверены 38 PNG экспортов, 19 RGB AppIcon
без alpha, XML/JSON/SVG подключений, adaptive foreground 432×432 с bbox
`(86,86,346,346)` внутри safe zone, прозрачные monochrome cutouts и maskable
safe zone. Детерминированная регенерация resvg 2.6.2 + Pillow 11.3.0
оставила все SHA256 экспортов и manifest неизменными, включая совпадение
с исходной веткой. Размеры 32/48/60 px и themed silhouette визуально
проверены в `export-preview.png`; рисунок не менялся.

## Проверки именно интеграционной ветки

- `flutter pub get`: успешно; lockfile и зависимости не изменены.
- `flutter analyze --no-pub`: успешно, No issues found.
- `flutter test --no-pub test/app_theme_test.dart test/color_foundations_test.dart
  test/reader_theme_test.dart test/platform_design_test.dart --reporter expanded`:
  **21 тест прошёл**.
- `flutter build apk --debug --no-pub`: выполняется; результат будет добавлен.
- Android API 34: свежий отдельный AVD подготовлен; проверка ожидает APK.
- Android до 12: launch XML и density assets проверены статически;
  runtime на старой ОС пока не выполнялся.
- iOS actool/ibtool: ожидается свежая проверка CI интеграционной ветки.
  Полная iOS-сборка/Simulator/iPhone не выполнялись на Windows.
- Flutter Web runner: manifest и размеры/opacity/maskable проверены статически;
  Web build/install здесь не запускались.

Старые `android-light-1.png`, `android-dark-1.png`, `android-installed-icon.png`,
`android-content-after-launch.png`, JSON исходных Android/iOS проверок
сохранены как **исторические результаты исходной ветки**, а не тест нового main.
В интеграции сохранены только показательные кадры; остальные доступны в
исходной ветке. Логи, APK, видео и временные данные не коммитятся.

## GitHub и отдельные последующие задачи

PR и статус слияния будут добавлены после свежих проверок.
Безопасное слияние разрешено владельцем после чистого diff и успешного CI.
Релизный workflow остаётся manual-only; магазинные выпуски и deployment
не выполняются.

Отдельный `senddownrain/mybrev` в этом задании не открывался и не менялся.
Для Web/PWA отдельно требуется выборочно интегрировать уже подготовленную
`codex/malitounik-brand-icons` в его актуальную целевую ветку, проверить
установленную PWA и отдельно решить вопрос deployment. Этот PR охватывает
только Flutter и его необязательный Web runner.
