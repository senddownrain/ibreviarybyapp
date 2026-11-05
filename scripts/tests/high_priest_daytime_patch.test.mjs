// Offline generator regressions. MYBREV_CHECKOUT=../mybrev node --test <file>
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const web = path.resolve(process.env.MYBREV_CHECKOUT || '../mybrev');
const api = await import(pathToFileURL(path.join(web, 'scripts/content/lib/app-content.mjs')));
const id = 'feast-christthehighpriest';
const before = api.decodeCollection(JSON.parse(zlib.gunzipSync(fs.readFileSync('assets/content/days.json.gz'))))[id];
const referenceFields = [1, 2, 3].flatMap(h => ['Hymn', 'Ps1', 'Ps2', 'Ps3'].map(s => `sext${h}${s}`));
function prepare(doc) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'daytime-plan-'));
  try {
    const { id: _id, ...data } = doc;
    fs.writeFileSync(path.join(root, 'days.json'), JSON.stringify({ schemaVersion: 1, collectionPath: 'days', documents: [{ id, data }] }));
    fs.writeFileSync(path.join(root, 'manifest.json'), JSON.stringify({ schemaVersion: 1, collections: { days: { file: 'days.json', documentCount: 1 } } }));
    const out = path.join(root, 'plan.json');
    try {
      execFileSync(process.execPath, ['scripts/prepare_high_priest_daytime_patch.mjs', '--web', web, '--snapshot', root, '--out', out], { stdio: 'pipe' });
      return { plan: JSON.parse(fs.readFileSync(out)), error: null };
    } catch (e) {
      assert.equal(fs.existsSync(out), false, 'A rejected plan is never written');
      return { plan: null, error: String(e.stderr) };
    }
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

test('exactly 12 references, every other stored field unchanged', () => {
  const { plan, error } = prepare(before);
  assert.equal(error, null);
  const update = plan.updates[0];
  assert.deepEqual(Object.keys(update.set), referenceFields);
  assert.deepEqual(Object.values(update.set), referenceFields.map(() => 'from-day'));
  const after = { ...before, ...update.set };
  for (const key of Object.keys(before)) {
    if (!referenceFields.includes(key)) assert.deepEqual(after[key], before[key], key);
  }
  assert.equal(api.documentHash(after), update.resultHash);
});
test('already resolved references need no new writes (idempotent)', () => {
  const doc = { ...before, ...Object.fromEntries(referenceFields.map(f => [f, 'from-day'])) };
  assert.deepEqual(prepare(doc).plan.updates, []);
});
test('correct full collect with different HTML is preserved', () => {
  const doc = { ...before, sext2Pr: before.sext2Pr.replaceAll('text-align: justify;', 'text-align: left;') };
  const { plan, error } = prepare(doc);
  assert.equal(error, null);
  assert(!Object.hasOwn(plan.updates[0].set, 'sext2Pr'));
});
test('refuse a shortened collect; never automatically repair it', () => {
  const source = JSON.parse(fs.readFileSync('content-patches/christ-high-priest-daytime-by.json'));
  const { plan, error } = prepare({ ...before, sext1Pr: source.fields.sext1Pr });
  assert.equal(plan, null);
  assert.match(error, /must retain Lauds collect/);
});
test('refuse unexpected Proper text', () => {
  const { plan, error } = prepare({ ...before, sext3R: before.sext2R });
  assert.equal(plan, null);
  assert.match(error, /needs source review/);
});
test('refuse stale Proper inheritance metadata instead of broadening the patch', () => {
  const { plan, error } = prepare({ ...before, _fromDayFields: ['sext1R'] });
  assert.equal(plan, null);
  assert.match(error, /refusing a broader patch/);
});
test('refuse unexpected populated psalm instead of overwriting it', () => {
  const { plan, error } = prepare({ ...before, sext2Ps1: 'unexpected populated source' });
  assert.equal(plan, null);
  assert.match(error, /unexpected own text needs review/);
});
