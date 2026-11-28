#!/usr/bin/env bash
# Isolated comparison of the SoftHyphen (U+00AD) behaviour on another Flutter
# version. Does NOT touch the main app, its lock files or CI.
#   ./compare_sdk.sh 3.41.4      (version used by the app)
#   ./compare_sdk.sh master
# Downloads the Flutter SDK + engine from Flutter's public release storage
# into a temp folder (this is toolchain download, not a Firebase call).
set -euo pipefail
V="${1:?flutter tag or branch}"
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
git clone --depth 1 --branch "$V" https://github.com/flutter/flutter.git "$TMP/sdk"
rsync -a --exclude .dart_tool --exclude build --exclude out --exclude pubspec.lock "$HERE/" "$TMP/lab/"
cd "$TMP/lab"
"$TMP/sdk/bin/flutter" --version
"$TMP/sdk/bin/flutter" pub get
"$TMP/sdk/bin/flutter" test test/renderer_test.dart --plain-name "B1 control"
echo "temp copy: $TMP (delete when done)"
