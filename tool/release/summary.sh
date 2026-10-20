#!/usr/bin/env bash
# Job summary of MyBrev Beta Release: one block per platform, separate verdicts.
# All inputs come from the environment (names below); prints Markdown.
#   SHA, PLATFORM, ANDROID_TRACK_INPUT, PUBSPEC_VERSION, PUBSPEC_BUILD
#   PREPARE_RESULT, PREPARE_REASON, QUALITY_RESULT, QUALITY_REASON
#   IOS_PREFLIGHT_RESULT, IOS_PREFLIGHT_REASON, IOS_RESULT, IOS_VERSION, IOS_BUILD,
#   IOS_GROUPS, IOS_ERROR_CODE, IOS_ERROR_TEXT, IOS_ERROR_NEXT
#   ANDROID_PREFLIGHT_RESULT, ANDROID_PREFLIGHT_REASON, ANDROID_RESULT, ANDROID_VERSION,
#   ANDROID_VERSION_CODE, ANDROID_TRACK, ANDROID_RELEASE_STATUS, ANDROID_BETA_TRACK,
#   ANDROID_ERROR_*, PLAY_RELEASE_STATUS, RUN_URL
set -uo pipefail

PLAY_CONSOLE_APP_URL="https://play.google.com/console/u/0/developers/5871364558640668686/app/4976052836403427313"
TF_URL="https://appstoreconnect.apple.com/apps/6819272902/testflight/ios"
sha="${SHA:-unknown}"; short="${sha:0:12}"

reason_text() { # code -> "message|next step"
  case "$1" in
    missing_secret) echo "Не хватает секрета или переменной (имена в аннотации ::error::).|Добавьте в Settings → Secrets and variables → Actions и запустите заново." ;;
    track_not_allowed) echo "Трек не разрешён: релиз возможен только в закрытое тестирование alpha.|Запустите android_track=alpha; ANDROID_BETA_TRACK должна быть alpha." ;;
    ref_not_branch) echo "Запуск не с ветки.|Запускайте workflow с ветки main." ;;
    not_main) echo "Запуск не с main.|Запускайте с main или осознанно включите allow_non_main." ;;
    branch_moved|sha_mismatch) echo "Ветка ушла вперёд после запуска; релиз собрал бы не тот коммит.|Запустите workflow заново на актуальной ветке." ;;
    dirty_tree) echo "Рабочее дерево не чистое.|Запустите заново; это не должно случаться на чистом checkout." ;;
    flutter_mismatch) echo "Версия Flutter не совпадает с pubspec.yaml (или codemagic.yaml).|Согласуйте environment.flutter в pubspec.yaml и codemagic.yaml; на Mac-раннере обновите Flutter." ;;
    analyze_failed) echo "flutter analyze нашёл ошибки или предупреждения.|Исправьте их в коде (info-замечания не блокируют)." ;;
    tests_failed) echo "Быстрые тесты не прошли.|Исправьте тесты; полный набор: run_full_tests=true." ;;
    pub_get_failed) echo "flutter pub get не прошёл.|Проверьте pubspec.yaml/pubspec.lock." ;;
    keystore_invalid) echo "Keystore не открывается или в нём нет alias.|Сверьте ANDROID_KEYSTORE_*, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD." ;;
    runner_offline) echo "Mac-раннер для iOS недоступен.|Включите Mac и проверьте: cd ~/actions-runner-mybrev && ./svc.sh status; сначала запустите Release runner smoke test." ;;
    *) echo "Проверка перед отправкой не прошла ($1).|Откройте лог упавшего шага в этом запуске." ;;
  esac
}

verdict() { case "$1" in success) echo SUCCESS;; skipped|'') echo SKIPPED;; cancelled) echo "FAILED (cancelled)";; *) echo FAILED;; esac; }

android_track_value() {
  local track="${ANDROID_TRACK:-}"
  [ -n "$track" ] || track="${ANDROID_TRACK_INPUT:-}"
  [ -n "$track" ] || track="${ANDROID_BETA_TRACK:-alpha}"
  printf '%s\n' "$track"
}

android_track_url() {
  echo "${PLAY_CONSOLE_APP_URL}/tracks/$1"
}

android_console_section() {
  echo "Closed testing → $1"
}

android_install_help() {
  local track="$1" section
  section=$(android_console_section "$track")
  echo "Установка: тестировщик открывает ссылку-приглашение ${section} (Play Console → ${section} → Testers → Copy link), принимает участие и обновляет «MyBrev Test» в Google Play."
}

