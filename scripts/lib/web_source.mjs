/** Provenance of the Web checkout a Flutter parity script runs against.
 *
 * Replaces the former hard-coded Web SHA. A script now records the commit it
 * actually used and refuses a source that cannot be reproduced:
 *   - the content/engine paths must be clean (no uncommitted edits);
 *   - HEAD must be contained in origin/main (override: --allow-unmerged-web);
 *   - `--expect-web-commit <sha>` pins a run when a reviewer needs it.
 * Nothing here talks to the network (`git fetch` is left to the caller).
 */
import path from 'node:path';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';

const SOURCE_PATHS = ['src', 'scripts', 'patchs/db-feasts', 'patchs/db-templates', 'package.json'];

const git = (cwd, ...args) => execFileSync('git', args, { cwd, encoding: 'utf8' }).trim();

export function resolveWeb(args, { requireClean = true } = {}) {
  const key = args.indexOf('--web');
  assert(key >= 0 && args[key + 1], 'Pass --web <Web checkout>');
  const web = path.resolve(args[key + 1]);
  const head = git(web, 'rev-parse', 'HEAD');
  const dirty = git(web, 'status', '--porcelain', '--', ...SOURCE_PATHS).split('\n').filter(Boolean);
  if (requireClean) {
    assert.deepEqual(dirty, [], `Web checkout has uncommitted changes in source paths:\n${dirty.join('\n')}`);
  }
  let onOriginMain = false;
  try {
    execFileSync('git', ['merge-base', '--is-ancestor', head, 'origin/main'], { cwd: web, stdio: 'ignore' });
    onOriginMain = true;
  } catch { /* not contained, or origin/main unknown */ }
  if (!args.includes('--allow-unmerged-web')) {
    assert(onOriginMain, `Web HEAD ${head} is not contained in origin/main (run git fetch, or pass --allow-unmerged-web)`);
  }
  const expect = args.includes('--expect-web-commit') ? args[args.indexOf('--expect-web-commit') + 1] : null;
  if (expect) assert.equal(head, expect, '--expect-web-commit does not match the Web checkout');
  return { web, head, dirty, onOriginMain, pinned: Boolean(expect) };
}

/** Flutter side of the same record. */
export function flutterHead(cwd = process.cwd()) {
  return { head: git(cwd, 'rev-parse', 'HEAD'), dirty: git(cwd, 'status', '--porcelain', '--', 'assets/content').split('\n').filter(Boolean) };
}
