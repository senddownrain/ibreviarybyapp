# Проверка UX prototype 1.1

Проверено 08.09.2026 в браузерной модели iOS и Android. Production Flutter не изменялся.

## Автоматические проверки

`node --test model.test.cjs refinement.test.cjs` — 17 тестов: независимые состояния вкладок и дат, Today, контекст Ora → Readings и обратный переход, templates, scroll keys, favorites, исходный порядок seasonal rules, литургические координаты и календарные даты, полные Bible seed-корпуса и соответствие идентификаторов переводов. `build.mjs` дополнительно проверяет синтаксис browser modules и собирает все локальные ресурсы.

## Интерактивная проверка

| Маршрут / состояние | Результат |
| --- | --- |
| 4 tabs, Hours today, открытие часа | Работают; вкладки сохраняют свой контекст |
| Hours alternatives | Grouped sheet, preview, соседние варианты и templates; sheet остаётся открытым при выборе |
| Другая дата / Today | Календарная сетка сентября, выбор 9 сентября и возврат на 8 сентября одним tap |
| Advanced calendar | Ordinary 23 Wednesday → 9 сентября; Advent 1 Sunday → 29 ноября; exceptional dates доступны |
| Поиск святого | Пётр Клявэр найден по тексту; дата и празднование применяются |
| Ora → Readings → Back | Дата 9 сентября и явный контекст Петра переданы; обратный переход сохраняет office/template |
| Readings / alternatives | Текст открыт сразу; выбор группы и цикла, manual marker и auto |
| Prayerbook | Все 6 Абраныя, единые категории, отдельный All Prayers |
| Categories | Скрытие стандартной, создание пользовательской, изменение состава и сохранение |
| Prayer search | Фильтры скрыты до запроса; «Велічае» находит Magnificat |
| Prayer detail / Aa | Открытие; Aa содержит только размер |
| Bible languages | БЕЛ/РУС доступны сразу; Иоанн корректно остаётся Иоанном при смене перевода |
| Bible picker | Заветы, поиск книги, главы; русский Псалтирь содержит исходные 151 главы |
| Bible reading | Следующая глава, выбор стихов, sky highlight `#4F9FC1`; contextual palette |
| Full / Compact / Hidden | Доступны в studio; Auto даёт Compact в readers, выход из focus виден |
| Long Readings | Auto сворачивает dock при чтении; switching tabs восстанавливает scroll точно |
| Loading / missing / empty / sync error | Демонстрационные состояния и локальный retry работают |
| Seasonal / Marian | Проверены исходные hue, нейтральный reader, отсутствие Android backdrop blur |

Проверены desktop 1440×1050 и viewport шириной 320 px, включая Dark и текст 200%. Горизонтального переполнения страницы и reader не обнаружено. Последние строки длинных Readings остаются выше dock. После переключения вкладок позиция восстановилась без изменения (646.67 px в контрольном проходе). В проверенном проходе browser console errors отсутствовали.

## Пределы проверки

- Это браузерная interaction specification, а не нативные iOS/Android builds. Системный Liquid Glass, VoiceOver/TalkBack, экранная клавиатура, safe-area insets, gestures и реальная производительность требуют проверки на устройствах.
- Годовые параметры календаря доступны для 2026; для других лет отсутствие результата явно показано. Fixture не является нормативным resolver.
- Ora и Readings содержат реальные сокращённые тексты для UX; это не полный литургический контент на каждую дату. Bible seed-корпуса включены полностью.
- Favorites, categories, sync/retry и offline states — локальные демонстрационные данные. Production accounts и storage не подключены.
- Все assets локальны, без CDN; hosted offline cold start без предварительной загрузки и service worker не заявляется.

Решения и полный control audit: `REFINEMENT.md`. Запуск, сборка и источники: `README.md`.
