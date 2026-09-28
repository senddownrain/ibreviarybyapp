#!/usr/bin/env bash
# iOS visual audit on the iOS Simulator (used by the Codemagic
# `ios-visual-audit` workflow, also runnable on any Mac with Xcode).
#
# Creates dedicated audit simulators from the device types/runtimes that are
# actually installed, runs integration_test/ios_visual_audit_test.dart in
# several passes and captures the real simulator screen whenever the test
# prints `AUDIT_SHOT::<name>`.
set -uo pipefail

OUT="${AUDIT_OUT:-audit-evidence/ios-cloud}"
TEST="integration_test/ios_visual_audit_test.dart"
mkdir -p "$OUT/logs"
ENV_FILE="$OUT/environment.txt"
INDEX="$OUT/screenshots.md"

log() { printf '[audit] %s\n' "$*"; }

pick_device_type() {
  local wanted
  for wanted in "$@"; do
    local id
    id=$(xcrun simctl list devicetypes -j | python3 -c "
import json,sys
name=sys.argv[1]
for d in json.load(sys.stdin)['devicetypes']:
    if d['name']==name: print(d['identifier']); break
" "$wanted")
    if [ -n "$id" ]; then printf '%s|%s\n' "$wanted" "$id"; return 0; fi
  done
  return 1
}

latest_ios_runtime() {
  xcrun simctl list runtimes -j | python3 -c "
import json,sys
rs=[r for r in json.load(sys.stdin)['runtimes'] if r.get('platform')=='iOS' and r.get('isAvailable')]
rs.sort(key=lambda r:[int(x) for x in r['version'].split('.')])
print(rs[-1]['identifier']+'|'+rs[-1]['version'] if rs else '')"
}

create_sim() { # name device_type_id runtime_id
  local udid
  udid=$(xcrun simctl create "$1" "$2" "$3")
  # Software keyboard must appear for the Prayer search keyboard states.
  defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl status_bar "$udid" override --time "9:41" --dataNetwork wifi \
    --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100 || true
  printf '%s' "$udid"
}

screen_info() { # udid
  xcrun simctl io "$1" screenshot "$OUT/logs/.probe.png" >/dev/null 2>&1 &&
    python3 - "$OUT/logs/.probe.png" <<'EOF'
import struct,sys
with open(sys.argv[1],'rb') as f:
    f.read(16); w,h=struct.unpack('>II',f.read(8))
print(f"{w}x{h} px")
EOF
  rm -f "$OUT/logs/.probe.png"
}

run_pass() { # udid pass
  local udid="$1" pass="$2" logfile="$OUT/logs/integration-$2.log" status
  log "pass $pass on $udid"
  flutter test "$TEST" -d "$udid" --dart-define=AUDIT_PASS="$pass" 2>&1 |
    while IFS= read -r line; do
      printf '%s\n' "$line" >>"$logfile"
      case "$line" in
        *AUDIT_SHOT::*)
          local name="${line##*AUDIT_SHOT::}"
          name="${name%%[[:space:]]*}"
          xcrun simctl io "$udid" screenshot "$OUT/$name.png" >/dev/null 2>&1 &&
            printf -- '- `%s.png` — pass `%s`\n' "$name" "$pass" >>"$INDEX"
          log "shot $name"
          ;;
        *AUDIT_BLOCKED::*|*AUDIT_INFO::*|*AUDIT_DONE::*)
          printf '%s\n' "${line#*flutter: }" >>"$OUT/audit-events.txt"
          log "${line#*flutter: }"
          ;;
        *"All tests passed"*|*"Some tests failed"*|*EXCEPTION*|*Error:*)
          log "$line"
          ;;
      esac
    done
  status=${PIPESTATUS[0]}
  log "pass $pass exit $status"
  printf 'pass %s: exit %s\n' "$pass" "$status" >>"$OUT/test-results.txt"
  return 0
}

: >"$OUT/audit-events.txt"
: >"$OUT/test-results.txt"
printf '# Screenshot index\n\n' >"$INDEX"

RUNTIME=$(latest_ios_runtime)
[ -n "$RUNTIME" ] || { log "no iOS runtime available"; exit 1; }
RUNTIME_ID="${RUNTIME%%|*}"; RUNTIME_VERSION="${RUNTIME##*|}"
PRO=$(pick_device_type "iPhone 17 Pro" "iPhone 16 Pro" "iPhone 15 Pro" "iPhone 17" "iPhone 16") ||
  { log "no Pro-size iPhone device type"; exit 1; }
COMPACT=$(pick_device_type "iPhone SE (3rd generation)" "iPhone 16e" "iPhone 13 mini" "iPhone 12 mini") || COMPACT=""

PRO_UDID=$(create_sim "iBreviary Audit iPhone" "${PRO##*|}" "$RUNTIME_ID")

{
  echo "git SHA: $(git rev-parse HEAD)"
  echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  flutter --version 2>&1 | sed 's/^/flutter: /'
  echo "dart: $(dart --version 2>&1)"
  xcodebuild -version | sed 's/^/xcode: /'
  echo "macOS: $(sw_vers -productVersion) ($(uname -m))"
  echo "iOS runtime: $RUNTIME_VERSION ($RUNTIME_ID)"
  echo "iPhone (main): ${PRO%%|*} — UDID $PRO_UDID — screen $(screen_info "$PRO_UDID")"
} >"$ENV_FILE"
xcrun simctl list devicetypes >"$OUT/logs/devicetypes.txt"
xcrun simctl list runtimes >"$OUT/logs/runtimes.txt"

xcrun simctl ui "$PRO_UDID" appearance light
run_pass "$PRO_UDID" main
xcrun simctl ui "$PRO_UDID" appearance dark
run_pass "$PRO_UDID" dark
xcrun simctl ui "$PRO_UDID" appearance light
xcrun simctl ui "$PRO_UDID" content_size extra-extra-extra-large
run_pass "$PRO_UDID" large-text
xcrun simctl ui "$PRO_UDID" content_size large
xcrun simctl shutdown "$PRO_UDID" || true

if [ -n "$COMPACT" ]; then
  COMPACT_UDID=$(create_sim "iBreviary Audit Compact" "${COMPACT##*|}" "$RUNTIME_ID")
  echo "iPhone (compact): ${COMPACT%%|*} — UDID $COMPACT_UDID — screen $(screen_info "$COMPACT_UDID")" >>"$ENV_FILE"
  xcrun simctl ui "$COMPACT_UDID" appearance light
  run_pass "$COMPACT_UDID" compact
  xcrun simctl shutdown "$COMPACT_UDID" || true
else
  echo "iPhone (compact): not available on this runner" >>"$ENV_FILE"
fi

log "screenshots: $(ls "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')"
exit 0
