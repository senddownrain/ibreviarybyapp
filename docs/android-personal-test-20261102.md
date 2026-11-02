# MyBrev — Android APK для личного тестирования, 02.11.2026

## Сборка и получение

APK source SHA: `fc37c1a1625cf587f216af5e7adafcbd1fa179cc`.
База: `6d83b536ccbbc38ca0fecb2a64621b7c286342bc` (актуальный origin/main на момент fetch).
Дополнительные коммиты в APK: `b3b17b84242668ca6ac37c99497aaf154b688212` (D-1, Windows QA guards, provenance), `fc37c1a` (отдельный workflow ручного APK).

[Успешный запуск](https://github.com/senddownrain/ibreviarybyapp/actions/runs/41518245815).
[Скачать облачный APK — ZIP, срок хранения 30 дней](https://github.com/senddownrain/ibreviarybyapp/actions/runs/41518245815/artifacts/13177161780).
Локальный APK: `C:/Users/User/Downloads/MyBrev-Android-20261102/MyBrev-Android-Latest-fc37c1a.apk`.

| Проверка | Локальный APK | Облачный APK |
|---|---|---|
| Размер, байт | 81452487 | 81452103 |
| SHA-256 | `540da06ca14806ec4c4998382c7fa4215eabd5cdc79dde5566ac58812b0cf282` | `b60a8edf0831acc0b13b1cc244064ec6224859c00cbd3d3424e9ae1cd74d62e0` |
| Сертификат SHA-256 | `21b8f556979f25f321a3f6f21d8fe347ef1ac7d5ddd5b9738cae1e95ee408c3f` | `43183a2abf5a69de85cc8aeb6130e6b6ffb75bd36cc6ec0b6c7b1b4659ddfc4e` |

Оба APK проверены apksigner и aapt: действительная debug-подпись APK v2; applicationId `by.mybrev.playtest2026`; versionName `1.0.0`; versionCode `6`; minSdk `24`, targetSdk `36`; arm64-v8a, armeabi-v7a, x86_64. Release, не магазинная подпись. Использованы Flutter 3.41.4, Dart 3.11.1, Java 17. QA dart-defines не передавались. Обычный analytics transport закрыт compile-time guard; production Firebase и магазин не изменялись.

## Изменения и паритет

Из main вошли сезонные Common и исправления гимнов, D-1, Firebase duplicate-app, Hive/доступность псалмов, Contextual Discovery P0/P1/P2, шестишаговый тур, настройки и сохранение показов.

Сверка с WEB main `5d5e10c3837bda823faaeb43f2506b904283ee4b`: 291 Proper, 16 Common и calendar meta совпадают по digest; bundle и ревизии не менялись. 2000 случаев гимнов совпали. Эталон D-1 пересчитан из WEB: 386 полей, 58 с выбором вместо 63. Разница объяснена WEB #176: пять religious R1 (база и четыре сезона) содержат вариант респонсория, который должен оставаться с чтением. Минимальный перенос парсера и регрессионный тест сохраняют весь исходный текст. Литургические тексты не создавались и не редактировались.

Draft PR не включены: #58 — только debug-диагностика staging analytics и отчёт; #42, #21 — QA reports; #28 — правила источников; #23 — cloud setup. Для обычного Release дополнительных исправлений приложения они не дают.

## Фактические проверки

- `flutter pub get --enforce-lockfile`: PASS локально и в CI.
- `flutter analyze --no-fatal-infos`: exit 0 локально и в CI; 12 info, нет warnings/errors.
- `flutter test --concurrency=2`: CI PASS, 1699 passed / 9 skipped.
- Критические локальные проверки D-1, гимнов, альтернатив и аналитики: 75 passed / 1 штатный server skip / 0 failed.
- Ранний локальный полный прогон остановлен: 410 passed / 9 skipped / 7 failed. Пять Windows path/CRLF ошибок исправлены и перепроверены; два resource timeout не скрывались.
- Дополнительный локальный regression: 235 passed / 5 failed (четыре timeout при 30 s и один timing-dependent тест подсказки). Все четыре timeout отдельно прошли при `--concurrency=1 --timeout 2m`.
- Подсказка даты: диагностикой подтверждено `automaticBlocked=true` из-за появившегося приглашения в тур. Приложение правильно не показывает подсказку одновременно с приглашением. В отдельном QA-коммите тест начинает с уже отклонённым приглашением; исходные проверки подсказки сохранены. После этого P0 + tour suites: 38 passed / 0 failed. QA-коммит меняет только тест и этот отчёт, выданный APK пересобирать не требуется.
- Первые локальные сборки падали из-за сгенерированного integration_test registrant: параллельные Flutter-команды, затем повтор с --no-pub сохранил старый файл. Последовательный обычный `flutter build apk --release` успешно пересоздал registrant и APK. Зависимости не удалялись, flutter clean не выполнялся.
- Chrome visual smoke: NOT TESTED, нехватка RAM; запуск остановлен, снимков нет; дальнейшие графические проверки исключены владельцем.
- Native smoke: NOT TESTED — OWNER WILL TEST ON PHYSICAL ANDROID DEVICE. Ранее запущенный AVD остановлен; повторно не запускался по указанию владельца. Это не блокер личной установки, native pass нужен перед мобильным релизом.

## Установка и сохранение данных

Скопировать APK на Android 7+ и открыть файловым менеджером; при необходимости разрешить установку из этого источника. ZIP из GitHub сначала распаковать.

Установка поверх существующего приложения с сохранением данных возможна только при совпадении applicationId, сертификата и допустимом versionCode. Текущая подпись/версия на телефоне не проверялась. Google Play App Signing может отличаться; более высокий установленный versionCode также мешает обновлению. При отказе Android не удалять приложение без сохранения избранного и настроек. Локальный и облачный APK подписаны разными debug-ключами и не обновляют друг друга. Для последующих локальных обновлений использовать тот же debug-ключ.

На телефоне проверить: сезонные Common/гимны/чтения; D-1 и сохранение выбора; 4.12.2026 Гродно и 9.11.2026; P0/P1/P2, все 6 шагов тура и отключение подсказок; молитвенник/Библию/песенник/избранное и темы/крупный текст; системную Back и перезапуск; встроенные тексты в авиарежиме.
