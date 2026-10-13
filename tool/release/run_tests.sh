#!/usr/bin/env bash
# Release test gate. Default: the fast subset in quick_tests.txt.
# RUN_FULL_TESTS=true: the whole `flutter test` suite.
set -euo pipefail
cd "$(dirname "$0")/../.."

if [ "${RUN_FULL_TESTS:-false}" = true ]; then
  echo "Running the full test suite"
  exec flutter test
fi

files=()
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue;; esac
  [ -f "$line" ] || { echo "::error::quick test list names a missing file: $line"; exit 2; }
  files+=("$line")
done < tool/release/quick_tests.txt

echo "Running ${#files[@]} quick test files (tool/release/quick_tests.txt)"
exec flutter test "${files[@]}"
