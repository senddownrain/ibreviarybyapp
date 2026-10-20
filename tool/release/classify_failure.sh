#!/usr/bin/env bash
# Maps a fastlane/flutter log (file $1) to a failure class.
# Prints: <code>|<message in Russian>|<next step in Russian>. Never echoes log lines (no secrets).
set -uo pipefail
log="${1:-/dev/null}"
has() { grep -qiE -- "$1" "$log"; }
say() { printf '%s|%s|%s\n' "$1" "$2" "$3"; exit 0; }

has 'Missing environment' && say missing_secret \
  "Не хватает секрета или переменной (имя указано в логе шага)." \
  "Добавьте его: Settings → Secrets and variables → Actions (docs/RELEASE_BETA.md) и запустите заново."
has 'Not on production|production track|not allowed' && say track_not_allowed \
  "Трек не разрешён: релиз возможен только в закрытое тестирование alpha." \
  "Запустите android_track=alpha; ANDROID_BETA_TRACK должна быть alpha, не production."
has 'Version ?code .* has already been used|versionCode .*already|already been used|version code .*conflict|Version code conflict' && say version_code_conflict \
  "Конфликт versionCode: такой номер уже есть в Google Play." \
  "Запустите workflow ещё раз: номер берётся из магазина (+1). Если повторяется — проверьте fastlane android check."
has 'draft app|Only releases with status draft|app is in draft|Draft app' && say play_draft_state \
  "Приложение в Google Play ещё в состоянии draft: релиз можно создать только как draft." \
  "Поставьте переменную PLAY_RELEASE_STATUS=draft; затем раскатайте релиз вручную в Play Console (Closed testing → alpha → Release → Rollout)."
has 'debug key|CN=Android Debug|not signed' && say debug_signing \
  "AAB подписан не ключом загрузки (debug) или не подписан." \
  "Проверьте секреты ANDROID_KEYSTORE_*, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD."
has 'Keystore was tampered|keystore password was incorrect|Cannot recover key|alias .* does not exist' && say keystore_invalid \
  "Не открывается keystore: неверный пароль или alias." \
  "Сверьте ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD с ~/.mybrev-release/key.properties."
has 'Flutter version mismatch|Flutter version drift|requires Flutter|Because .* requires Flutter SDK version' && say flutter_mismatch \
  "Версия Flutter не совпадает с pubspec.yaml." \
  "Нужна версия из pubspec.yaml (environment.flutter). На Mac-раннере обновите Flutter или задайте FLUTTER."
has 'invalid_grant|Google Api Error: (Invalid|Forbidden|Unauthorized)|caller does not have permission|The caller does not' && say play_access \
  "Google Play отклонил доступ сервис-аккаунта." \
  "Проверьте GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64 и права сервис-аккаунта на приложение в Play Console."
has 'Authentication credentials|App Store Connect.*(401|403)|UNAUTHORIZED|FORBIDDEN' && say asc_access \
  "App Store Connect отклонил ключ API." \
  "Проверьте APP_STORE_CONNECT_KEY_ID / _ISSUER_ID / _PRIVATE_KEY_BASE64 (роль App Manager)."
has 'No signing certificate|provisioning profile|errSecInternalComponent|code ?sign' && say ios_signing \
  "Не удалось подписать iOS-сборку." \
  "Проверьте сертификат Apple Distribution в связке ключей Mac-раннера (docs/RELEASE_BETA.md)."
has 'build number .* already|bundle version must be higher|already exists' && say ios_build_conflict \
  "Конфликт номера сборки TestFlight." \
  "Запустите заново: номер берётся из TestFlight (+1)."
has 'Gradle|FAILURE: Build failed|flutter build .* failed|Execution failed' && say build_failed \
  "Сборка не прошла." \
  "Откройте лог шага fastlane, исправьте ошибку сборки и запустите заново."
say unknown "Релиз не завершился (причина не распознана)." "Откройте лог шага fastlane в этом запуске."
