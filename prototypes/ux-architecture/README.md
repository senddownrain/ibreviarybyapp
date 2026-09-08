# iBreviary UX prototype 1.1

Изолированная браузерная visual/interaction specification. Основа — `docs/ibreviary-ux-handoff.md` и последующее refinement-задание пользователя. Production Flutter, Hive, Firebase и MyBrev не изменяются.

## Открыть

Sites: https://ibreviary-ux-prototype.merlinkarusel.chatgpt.site

Локально из корня репозитория:

```powershell
node prototypes/ux-architecture/serve.mjs
```

Открыть http://127.0.0.1:4178. Сервер слушает только localhost. Можно открыть `index.html` напрямую. Нет CDN, API или npm-зависимостей. Все ресурсы включены. `UX_PROTOTYPE_PORT` меняет локальный порт.

Studio selectors снаружи телефонов: iOS/Android, Light/Dark, Text 100–200%, **Navigation Auto/Full/Compact/Hidden**, **Season**. Сценарии сбрасывают только демонстрационное состояние телефонов. Обычные tabs сохраняют документы, даты, фильтры и scroll positions.

## Маршруты для проверки

1. **Гадзіны:** час открывается одним tap. Alternatives → grouped sheet; переключение празднований, соседних вариантов и office templates без закрытия sheet.
2. **Дата:** date sheet → «Выбраць дату» → календарная сетка → выбранная дата. Hours и Readings независимы. One-tap «Сёння» зафиксировано на **08.09.2026**.
3. **Advanced picker:** дата → «Знайсці літургічны дзень / свята». Год, период/неделя/день, исключительные календарные даты, поиск постоянных/подвижных праздников и святых.
4. **Ora → Чытанні:** сценарий 04: **09.09.2026**, Пётр Клявэр. Передаются дата и явный `dayId`; при наличии связанной группы выбирается она, иначе default даты. Название часа не используется как правило соответствия. Back восстанавливает час, template и позицию. Это следует **последнему refinement-заданию**, уточняющему ранний handoff.
5. **Чытанні:** текст сразу; celebration/cycle вторично; ручной вариант подписан; есть auto. Длинные Readings после начала чтения сворачивают dock до Compact без перерисовки текста.
6. **Малітоўнік:** все Абраныя списком → единые Катэгорыі → Усе малітвы. Поиск в chrome, фильтры раскрываются по запросу. Управление категориями: скрыть/вернуть стандартные, порядок, создать/переименовать/изменить состав/удалить пользовательскую.
7. **Біблія:** последнее место, быстрый БЕЛ/РУС, Старый/Новый Завет, поиск книги, главы внутри списка, previous/next с переходом между книгами. Поиск текста в текущей книге. Выберите номера стихов и цвет: contextual palette заменяет dock.
8. **Reader:** Aa содержит только размер. Focus в меню чтения, выход доступен. Auto: root Full; Ora/Prayer Detail/Bible Compact. Нет общего Android scroll auto-hide.
9. **Season:** Ordinary, Advent, Christmas, Lent, Holy Week, Easter, Red/Martyr, Marian, Solemnity, Requiem. Default — исходное правило контекста. Marian feast голубой; Marian solemnity золотая по production rule order.

Источники, решения, audit controls и removed/hidden controls: **REFINEMENT.md**. Результаты проверки: **QA.md**.

## Граница данных

- Браузерная модель не воспроизводит системный Liquid Glass. Нативные материалы, safe areas, экранная клавиатура, screen readers, gestures и frame timings требуют проверки на устройствах.
- Calendar bounds из production: **2019–2030**. Литургические параметры fixture — **2026** из Flutter test. 349 координат рассчитаны исходным MyBrev; 247 записей постоянных празднований и 13 подвижных. Другие годы без параметров дают явное отсутствие результата.
- Primary — первый отсортированный элемент. Подготовка calendar fixtures повторяет существующую сортировку `LiturgicalContentService`: rank bucket, затем source order. Это не новый нормативный resolver. **TODO Flutter:** отдельный contract primary, пока `sorted.firstOrNull`; не resolver на каждый час.
- Production `ParsedReadingsService.fetchForDate` не изменён и не исполняется браузером. Наборы чтений демонстрационные: реальные евангельские отрывки, не полный набор Мессы. Ora — сокращённые реальные части, не полностью собранный афиций. Это подписано в reader.
- Bible: **полные seed-корпуса — 66 книг БЕЛ и 73 РУС**, все главы и исходные номера стихов. Соответствие переводов следует `BibleRepository.getParallelBook`, включая семь книг только РУС. Пустой стих источника явно помечен, текст не выдумывается.
- Ora/песни: константы `lib/screens/ora_screen.dart`; Marian и два варианта Петра Клявэра из публичных `mybrev/patchs/db-feasts`. Метаданные празднований — только публичные patches. Приватные backups, аккаунты и личные молитвы не выгружались.
- Абраныя, категории и состав демонстрационные. Изменения и позиции — только `localStorage` с префиксом `ibreviary-ux-prototype-v1:`. Localhost и Sites имеют отдельное storage. Production данные не затрагиваются.
- Loading/missing/empty/sync error — проверочные состояния. Повтор sync моделируется локально, сервер не подключён. Offline с доступным текстом штатен, без постоянного banner. Hosted offline cold start/service worker не заявляются.

## Проверка и сборка

```powershell
node --test prototypes/ux-architecture/model.test.cjs prototypes/ux-architecture/refinement.test.cjs
node prototypes/ux-architecture/build.mjs
```

Сборка копирует browser assets и документацию в `dist`. `extract-fixtures.py` и `extract-calendar.mjs` нужны только для повторного экспорта из соседнего MyBrev. Sites использует `.openai/hosting.json` и отдельную копию source checkout; parent Flutter repository в Sites не коммитится.
