# Настройки чтения Flutter

Основа: актуальный `main`, `19125bb`. Web-контракт:
[MyBrev PR #202](https://github.com/senddownrain/mybrev/pull/202),
commit `38e94e65b2d944eb34b6c86ef761b1d5b28284cd`.

## Поведение

- В «Налады» размер, прежний пример, семейство и выравнивание объединены в
  `ExpansionTile` «Тэкст» / «Шрыфт, памер і выраўноўванне». Раскрытие хранит
  `PageStorage`, без нового Hive-ключа. Остальные разделы сохраняют порядок.
- Пять семейств: Literata (рэкамендаваны), Source Serif 4, Old Standard TT,
  Kurale, Сістэмны. Google Fonts 6.3.3 поддерживает обе новые гарнитуры. Их
  настоящие TTF включены в существующий asset-каталог, OFL зарегистрированы
  в `LicenseRegistry`. Файлы и SHA-256 описаны в assets/google_fonts/README.md.
- `ReaderTextAlignment.start/justify` хранится в существующем Hive `settings`,
  ключ `textAlignment`, через тот же `settingsProvider`. Отсутствующее или
  неизвестное значение даёт start; чтение ничего не записывает. Другие
  сохранения не перезаписывают этот ключ из устаревшего контейнера.
- Общие `ReaderFontPicker` и `ReaderAlignmentControl` применяют изменения сразу.
  На узком экране с крупным системным текстом процент переносится под заголовок
  панели, чтобы слово «Шрыфт» оставалось целым. У прежнего списка стартового
  раздела включена адаптивная ширина, устраняющая переполнение при 320 dp / 200%.
  В нижней панели Hours показана только псалмодия; у обычного читателя —
  только выравнивание. Семейство и масштаб доступны в обоих контекстах.
- `PsalmodyControlRow` использует прежний `PsalmodyModeSelector`: 48 dp по
  высоте, три равные зоны на телефоне; компактные 240 dp справа при достаточной
  ширине. Enum и ключи псалмодии прежние.
- Overflow измеряет реальные подписи через `TextPainter` и системный
  `TextScaler`: короткое меню 224–280 dp, длинные контекстные действия могут
  занимать до 360 dp в пределах SafeArea. Якорь — фактический правый нижний
  угол адаптивной кнопки с учётом её трансформации, промежуток 4 dp. Chevrons
  у действий удалены. Существующие маршруты, категории, callbacks, закрытие
  popup перед sheet и удаление popup при скрытии chrome сохранены. Повторный
  выбор во время закрытия popup защищён проверкой текущего route: читатель не
  закрывается вторым тапом.

## Где действует выравнивание

| Рендерер | Область применения | Исключения |
| --- | --- | --- |
| Bible | RichText обычного стиха | явные фиксированные переносы; номер остаётся inline WidgetSpan |
| Readings / наборы Імшы | проза `_ReadingText`, HTML `.reader-prose` | псалмы, секвенции, аккламации, реплики, заголовки и ссылки на чтения |
| ReadingDetail | прозаический SelectableText / HTML | семантические исключения HTML и фиксированные переносы |
| Prayerbook / preview редактора | обычные абзацы PrayerContent | рубрики, реплики, стихи с br, списки, отдельные ссылки и подписи |
| Catechism | Text.rich абзацев CompendiumAnswer | ККК, заголовки, цитатные блоки и навигация |
| Mass | `.reader-prose` после семантического разбиения документа | ответы, обозначения говорящего, рубрики, поза, альтернативы, заголовки |
| Ora / DevotionalOfficeReader | не подключено | все тексты, не только псалмы |
| Songs, Ordo, ссылки на источники | не подключено | фиксированные строки, метаданные, списки и управляющие элементы |

HTML-классификация работает на временном DOM и не изменяет сохранённые
документы. Inline emphasis и ссылки внутри прозы остаются на месте. Отдельные
ссылки и реплики не получают justify. Это уточнение по отношению к Web #202:
ссылка внутри обычного прозаического абзаца сохраняет семантику абзаца.
Сам `PrayerContent` остаётся самостоятельным рендерером: экран чтения и
предпросмотр редактора передают выравнивание из того же `settingsProvider`,
аналогично уже передаваемому `TextStyle`.
Нативный `TextAlign.justify` оставляет последнюю строку выровненной по началу;
абзацы с фиксированными переносами консервативно остаются start.
Выравнивание не добавляется в глобальную тему или DefaultTextStyle.

## Точный пример псалма

**Псальм 63 (62), 2–3**. Источник: MyBrev
`patchs/json/ordinary-w5-d1-fixed-day.json`, `laudesPs1`, первые три простые
строфы `<p>`, исключая заголовок и эпиграф. Текст `psalmodyPreviewHtml`
побайтово сверяется с `test/fixtures/psalmody-preview-web.html`, извлечённым
из исходного JSON PR #202.

Пример использует настоящий `formatPsalmHtml` → `PsalmodyScope` →
`PsalmChoirHtml` → `preparePsalmChoirHtml`. Новый необязательный параметр
`interactive: false` выключает только ссылки затемнения в примере; у настоящих
псалмов значение по умолчанию true и прежнее поведение. Переносы после
литургических знаков, отступы продолжений и чередование строф имеют один
алгоритм для примера и настоящего псалма. Нижний sheet не дублирует пример.

## Проверки

Полный `flutter test --concurrency=2 --timeout=2m`: **1888 passed, 9 skipped,
2 failed**. Оба падения воспроизводятся на чистом `main` (`19125bb`):

- `hours_parity_test.dart`: 44 расхождения `feast-christthehighpriest` для
  2025–2035 × 4 диоцезии. То же падение в полном baseline-прогоне
  (1868 passed, 9 skipped, 1 failed).
- `discovery/p0_hints_screens_test.dart`, `Readings date_navigation`: отсутствует
  `discovery-card-calendar.date_navigation`. В полном baseline проходил,
  но отдельно на чистом main падает с тем же ожиданием; зависит от порядка
  выполнения/состояния подсказок.

Целевые тесты предпочтений, Hive, шрифтов, prose, псалмодии, меню и панели:
**155 passed**. После последних адаптивных правок повторены пять связанных
наборов: **100 passed**. Полный прогон также покрывает Bible, Readings, Mass
и навигационные регрессии. `dart format --set-exit-if-changed`: 34 файла,
изменений нет; `git diff --check` чистый.

`flutter analyze`: **0 errors, 0 warnings, 27 info**, те же замечания на main.
Команда завершает работу с кодом 1 из-за существующих info; они не скрыты.

В настоящем Chromium проверена debug-сборка Flutter Web: light/dark/Marian ×
Material/Cupertino при 393 dp, а также 320 dp / 200%, 360 dp и 1440 dp.
Проверены пять реально загруженных семейств, три режима живого примера,
start/justify в Bible, изоляция Ora, popup и оба контекста панели. **9 конфигураций,
0 браузерных ошибок/переполнений**, 122 PNG, включая два снимка main «до».
Новые TTF отвечают 200 из локальных assets. Ключевые снимки просмотрены вручную;
обнаруженные переполнения 320 dp исправлены и весь visual smoke повторён.
Индекс, команды, логи и сравнение с main:
[audit-evidence/reader-settings/README.md](../audit-evidence/reader-settings/README.md).

Доступность нативной среды: Linux, Android AVD отсутствуют, iOS Simulator
отсутствует. Material и Cupertino оформление проверены в Flutter Web; это
не native smoke и не проверка системной навигации Android/iOS. Перед мобильным
релизом нужен native smoke. Слияние, релиз и изменения production Firebase
не выполнялись.

## Воспроизведение визуального прогона

Основной путь:

```sh
flutter devices
flutter run -d chrome -t tool/reader_settings_smoke.dart --web-port 5241 --no-web-resources-cdn
NODE_PATH=<путь к playwright/node_modules> CDP_URL=http://localhost:<Chrome-CDP-port> node scripts/smoke_reader_settings.cjs
```

При ошибке DWDS `LateInitializationError: Field inspector has not been initialized`
та же отладочная Flutter Web-сборка может быть проверена в Chromium:

```sh
flutter build web --debug --no-wasm-dry-run --no-web-resources-cdn -t tool/reader_settings_smoke.dart --output work/reader-web
python3 -m http.server 5241 --bind 127.0.0.1 --directory work/reader-web
```

Smoke ожидает точный URL `http://localhost:5241/`. Дополнительный
`AUDIT_ROBOTO=<реальный локальный Roboto-Regular.ttf>` подаёт только стандартные
UI/fallback-шрифты движка вместо заблокированного fonts.gstatic.com. Четыре
читательские гарнитуры загружаются исключительно из assets приложения; они
не подменяются. Приложение не инициализирует Firebase; обновления, connectivity
и priest gateway изолированы. Production Firestore и hosting не используются.
