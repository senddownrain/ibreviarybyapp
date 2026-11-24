# App Check в Flutter

Firebase-проект `ibreviaryby`. Регистрация провайдеров, параметры Firebase
Console и порядок включения Enforcement описаны в
[общей инструкции Web][web-guide].

| Платформа | Идентификатор | Провайдер |
| --- | --- | --- |
| Android | `by.mybrev.playtest2026` · `1:344097781816:android:92f6c24311cce114fd8ecd` | Play Integrity |
| iOS | `by.mybrev.testflight2026` · `1:344097781816:ios:e3feba9d3a782b7dfd8ecd` | App Attest, с DeviceCheck на устройствах без поддержки App Attest |
| Flutter Web | `1:344097781816:web:93ffb2d167ed7765fd8ecd` | reCAPTCHA Enterprise с публичным site key при сборке |

Провайдер устанавливается после создания Firebase App, до первого обращения
к Firestore или Auth. `[DEFAULT]` обслуживает публичные обновления и Auth
администратора Песенника. `mybrev-priest` обслуживает анонимную идентичность
устройства, активацию, проверку гранта и защищённые тексты. При удалении
и создании экземпляра священника под тем же именем провайдер устанавливается
на новый экземпляр. Авторизация приложения и Firestore Rules применяются
как прежде. Нативная сборка использует production-провайдеры. Debug provider
в коде не выбирается.

## Сборки и проверки

### Android

1. Используйте следующий свободный versionCode для каждого канала и
   проверьте, каким сертификатом подписан устанавливаемый файл. Для AAB с
   Play App Signing это сертификат **App signing key**. Прямой APK,
   который готовит текущий workflow, подписывается **upload key**. Равенство
   подписей двух каналов проверяется по SHA-256, полученному на устройстве
   или из подписанного пакета, и по данным Play Console.
2. Текущий workflow прямого APK закреплён на SHA `54b4fec` и build 26,
   выпущенных до App Check. После согласования выпуска обновите
   `RELEASE_SHA` и параметры версии в `.github/workflows/build-android-apk.yml`
   на одобренный коммит с App Check. Путь выпуска в Play остаётся
   описан в [RELEASE_BETA.md](RELEASE_BETA.md).
3. Проверьте на физических устройствах Google Play с новой поставляемой
   версией и тот самый прямой APK после новой установки и после обновления
   ранее выданного прямого APK. Включите Android 13+ и одно более раннее
   поддерживаемое устройство. Сравните App Check verified и контрольные
   операции для каждого канала. Для прямого APK проверьте совместимость
   с установленной подписью, наличие Google Play services и фактический
   Play Integrity verdict. При несовпадающих сертификатах переход
   APK ↔ Play потребует отдельного плана, поскольку штатное обновление
   пакета поверх другой подписи невозможно и переустановка теряет
   локальные данные или идентификатор установки.
4. Если прямой APK недоступен с требованиями для смешанного канала
   (`PLAY_RECOGNIZED`), оставьте Firestore в режиме наблюдения. Согласуйте
   с владельцем либо перевод этих пользователей на поддерживаемый Play-выпуск
   с сохранением доступа, либо отдельно проверенный канал аттестации
   sideload. Изменение требований Play Integrity для общего Firebase App
   затронет оба Android-канала. [Play Integrity][play]

### iOS

1. На macOS проверьте `pod install`, сборку и наличие App Attest capability
   в Runner. Для подписанной сборки проверьте профиль нужной Apple Team и
   значение `production` у entitlement
   `com.apple.developer.devicecheck.appattest-environment` через
   `codesign -d --entitlements :- <Runner.app>`.
2. Используйте одобренный [TestFlight-процесс](RELEASE_BETA.md) или
   `ios-testflight` из `codemagic.yaml` и новый build number.
   Реальную аттестацию проверяйте на физическом iPhone через TestFlight/
   App Store. Simulator build подтверждает сборку плагина и entitlement,
   но для выдачи токена оба Apple-провайдера требуют подходящего устройства.
3. Проверьте App Attest на поддерживаемом устройстве и отдельно готовность
   DeviceCheck в Firebase. SDK выбирает DeviceCheck, когда iOS сообщает,
   что App Attest недоступен. Ошибки App Attest на поддерживаемом устройстве
   требуют диагностики и остаются видны в режиме мониторинга.
   [App Attest][attest] · [DeviceCheck][devicecheck]

### Flutter Web и локальные проверки

```sh
flutter build web --dart-define=FIREBASE_APP_CHECK_SITE_KEY=<public-site-key>
flutter test test/services/firebase_app_check_test.dart
flutter test --dart-define=PRIEST_USE_EMULATORS=true test/services/firebase_app_check_test.dart
```

Указывайте ключ из регистрации именно этого Firebase Web App и
разрешите фактический домен. Сборка без ключа подходит для локальных
проверок. При запуске приложения с `PRIEST_USE_EMULATORS=true` используйте
debug-сборку и локальный `FIREBASE_EMULATOR_HOST`. Auth и Firestore
перенаправляются в emulators, App Check не активируется. Для настоящей
аттестации нужна отдельно зарегистрированная staging-конфигурация с
синтетическими данными.

### Приёмка и старые версии

На каждом канале проверьте обновление с предыдущей установки и новый
запуск, холодное чтение `contentManifest/current`, манифест коллекции и
загрузку небольшого синтетического патча. Повторите проверку после
истечения TTL, возврата из фона и восстановления сети. Проверьте офлайн
чтение из бандла, новый и существующий гранты священника,
активацию, отзыв и повторное открытие после очистки защищённой памяти,
а также вход администратора и проверку доступа к Песеннику.
На staging отдельно проверьте обычного пользователя без роли.

Старые версии продолжают работать с Firestore в режиме наблюдения.
После Enforcement они сохранят доступ к встроенному бандлу и локальному
кэшу, а загрузка патчей, проверка ролей и серверный доступ священника
будут зависеть от версии с рабочей аттестацией. До согласованного решения
об Enforcement сохраните возможность обновиться во всех поддерживаемых
каналах. Симуляторы и сборки без App Check не подтверждают готовность
реального канала.

[web-guide]: https://github.com/senddownrain/mybrev/blob/codex/firebase-app-check-web/docs/firebase-app-check.md
[play]: https://firebase.google.com/docs/app-check/android/play-integrity-provider
[attest]: https://firebase.google.com/docs/app-check/ios/app-attest-provider
[devicecheck]: https://firebase.google.com/docs/app-check/ios/devicecheck-provider
