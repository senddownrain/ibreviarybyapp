# Заголовки и ритм респонсориев — Flutter Chrome

До: main `66288466d6a6ef8c9bfded22fe63bcc71a1337f3`. После: изменения этого PR. Реальные снимки Flutter Web в Chrome/Chromium 156, Flutter 3.41.4 / Dart 3.11.1, viewport 390 × 1000. Использован существующий `tool/doxology_smoke.dart`: production router/OraScreen и локальный bundle, offline-provider, без Firebase initialization. Firebase URL дополнительно заблокированы браузерным перехватчиком. Никаких изменений bundle, текстов, Firebase или Web-репозитория.

Снимки просмотрены. Ютрань, Нешпары и Гадзіна чытанняў: одинаковый ReaderTheme для заголовков, меньшая ссылка без uppercase, красные К./Н./*, обычная высота строки, переносы длинных реплик и вертикальная прокрутка. В крупном шрифте строка заголовка/ссылки штатно переходит в колонку; наложений и горизонтального переполнения не обнаружено. Система переносов слов не изменялась. Позиция прокрутки снимков может отличаться из-за изменившейся высоты блоков.

| Светлая тема, обычный шрифт | До | После |
| --- | --- | --- |
| Ютрань: чтение + короткий респонсорий | [Снимок](before-laudes-light-normal.png) | [Снимок](after-laudes-light-normal.png) |
| Нешпары: чтение + короткий респонсорий | [Снимок](before-vespers-light-normal.png) | [Снимок](after-vespers-light-normal.png) |
| Гадзіна чытанняў: обычный респонсорий | [Снимок](before-lectionis-light-normal.png) | [Снимок](after-lectionis-light-normal.png) |

| Тёмная тема, максимальный Aa | До | После |
| --- | --- | --- |
| Ютрань: заголовок короткого чтения | [Снимок](before-laudes-dark-large.png) | [Снимок](after-laudes-dark-large.png) |
| Нешпары: заголовок короткого чтения | [Снимок](before-vespers-dark-large.png) | [Снимок](after-vespers-dark-large.png) |
| Ютрань: короткий респонсорий | — | [Снимок](after-laudes-responsory-dark-large.png) |
| Нешпары: короткий респонсорий | — | [Снимок](after-vespers-responsory-dark-large.png) |
| Гадзіна чытанняў: обычный респонсорий | — | [Снимок](after-lectionis-dark-large.png) |

Воспроизведение (Chrome, без production):

```sh
flutter devices
flutter run -d chrome -t tool/doxology_smoke.dart --web-port 5241 --web-hostname 127.0.0.1 --no-web-resources-cdn
```

Точный URL: `http://127.0.0.1:5241/?date=2026-11-16&dayId=ordinary-w33-d2&hour=laudes&theme=light`. Повторить с `hour=vespers`, `hour=lectionis`, затем `theme=dark&scale=large`. Существующий smoke-only bridge `highPriestScrollTo('@any:КАРОТКАЕ ЧЫТАННЕ')`, `highPriestScrollTo('@any:КАРОТКІ РЭСПАНСОРЫЙ')` или `highPriestScrollTo('@any:РЭСПАНСОРЫЙ')` позволяет дойти до нужного блока; после загрузки шрифтов повторить прокрутку. Linux headless запуск использовал Chrome wrapper с `--headless --no-sandbox --disable-dev-shm-usage` и подключение к этому же экземпляру по CDP.

Проверки: `dart format` затронутых секций/тестов; `flutter analyze --no-fatal-infos` — exit 0, ошибок/предупреждений нет (29 информационных замечаний существующего проекта); 121 целевой тест прошёл (office_responsory_formatting, liturgical_visual_contract, liturgical_html, liturgical_screen_smoke, liturgical_alternatives, reader_theme). После последней защиты от потери текста между заголовком и ссылкой повторены 62 теста normalizer + настоящих экранов — все прошли. Новый набор проверяет девять форматов HTML, регистр ссылки, сохранность текста/inline-разметки, отсутствие межабзацного интервала при 16/24 и одинаковые TextStyle реальных заголовков экранов.

Native smoke не запускался: изменения только общего форматирования/вёрстки, без плагинов или нативных возможностей. Перед отдельным мобильным релизом требуется обычная проверка на устройстве. Merge, release и deploy не выполнялись; снимки оставлены для визуального ревью владельцем.
