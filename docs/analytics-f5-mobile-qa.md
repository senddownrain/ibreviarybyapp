# F5 — мобильная QA аналитики v2 (Android + iOS Simulator, локальный mock-ингест)

Дата: 2026-11-01. База: `main` @ `6d83b53`. Только локальный Worker (`127.0.0.1`), **без Cloudflare, Firebase и production**;
реальный сбор у пользователей не включался. Сервер после QA выключен (`503 ingest_disabled`), процесс остановлен.

## Итог

| Проверка | Статус |
|---|---|
| Android API 34 (эмулятор `MyBrev_Test_API34`), QA-сборка → mock-ингест | **PASS** |
| iOS Simulator (`an-f5-iphone`, клон `cd-s6-iphone`), QA-сборка → mock-ингест | **PASS** |
| Раздельные `platform=android` / `platform=ios` в хранилище | **PASS** (по 23 ячейки; 40 и 33 события) |
| Запрещённые поля / заголовки в пакетах | **PASS** (см. «Скан») |
| `sd=fit` на короткой песне (Android, iOS) | **PASS** при свежем открытии; см. находку 2 |
| Kill switch OFF → 503, без повторной отправки (обе платформы) | **PASS** |
| Обычный Android release без флагов: нет endpoint/отправителя, 0 запросов | **PASS** |
| Обычная iOS-сборка без флагов (debug на симуляторе): endpoint не в бинарнике, 0 запросов | **PASS** (ограничение: iOS release/profile на симуляторе Flutter не собирает) |
| `flutter analyze --no-fatal-infos` | **PASS** (exit 0, только info) |
| `flutter test test/analytics` | **PASS** (+84 ~9) |
| полный `flutter test --concurrency=2` | **PASS** на `6d83b53`: +1698 ~9, exit 0 (до добавления debug-диагностики, см. «Изменение кода») |
| Панель k≥5 (скрытие n<5) на мобильных данных | **NOT TESTED** (панель не запускалась; синтетика k<5) |
| HTTPS staging / Cloudflare / D1 | **NOT TESTED** (вне задачи) |
| Физический телефон, TalkBack, VoiceOver, батарея/плавность на устройстве | **NOT TESTED** |
| Нативный smoke Android/iOS для релиза | нужен перед релизом (эта QA — только аналитика) |

## Окружение

* Flutter 3.41.4; Worker — `mybrev` `origin/main` @ `5d5e10c`, `experiments/analytics-ingest/worker/local-server.mjs`
  с SQLite вместо D1 (копия вне репозитория; добавлен только журнал запросов: метод, URL, **имена** заголовков, статус, тело
  — см. `docs/analytics-evidence/f5/local-server-logged.mjs`). Токены в журнал не пишутся; тестовые токены — одноразовые, не секреты.
* Android: `adb reverse tcp:8788 tcp:8788`. iOS Simulator делит loopback с Mac.
* Сборки (debug, т.к. нужен `[analytics-local]` лог; AOT-проверка — отдельно release):

```bash
export PATH=/Users/gleb/.cache/flutter-3.41.4/bin:$PATH
# сервер (из mybrev @ 5d5e10c; INGEST_ENABLED=true; REQ_LOG=файл журнала)
INGEST_ENABLED=true REPORT_TOKEN=… ADMIN_TOKEN=… REQ_LOG=/tmp/req.jsonl node local-server-logged.mjs --port 8788 --db /tmp/f5.sqlite
adb reverse tcp:8788 tcp:8788
flutter run -d emulator-5554 --debug --no-resident --dart-define=ANALYTICS_LOCAL=true --dart-define=ANALYTICS_STAGING=true --dart-define=ANALYTICS_STAGING_URL=http://127.0.0.1:8788
flutter run -d <udid an-f5-iphone> --debug --no-resident <те же --dart-define>
# kill switch
curl -X POST 127.0.0.1:8788/v2/admin/ingest -H "Authorization: Bearer $ADMIN_TOKEN" -d '{"enabled":false}'
```

## Сценарии (одинаково на обеих платформах)

Ютрань (прокрутка) → Малітоўнік → Спеўнік → короткая песня «Аллелюя» (избранное) → смена темы на тёмную и шрифта →
Біблія (Быццё 1) → уход в фон (HOME; на Android также системная «назад» с корня).
Пакеты уходят **на `paused`** (уход в фон), одним POST на день, ответ 204.

Принято сервером (`mock-ingest-requests.jsonl`): 8 × `204` (6 android, 2 ios), 2 × `503` (по одному на платформу после OFF).
Хранилище: `platform=android` 23 строки / 40 событий, `platform=ios` 23 строки / 33 события. Присутствуют `screen_view`
(today, hours/`hour:laudes`, songs, bible `bible:bel:gn`, settings, about), `text_read` (fv, sd, er), `catalog_open`
(`prayers_home`, `songs`), `feature_use` (`favorite_add`, `theme_change`, `text_scale_change`).
`sd=fit` у `song:holysongs-47aac31ac301c3c2d79c` (текст целиком виден) — на обеих платформах; при крупном шрифте тот же текст
даёт `p75_99`, у длинных песен/Ютрани — `p0_25`…`p75_99` (поведение корректно).

