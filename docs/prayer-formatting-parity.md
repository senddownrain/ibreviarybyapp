# Форматирование молитв во Flutter: паритет и Chrome-проверка

> Исторический отчёт этапа 1.0. Текущий reader обновлён до утверждённого MyBrev 1.1; прежние различия устранены. Актуальный отчёт: [паритет 1.1 и новые Chrome-снимки](prayer-formatting-parity-1.1.md).

Проверено 2026-10-14 в ветке `codex/prayer-formatting`, база `origin/main` — `be276b8148a1eb30f9795e76ba9c9499ea9a9ec3`.

## Реализация

CommonMark AST из `markdown` 7.3.1 заменяет минимальный конвертер. Поддерживаются h1–h6, абзацы, вложенные списки, жирность/курсив, код, внутренние и reference links, одиночные переносы литаний и явные `:::rubric`.

К./С./Н./Д./Л./Ц./V./R. и наследуемое двоеточие выделяются только в начале самостоятельной реплики. Метка красная жирная, слова обычные с сохранением авторского выделения. Инициалы/имена, латинские двойники, текст внутри повествования, ссылки, код, заголовки, списки и рубрики исключены.

По новой явной поправке пользователя участники также распознаются в обычных абзацах настоящих blockquotes. `> Н. І з духам тваім.` сохраняет цитату, отступ, вертикальную границу, слова и исходный `>`; красной жирной становится только `Н.`. Полное правило и тестовые примеры — [поправка к общему контракту](prayer-formatting-quote-amendment.md).

Чтение и предпросмотр личного редактора используют общие `PrayerContent`/стили/шрифт/темы и `SelectionArea`. Markdown HTML экранируется; наследуемый HTML очищается DOM-санитайзером, опасные URI и активное содержимое удаляются. Обработчик Мессы остаётся отдельным, общие метки для него отключены. Права доступа и доставка bundle/overlay не менялись.

Smoke harness перенесён из `test/support` в `lib/dev/prayer_formatting_harness.dart` и импортируется через `package:`: это исправляет реальную ошибку относительных импортов в `flutter run -t tool/...`. Основной entrypoint приложения этот harness не импортирует. В нём реальные экраны, публичный bundle и memory-only providers, без Firebase/Hive и записи в production.

## Chrome visual smoke — выполнен

Команда: `flutter run -d chrome -t tool/prayer_formatting_smoke.dart --web-port 5237`.

Проверен именно Google Chrome **155.0.8059.40**, запущенный Flutter. Прямое подключение Playwright по Chrome DevTools Protocol; выбранная вкладка проверена по `http://localhost:5237/`, без определения адреса по заголовку Windows. CanvasKit показывает настоящий Flutter UI с bundled fonts. После первоначального сбоя импорта и неустойчивого управления через accessibility locators применены корректный package-import и прямые действия по наблюдаемым координатам внутри вкладки. Android-эмулятор не запускался.

**18 актуальных PNG получены и просмотрены.** Метаданные, сценарии, размеры и SHA256 файлов — [chrome-smoke-results.json](../audit-evidence/prayer-formatting/chrome-smoke-results.json). Ошибок pageerror/console error во время проверенных сценариев не получено. Два отдельно названных `chrome-before-quote-amendment-*.png` показывают состояние до поправки и не считаются успешной проверкой нового правила.

| Проверенное состояние | Реальный снимок |
| --- | --- |
| Светлая тема, обычный шрифт, роли/рубрика/исправленная цитата | [1280 × 1000](../audit-evidence/prayer-formatting/chrome-quote-fixed-light.png) |
| Тёмная тема, те же слова и структура | [1280 × 1000](../audit-evidence/prayer-formatting/chrome-quote-fixed-dark.png) |
| Тёмная тема, мобильная ширина 320 px | [320 px](../audit-evidence/prayer-formatting/chrome-dark-320-reader.png) |
| Штатный размер читательского шрифта действительно 180% | [Контроль 180%](../audit-evidence/prayer-formatting/chrome-font-180-control.png) |
| Цитата и переносы на 320 px/180%, dark/light | [Dark](../audit-evidence/prayer-formatting/chrome-dark-320-180-quote.png), [light](../audit-evidence/prayer-formatting/chrome-light-320-180-quote.png) |
| Длинная контрольная литания: прокрутка до ответа 50 | [Конец](../audit-evidence/prayer-formatting/chrome-light-320-180-litany-end.png) |
| Реальная «Літанія да Духа Святога» из public bundle | [Начало](../audit-evidence/prayer-formatting/chrome-real-litany-320-180.png), [середина](../audit-evidence/prayer-formatting/chrome-real-litany-middle-320-180.png) |
| Реальная короткая «Тваёй абароне» | [Начало](../audit-evidence/prayer-formatting/chrome-real-short-320-180.png), [конец](../audit-evidence/prayer-formatting/chrome-real-short-end-320-180.png) |
| Личный редактор: сохранённые символы `>` видны в исходнике | [Редактор](../audit-evidence/prayer-formatting/chrome-local-editor-320.png) |
| Общий предпросмотр личной молитвы, роли/рубрики/цитата, 320 px/180% | [Light](../audit-evidence/prayer-formatting/chrome-local-preview-light-320-180.png), [dark](../audit-evidence/prayer-formatting/chrome-local-preview-dark-320-180.png) |
| Старый HTML: форматирование, цитата, ссылка; script не отображается | [Legacy](../audit-evidence/prayer-formatting/chrome-legacy-dark-320-180.png) |
| Внутренняя ссылка открывает указанную молитву; возврат работает | [Цель ссылки](../audit-evidence/prayer-formatting/chrome-internal-link-target-320-180.png) |
| Несуществующий ID: сообщение без аварии | [Не найдено](../audit-evidence/prayer-formatting/chrome-missing-link-320.png) |
| Закрытый ID: отказ без отображения `SECRET` | [Нет доступа](../audit-evidence/prayer-formatting/chrome-restricted-link-320.png) |

