# Firebase Spark: проверка Flutter, 12.10.2026

Рабочая ветка: `feature/priest-access-firebase-spark`, исходный Flutter HEAD
`94fbc08`. Реализация использует общий Firebase проект и контракт mybrev из
`codex/priest-spark`; production deploy, push и публикация приложения не выполнялись.
Параллельные изменения календаря, ORDO и Readings в коммит этой задачи не входят.

## Изменения

- `lib/services/firebase_priest_access.dart`: первоначальная активация атомарным
  WriteBatch — закрытый `priestActivationClaims/{uid}` с proof и безопасный для
  чтения владельцем `priestDeviceGrants/{uid}` без proof. Самостоятельное создание
  одного документа, чтение claims и старый writer отсутствуют. Серверные snapshots
  с `isFromCache` или `hasPendingWrites` не подтверждают доступ. Логи SDK отключены.
- `lib/providers/priest_access_provider.dart`, `lib/services/priest_access_gateway.dart`:
  незавершённая очистка старого proof-bearing grant временно скрывает материалы,
  сохраняет Auth UID и повторяет проверку; не считается окончательным отзывом.
- `lib/content/content_bundle.dart`, `content_store.dart`, `content_migration.dart`,
  `lib/services/hive_service.dart`: однократная очистка старых публичных Hive и
  Firestore кешей по проверенному списку перемещённых ID, включая документы со
  старыми ложными публичными флагами. Удалённые Hive frames компактируются.
  Избранные ID, локальные пользовательские молитвы и настройки сохраняются.
  Позднее возвращённый сервером в публичную коллекцию ID не блокируется навсегда.
- `assets/content/prayers.json.gz`, `prayerCategories.json.gz`, `manifest.json`:
  безопасный публичный пакет из существующего локального snapshot веба и
  проверенной политики переноса: **85 молитв / 4 категории**. Закрытые 21 молитва
  и 1 категория исключены. Прочие коллекции bundle не менялись.
- `tools/refresh_priest_public_bundle.mjs`: воспроизводимая локальная сборка
  только публичных молитв/категорий через официальные web storage plan и codec;
  по умолчанию dry run, без Firestore/production запросов. Manifest cleanup
  содержит только ID и digest, не названия, тексты или разрешения.
- `tools/audit_priest_apk.py`: проверяет реально упакованные assets, включая
  перемещённые ID, наследуемые ограничения и отсутствие тестовых private fixtures.
- `test/priest_access_test.dart`, `test/priest_public_cache_test.dart`,
  `integration_test/priest_access_flow_test.dart`: проверки новой активации,
  недоступности claims, старого кеша и восстановления Auth при перезапусках.
  `tools/priest_spark_capture.mjs` поддерживает отдельную папку снимков.
- `docs/priest-access.md`: актуальный контракт и порядок выпуска.

## Общий серверный контракт

Изучены фактические web `firestore.rules`, `docs/priest-access.md`,
`src/services/priestAccessService.js`, storage policy и официальные code vectors.
Исходный контракт `7122bb2` дополнен веб-задачей 12 октября; проверена новая
рабочая версия Rules, SHA-256:
`CDFB73B136344E532E9C417CFF1B47E4343EDD4CB45AB9A33862CCA16BE2C930`.
Хеш совпадает с копией, загруженной в Firebase Emulator. Векторы Flutter и веба
имеют одинаковый SHA-256:
`80FA47ECB0F4E4BCEFD014E1F49EFC784D102EA64AE21C816959929A503D5E0E`.

Rules через `getAfter()` проверяют новый claim, новый grant и закрытый proof
настроек. Ни UID, ни интерфейс, ни локальный SHA-256 сами по себе доступа не дают.
Claims нельзя читать даже владельцу и администратору через клиентский SDK.
Grant проверяется по UID/status, без даты окончания и сравнения с текущим кодом.
Смена кода не прекращает существующий доступ. Индивидуальный отзыв прекращает
серверные чтения и очищает открытый reader, каталог, поиск и избранное в UI.

Именованный Firebase App `mybrev-priest` сохраняет отдельную Anonymous Auth
сессию штатным SDK; основная/администраторская Auth не подменяется. SDK обновляет
ID tokens автоматически. `flutter_secure_storage` хранит только подсказку
verified UID и намерение отложенного отзыва. Код/proof локально не сохраняются.
Потеря Auth данных при очистке или переустановке может потребовать новой активации.

Закрытые тексты доступны только онлайн: отдельный Firestore клиент отключает
дисковый persistence, получает документы с сервера и хранит их в памяти.
Потеря сети скрывает тексты, но сохраняет регистрацию и возможность восстановления.
Офлайн отключение сохраняет намерение отзыва и блокирует защищённые чтения до
серверного подтверждения. Обычные молитвы продолжают работать офлайн.

## Результаты

- `flutter pub get`: успешно, SDK и основные зависимости не обновлялись.
- `flutter analyze`: **No issues found**, последний полный прогон 235 секунд.
- Целевой прогон доступа, настроек, публичного кеша и offline content: **53 PASS**.
  После него добавлена проверка восстановления UID во время миграции proof;
  она и все остальные priest-тесты успешно прошли в полном прогоне.
