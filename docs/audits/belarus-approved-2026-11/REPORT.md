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
