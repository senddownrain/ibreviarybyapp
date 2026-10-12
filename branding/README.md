# Малітоўнік — выбранная иконка и launch surfaces

Владелец выбрал первый из двух новых эскизов: тёплый круг, естественный белый
голубь Святого Духа над раскрытой молитвенной книгой, крест и мягкие лучи.
12 октября 2026 владелец разрешил следующий этап: внедрение по брифу.

## Источник и воспроизводимость

Канонический исходник: `source/approved-icon.png`, 1254×1254, SHA256
`fa8ac6990b67f4a48e5907d00c86aa7306fb44921f079dd5bc92c7bba682a294`.
Это точная копия выбранного изображения; его не перерисовывали и не заменяли
вариантом A1 из первой, отклонённой серии. Сохранены также промпт и запись
этапа выбора (`source/design-selection.md`).

`tools/generate_brand_assets.py` размещает неизменный рисунок в SVG-контейнере,
вырезает его существующий круг, убирает внешнюю светлую кайму и задаёт ровный
ivory `#F5F1E8` вокруг него. Контейнер не добавляет нарисованный squircle.
Так сохраняется выбранная композиция, а системные маски обрабатывают края.
PNG экспортирует resvg. Полностью непрозрачные PNG нормализуются в RGB.
`source/monochrome.svg` — отдельный редактируемый одноцветный силуэт того же
сюжета с прозрачными просветами книги и креста. Детальная цветная иллюстрация
не объявляется векторным рисунком: её исходник — PNG, экспорт — воспроизводимый.

```powershell
npm install --prefix branding/toolchain --no-audit --no-fund
python -m pip install -r branding/toolchain/requirements.txt
python tools/generate_brand_assets.py
python tools/preview_brand_assets.py
```

`asset-manifest.json` фиксирует SHA256 всех экспортов. Одна и та же версия
исходника, силуэта и генератора хранится в Web-репозитории; там команда
`python scripts/generate_brand_assets.py` экспортирует PWA и favicon.

## Платформы

- iOS: все файлы существующего AppIcon catalog, включая непрозрачный RGB
  1024×1024. Нет встроенного скруглённого квадрата. Собственный круг выбранного
  дизайна сохраняется. Dark/Tinted не добавлены как новые дизайны без выбора
  владельца; обычная иконка постоянна.
- Android legacy: PNG mdpi–xxxhdpi. Adaptive icon: отдельный ivory background,
  прозрачный цветной foreground 432×432 и monochrome 432×432. XML v26 и v33
  подключают подходящие слои. Реальные альфа-границы foreground:
  `(86,86)..(346,346)` — 260×260 px, внутри центральной зоны 264×264 px
  (66/108 от 432). Цветной круг является частью выбранного знака, а не второй
  системной маской. См. [Android adaptive icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive).
- Android до 12: центрированный статичный знак 160 dp в `launch_background`.
  Android 12+: один системный splash, без следующего брендового Flutter-экрана.
  Прозрачный холст 288 dp, диаметр знака около 180 dp, внутри круга 192 dp.
  Фон `#F2F1EE` / `#0F110F` соответствует `IbColors.page`. NormalTheme тоже
  использует подходящий фон. См. [Android splash](https://developer.android.com/develop/ui/views/launch/splash-screen).
- iOS: восстановлен реально отсутствовавший `LaunchImage.imageset`,
  изображения 168/336/504 px, статичный знак 168 pt и ограничения размера
  в storyboard. `LaunchBackground.colorset` имеет светлую и тёмную версии,
  совпадающие с Flutter. Native launch следует системной теме; отдельная
  настройка темы приложения применяется после загрузки Flutter/Hive.
- Дополнительный Flutter Web runner: обновлены 192/512, maskable, favicon,
  manifest и HTML-имена. `start_url` и режим установки сохранены. Основной
  Web/PWA реализован отдельно в `senddownrain/mybrev`.

## Идентичность и пределы изменения

Android label: `MyBrev Test`; applicationId: `by.mybrev.playtest2026`;
code namespace: `com.example.mybrev_flutter`.
iOS CFBundleDisplayName: `MyBrev Test`; bundle ID: `by.mybrev.testflight2026`;
CFBundleName: `Малітоўнік`. Идентификаторы, подписи, версии, Firebase
конфигурации и отображаемые тестовые native-метки не менялись.

Flutter UI остаётся графитовым; Web остаётся тёплым. Рубрики `#9B302A`,
литургические периоды и календарь не затронуты. Старый `assets/logo.png`
по-прежнему не используется как источник: он остаётся прежним неиспользуемым
legacy-ресурсом. Эмблема Марии на странице информации относится к парафии
и не заменяется автоматически.

Изменения изолированы на `codex/malitounik-brand-icons`, от Flutter HEAD
`fa973584b74a4feef6e57f0af1dca3465f8fcde4`. Исходная рабочая ветка с текущими
изменениями календаря не переключалась и не очищалась.

## Проверка

Проверены размеры, RGB без альфа-канала у AppIcon, прозрачность слоёв и
safe zone. `flutter analyze --no-pub` прошёл без замечаний.
`flutter build apk --debug` завершился успешно. Дополнительно декодирован
foreground из готового APK: пиксели совпадают с последним экспортом.

`validation/export-preview.png` показывает экспорт и системный tint.
`tools/capture_brand_launch.py` предназначен для отдельного одноразового
эмулятора и сохраняет light/dark cold-start кадры и видео. Записи проверки
устройства и текущего результата добавляются в `validation/`.

На Windows недоступны Xcode/Simulator. Отдельный GitHub Actions workflow
`Validate iOS brand assets` компилирует AppIcon, launch images/colours через
actool и storyboard через ibtool на macOS. Это проверка ресурсов, без
подписи и публикации в TestFlight; полный запуск на iPhone остаётся частью
проверки будущей native-сборки.

## Перед магазинной публикацией

Сверить production app IDs, подпись и существующие карточки магазинов.
Не переносить тестовые IDs в production и не менять привязанный к Play
applicationId. Переименование разрешённых display labels делать отдельным
изменением. Для обновления установленного приложения сохранить его ID и
подпись, повысить build/version, проверить данные и обновление поверх прежней
версии. В этой задаче публикация означает Git-ветки для проверки; deploy,
слияние в main, Google Play и TestFlight не выполняются.
