# Пять набажэнстваў: Flutter reader

Issue #34 реализован по окончательно принятому [WEB PR #146](https://github.com/senddownrain/mybrev/pull/146), merge `6e0b7087548e7c823ab009d903556d5413182f01`.

`PrayerDetailScreen` выбирает semantic reader только для пяти ID из `devotionalOfficeProfiles`, когда совпадают порядок разделов и структура источника. Для четырёх часов дополнительно проверяются три псалмовых места и шесть антифонов. При несовпадении остаётся обычный `PrayerContent`. Месса и проверка доступа сохраняют прежний путь.

Парсер сохраняет оригинальный Markdown в `document.source`, а каждый блок — с точным диапазоном строк. Все альтернативы остаются в модели; UI скрывает импортные заголовки и лишние варианты. Четыре намерения за умерших не имеют начального выбора и синхронно переключают гимн и молитву. Формулы `N.`, скобки и грамматика источника сохраняются. У марианских часов два смысловых варианта просьб и пять молитв; у Гадзінак — восемь оригинальных частей.

Использованы существующие `ReaderScaffold`, `ReadingScaffold`, `PrayerContent`, безопасный `prayerMarkdownToHtml`, литургические заголовки/стили, `PsalmChoirHtml` и `PsalmodyScope`. Псалмы и евангельская песня имеют общий выбор хора и учитывают сохранённые отступы и перенос после `* / †`. Настройки шрифта, тема, избранное и offline-поток принадлежат существующему экрану. `PrayerContent.wrapInSelectionArea` позволяет выделять текст всего составного документа; для обычных молитв сохранено значение по умолчанию.

## Проверенный локальный источник

Все пять полных документов прочитаны через `decodeContentCollection` из `assets/content/prayers.json.gz`; публичность проверена через `PriestAccessPolicy`. Формат всех пяти — `mybrev-markdown`. Синтетических литургических текстов в smoke нет. Bundle и manifest не менялись, Firebase не инициализировался.

SHA-256 bundle: `6edd638b13e76820367771357161d14bd51273ede2c4e551b15925e9c5e9e3ee`.

| ID | Символов Markdown | Кадр Chrome |
| --- | ---: | --- |
| `mybrev-devotion-office-for-dead-laudes` | 11304 | [Женское намерение и гимн](../audit-evidence/devotional-office/mybrev-devotion-office-for-dead-laudes.png) |
| `mybrev-devotion-office-for-dead-vesper` | 9531 | [Молитва после выбора «За некалькіх»](../audit-evidence/devotional-office/mybrev-devotion-office-for-dead-vesper.png) |
| `mybrev-devotion-blessed-virgin-mary-laudes` | 14719 | [Псалом, тема и эпиграф](../audit-evidence/devotional-office/mybrev-devotion-blessed-virgin-mary-laudes.png) |
| `mybrev-devotion-blessed-virgin-mary-vesper` | 8407 | [Переключённые просьбы](../audit-evidence/devotional-office/mybrev-devotion-blessed-virgin-mary-vesper.png) |
| `catholicby-yearcycle-100116` | 8441 | [Вложенный гимн и К./Н.](../audit-evidence/devotional-office/catholicby-yearcycle-100116.png) |

## Воспроизведение проверок

Flutter 3.41.4 / Dart 3.11.1. Целевые unit/widget и регрессии обычного ридера и Мессы:

```sh
flutter test test/devotional_office_test.dart test/devotional_office_widget_test.dart test/prayer_formatting_widget_test.dart test/prayer_markdown_test.dart test/mass_reader_test.dart
flutter test test/liturgical_alternatives_test.dart test/pastors_hymn_test.dart
flutter analyze --no-fatal-infos
```

Режим analyze совпадает с существующим CI: 0 errors, 0 warnings; 9 прежних info в неизменённых `lib/utils/pastors_hymn.dart` и `test/analytics/consent_mock_test.dart`. Новые файлы не добавляют диагностик. CI также запускает новые тесты и проверку `dart format`.

Настоящий Flutter Web в Google Chrome:

```sh
flutter devices
flutter run --release -d chrome -t tool/devotional_office_smoke.dart --web-port 5239 --web-browser-debug-port 9222 --no-web-resources-cdn
```

Без дисплея добавить `--web-run-headless`; контейнерный Chrome требует своих стандартных параметров запуска. Автоматизация подключается через CDP к этой же вкладке `http://localhost:5239/` и не запускает другой браузер. Нужен пакет `playwright` в Node resolution path и `FLUTTER_ROOT`, указывающий на установленный SDK:

```sh
npm install --prefix work/chrome-smoke playwright
NODE_PATH="$PWD/work/chrome-smoke/node_modules" FLUTTER_ROOT=/path/to/flutter node scripts/smoke_devotional_office.cjs
```

Script проверяет 390/320 px, светлую/тёмную тему, текст 100/200%, оба отступа и оба режима переноса, все четыре намерения и марианские смысловые варианты; прокручивает до респонсория и конца. Он сохраняет пять PNG и [машинный протокол](../audit-evidence/devotional-office/chrome-smoke.json). Material fallback Roboto отдаётся локально из Flutter SDK, книжные шрифты — из неизменённых assets; обращения к внешним сервисам блокируются. Свежесть относительно live Firestore не утверждается.

Итог проверки: 47 целевых тестов и 10 существующих CI-регрессий — PASS; форматирование и analyze в режиме CI — PASS. Повторный чистый Chrome run: 40/40 состояний, 0 JS/Flutter errors, 0 failed resource requests, 0 внешних обращений. Все пять итоговых PNG и пять дополнительных кадров 320 px / dark / 200% просмотрены.

Native smoke = **нужен перед мобильным релизом**. Android/iOS не запускались; merge, APK и release не выполнялись.


## Подготовка PR #35 к слиянию

Ветка обновлена от `origin/main` (`9907479`, включая P04/P07 аналитики). В `PrayerDetailScreen` сохранены событие `mass_section_nav` и semantic reader пяти молитв. Workflow содержит исходную задачу аналитики из main и проверки ридера; дополнительно проверяется `ANALYTICS_LOCAL=true`, чтобы gated fit/recording-тесты выполнялись в CI.

После объединения: 47 тестов ридера/регрессий — PASS; аналитика без флага — 68 PASS (8 тестов требуют флага), с флагом — 75 PASS (одна проверка выключенного режима пропускается, она пройдена в первом прогоне). Analyze в принятом CI режиме — PASS, 0 errors/warnings, 9 прежних info. Форматирование — PASS.

Визуальная часть ридера и пять принятых PNG не изменены. Из main перенесены аналитические события и поправка подсчёта пустого резерва, без изменения геометрии или оформления. По решению владельца Chrome-матрица повторно не запускалась; сохранены принятые снимки и протокол предыдущих 40 состояний. Bundle, тексты молитв и Firebase не менялись.
