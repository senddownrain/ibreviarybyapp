#!/usr/bin/env bash
# Single source of truth for the release Flutter version: the lower bound of
# `environment.flutter` in pubspec.yaml (">=3.41.4 <4.0.0" → 3.41.4).
# Prints the version. Fails when codemagic.yaml pins a different one, or when
# EXPECT_FLUTTER (a tool that is about to be used) differs.
set -euo pipefail
cd "$(dirname "$0")/../.."

required=$(sed -nE 's/^[[:space:]]+flutter:[[:space:]]*"?>=([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' pubspec.yaml | head -1)
if [ -z "$required" ]; then
  echo "::error::pubspec.yaml environment.flutter has no '>=X.Y.Z' lower bound" >&2
  exit 2
fi

if [ -f codemagic.yaml ]; then
  for pinned in $(sed -nE 's/^[[:space:]]+flutter:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)[[:space:]]*$/\1/p' codemagic.yaml | sort -u); do
    if [ "$pinned" != "$required" ]; then
      echo "::error::Flutter version drift: pubspec.yaml requires $required, codemagic.yaml pins $pinned" >&2
      exit 3
    fi
  done
fi

if [ -n "${EXPECT_FLUTTER:-}" ] && [ "$EXPECT_FLUTTER" != "$required" ]; then
  echo "::error::Flutter version mismatch: pubspec.yaml requires $required, found $EXPECT_FLUTTER" >&2
  exit 3
fi
echo "$required"
