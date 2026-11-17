/** Offline only. Existing reviewed selector and app bundle writer; no Firebase. */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { resolveWeb } from './lib/web_source.mjs';
const args = process.argv.slice(2);
for (const name of ['--web', '--baseline', '--out', '--version', '--report']) {
  assert(args.includes(name) && args[args.indexOf(name) + 1], `Required ${name}`);
}
const option = k => args[args.indexOf(k) + 1];
const source = resolveWeb(args);
const moduleAt = p => import(pathToFileURL(path.join(source.web, p)));
const api = await moduleAt('scripts/content/lib/app-content.mjs');
const { writeBundle } = await moduleAt('scripts/content/build-app-bundle.mjs');
const { selectDaysTemplates } = await moduleAt('scripts/liturgy/prepare-days-templates.mjs');
const sha = v => createHash('sha256').update(v).digest('hex');
const root = path.join(source.web, 'docs/audits/liturgical-common-texts-2026-11/v4');
const json = p => JSON.parse(fs.readFileSync(p));
const fullBytes = fs.readFileSync(path.join(root, 'full-content-plan.json.gz'));
assert.equal(sha(String(fullBytes)), 'adb05cfee3a90528a0588a3ff3a3f85dd9db4ef712469e0e3e738340fccabbf1');
const full = JSON.parse(zlib.gunzipSync(fullBytes));
const plan = selectDaysTemplates(full, json(path.join(root, 'PUBLICATION_RESULT.json')));
const input = path.resolve(option('--baseline'));
const out = path.resolve(option('--out'));
assert.notEqual(input, out, 'Keep original baseline immutable');
const manifest = json(path.join(input, 'manifest.json'));
const docs = new Map(Object.entries(manifest.collections).map(([n, e]) => [n,
  api.decodeCollection(JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(input, e.file)))))]));
const original = structuredClone(docs);
const at = (o, p) => p.reduce((v, k) => v?.[k], o);
const set = (o, p, v) => { p.slice(0, -1).reduce((v, k) => v[k], o)[p.at(-1)] = v; };
const changes = [];
function edit(n, id, p, before, after, legacyHash) {
  const doc = docs.get(n)[id]; assert(doc, `Missing ${n}/${id}`);
  const value = at(doc, p);
  assert(typeof value === 'string');
  assert(value === before || value === after || (legacyHash && sha(value) === legacyHash), `Baseline drift ${n}/${id}|${p.join('.')}`);
  if (value !== after) { set(doc, p, after); changes.push(`${n}/${id}|${p.join('.')}`); }
}
// Exact reviewed 13 evening fields + the separately approved Benedictus field.
const advent = json(path.join(source.web, 'src/data/liturgical/advent-vespers-by.json')).documents;
const ben = json(path.join(source.web, 'src/data/liturgical/advent-benedictus-by.json'));
advent[ben.document][ben.field] = { before: ben.legacyValue, value: ben.value };
const compatibility = json(path.join(root, 'compatibility-review.json'));
let adventFields = 0;
for (const d of compatibility.advent) for (const f of d.changedFields) {
  const id = d.document.split('/')[1], e = advent[id][f.field];
  assert.equal(sha(api.canonicalJson(e.value)), f.afterSha256, `Advent receipt ${f.field}`);
  edit('days', id, [f.field], e.before, e.value); adventFields++;
}
assert.equal(adventFields, 14);
let properFields = 0;
for (const d of full.documents.filter(d => d.document.startsWith('liturgicalProperTexts/'))) for (const f of d.fields) {
  edit('liturgicalProperTexts', d.document.split('/')[1], f.path, f.before, f.after); properFields++;
}
assert.equal(properFields, 406);
let fields = 0;
for (const d of plan.documents) for (const f of d.fields) {
  assert.equal(sha(f.before), f.beforeSha256); assert.equal(sha(f.after), f.afterSha256);
  const [n, id] = d.document.split('/');
  // Shipped November 7 bundle predates the Web captured baseline of this field.
  const legacyHash = d.document === 'days/ordinary-w30-d6' && f.field === 'vesperR'
    ? '51ab96d9b99433d559d91e27809403f25caa4cfab37dd20715ae5543eac6f15b' : null;
  edit(n, id, f.path, f.before, f.after, legacyHash);
  assert.equal(sha(at(docs.get(n)[id], f.path)), f.afterSha256); fields++;
}
assert.equal(fields, 7791);
let held = 0;
for (const f of full.fields.filter(f => f.contentStatus === 'held')) {
  const [n, id] = f.document.split('/');
  assert.deepEqual(at(docs.get(n)[id], f.path), at(original.get(n)[id], f.path), `Held field changed ${f.document}|${f.field}`); held++;
}
assert.equal(held, 843);
// Reverting exactly the allowlisted changes must restore the entire baseline.
const restored = structuredClone(docs);
for (const key of changes) {
  const [document, field] = key.split('|');
  const [n, id] = document.split('/');
  const p = field.split('.');
  set(restored.get(n)[id], p, at(original.get(n)[id], p));
}
assert.deepEqual(restored, original, 'Unplanned content modification');
const version = Number(option('--version'));
assert(Number.isSafeInteger(version) && version > manifest.contentVersion);
const names = ['days', 'liturgicalTemplates', 'liturgicalProperTexts'];
const selected = new Map(names.map(n => [n, Object.values(docs.get(n)).sort((a,b) => a.id < b.id ? -1 : 1)]));
for (const [n, d] of selected) assert.deepEqual(api.validateCollection(n, d), []);
// Reuse the established codec/writer, preserving bytes and versions of unrelated collections.
fs.mkdirSync(out, { recursive: true });
const built = writeBundle(selected, new Map(names.map(n => [n, version])), version, out);
for (const [n, e] of Object.entries(manifest.collections)) {
  if (names.includes(n)) continue;
  fs.copyFileSync(path.join(input, e.file), path.join(out, e.file));
}
const result = { ...manifest, contentVersion: version, contentDate: new Date(version).toISOString(),
  collections: { ...manifest.collections, ...built.collections } };