- Полный `flutter test --no-pub --concurrency=1 --timeout=5m`: **800 PASS, 8 FAIL**.
  Семь ошибок — `LocaleDataException` в новой `LiturgicalDateNavigationRow`
  параллельной задачи (app shell и Android layout lab). Восьмая — `Bad state:
  No element` при поиске Scrollable в тесте Readings 320 px / 200% текста.
  Это не зелёный полный прогон; ошибки сохранены в отчёте и чужие файлы не изменялись.
- Фактические web тесты Firebase Emulator, исключительно `demo-rules`,
  `priest-firestore`, `priest-migration`, `priest-grant-migration`,
  `priest-registration`: **28 PASS, 0 FAIL**. Проверены атомарность, неверный proof,
  закрытость claims, запрет поддельного grant/воскрешения, отзыв и смена кода.
- `flutter build apk --debug --target lib/main.dart --no-pub`: успешно, 245,9 сек.
  Проверенный обычный APK: `build/priest-spark/normal-claims.apk`.
  SHA-256: `6028EB115CB364353E7661AA3D8B4E04B767AA9219C9864B4AE44145BAFED2F6`.
  Это debug APK, без emulator dart-defines и интеграционного test target.
- `python tools/audit_priest_apk.py build/priest-spark/normal-claims.apk`: **PASS**,
  85 публичных молитв, 4 категории; закрытые документы/тестовые fixtures отсутствуют.
- Pixel 7 API 34 (`Pixel7_LiturgicalFinal`, `emulator-5654`): полный native
  integration flow с окончательными Rules **PASS**, 43 секунды после старта
  теста. Проверены оба режима, reader, вложенные категории, поиск, избранное,
  atomic rejection неверного кода (не остаётся ни grant, ни claim), owner get
  безопасного grant и отказ owner get claim, сохранённый UID, смена кода,
  серверный отзыв, offline и отложенное ручное отключение. Основная Auth остаётся
  нетронутой. Проверка sentinel в app `files/databases/shared_prefs/cache` не
  обнаружила защищённый текст. Лог: `android-integration-final.log`.
  Первую попытку этого повторного прогона остановила устаревшая тестовая отметка
  после сброса Emulator fixtures соседним тестом; она не считается PASS.
- Повторный запуск процесса без переустановки APK: **PASS**, тот же UID и
  защищённый каталог без нового кода (`android-process-restart-final.log`).
- Перезагрузка Android без переустановки/очистки данных: **PASS**, тот же UID
  и защищённый каталог без кода (`android-reboot-final.log`, 30 секунд теста).
  После cold boot конфигурация Android несколько раз пересоздавала Activity;
  первое подключение driver прервано и сохранено как `android-coldboot-partial.log`.
  Повторный старт после стабилизации системы сохранил исходную Auth сессию.
  Завершающая тестовая фаза сама отзывает свой grant и удаляет тестовую отметку.
- Обычный APK установлен и запущен отдельно, с отключённой сетью: стартовый
  экран Liturgia, переход в молитвенник, четыре публичные категории, список,
  чтение обычной молитвы и настройки отображаются. При очистке тестового окружения
  удалены только два публичных overlay кеша тестовых Emulator fixtures;
  пользовательские настройки/local prayers/Auth не очищались. В молитвеннике
  отображается 85 обычных молитв из APK. Снимки: `normal-startup.png`,
  `normal-prayers.png`, `normal-public-list.png`, `normal-public-reader.png`,
  `normal-settings.png`.
  AndroidRuntime не показывает FATAL EXCEPTION приложения.
  На перегруженном Windows host после cold boot появился **System UI ANR**;
  после закрытия системного диалога UI и навигация приложения проверены.
  AVD работает с SwiftShader; диагностический запуск использовал software
  rendering / `enable-impeller=false`, manifest приложения не менялся.
  Этот прогон не заменяет проверку штатного renderer на физическом устройстве.

Логи и native screenshots находятся в `audit-evidence/priest-spark-refresh/`.
Полные дампы production документов и исходные коды активации не включены в коммит.

## Перед выпуском

1. Согласовать и опубликовать hardened Rules веб-задачи; выполнить её field-only
   очистку proof в старых grants, сохранив UID, статус и даты. Production backend
   в рамках этого Flutter task не обновлялся. Новый клиент требует новый контракт.
2. Включить Anonymous Auth без автоматического удаления anonymous accounts.
   После старого readable-proof контракта выполнить согласованную ротацию кода.
3. Выпустить безопасный публичный Bundle/Manifest по правилам массовой миграции
   веба; не заменять её принудительным content patch. Уже выпущенные APK нельзя
   ретроспективно очистить от их статических ресурсов.
4. Исправить/согласовать отмеченные ошибки общего набора тестов, завершить QA
   параллельной UI-задачи и проверить штатный renderer на физическом Android.
5. Подготовить подписанную release сборку и согласовать публикацию отдельно.

Мгновенный отзыв при отсутствии сети технически невозможен. Эта версия не
выдаёт защищённый офлайн контент и не обещает удалить сделанные пользователем
скриншоты или копии за пределами приложения.