На 320 px и 180% проверены естественные переносы меток/длинных строк/цитат и вертикальная прокрутка. Панель smoke harness сокращает длинный технический заголовок; это не экран production. Проверка защищённой ссылки использует отказ memory-provider; фактическая серверная авторизация не проверялась этим harness.

## Сверка с вебом и оставшиеся различия

Опубликованный `main` MyBrev сохраняет [1.0](https://github.com/senddownrain/mybrev/blob/8b02183667490ac50bb9982652512bdfc543a7aa/docs/prayer-formatting-standard.md), blob `f38c08df99459f02b65971e991210ac1121fad93`. [PR #124](https://github.com/senddownrain/mybrev/pull/124) предлагает 1.1, ещё OPEN на момент проверки.

Поправка о bare-репликах внутри цитат передана в веб-чат «Форматирование» по прямому запросу пользователя. Веб уже синхронизировал parser/контракт/тесты в [0fcce378d6dd4b6f3d67a35fb45e44f49c5da4af](https://github.com/senddownrain/mybrev/commit/0fcce378d6dd4b6f3d67a35fb45e44f49c5da4af). Для этого случая обе ветки теперь работают одинаково. Flutter остаётся на **1.0 + явно утверждённая поправка цитат**, не переносит остальные возможности будущего 1.1 по догадке.

| Форма | Flutter в этом PR | Веб PR #124 / последующая синхронизация |
| --- | --- | --- |
| `**С.**`, `**Н.:**`, strong/em-обёртки метки вне цитат | Авторская разметка сохраняется; общий role-span не добавляется | Проекция валидной обёртки в семантическую метку |
| `**С.: Пан з вамі.**`, выделение всей реплики | Всё авторское выделение сохраняется | Метка семантическая, выделение слов сохраняется отдельно |
| Метка на отдельной строке | Обычный читаемый текст/перенос, без роли | Подтверждённый диалог одного абзаца с другим участником рядом |
| `Усе:` / `Цэлебрант:` | Обычный текст; поддерживаются восемь базовых обозначений | Дополнительные роли all/celebrant |
| Отдельные указания без `:::rubric` | Рубрика только при явной разметке | Ограниченный точный словарь указаний, без превращения любого курсива в рубрику |
| Старый HTML | Безопасный DOM/историческое оформление, без общего HTML → MD rewrite | Turndown → Markdown и расширенная проекция наследуемых участников; точный паритет такого импорта пока не заявлен |
| Настоящий или ошибочно импортированный `>` | Blockquote сохраняется; bare-реплика может иметь роль | То же правило после поправки; глобального удаления `>` нет |

Обёртки/самостоятельные метки/полные названия участников **в цитатах** не добавлены этой поправкой ни в Flutter, ни в обновлённом веб-правиле. «Анёл Панскі» не найден по названию в Flutter bundle; веб-этап 2 нашёл его в теле сборного документа private snapshot. Синтетические случаи не выдаются за подлинный источник, production не читался/не переписывался. Проверено сохранение валидных quote-маркеров и отдельный литеральный `\>`.

Завершения массовой миграции не нужно ждать для этого кода. Перед выпуском с новым нормализованным bundle необходимо зафиксировать/согласовать 1.1 и перечисленные различия; неизвестный синтаксис не следует добавлять независимо во Flutter.

## Проверки

- `dart format --output=none --set-exit-if-changed`: 13 изменённых Dart-файлов, 0 изменений — [лог](../audit-evidence/prayer-formatting/format-final.log).
- `flutter analyze`: No issues found — [лог](../audit-evidence/prayer-formatting/analyze-final.log).
- Профильный `flutter test` по восьми файлам молитв, моделей, экрана/редактора, bundle и Мессы: **94 passed**, включая новые положительные/отрицательные quote-кейсы всех восьми ролей — [лог](../audit-evidence/prayer-formatting/unit-widget-final.log).
- Ранее полный suite был остановлен после 899 прошедших тестов и тайм-аута неизменённого теста доставки контента. Полное прохождение не заявляется — [исторический лог](../audit-evidence/prayer-formatting/full-suite-attempt.log). Тот же тест прошёл за 32 секунды с диагностическим лимитом 2m вместо 30s, без изменения кода/ожиданий — [лог](../audit-evidence/prayer-formatting/content-extended.log).
- Browser widget-команда `--platform chrome` не выдаётся за завершённую проверку; подтверждён именно visual smoke реального приложения, описанный выше.
- Native smoke не выполнялся: общий UI/парсер, нативные API не менялись. Android/iOS smoke требуется перед соответствующим мобильным релизом.

Постоянное правило **headless для логики; headless + Chrome visual для общего UI; целевое устройство для платформенных функций/релиза** закреплено в [AGENTS.md](../AGENTS.md), краткая ссылка и фиксированный порт — в [README.md](../README.md). Скрипт `run_in_chrome.bat` сохранён.

Firestore, `contentManifest`, bundle/overlay, закрытый контент и релизы Google Play/TestFlight не изменялись. Слияние в main не выполнялось.