# platform block: name result version build channel link tester preflight_result preflight_reason code text next
block() {
  local name="$1" result="$2" version="$3" build="$4" channel="$5" link="$6" tester="$7"
  local pre_res="$8" pre_reason="$9" ecode="${10}" etext="${11}" enext="${12}" build_label="${13}"
  local gate_res gate_reason
  # An upstream gate that failed (prepare / quality) explains a skipped platform.
  if [ "${PREPARE_RESULT:-success}" != success ] && [ "${PREPARE_RESULT:-}" != skipped ]; then gate_res=failed; gate_reason="${PREPARE_REASON:-unknown}"
  elif [ "${QUALITY_RESULT:-success}" != success ] && [ "${QUALITY_RESULT:-}" != skipped ]; then gate_res=failed; gate_reason="${QUALITY_REASON:-unknown}"
  elif [ "$pre_res" != success ] && [ "$pre_res" != skipped ] && [ -n "$pre_res" ]; then gate_res=failed; gate_reason="${pre_reason:-unknown}"
  fi
  local v; v=$(verdict "$result")
  if [ -n "${gate_res:-}" ]; then v=FAILED; fi
  # Platform not requested.
  case "$name:${PLATFORM:-both}" in
    iOS:android|Android:ios) v=SKIPPED; gate_res=; result=skipped ;;
  esac
  echo "### $name — $v"
  echo
  echo "- Commit: \`$short\` (\`$sha\`)"
  if [ "$v" = SKIPPED ]; then echo "- Платформа не выбрана в этом запуске."; echo; return; fi
  echo "- Version: ${version:-${PUBSPEC_VERSION:-—}}"
  echo "- $build_label: ${build:-—}"
  echo "- Test channel: $channel"
  echo "- Console: $link"
  if [ "$v" = SUCCESS ]; then
    echo "- $tester"
  else
    local t m n
    if [ -n "${gate_res:-}" ]; then t=$(reason_text "$gate_reason"); else t="${etext:-Релиз не завершился.}|${enext:-Откройте лог шага в этом запуске.}"; fi
    m="${t%%|*}"; n="${t#*|}"
    [ -n "${ecode:-}" ] && [ -z "${gate_res:-}" ] && echo "- Класс ошибки: \`$ecode\`"
    echo "- Ошибка: $m"
    echo "- Следующий шаг: $n"
    [ -n "${RUN_URL:-}" ] && echo "- Лог: $RUN_URL"
  fi
  echo
}

echo "## MyBrev Beta Release"
echo
echo "Release builds exactly commit \`$sha\` (short \`$short\`). Android is limited to Google Play closed testing alpha; production is not possible."
echo

block iOS "${IOS_RESULT:-}" "${IOS_VERSION:-}" "${IOS_BUILD:-}" \
  "TestFlight (by.mybrev.testflight2026) · ${IOS_GROUPS:-—}" "$TF_URL" \
  "Установка: приложение TestFlight на iPhone → «MyBrev Test»; новая сборка появится после обработки Apple (обычно 5–30 мин)." \
  "${IOS_PREFLIGHT_RESULT:-}" "${IOS_PREFLIGHT_REASON:-}" "${IOS_ERROR_CODE:-}" "${IOS_ERROR_TEXT:-}" "${IOS_ERROR_NEXT:-}" "Build number"

android_track=$(android_track_value)
android_url=$(android_track_url "$android_track")
android_help=$(android_install_help "$android_track")

block Android "${ANDROID_RESULT:-}" "${ANDROID_VERSION:-}" "${ANDROID_VERSION_CODE:-}" \
  "Google Play closed testing (${android_track}) (by.mybrev.playtest2026)" "$android_url" \
  "$android_help" \
  "${ANDROID_PREFLIGHT_RESULT:-}" "${ANDROID_PREFLIGHT_REASON:-}" "${ANDROID_ERROR_CODE:-}" "${ANDROID_ERROR_TEXT:-}" "${ANDROID_ERROR_NEXT:-}" "VersionCode"

android_status="${ANDROID_RELEASE_STATUS:-${PLAY_RELEASE_STATUS:-completed}}"
if [ "${ANDROID_RESULT:-}" = success ] && [ "$android_status" = draft ]; then
  echo "> **Android: релиз создан как draft.** Пока Google не проверил приложение, откройте Play Console → $(android_console_section "$android_track") → релиз → «Review/Roll out» и раскатайте его вручную; до этого тестировщики его не получат."
  echo
fi
echo "### Manual actions still required"
echo "- Группы TestFlight / Beta App Review и список тестировщиков Play ведутся в консолях (docs/RELEASE_BETA.md)."
