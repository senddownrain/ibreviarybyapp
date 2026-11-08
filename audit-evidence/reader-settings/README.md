# Приёмка настроек чтения

База: `main` / `19125bb`. Контракт примера:
[MyBrev #202](https://github.com/senddownrain/mybrev/pull/202),
`38e94e65b2d944eb34b6c86ef761b1d5b28284cd`.
Подробности реализации и ограничения: [отчёт](../../docs/reader-settings-review.md).
Машиночитаемые результаты: [validation.json](validation.json),
[chrome-results.json](chrome-results.json).

## До / после

| Состояние | До, main | После |
| --- | --- | --- |
| Налады, 393 dp | [снимок](before/android-393-settings.png) | [Тэкст свёрнут](android-393-light-collapsed.png), [раскрыт](android-393-light-expanded.png) |
| Главное overflow | [снимок](before/android-393-menu-home.png) | [компактное меню](android-393-light-menu-home.png) |

## Просмотренные состояния

- [Old Standard TT](android-393-light-font-oldStandardTT.png),
  [Kurale](android-393-light-font-kurale.png),
  [пять вариантов](android-393-light-font-options.png).
- Точный Web-пример в трёх режимах:
  [leftBreak](android-393-light-psalmody-leftBreak.png),
  [leftBreakIndent](android-393-light-psalmody-leftBreakIndent.png),
  [alternatingStanzas](android-393-light-psalmody-alternatingStanzas.png).
- Bible [start](android-393-light-bible-start.png) /
  [justify](android-393-light-bible-justify.png).
  [Ora после включения justify](android-393-light-ora-justify-isolated.png):
  smoke сравнивает текст и выравнивание всех RenderParagraph до/после.
- Панели [обычного читателя](ios-393-marian-sheet-bible.png) и
  [Hours](ios-393-marian-sheet-ora.png),
  [контекстное меню](android-393-light-menu-reader.png).
- [Тёмная тема / Cupertino](ios-393-dark-expanded.png),
  [Marian / Material](android-393-marian-expanded.png).
- 320 dp / системный масштаб 200%:
  [настройки](android-320-marian-expanded-scale-2.png),
  [список шрифтов](android-320-font-options-scale-2.png),
  [панель текста](android-320-marian-sheet-scale-2.png),
  [панель Hours](android-320-marian-ora-sheet-scale-2.png).
- [360 dp](android-360-marian-expanded-scale-1.png),
  [1440 dp](android-1440-marian-expanded-scale-1.png).

Всего 122 PNG. Полный smoke повторяет light/dark/Marian на 393 dp для
Material/Cupertino и три дополнительные ширины: 9 конфигураций, 0 ошибок и
переполнений. Новые TTF фактически загружены из assets (HTTP 200).
Это реальная debug-сборка Flutter Web в Chromium. Из-за ошибки DWDS inspector
использован статический сервер этой сборки; порядок воспроизведения и обход
заблокированного CDN только для стандартного UI Roboto описаны в отчёте.
Читательские гарнитуры не подменялись.

## Автоматические проверки

```sh
flutter test --concurrency=2 --timeout=2m
flutter test test/app_overflow_menu_test.dart test/bundled_fonts_test.dart test/prayer_11_safety_widget_test.dart test/psalmody_html_modes_test.dart test/psalmody_mode_selector_test.dart test/psalmody_navigation_test.dart test/psalmody_preferences_test.dart test/reader_preferences_test.dart test/reader_prose_test.dart test/reader_theme_test.dart test/text_scale_control_test.dart
flutter test test/text_scale_control_test.dart test/psalmody_navigation_test.dart test/app_overflow_menu_test.dart test/psalmody_mode_selector_test.dart test/reader_prose_test.dart
flutter analyze
```

| Проверка | Результат | Лог |
| --- | --- | --- |
| Полный набор | 1888 passed, 9 skipped, 2 известных падения | [выдержки](logs/full-suite-excerpts.log) |
| Целевые 11 файлов | 155 passed | [лог](logs/targeted-155.log) |
| Повтор после финальных адаптивных правок | 100 passed | [лог](logs/responsive-100.log) |
| Analyze | 0 errors, 0 warnings, 27 info; exit 1 | [ветка](logs/analyze.log), [main](logs/main-analyze.log) |
| Format / diff check | 34 файла без изменений / чисто | [validation.json](validation.json) |

Полный baseline на чистом `main`: 1868 passed, 9 skipped, 1 failed —
`hours_parity_test`, те же 44 расхождения `feast-christthehighpriest`
([выдержки](logs/main-suite-excerpts.log)). Второе падение ветки,
`Readings date_navigation` / отсутствующий `discovery-card-calendar.date_navigation`,
воспроизведено отдельно на чистом main
([лог](logs/main-discovery-repro.log)); в полном baseline проходило и зависит
от порядка/состояния подсказок. Эти несвязанные тесты не ослаблены и не пропущены.

Тесты проверяют реальное сохранение Hive после close/reopen, прежние значения,
реальные cmap белорусских глифов, OFL и offline-загрузку TTF, семантические
исключения prose, сохранение inline-ссылок/выделений, изоляцию Office, одинаковый
рендерер примера и псалмов, размеры/якорь popup, повторный тап при закрытии,
синхронизацию sheet/настроек без сброса прокрутки, SafeArea и клавиатуру на
320 dp / 200% (widget-тест).

## Нативная среда

`flutter devices`: Linux, Chrome; `flutter emulators`: нет доступных AVD.
iOS Simulator в Linux отсутствует. Android/iOS native smoke не выполнен;
проверено только оформление обеих платформ в Web. Системная клавиатура,
навигация и lifecycle требуют отдельного native smoke перед мобильным релизом.
Firebase production, hosting и релизы не изменялись; PR остаётся Draft.