### Скан запрещённых полей
Верхний уровень каждого тела ⊆ {`schema_version`,`day`,`platform`,`app_version`,`region`,`cells`}; ключи ячеек ⊆
{`e`,`n`,`section`,`content_id`,`metric`,`bucket`,`catalog_id`,`feature_id`}. Нет user/device/session id, IP, URL, текстов, поиска,
времени с точностью до секунд. Заголовки клиента: `content-type`, `accept-encoding` (стандартный `HttpClient`), `content-length`,
`host`; нет cookie, авторизации, User-Agent. `region` = `UNKNOWN`.

## Kill switch
Android: OFF → следующий уход в фон = 1 запрос, ответ `503`; затем две серии «действия + фон» — **0 новых запросов**,
локальная очередь очищена (`[analytics-local] []`). iOS: то же — один `503`, потом ещё одна серия без запросов.
В конце сервер OFF (проверено `503 ingest_disabled`).

## Обычные сборки без флагов
* Android `flutter build apk --release` (81,5 МБ): в `libapp.so` (arm64, armv7, x86_64) нет `v2/ingest`, `127.0.0.1`, `ANALYTICS`,
  `StagingSender`, `HttpStagingTransport`, `analytics-local`. Единственные совпадения «8788» — хеш и имя символа.
  Запуск на эмуляторе при включённом сервере: Ютрань, каталог, Біблія, фон — **0 запросов** к mock; приложение работает.
* iOS (debug на симуляторе, без флагов): `127.0.0.1:8788` в `kernel_blob.bin` отсутствует (в debug-ядре остаётся код отправителя,
  но флаги `false`, адреса нет); запуск, переход, уход в фон — **0 запросов** при включённом сервере.
* Размер/плавность/батарея на устройстве — **NOT TESTED**.

## Находки
1. **(Диагностика, исправлено в этом PR)** Исключения и не-204 в `StagingSender` проглатывались без следа: первый заход
   на Android дал 0 запросов, причину не удалось найти по логам. Добавлен `debugPrint` под `kDebugMode`
   (в release отсутствует). После пересоздания `adb reverse` и переустановки отправка заработала; первопричину
   первого нуля **не доказал** (вероятно, устаревший reverse после перезапуска adb-демона / убитый установкой GMS процесс).
2. **(Не исправлено, вне границ)** Если песня уже открыта, на неё возвращаются с экрана «Налады» после уменьшения шрифта (текст теперь помещается),
   визит закрывается как `measurement_error: scroll_unmeasurable` без `sd` (метрик после возврата нет). При свежем открытии `sd=fit` корректен.
   Предложение: пере-измерять при возврате на маршрут. Влияние малое (одна редкая ветка).
3. **(Окружение)** `flutter run` Flutter 3.41.4 при первом запуске автоматически мигрировал `ios/` на UIScene
   (`AppDelegate.swift`, `Info.plist`, `Runner.xcscheme`, `Podfile.lock`, `AppFrameworkInfo.plist`). QA iOS шла с этой локальной миграцией;
   изменения **не закоммичены** и откатаны (`git checkout -- ios`). Ошибки `duplicate-app` не было (запуск и фон чисто, после #45).
4. Android: процесс был убит ОС во время установки GMS (`installPackageLI`) — шум эмулятора, не приложения.
5. Свежий iOS-запуск показывает карточку тура Contextual Discovery («Показаць крокі?») — ожидаемо, не аналитика.

## Изменение кода
Только `lib/analytics/staging_http.dart`: `debugPrint` в двух местах под `kDebugMode`. Поведение отправки, сеть и контракт не изменены.
Повторно после изменения: `flutter analyze --no-fatal-infos` (exit 0), `flutter test test/analytics` (+84 ~9). Полный `flutter test` —
на `6d83b53` до изменения; после него не перезапускался.

## ПРОВЕРКА ЗА 60 СЕКУНД
1. `git diff origin/main --stat` — виден только `staging_http.dart` (+7/−1) и `docs/`; в `ios/` и `lib/` кроме него ничего.
2. `grep -cF '\"platform\":\"ios\"' docs/analytics-evidence/f5/mock-ingest-requests.jsonl` (→ 3: 2×204 + 1×503) и то же с `android` (→ 7: 6×204 + 1×503);
   `grep -cF '"status": 503'` → 3 (2 клиентских после OFF + проверочный POST `{}` в конце).
3. Откройте `docs/analytics-evidence/f5/c5.png` (Android) и `i4.png` (iOS): короткая песня «Аллелюя» целиком на экране ↔ в журнале
   `"metric": "sd", "bucket": "fit"`. `r1.png` — обычный release без флагов: 0 строк в журнале после его запуска (последние запросы — от QA-сборок).

## Evidence (`docs/analytics-evidence/f5/`)
`mock-ingest-requests.jsonl` (все запросы, без секретов), `local-server-logged.mjs`, скриншоты: `a1` Ютрань Android, `a6` песня,
`a10` тёмная тема/шрифт, `c5`/`d1` песня fit (Android), `b6` Біблія (Android), `r1` release без флагов (Android),
`i4` песня fit (iOS), `i8` тема/шрифт (iOS), `i10` Біблія (iOS), `n1` обычная iOS-сборка без флагов.
