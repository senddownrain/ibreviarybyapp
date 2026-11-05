# Источники и официальные документы во Flutter

Эталон: [Web PR #189](https://github.com/senddownrain/mybrev/pull/189),
`f185657e88436eb8c6adb0f666b6e50bed416b40` (HEAD проверен перед переносом).
База Flutter: `7abba85bebe184e2314b6df1593bab0720fb1c77`.
Старые промежуточные формулировки исторических отчётов не использованы.

| Web | Flutter | Перенос |
| --- | --- | --- |
| `src/data/sources.json` | `assets/legal/sources.json` | Побайтно, все 6 записей, ID, bindings, evidence, pending и метаданные декретов |
| `src/data/documents/liturgy-hours-decrees.json` | `assets/legal/liturgy-hours-decrees.json` | Побайтно, 4 полных документа |
| `src/data/documents/proper-calendar.json` | `assets/legal/proper-calendar.json` | Побайтно, 13 листов, 495 строк, 12 месяцев, 365 дат |
| `public/documents/proper-calendar.pdf` | `assets/legal/proper-calendar.pdf` | Побайтно, оригинал доступен офлайн |
| `SourceRights.vue`, `Sources.vue` | `SourcesScreen` | Те же группы, порядок и краткие библиографические строки |
| `LiturgyHoursDecrees.vue` | `LiturgyHoursDecreesScreen` | Полные абзацы, орган, номера, датировки, подписи; переходы по томам |
| `ProperCalendar.vue`, `DocumentRuns.vue`, `documents.css` | `ProperCalendarScreen`, `DocumentRuns`, `CalendarDocumentLine` | TextSpan: цвет, курсив, уменьшенные прописные, жирность, отступы, степень под соответствующей строкой |
| Ссылка в About | `about-sources-link` | Одна компактная строка в прежнем AboutScreen |
| Служебные маршруты | `/sources`, `/documents/liturgy-hours-decrees`, `/documents/proper-calendar` | Root navigator рядом с `/about` и `/settings`, отдельно от четырёх веток |

SHA-256 и точное происхождение: [web-import-lock.json](web-import-lock.json).
JSON не переформатировался и не генерировался заново. Модели оставляют исходные
технические сведения в данных, но UI выводит только утверждённую библиографию.
Дефисы диапазонов сохранены как в окончательном Web и оригинале Крэміса.

## Первичные документы

Прочитаны исходные Vue/CSS, оба Web-аудита, оригинальный DOCX Крэміса,
транскрипции I–III и IV, DOC IV тома и PDF календаря. В checkout Web выполнены:

```sh
python3 scripts/documents/check-source-citations.py
python3 scripts/documents/extract-hours-decree.py --check
python3 scripts/documents/build-hours-decrees.py --check
python3 scripts/documents/build-proper-calendar.py --check
```

Все четыре проверки прошли: библиография сверена непосредственно с
`word/document.xml`, IV восстановлен через Word piece table, полные декреты
сверены с первичными транскрипциями, календарь — с символами и стилями PDF.
Дублировать первичные DOCX/DOC и исторические отчёты во Flutter не требуется:
их постоянные ссылки остаются в исходном JSON и в Web на указанном SHA.

## Реальные корпуса и существующие подписи

Сравнивались полностью декодированные gzip JSON, включая метаданные каждой
книги, массивы глав и значения всех стихов; не отдельные контрольные цитаты.

| Flutter asset | Web на указанном SHA | Результат / привязка |
| --- | --- | --- |
| `assets/bible_seed_bel.json.gz` | `scripts/bible/bible_seed_bel_mixed.json.gz` | Полное структурное равенство: 73 книги, 35 532 стиха; OT `bible-charniauski-2017`, NT `bible-nt-kkbb-2017` |
| `assets/bible_seed_ru.json.gz` | `scripts/bible/bible_seed_ru.json.gz` | Полное структурное равенство: 73 книги, 35 590 стихов; оба Завета `bible-ru-synodal` |

Библейские assets не изменены. Наименование NT теперь берётся из реестра:
«Новы Запавет · ККББ, 2017». Подписи OT и Синодального перевода сохранены.
ККББ в новой библиографии явно указан полным наименованием как правообладатель.

Аудит `about_screen.dart`, `settings_screen.dart`, router и читателей выявил
общее жёстко заданное © ККББ в SourceFooter Чтений и часов. Для часов это
противоречило `rightsholder: null` эталона. Теперь эти два footer получают
цифровой источник и только установленные © по ID из общего реестра. У часов
остаётся `lh.catholic.by` без неподтверждённого ©, у Чтений — ККББ 2002-2005.
Footer Компендиума сохраняет своё место, оформление и название цифрового
источника; URL и обе строки © берутся из реестра, включая LEV 2005.
Библиография целиком в About не вставляется, настройки не изменены.

## Представление документов

- Четыре полных декрета выводятся из структурных полей; тест собирает из этих
  же полей полный текст и сравнивает с `fullText`, игнорируя только пробелы.
  `04/P/20` от 02.02.2020 не подменяется решением `15/P/19`.
- Пять исходных строк вступления соединены одним логическим абзацем, с шестью
  римскими протоколами и исходным порядком символов.
- Сохранены все 153 пустые даты, 100 строк с отступом, 193 фрагмента уменьшенных
  прописных, 133 курсивных фрагмента, 194 красных и 3 пурпурных фрагмента.
  Диоцезиальные варианты и многострочные записи сохранены без фильтрации.
- Системное масштабирование текста не ограничивается; навигация Wrap переносится,
  степени стоят под своей строкой. Книжный шрифт — существующий локальный Literata.
- Переход по тому/месяцу прокручивает статью без записи шага в истории.
  Back возвращает на предыдущую страницу; прямой вход в документ — на источники,
  прямой вход в источники — в информацию. Используется прежний SecondaryPageScaffold.
- «Арыгінал PDF» передаёт локальные bytes существующему `share_plus`:
  системное меню открытия/сохранения на Android/iOS, сохранение файла в Web.
  Для iPad задаётся прямоугольник popover. Это дополнение к полной статье.

## Нерешённая библиография

Сохранены вопросы Web: полные выходные данные и правообладатель Чарняўскага;
точная цифровая/печатная редакция и правовой статус Синодального перевода;
правообладатели и © томов часов по выходным страницам; переводчики и полные
выходные сведения Лекционария/Компендиума; отдельные разрешения на цифровое
использование. Существование и реквизиты IV декрета подтверждены.
Новые правообладатели, лицензии или сайты происхождения не добавлены.
Эти вопросы остаются в техническом JSON и отчёте, без служебных сообщений в UI.

## Воспроизведение

```sh
python3 scripts/check_web_source_import.py
# Дополнительно: полное сравнение с checkout ровно указанного Web SHA:
python3 scripts/check_web_source_import.py --web-root ../mybrev-reference
flutter analyze
flutter test test/source_documents_test.dart test/source_documents_widget_test.dart \
  test/bible_repository_test.dart test/source_footer_test.dart \
  test/compendium_screens_test.dart test/router_architecture_test.dart \
  test/stateful_shell_navigation_test.dart test/secondary_menu_test.dart \
  test/privacy_policy_link_test.dart
flutter test
flutter run -d chrome -t tool/source_documents_smoke.dart --web-port 5241
# Подключиться к CDP-порту именно этого экземпляра Chrome:
NODE_PATH=<playwright parent> FLUTTER_ROOT=<sdk> CDP_URL=http://127.0.0.1:<port> \
  node scripts/smoke_source_documents.cjs
```

Harness использует реальные экраны и production router без Firebase и без
записи пользовательских настроек. Скрипт выдаёт локальные файлы Flutter engine
и fallback-шрифтов из SDK/ОС, блокирует прочие внешние запросы и проверяет
полный порядок текста 13 листов и все абзацы четырёх декретов в отрисованном UI.
В CI добавлены проверки хешей, данных, виджетов, маршрутов и библиографии.

Результаты запусков и визуального просмотра фиксируются в PR и
`audit-evidence/source-documents/`. Native smoke Android/iOS выделяется отдельно:
Chrome и тесты с TargetPlatform.iOS не заменяют проверку устройства/симулятора.

## Фактические результаты

- `dart format`: все 16 изменённых/новых Dart-файлов отформатированы.
- Строгий `flutter analyze`: 12 info, без warning/error, список в точности
  совпадает с базой. `flutter analyze --no-fatal-infos` завершается успешно.
- 59 целевых unit/widget/regression тестов прошли. После сокращения заголовка
  верхней панели до «Каляндар» повторно прошли все 13 тестов новых экранов.
- Полный `flutter test` на базе: 1710 pass, 9 skipped, 7 fail.
  На ветке: 1727 pass, 9 skipped, 8 fail; все 18 новых проверок прошли.
  Семь падений совпадают с базой: подсказка Чтений, Hours parity, Day → ORDO
  и четыре варианта ORDO utility layout. Дополнительное падение
  `content_offline_test.dart` — тайм-аут 30 секунд; при отдельном повторном
  запуске тот же тест прошёл за 19 секунд. Тайм-ауты и посторонние тесты не менялись.
- [База](../../audit-evidence/source-documents/baseline-checks.json) и
  [результаты ветки](../../audit-evidence/source-documents/checks.json) сохранены
  отдельно, чтобы существующие проблемы не выдавались за новые.
- Chrome: 8 сценариев PASS (320/390 px × light/dark × 100/200% текста),
  без ошибок, горизонтального переполнения и усечения строк. Офлайн-сохранение
  PDF проверено по SHA-256. Результат — [visual-result.json](../../audit-evidence/source-documents/visual-result.json).
- Android/iOS устройство или симулятор в окружении недоступны. Перед релизом
  требуется native smoke системной навигации/жестов и PDF share sheet, включая iPad.

Firestore, Firebase-конфигурация, удалённые данные, тексты Библии/Чтений/часов,
календарные алгоритмы, молитвы, песенник, аналитика, псалмодия и пользовательские
предпочтения не менялись. Merge, deploy и публикация приложения не выполнялись.
