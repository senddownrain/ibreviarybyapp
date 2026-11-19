#!/usr/bin/env bash
# Preflight only: no production credentials, releases, uploads or deployments.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

mode="${1:---quick}"
case "$mode" in
  --quick|--apk|--full) ;;
  *) echo 'Usage: bash tool/cloud/flutter_preflight.sh [--quick|--apk|--full]' >&2; exit 2 ;;
esac
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter missing from PATH: install the exact SDK version first.' >&2
  exit 1
fi
expected="$(bash tool/release/flutter_version.sh)"
installed="$(flutter --version --machine | sed -nE 's/.*"frameworkVersion": *"([^"]+)".*/\1/p')"
if [[ "$installed" != "$expected" ]]; then
  echo "Flutter version mismatch: expected $expected, found ${installed:-unknown}" >&2
  exit 1
fi

printf 'Checking Flutter %s with the locked dependencies...\n' "$installed"
flutter pub get --enforce-lockfile
flutter analyze --no-fatal-infos
if [[ "$mode" == "--full" ]]; then
  flutter test
else
  flutter test test/prayer_formatting_widget_test.dart
fi

if [[ "$mode" == "--apk" ]]; then
  # Debug-only; all signed releases remain under GitHub Actions.
  flutter build apk --debug
fi
printf 'Completed %s checks. Chrome visual and device-native smoke remain separate.\n' "$mode"
