# Flutter: календарь Беларусі 06.11.2026 — кандидат для приёмки

Задача: [ibreviarybyapp#75](https://github.com/senddownrain/ibreviarybyapp/issues/75).
Календарные решения приняты владельцем задачи; старые годовые Ordo не используются для переопределения PDF.

## Статус источника и выпуска

Эталон: «Уласны каляндар дыяцэзій на Беларусі», 06.11.2026, SHA256
`a55dc34c89317bd0a4b683ea84b46941213aa2b981d0a9de1fe3ebeb71dc9696`.
Источник приёмки — issue #75 и Web [#201](https://github.com/senddownrain/mybrev/pull/201),
с исправлением [#217](https://github.com/senddownrain/mybrev/pull/217), commit
`7a5fb196c129814d1be436d57cbce368eafb91fd`.
Новый HEAD #217 `d00dff03a11cb82fcb8bb9b957923280328a79b8` также проверен:
используемые calendar/engine/generator/PDF/reference пути побайтно идентичны зафиксированному commit
(`reports/belarus-approved/web-head-equivalence.json`).
Точное содержание проверено по 262 строкам Web PDF extraction, включая исходные цитаты,
страницы и sourceSha256. Матрица Flutter: **959/959** effective ID/date/rank, 0 fixed extras.

**Это Draft, не готовый store release.** При начале работы #201 слит, #217 открыт как Draft.
В #217 явно указано, что Firestore revision3→4 (отдельный sealed 71-op batch) ещё не завершён,
а удаление двух декабрьских назначений должно публиковаться отдельно под revision5 после revision4.
Здесь воспроизведена окончательная календарная модель #217, но не заявляется, что она уже опубликована.
В bundled metadata оставлена revision4 из Web #217; revision5/publishedAt не выдуманы.
В `reports/belarus-approved/source.json` явно отмечены candidateOnly и serverPublicationVerified=false.

Live Firestore reads/writes, публикация contentManifest, Hosting deploy, merge и публикация в магазины
не выполнялись. В Web checkout нет private snapshot; для локального воспроизводимого анализа
использован snapshot из уже поставляемого Flutter bundle с календарным overlay из принятого Web source.
Это не доказательство паритета с ещё не опубликованным production Firestore.

## Изменения

- Постоянные определения перенесены целиком из #217. Старые дополнительные документы определений
  сохранены выключенными; собственные `days`, `liturgicalProperTexts`, `readings` и остальные
  текстовые коллекции сохранены **побайтно**. Juan Diego и Guadalupe убраны из календарных назначений;
  их существующие Proper документы сохранены.
- Сохранены четыре выключенных ручных переноса и 23 скрытых местных назначения.
  Существующие материализованные auto-transfers пересчитаны Web-алгоритмом; непроверенный
  auto record не может переопределять исправленную общую норму. Bobola Пинск: 17.05.2027/2032.
- Mother Church подавляет другие воспоминания; при коллизии Immaculate Heart два воспоминания
  становятся optional с weekday primary. Убрано временное исключение High Priest «оба праздника».
- `validFrom`/`validUntil` применяются при размещении дней: Newman не появляется в 2025.
  Рождественская граница GNLYC 33/39: 24 декабря (включая воскресенье Адвента) имеет I Vespers Рождества.
- Braslau сохраняет собственную identity/молитву, наследуя существующие тексты Nativity.
  Старые ссылки Nativity/Braslau и сохранённый выбор ведут к действующей диоцезальной опции.
- `ContentStore.commit` отклоняет старую/неизвестную календарную schema и регрессию revision;
  изменение definitions требует большей revision. При старом overlay, в том числе скачанном позже
  нового bundle, runtime выбирает bundled calendar целиком. Новый commit обновляет engine и открытый день.
  Пока не декодированы все календарные слои, старый overlay не становится календарём.
  Atomic staging/recovery сохраняются.
- Деталь Ordo вычисляет выбор Office по собственной дате/диоцезиям; она больше не подписана
  на ленивый глобальный выбор скрытого Hours root. Устранено уведомление скрытого экрана
  во время build при переходах Ordo → Hours и смене дня (поймано Chrome smoke).
- Для позднего Адвента перенесены Web-правила источников Office: воскресный period Office,
  текущий псалтирь буднего дня, собственные Benedictus/Magnificat и антифоны.
  I Vespers сохраняет O-антифон гражданского вечера. Таблица источников генерируется из Web,
  её исходные SHA256 записаны в `reports/belarus-approved/office-sources.json`.
- Ветка включает актуальный проверенный `main` (`1a628b9197d481c0495cb944d4ce127357fa3a54`),
  в том числе Marian Hours и общий сборщик I Vespers из #60, canonical Juan Diego из #100,
  review prompt и triage UI. Удалён общий skip Hours parity и исключения route ID в Readings:
  расхождения теперь действительно проверяются и приводят к красному тесту.

## Границы паритета

959 календарных назначений и правила выбора Ordo проверяются отдельно от содержимого Office.
Web oracle сгенерирован независимым Web pipeline из **того же** локального snapshot, что bundle;
это позволяет проверить календарную миграцию без изменения литургических текстовых документов.

После включения актуального `main` обнаружены отличия от Web #217 в Hours:
идентификаторы документов Mother Church и сборка Immaculate Heart/Marian Common из #60.
Кроме того, существующий принятый Flutter Proper Христа Первосвященника сохраняет исходный HTML
и полную заключительную формулу молитвы, тогда как общий Web oracle содержит другое представление
и сокращённую формулу. Подмена этих текстов ради совпадения хешей нарушает уже существующие
`high_priest_daytime_parity_test` и `high_priest_minimal_patch_test`, включая будущий updater patch.
Эта подмена не входит в окончательный diff. Специализированные проверки полного Proper и
минимального reference-only обновления выполнены повторно после её удаления.

Расхождения не объявлены допустимыми исключениями: общий Hours parity остаётся красным.
До приёмки нужен согласованный Web/Flutter источник этих Office и повторный полный паритет.
Проверка текстовых хешей общего Hours-теста охватывает только дни с одинаковой структурой карт;
на остальных датах отчёт фиксирует structural mismatch, а не утверждает совпадение текстов.
В Readings сравниваются также default screen, все legal option routes, наборы, циклы и sections hashes;
старые route-ID исключения не скрывают результат.

## Выполненные проверки

| Проверка | Результат |
|---|---|
| PDF inventory | 262 строки → 959 назначений, exact ID/rank/fixed date, 0 extras |
| Ordo 2025–2035 × 4 | 16 068 дат, 0 расхождений по всем 18 полям, включая primary/alternatives/suppressed и решение I/II Vespers |
| Readings references | 16 068 дат, 0 расхождений |
| Readings screen | 16 068 дат / 20 700 legal options / 155 486 sections: 0 content/sets/cycle mismatches; **38 route-day-id mismatches**, тест FAIL |
| Hours | 16 068 дат; 37 508 сравнённых сборок; **70 structural / 44 text mismatches**, тест FAIL |
| Целевые проверки после merge main | 47 PASS: inventory, cache/update, picker, Hours и Marian/vespers regressions |
| Полный Proper High Priest / minimal patch / Advent | Повторно 14 PASS после сохранения принятого полного текста |
| Навигация и вечерний Office | 51 PASS: Ordo → Hours, Christmas I Vespers, Grodno solemnity I Vespers и регрессии |
| Web `npm run test:ordo` | 220 PASS / 8 SKIP / 0 FAIL на зафиксированном Web source |
| Полный доступный Flutter suite, parity отдельно | 1950 PASS / 9 SKIP / 3 FAIL; подробности и повторная проверка ниже |
| Дополнительные opt-in прогоны | Local analytics 8 PASS / 1 обратный flag SKIP; HTTP/R02 17 PASS, включая loopback Worker/SQLite и kill-switch |
| `dart format` | 28 изменённых Dart-файлов, 0 дополнительных изменений форматтера |
| `flutter analyze --no-pub` | 0 errors / 0 warnings / 29 info; стандартная команда exit 1 |
| `flutter analyze --no-pub --no-fatal-infos` | Exit 0, те же 29 info в существующих feedback/pastors/analytics/reader файлах |
| Chrome visual smoke после merge main | 36 состояний / 34 различных PNG; 0 Flutter/JS errors; 0 внешних запросов |
| Android visual / установка поверх старого APK | **BLOCKED**: нет Android SDK, AVD, подключённого Android; команда integration test не нашла устройство |

Hours: 44 structural случая Mother Church (document/template identity) и 26 Immaculate Heart
(Common/Proper assembly из актуального #60). Все 44 text mismatch относятся к High Priest,
один день × 11 лет × 4 диоцезии. Это не ошибки матрицы PDF и не основание менять утверждённые ранги.
Тесты не пропущены и ожидают ноль; их красный результат сохранён в machine-readable отчёте.

Все 38 Readings mismatches — `mary-mother-church` → `feast-marymotherchurch` в route ID;
это та же document identity из актуального #60. Сами reading groups, документы, sets, cycles
и все сравниваемые sections hashes совпали. Route-проверка остаётся строгой и красной.
`reports/belarus-approved/parity-matrix.json` содержит все 44 пары диоцезия/год,
проверенные количества и фактические расхождения; итог **DIFFERENCES_REQUIRE_REVIEW**.
В raw Readings report часть bundle metadata унаследована из исторического readings delivery fixture;
actual candidate manifest записан отдельно в matrix, digest/count Readings проверены на совпадение.

Полный Flutter suite запускался без четырёх parity-файлов, которые выполнялись отдельным полным
прогоном; их skip из main удалён. Из трёх failures общего прогона два относились к временному
High Priest overlay, нарушавшему принятый исходный Proper. Overlay удалён, все три High Priest
файла вместе с Advent повторно дали 14 PASS. Исходный общий лог сохраняет эти failures и не
выдаётся за полностью зелёный запуск окончательного дерева.
Оставшийся `discovery/p0_hints_screens_test.dart` → `date_navigation: three day arrows, once`
воспроизводится на исходной базе `729f17a` (14 PASS / 1 FAIL); calendar branch его не исправляет.
Baseline и итоговые логи сохранены в `reports/belarus-approved/logs/`.
Девять исходных skips — compile-time opt-in local analytics и локальный R02 HTTP endpoint;
календарные и parity-тесты в это число не входят.
Они дополнительно выполнены с `ANALYTICS_LOCAL=true` и локальным Web Worker на `127.0.0.1:8875`,
с отдельным scratch SQLite и тестовым admin token: 8 и 17 PASS соответственно. Единственный skip
дополнительного прогона — обратная ветвь «flag выключен», уже пройденная общим suite.
Внешний analytics endpoint не использовался.

Chrome: использованы реальные production router/providers и bundled content, Firebase не инициализируется.
Проверены все четыре диоцезии и возврат Витебск → другие → Витебск, ключевые даты из задачи,
декабрь 2026/2027, Hours/Readings/month, прокрутка, reload с persisted Hive.
Viewport 390 px/light/×1 и 320 px/dark/×1.8. Внешняя сеть блокируется; CanvasKit и шрифты
отдаются из локального SDK. Реальные PNG просмотрены для Ordo и обоих reader roots с крупным шрифтом.
`audit-evidence/belarus-approved/{results,provenance}.json` фиксируют сценарии и исходный commit.
Это Flutter Web в Chrome, **не Android**.

Hive upgrade-проверки охватывают revision3, конфликтующую revision4, неизвестную schema99,
кэш с будущим timestamp, принятие большей revision5, повторный запуск, обновление уже открытой даты,
декодирование слоёв на старте, удалённый saved option и диоцезальные старые deep links.
Они не доказывают обновление установленного подписанного Android-приложения без очистки данных.

## Проверенные ранги

| Дата / назначение | Минск | Гродно | Пинск | Витебск |
|---|---|---|---|---|
| 02.07 Budslav | solemnitas | optional | optional | festum |
| 05.07 Trakai | — | memoria | — | — |
| 08.09 | Nativity festum | Nativity festum | Nativity festum | Braslau festum |
| 12.11 Josaphat | festum | memoria | festum | solemnitas |
| 16.11 Ostra Brama | memoria | solemnitas | memoria | memoria |
| Effective назначений | 238 | 244 | 238 | 239 |

Все остальные ранги и fixed dates проверены exact-inventory тестом, а не только этой таблицей.
Подвижные Ash Wednesday/Palm Sunday/Easter/Ascension/Pentecost сохранены.
2033: общий алгоритм даёт 25 июня для Nativity John Baptist; специальное решение остаётся needs-review,
не выдаётся за установленную универсальную норму. PDF 10.12 `Латэранскай` / приложение `Ларэтанскай`
(Loreto) сохранено как source-title discrepancy, без самостоятельного исправления.

## Воспроизведение

```sh
node scripts/refresh_approved_calendar.mjs --web ../mybrev \
  --work /absolute/path/to/new-private-scratch \
  --expect-web-commit 7a5fb196c129814d1be436d57cbce368eafb91fd --allow-unmerged-web
# Скрипт вызывает канонический npm run content:app-bundle в Web checkout.
# Тот же scratch snapshot для независимого Web engine/Hours/readings oracle:
cd ../mybrev
npm run ordo:flutter-fixture -- --snapshot /absolute/path/to/new-private-scratch \
  --from 2025 --to 2035 --out ../ibreviarybyapp/test/fixtures/ordo_parity.json.gz
cd ../ibreviarybyapp
ORDO_PARITY_REPORT=1 HOURS_PARITY_REPORT=1 flutter test --concurrency=2 --timeout=5m
flutter analyze
flutter run -d chrome -t tool/approved_calendar_smoke.dart --web-port 5242
# Attach smoke runner to that Chrome CDP; PLAYWRIGHT_MODULE and FLUTTER_ROOT
# can point to local tools. The harness never initializes Firebase.
node scripts/smoke_approved_calendar.cjs
flutter test integration_test/calendar_ordo_refinement_test.dart -d <android-device>
```

Для полного Readings-screen паритета (включая sections/text hashes) дополнительно:

```sh
node scripts/lectionary/build_parity_fixture.mjs --web ../mybrev \
  --snapshot /absolute/path/to/new-private-scratch --from 2025 --to 2035 \
  --out test/fixtures/lectionary_parity.json.gz --allow-unmerged-web \
  --expect-web-commit 7a5fb196c129814d1be436d57cbce368eafb91fd
LECTIONARY_REPORT=reports/flutter-lectionary-parity.json flutter test test/lectionary_parity_test.dart
node scripts/summarize_approved_parity.mjs
```

Compressed JSON и hashes не редактировались вручную. Генератор проверяет source digest,
валидацию каждой коллекции и сохранность всех остальных content digests; canonical encoder/gzip
пересобирает четыре календарные коллекции. Новый manifest берётся из его результата.
Snapshot содержит только public app content, находится вне Git; сервисные ключи не использованы.
Полные SHA256 bundle/fixture и матрица — в `reports/belarus-approved/`.

## Приёмка и публикация

Перед признанием паритета полным устранить 70/44 Hours и 38 Readings route-ID расхождений
на согласованном Web/Flutter Office source, сохранив принятый полный Proper, и повторить строгие
parity-тесты. Общий suite также должен получить зелёный результат, включая существующий date hint failure.

1. Подтвердить завершённый отдельный sealed Firestore revision4 release; не добавлять в него декабрьские операции.
2. Принять/опубликовать #217 и отдельный controlled revision5 patch двух enabled entries с новым dry-run,
   preconditions и rollback. Эта Flutter-ветка не выполняет серверные операции.
3. По фактическому final snapshot повторить canonical bundle build и parity 2025–2035.
   Сверить revision/sourceSha256, четыре calendar digests, manifest и hash каждого документа;
   meta должна соответствовать фактически опубликованной revision5 (или следующей принятой ревизии).
   `npm run content:app-release -- --snapshot <final-snapshot> --out <candidate> --compare-live`
   должен подтвердить опубликованный contentManifest перед сборкой для магазинов.
4. На Android выполнить обновление поверх предыдущего подписанного build без очистки данных,
   airplane mode/restart, старый cache, все четыре диоцезии, Hours/Readings/deep links и I/II Vespers;
   добавить нативные screenshots. Локальные Hive-тесты не заменяют этот проход.
5. Отдельная приёмка Draft PR и приложения. Только после неё планировать store release.
   Понижение номера календарной ревизии не является rollback: rollback публикуется с большей revision.
