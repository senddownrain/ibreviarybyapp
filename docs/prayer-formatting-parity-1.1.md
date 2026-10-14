# Flutter reader: паритет MyBrev 1.1

Проверено 2026-10-14, ветка `codex/prayer-formatting`, [PR #13](https://github.com/senddownrain/ibreviarybyapp/pull/13).

Источник правил зафиксирован пользователем: веб-коммит `0fcce378d6dd4b6f3d67a35fb45e44f49c5da4af` из [MyBrev PR #124](https://github.com/senddownrain/mybrev/pull/124). Прочитаны [стандарт](https://github.com/senddownrain/mybrev/blob/0fcce378d6dd4b6f3d67a35fb45e44f49c5da4af/docs/prayer-formatting-standard.md), [этап 2](https://github.com/senddownrain/mybrev/blob/0fcce378d6dd4b6f3d67a35fb45e44f49c5da4af/docs/prayer-normalization-stage2.md), `prayerMarkdown.js`, `prayerLegacyFormatting.js`, CSS reader/preview и сопоставимые веб-тесты. Указанный коммит остаётся head открытого веб-PR; пользователь явно разрешил перенос его правил отображения. Это версия интерпретации 1.1, формат хранения остаётся v1.

## Реализованные правила

| Правило веба 1.1 | Flutter reader / preview |
| --- | --- |
| К./С./Н./Д./Л./Ц./V./R., регистр, алфавит, необязательное двоеточие | Та же грамматика; латинские двойники не добавлены, пунктуация сохранена |
| Валидные обёртки strong/em: `**С.**`, `**Н.:**`, `_К._`, `**_Д._**:` и сопоставимые формы | В памяти снимается только обёртка метки; метка красная жирная без курсива, размер наследуется |
| Полностью или многострочно выделенная реплика | Обёртка переносится на слова реплики при чтении; авторские strong/em, переносы и слова сохранены |
| Метка на отдельной строке | Только подтверждённый диалог в одном абзаце: допустимая следующая строка, иной участник не дальше восьми строк. Не объединяет и не переписывает строки источника |
| `Усе:` / `Цэлебрант:` | `all` / `celebrant`; без новых синонимов |
| Самостоятельное литургическое указание | Только однострочный абзац с точным совпадением 13 строк из веб-словаря, вне цитат/списков/рубрик/кода. Авторское выделение внутри новой рубрики сохранено |
| Старый HTML | Безопасная DOM-конверсия в Markdown в памяти, затем тот же семантический reader. strong/em, заголовки, списки, код, blockquotes и безопасные ссылки сохранены. Только явные классы `rubric`/`mass-rubric-line` у p обозначают рубрику; обычный курсив и цвет CSS не являются таким сигналом |
| Blockquote | Только самостоятельные bare К./С./Н./Д./Л./Ц./V./R. и двоеточие, с прежними защитами. Обёрнутые метки, отдельные метки и полные обозначения в цитатах автоматически не добавляются. Контейнер, линия, текст и сохранённые `>` остаются |

Инициалы, имена с двоеточием, римские разделы без достаточного контекста, повествование, ссылки, код, списки, заголовки и явные рубрики сохраняют защитные исключения. Обычные `_Молімся._`, `_Вітай, Марыя…_`, курсивные ответы литании не превращаются в рубрики. Двоеточия не удаляются при чтении; canonical rewrite и нормализация сохранения веба не перенесены в мобильный редактор.

Точный словарь: `Усе ўстаюць.`, `Усе кленчаць.`, `Усе садзяцца.`, `Усе моляцца ў цішыні.`, `Святар кажа:`, `Святар гаворыць:`, `Цэлебрант кажа:`, `Цэлебрант гаворыць:`, `Народ адказвае:`, `Усе адказваюць:`, `Кантар спявае:`, `Дыякан кажа:`, `Лектар чытае:`. Поиск ключевых слов и расширенный assisted autofix не используются.

`PrayerContent` общий для чтения и локального предпросмотра. `prayer_legacy.dart` переносит ограниченную read-only проекцию веба; `prayer_legacy_html.dart` преобразует безопасное наследуемое представление. Raw HTML канонического Markdown по-прежнему экранируется. Script/style/iframe/object и другие активные элементы удаляются, опасные URI/атрибуты не сохраняются, внешние изображения не загружаются. Политика безопасных URI Flutter остаётся строгой; произвольный CSS старого HTML не переносится в reader, как и в веб-пути Turndown.

Различий по согласованным правилам отображения 1.1 не осталось в проверенном наборе. Это семантический паритет интерпретации, без требования одинаковых HTML-байтов и платформенной типографики. Ограничения внутри цитат — часть общего контракта, а не отложенная возможность Flutter. Непроверенная пунктуация/алфавиты и повреждённый курсив не исправляются догадками.

## Тесты и сравнение с вебом

[prayer_11_web_oracle.json](../test/support/prayer_11_web_oracle.json): **342 случая**, HTML-эталоны сгенерированы непосредственно pinned веб-рендерером. Это синтетические комбинации десяти обозначений, разных обёрток и двоеточий, whole/multiline emphasis, подтверждённого/неподтверждённого диалога, всех 13 указаний, отрицательных контекстов, обезличенные формы из веб-fixture и десять вариантов старого HTML. Приватные молитвы и Firestore snapshot не использованы.

Flutter-тест сравнивает видимый текст, последовательность меток/data-role, рубрики, author emphasis, href/title, заголовки, количество цитат/переносов и код с фактическим HTML веба. Эталоны не вычисляются из Flutter-реализации. Для регенерации нужен локальный MyBrev checkout на указанном SHA с его установленными npm-зависимостями:

```powershell
node tool/generate_prayer_11_oracle.mjs <path-to-pinned-mybrev>
```

Генератор проверяет HEAD и отсутствие изменений веб-рендерера относительно SHA, не импортирует Firebase и не обращается к сети/данным. Результаты сравнения: **342/342 совпали**.

Профильный запуск десяти suite: **443 теста прошли** (2:06). Включены 342 эталона + проверка SHA, безопасность и widget-стили 1.1, существующие parser/widget/bundle, BE/LA/EN Mass semantics/ritual/reader и Prayerbook stage5.

```powershell
flutter test test/prayer_11_parity_test.dart test/prayer_11_safety_widget_test.dart test/prayer_formatting_test.dart test/prayer_formatting_widget_test.dart test/prayer_formatting_bundle_test.dart test/prayer_markdown_test.dart test/mass_semantics_test.dart test/mass_ritual_test.dart test/mass_reader_test.dart test/prayerbook_stage5_test.dart --concurrency=1 --reporter expanded
```

После последней поправки курсива рубрик повторно прошли все **14** затронутых safety/widget тестов (0:33). Они проверяют красную жирную метку без курсива, обычный цвет слов с author emphasis, размер 28.8 (180%), 320 px, обе темы, HTML/Markdown, неизменность источника и общие reader/preview styles. Последняя правка dev harness маршрутизирует предпросмотр контрольной молитвы 1.1; реальный редактор и предпросмотр этого источника затем проверены в Chrome.

`dart format --output=none --set-exit-if-changed` — 8 изменённых Dart-файлов, 0 изменений. `flutter analyze` — **No issues found**. Журналы: [443 tests](../audit-evidence/prayer-formatting/unit-widget-11-final.log), [14 after style change](../audit-evidence/prayer-formatting/widget-style-11-final.log), [analyze](../audit-evidence/prayer-formatting/analyze-11-final.log), [format](../audit-evidence/prayer-formatting/format-11-final.log).

Первые попытки столкнулись с заполненным диском/нехваткой памяти; удалены только известные устаревшие файлы компиляции этой задачи, тесты выполнены последовательно. Ошибка промежуточного HTML-summary для pre исправлена сравнением DOM непосредственно сохранённого эталонного HTML. Условия тестов и правила не ослаблялись. Полный suite всего репозитория в этом этапе не запускался; прежний ограниченный broad-run описан в историческом отчёте 1.0.

## Chrome visual smoke — выполнен

Команда по постоянному [AGENTS.md](../AGENTS.md):

```powershell
flutter run -d chrome -t tool/prayer_formatting_smoke.dart --web-port 5237
```

Google Chrome **155.0.8059.40**, точный URL **http://localhost:5237/**. Широкий reader просмотрен через CDP Chrome, запущенного Flutter. При изменении viewport/DPR этого экземпляра захват стал нестабильным; пустые и обрезанные диагностические кадры не засчитаны. Без повторного Flutter launch открыта управляемая Playwright вкладка отдельного **headed Google Chrome** по тому же URL, с фиксированными **320×1000, DPR 1**. В ней выполнен весь узкий smoke. 180% установлены обычным регулятором reader; снимок показывает 180%. Все окончательные снимки настоящие, получены и просмотрены, а не заменены сборкой/headless widget-тестом.

**21 новый PNG** в `audit-evidence/prayer-formatting/`, список размеров/хешей и итоговые состояния: [chrome-smoke-11-results.json](../audit-evidence/prayer-formatting/chrome-smoke-11-results.json). Pageerror/console error в проверенных сценариях: **0**.

| Состояние | Новые снимки |
| --- | --- |
| Обёрнутые метки, авторская жирность/курсив; широкое окно | [light](../audit-evidence/prayer-formatting/chrome-11-light-wide-labels.png), [dark](../audit-evidence/prayer-formatting/chrome-11-dark-wide-labels.png) |
| Все формы 1.1, исходный размер, 320 px | [light](../audit-evidence/prayer-formatting/chrome-11-light-320-labels.png), [dark](../audit-evidence/prayer-formatting/chrome-11-dark-320-labels.png) |
| Реальный регулятор, 180% | [control](../audit-evidence/prayer-formatting/chrome-11-font-180-control.png) |
| Метки и whole/multiline emphasis, 320 px / 180% | [labels](../audit-evidence/prayer-formatting/chrome-11-dark-320-180-labels.png) |
| Отдельные метки, Усе:/Цэлебрант:, точные рубрики и обычный курсив | [dialogue](../audit-evidence/prayer-formatting/chrome-11-dark-320-180-dialogue.png) |
| Bare-цитата красная, обёрнутая метка и полное обозначение без роли, именованная атрибуция | [dark](../audit-evidence/prayer-formatting/chrome-11-dark-320-180-quotes.png), [light](../audit-evidence/prayer-formatting/chrome-11-light-320-180-quotes.png) |
| Настоящий локальный редактор: исходные wrappers/переносы | [editor](../audit-evidence/prayer-formatting/chrome-11-local-editor-320.png) |
| Тот же источник в предпросмотре / 180% | [top](../audit-evidence/prayer-formatting/chrome-11-local-preview-light-320-180.png), [light quotes](../audit-evidence/prayer-formatting/chrome-11-local-preview-light-quotes.png), [dark quotes](../audit-evidence/prayer-formatting/chrome-11-local-preview-dark-quotes.png) |
| Старый HTML: роли, обычный курсив, явная рубрика, quote, script удалён | [legacy](../audit-evidence/prayer-formatting/chrome-11-legacy-dark-320-180.png) |
| Переход по настоящей HTML-ссылке к другому ID, затем возврат | [target](../audit-evidence/prayer-formatting/chrome-11-legacy-link-target-320-180.png) |
| Реальная публичная «Тваёй абароне», 320 px / 180% | [dark](../audit-evidence/prayer-formatting/chrome-11-real-short-dark-320-180.png), [light](../audit-evidence/prayer-formatting/chrome-11-real-short-light-320-180.png) |
| Реальная «Літанія да Духа Святога», курсив формул/ответов и прокрутка до последнего Н. Амэн. | [start](../audit-evidence/prayer-formatting/chrome-11-real-litany-light-320-180.png), [middle](../audit-evidence/prayer-formatting/chrome-11-real-litany-middle-320-180.png), [light end](../audit-evidence/prayer-formatting/chrome-11-real-litany-end-320-180.png), [dark end](../audit-evidence/prayer-formatting/chrome-11-real-litany-dark-end-320-180.png) |

## Границы работы

Firestore, contentManifest, `assets/content` / app bundle и отдельный семантический renderer Святой Мессы не изменены. Mass отключает общую проекцию 1.1, его существующие BE/LA/EN тесты прошли. Права доступа и маршрутизация производственных молитв не менялись. Harness использует существующий публичный bundle и memory-only overrides, без Firebase/Hive, сохранения в production и публикации контента.

Android-эмулятор не запускался. Native smoke для этой общей UI/parser правки не выполнялся; перед мобильным выпуском нужен отдельный native smoke. Merge, deploy и мобильный релиз не выполнялись. Полный паритет чтения 1.1 не является разрешением на массовую миграцию или обновление bundle.