fs.writeFileSync(path.join(out, 'manifest.json'), JSON.stringify(result, null, 2) + '\n');
for (const [n, e] of Object.entries(result.collections)) {
  const bytes = fs.readFileSync(path.join(out, e.file));
  const payload = JSON.parse(zlib.gunzipSync(bytes));
  const decoded = api.decodeCollection(payload);
  const described = api.describeDocuments(Object.values(decoded));
  assert.equal(described.digest, e.digest);
  assert.deepEqual(described.hashes, payload.hashes);
  assert.equal(payload.contentVersion, e.contentVersion);
  assert.equal(described.count, e.count);
  assert.equal(described.bytes, e.storedBytes);
  assert.equal(bytes.length, e.bundleBytes);
}
// Web production shards independently reconstruct precisely the same 7,791 strings.
const { applyWebLiturgicalCorrections } = await moduleAt('src/utils/webLiturgicalCorrections.js');
for (const d of plan.documents) {
  const [n,id] = d.document.split('/'); const before = structuredClone(original.get(n)[id]);
  for (const f of d.fields) set(before, f.path, f.before);
  const web = await applyWebLiturgicalCorrections(n, before);
  for (const f of d.fields) assert.equal(at(web, f.path), at(docs.get(n)[id], f.path));
}
const report = { webCommit: source.head, sourcePlanSha256: sha(fullBytes), schemaVersion: result.schemaVersion,
  contentVersion: version, fields, documents: plan.documents.length, properFields, adventFields, heldFieldsUnchanged: held,
  changedFields: changes.length, collections: result.collections,
  files: Object.fromEntries(['manifest.json', ...Object.values(result.collections).map(e => e.file)].map(f => [f, {sha256: sha(fs.readFileSync(path.join(out,f))), bytes: fs.statSync(path.join(out,f)).size}])),
  previousDiff: Object.fromEntries(names.map(n => {
    const before = api.describeDocuments(Object.values(original.get(n)));
    const after = api.describeDocuments(Object.values(docs.get(n)));
    const changed = Object.keys(before.hashes).filter(id => before.hashes[id] !== after.hashes[id]);
    return [n, { beforeDigest: before.digest, changed: changed.length, existing: before.count,
      downloadBytes: changed.reduce((sum, id) => sum + after.sizes[id], 0) }];
  })) };
fs.writeFileSync(option('--report'), JSON.stringify(report, null, 2) + '\n');
if (args.includes('--manifest-out')) {
  const dir = path.resolve(option('--manifest-out'));
  fs.mkdirSync(dir, { recursive: true });
  const requirements = { status: 'offline-candidate-not-a-production-receipt',
    schemaVersion: 1, bundleContentVersion: version,
    publicationContentVersion: 'actual publication epoch milliseconds, >= bundleContentVersion', collections: {} };
  for (const [n, documents] of selected) {
    const d = api.describeDocuments(documents);
    const nextVersion = (compatibility.publishedCollections[n]?.version ?? 0) + 1;
    requirements.collections[n] = { digest: d.digest, count: d.count, bytes: d.bytes,
      versionIfPublishedBaselineUnchanged: nextVersion, requiresFreshPriorManifestCheck: true };
    fs.writeFileSync(path.join(dir, `${n}-manifest-candidate.json`), JSON.stringify({
      collection: n, digest: d.digest, version: nextVersion, hashes: d.hashes, sizes: d.sizes,
    }, null, 2) + '\n');
  }
  fs.writeFileSync(path.join(dir, 'manifest-requirements.json'), JSON.stringify(requirements, null, 2) + '\n');
}
console.log(JSON.stringify({fields, properFields, adventFields, held, contentVersion:version, webParity:'7791/7791'}));
