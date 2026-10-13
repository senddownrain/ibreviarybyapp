# Flutter / mybrev: окончательный Spark-контракт

Проверка 12–13.10.2026, Flutter ветка `feature/priest-access-firebase-spark`,
исходный HEAD `fa97358`. Веб security fix: `4966383`, отчёт внедрения: `cb35ee8`.

## Источник контракта

В `senddownrain/mybrev` выполнены `git fetch origin codex/priest-spark` и
`git merge --ff-only origin/codex/priest-spark`. Локальная ветка уже содержит
новые security-коммиты и опережает remote на семь коммитов; remote на момент
первой проверки ещё указывает на `7122bb2`. Повторный fetch/fast-forward
13.10.2026 подтвердил совпадение local/remote на `2fe0d67`, содержащем security
fix. Rules и code vectors не изменились. Незавершённые посторонние изменения
веба сохранены. Изучены актуальные `docs/priest-access.md`, `firestore.rules`,
`src/services/priestAccessService.js` и официальные code vectors.
Для проверок использован security-контракт `4966383`.

SHA-256 Rules из `4966383` и файла Firebase Emulator совпадает:
`cdfb73b136344e532e9c417cff1b47e4343edd4cb45ab9a33862cca16be2c930` (LF).
У опубликованной копии из локального отчёта веба SHA-256
`90f2ccc7acf209200c14e02d68a624563a61a86e3385d396b69b17bcb1ebca50` (CRLF).
Программно подтверждено: различие — только окончания строк.
Code vectors Flutter и веба совпадают:
`80fa47ecb0f4e4bcefd014e1f49efc784d102ea64ae21c816959929a503d5e0e`.

Документация `cb35ee8` сообщает о завершённом Rules/Hosting rollout и field-only
удалении proof из четырёх прежних grants без смены UID, статусов или дат.
Старый код отключён, новый рабочий код ещё должен создать владелец в админке.
Это сведения веб-отчёта; Flutter-задача не выполняет production чтений, миграций,
deployment, push или публикации приложения.

## Совместимость и изменения Flutter

| Область | Flutter |
| --- | --- |
| Auth | Отдельный `mybrev-priest`, persistent Anonymous Auth, восстановление прежнего UID; основная Auth не заменяется |
| Код | Общая нормализация v3 и SHA-256, решение принимает сервер |
| Активация | Один WriteBatch: новый `priestActivationClaims/{uid}` и новый `priestDeviceGrants/{uid}` |
| Claim | Только uid/proof/server timestamp; рабочий клиент не читает claim |
| Grant | Девять согласованных полей, `client: Flutter`, три server timestamps, `revokedAt: null`, без proof |
| Подтверждение | Свой grant с `Source.server`, без cached/pending snapshots; затем private collections с сервера |
| Смена кода | Не затрагивает active grant; нет проверки старого кода или срока 30 дней |
| Legacy grant | UID сохраняется; непроверенный статус скрывает тексты до безопасной server migration |
| Отзыв | Server status/listener, очистка UI/памяти; offline self-disable сохраняет намерение до отправки |
| Данные | Общие IDs и обычное дерево: публичные и защищённые коллекции без дублей |
| Офлайн | Публичный bundle/cache работают; защищённые тексты только онлайн и в памяти |

Новое обязательное изменение в `lib/services/firebase_priest_access.dart`:
после **каждой** попытки batch вызывается `clearProtectedMemory()` в `finally`.
Firestore client завершается, именованный App удаляется, Auth не signOut.
Следующее чтение создаёт новый platform delegate и восстанавливает тот же UID.
Успешный claim не остаётся в memory cache полного SDK. Это эквивалент требования
веба, который для регистрации использует Firestore Lite без local store.

Commit имеет собственный timeout. Внешний timeout для этой операции отключён,
чтобы вызов не завершался раньше очистки кеша и offline write queue.
После отказа Rules проверка возможной гонки вкладок читает безопасный grant
через новый клиент; fallback на одиночный grant или старую схему отсутствует.
Если результат неизвестен, access не включается автоматически; следующий
server check определяет, был ли grant действительно создан.

`integration_test/priest_access_flow_test.dart` дополнен adversarial cache-only
probe: после отказа и успеха SDK не должен иметь claim в кеше. Только тест
пытается прочитать локальный кеш; приложение не делает server/cache claim get.
Также реальный SDK batch ставится в offline очередь через `disableNetwork()`:
timeout обязан завершить очистку до возврата ошибки, сохранить UID и не
переиграть очередь после восстановления. Проверки не выводят payload/proof.

