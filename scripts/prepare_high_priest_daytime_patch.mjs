/** Offline only: prepare a field patch for review, never connect to Firebase.
 * node scripts/prepare_high_priest_daytime_patch.mjs --web ../mybrev
 *   [--snapshot <local Firestore snapshot>] [--out <plan.json>]
 * Without --snapshot, audits the shipped bundle; live IDs remain unverified.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { resolveWeb } from './lib/web_source.mjs';

const args = process.argv.slice(2);
const arg = key => args.includes(key) ? args[args.indexOf(key) + 1] : undefined;
assert(!args.includes('--apply'), 'Offline preparation only; no --apply phase');
const source = resolveWeb(args);
const api = await import(pathToFileURL(path.join(source.web, 'scripts/content/lib/app-content.mjs')));
const sourcePath = 'src/data/liturgical/christ-high-priest-daytime-by.json';
const sourceBytes = fs.readFileSync(path.join(source.web, sourcePath));
const copyPath = 'content-patches/christ-high-priest-daytime-by.json';
assert(sourceBytes.equals(fs.readFileSync(copyPath)), 'Canonical copy differs from merged Web source');
const proper = JSON.parse(sourceBytes);
assert.equal(Object.keys(proper.fields).length, 15);
let docs;
if (arg('--snapshot')) {
  const { openFirestoreSnapshot } = await import(pathToFileURL(path.join(source.web, 'scripts/lib/firestore-snapshot.mjs')));
  const snapshot = await openFirestoreSnapshot(arg('--snapshot'));
  docs = (await snapshot.collection('days'))?.map(({ id, ...data }) => api.storedDocument(id, data));
  assert(docs, 'Snapshot has no days collection');
} else {
  const payload = JSON.parse(zlib.gunzipSync(fs.readFileSync('assets/content/days.json.gz')));
  docs = Object.values(api.decodeCollection(payload));
}
const matched = docs.filter(d => String(d._feast || '').replace(/^feast-/, '') === 'christthehighpriest');
assert(matched.length, 'No High Priest documents found');
const updates = matched.map(before => {
  const set = { ...proper.fields };
  // Existing app versions resolve explicit references even though null gaps
  // mask the psalter. This makes the content patch compatible with them too.
  for (const hour of [1, 2, 3]) {
    for (const suffix of ['Hymn', 'Ps1', 'Ps2', 'Ps3']) set[`sext${hour}${suffix}`] = 'from-day';
  }
  if (Array.isArray(before._fromDayFields)) {
    set._fromDayFields = before._fromDayFields.filter(field => !Object.hasOwn(proper.fields, field));
  }
  const after = { ...before, ...set };
  assert.deepEqual(api.validateCollection('days', [after]), []);
  return {
    id: before.id,
    preconditionHash: api.documentHash(before),
    resultHash: api.documentHash(after),
    set,
    changedFields: Object.keys(set).filter(field => api.canonicalJson(before[field] ?? null) !== api.canonicalJson(set[field])),
    storedBytes: Buffer.byteLength(JSON.stringify(after)),
  };
});
const plan = {
  mode: 'OFFLINE REVIEW ONLY — NOT PUBLISHED',
  input: arg('--snapshot') ? 'local-snapshot' : 'shipped-bundle; live IDs and hashes must be verified before writing',
  webCommit: source.head,
  sourcePath,
  sourceSha256: createHash('sha256').update(sourceBytes).digest('hex'),
  collection: 'days',
  updates,
  publication: 'After explicit approval: compare live IDs/preconditions, field-only transaction update; content:manifest dry-run must say SAFE CONTENT PATCH before separate publication approval.',
};
const out = arg('--out') || 'reports/liturgy/christ-high-priest-daytime-patch.json';
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, JSON.stringify(plan, null, 2) + '\n');
console.log(JSON.stringify({ out, input: plan.input, documents: updates.length, fields: updates.map(u => ({ id: u.id, changed: u.changedFields.length })), webCommit: source.head }));
