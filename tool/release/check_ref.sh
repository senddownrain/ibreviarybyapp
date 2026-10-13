#!/usr/bin/env bash
# Is this dispatch allowed to publish? Inputs (env): GITHUB_REF_TYPE,
# GITHUB_REF_NAME, GITHUB_SHA, ALLOW_NON_MAIN, ANDROID_TRACK.
# On failure writes reason=<code> to $GITHUB_OUTPUT and exits 1.
set -euo pipefail
cd "$(dirname "$0")/../.."
out="${GITHUB_OUTPUT:-/dev/null}"
fail() { echo "reason=$1" >> "$out"; echo "::error::$2"; exit 1; }

# Tracks: an explicit allow-list. Production is never a release target.
case "${ANDROID_TRACK:-internal}" in
  internal|beta) ;;
  *) fail track_not_allowed "android_track '${ANDROID_TRACK}' is not allowed: only internal and beta (never production)" ;;
esac

[ "${GITHUB_REF_TYPE:-branch}" = branch ] || fail ref_not_branch "Run from a branch, not ${GITHUB_REF_TYPE} '${GITHUB_REF_NAME}'"

git fetch --quiet origin main || true
git fetch --quiet origin "+refs/heads/${GITHUB_REF_NAME}:refs/remotes/origin/${GITHUB_REF_NAME}" || true
head_sha=$(git rev-parse HEAD)
[ "$head_sha" = "$GITHUB_SHA" ] || fail sha_mismatch "checkout is $head_sha, the run was started for $GITHUB_SHA"
[ -z "$(git status --porcelain)" ] || fail dirty_tree "the checkout has uncommitted changes"

tip=$(git rev-parse "refs/remotes/origin/${GITHUB_REF_NAME}" 2>/dev/null || true)
[ "$tip" = "$GITHUB_SHA" ] || fail branch_moved "branch ${GITHUB_REF_NAME} moved on (tip ${tip:-unknown}); this run would build ${GITHUB_SHA}. Re-run on the current tip"

if [ "$GITHUB_REF_NAME" = main ]; then
  echo "ref OK: main at ${GITHUB_SHA}"
else
  [ "${ALLOW_NON_MAIN:-false}" = true ] || fail not_main "ref '${GITHUB_REF_NAME}' is not main. Run from main, or set allow_non_main=true on purpose"
  echo "::warning::releasing from branch ${GITHUB_REF_NAME} (allow_non_main=true), not main"
  if ! git merge-base --is-ancestor refs/remotes/origin/main HEAD; then
    echo "::warning::${GITHUB_REF_NAME} does not contain the current origin/main"
  fi
fi