Изменены только Firebase gateway, интеграционный тест и документация этой задачи.
Публичный bundle остаётся безопасным: 85 молитв / 4 категории; кеширование,
литургические часы, Readings и ORDO не переделывались.

## Результаты проверки

Исходники для воспроизводимой проверки: `git archive fa97358` в игнорируемую
папку `build/priest-spark/compatibility-src` + файлы этой задачи. Хеши gateway
и integration test совпадают с рабочей веткой (`tested-source-checksums.json`).
Это исключает параллельные незавершённые изменения UI. Первая сборка общего
рабочего каталога была остановлена ошибкой nullability в изменяемом соседней
задачей `adaptive_app_bar.dart`; этот файл не исправлялся данной задачей.

- `flutter pub get`: PASS; существующий SDK и версии зависимостей сохранены.
- `flutter analyze --no-pub`: PASS, No issues found, 122,9 секунды.
- `flutter test` для доступа/настроек/публичного кеша: **19 PASS**.
- Actual web Rules/registration/migration tests в Firebase Emulator
  `demo-rules`, Standard edition, `(default)`: **28 PASS, 0 FAIL, 0 SKIP**.
- Тестовый Android APK: PASS, 789,4 секунды изолированной сборки.
- Native SDK integration на Pixel 7 API 34: **PASS**, 2:06 после старта теста.
  Включает cache-only проверки после неверного кода и успешного batch;
  настоящий offline SDK batch, его timeout, уничтожение App до возврата ошибки,
  сохранение UID и отсутствие grant после переподключения; затем успешную
  активацию тем же UID, owner claim get 403 и безопасный grant get 200.
  Пройдены категории/вложенность, reader, поиск, избранное, смена кода,
  восстановление gateway, серверный отзыв и offline self-disable/retry.
- Обычный Android APK с `lib/main.dart`, без test/emulator defines: PASS,
  454,1 секунды. Файл `build/priest-spark/normal-final-contract.apk`.
- Аудит реально упакованных assets/fixtures: **PASS**, 85 публичных молитв,
  4 категории, перемещённых закрытых документов и integration fixtures нет.
- Перезапуск процесса без переустановки APK: **PASS**, тот же UID, серверный
  active grant и закрытые молитвы восстановлены без кода.
- Перезагрузка Android без переустановки/очистки: **PASS**, тот же UID и
  доступ восстановлены без кода (`android-reboot.log`). После загрузки ОС
  тест запущен с сохранёнными данными; финальная фаза отзывает свой тестовый
  grant, удаляет тестовую отметку и собственный synthetic favorite ID.
- Обычный APK отдельно запущен без сети: стартовый экран и переход в
  молитвенник/публичные категории отображаются (`normal-startup.png`,
  `normal-prayers.png`); FATAL/Unhandled Exception приложения в logcat нет.
  Только два публичных overlay тестовых fixtures сброшены для возврата к
  обычному APK bundle; настройки/local prayers/Auth не очищались.
  На host снова наблюдался **System UI ANR**; после закрытия системного диалога
  UI работает. Использованы SwiftShader и диагностические launch flags
  software rendering / Impeller off; production renderer/manifest не изменён.
  Это ограничение emulator QA, нужна отдельная проверка физического Android.

SHA-256 обычного debug APK:
`170f3c7cc34804c43f8a71d35206a7c365ec34403f06a4338f18d882ae82c3e2`.

Артефакты этого прогона: `audit-evidence/priest-spark-contract-final/`.
Полный общий набор тестов параллельных UI-изменений в этой изолированной
проверке не заявляется зелёным; это отдельная граница проверки совместимости.

Изменённые файлы:
`lib/services/firebase_priest_access.dart`,
`integration_test/priest_access_flow_test.dart`,
`docs/priest-access.md`, `docs/priest-spark-compatibility.md`.

## Перед публикацией

1. Владелец создаёт рабочий код в опубликованной веб-админке; не размещать его
   в отчёте, логах, preferences или URL. Прежние active grants сохраняют доступ
   независимо от отключённого общего кода.
2. Перед выпуском сверить фактический backend с зафиксированным web security
   release и квоты Spark, используя существующий порядок согласования live audit.
   Anonymous Auth должен оставаться включённым без automatic cleanup.
3. Использовать безопасный bundle и обычный `lib/main.dart` без test/emulator
   defines. Пройти аудит финального APK и штатного renderer на физическом Android.
4. Устранить отмеченные в предыдущем полном прогоне ошибки параллельной UI-задачи
   перед общим выпуском. Публикация приложения требует отдельного подтверждения.

Ранее сохранённые пользователем за пределами приложения тексты/скриншоты
удалить невозможно. Немедленный отзыв без сети не обещается; защищённого
офлайн контента эта версия не выдаёт.
