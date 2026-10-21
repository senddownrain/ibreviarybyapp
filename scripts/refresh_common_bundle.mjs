/** Local bundle only; no network and no Firestore writes.
 * node scripts/refresh_common_bundle.mjs --web ../mybrev --publication <after.json>
 * Add --apply-bundle after inspecting the dry-run. Only three collections change.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';

const args = process.argv.slice(2);
const arg = (key) => args[args.indexOf(key) + 1];
assert(args.includes('--web') && args.includes('--publication'), 'Pass --web and --publication');
const web = path.resolve(arg('--web'));
assert.equal(execFileSync('git', ['rev-parse', 'HEAD'], { cwd: web, encoding: 'utf8' }).trim(),
  '0612d534cacbc847ab6c6b7e0102137333f07211', 'Use the reviewed production Web commit');
const api = await import(pathToFileURL(path.join(web, 'scripts/content/lib/app-content.mjs')));
const publication = JSON.parse(fs.readFileSync(arg('--publication'), 'utf8'));
assert.equal(publication.meta.data.properTextsRevision, 4);
assert.equal(publication.documents.length, 27);
assert.equal(publication.documents.reduce((n, d) => n + Object.keys(d.data._commonBase ?? {}).length, 0), 29);
const bundle = path.resolve('assets/content');
const manifest = JSON.parse(fs.readFileSync(path.join(bundle, 'manifest.json')));
const version = Math.max(...[publication.meta, ...publication.documents]
  .map(d => d.updateTime.seconds * 1000 + Math.floor(d.updateTime.nanoseconds / 1e6)));
const read = name => api.decodeCollection(JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(bundle, `${name}.json.gz`)))));
const propers = read('liturgicalProperTexts');
const normalize = doc => Object.fromEntries(Object.entries(doc).filter(([k]) =>
  !api.BOOKKEEPING_FIELDS.has(k) && k !== '_commonBase' && k !== '_fieldRules'));
for (const entry of publication.documents) {
  assert(entry.exists && propers[entry.id], `Missing public Proper ${entry.id}`);
  const source = api.storedDocument(entry.id, entry.data);
  // Refuse text/identity drift; rules and bases are verified separately below.
  assert.equal(api.canonicalJson(normalize(propers[entry.id])), api.canonicalJson(normalize(source)), entry.id);
  propers[entry.id]._commonBase = source._commonBase;
}
const properDocs = fs.readdirSync(path.join(web, 'patchs/db-feasts')).filter(n => n.endsWith('.json')).map(n => {
  const { _id, ...data } = JSON.parse(fs.readFileSync(path.join(web, 'patchs/db-feasts', n)));
  return api.storedDocument(_id, data);
});
// Independently verified by audit_common_delivery.mjs against live public Proper.
assert.equal(api.describeDocuments(properDocs).digest, '16c87c1e79df5370');
assert.deepEqual(properDocs.map(d => d.id).sort(), Object.keys(propers).sort());
for (const doc of properDocs) {
  assert.equal(api.canonicalJson(normalize(propers[doc.id])), api.canonicalJson(normalize(doc)),
    `Text or identity drift: ${doc.id}`);
}
const templates = fs.readdirSync(path.join(web, 'patchs/db-templates')).filter(n => n.endsWith('.json')).map(n => {
  const { _id, ...data } = JSON.parse(fs.readFileSync(path.join(web, 'patchs/db-templates', n)));
  return api.storedDocument(_id, data);
});
// Published identity from the 2026-10-20 scoped dry-run and publication backup.
assert.equal(api.describeDocuments(templates).digest, 'fd4b4f8eac9c9902');
assert.deepEqual(templates.map(d => d.id).sort(), Object.keys(read('liturgicalTemplates')).sort());
const meta = read('liturgicalCalendarMeta');
meta.current.properTextsRevision = 4;
meta.current.templatesRevision = 3;
const updates = { liturgicalProperTexts: properDocs, liturgicalTemplates: templates,
  liturgicalCalendarMeta: Object.values(meta) };
const changes = [];
for (const [name, docs] of Object.entries(updates)) {
  const invalid = api.validateCollection(name, docs);
  assert.deepEqual(invalid, []);
  const described = api.describeDocuments(docs);
  const old = read(name);
  changes.push({ collection: name, before: manifest.collections[name].digest, after: described.digest,
    changed: docs.filter(d => api.documentHash(old[d.id]) !== api.documentHash(d)).map(d => d.id),
    added: docs.filter(d => !old[d.id]).map(d => d.id), removed: Object.keys(old).filter(id => !docs.some(d => d.id === id)) });
  if (!args.includes('--apply-bundle')) continue;
  const payload = { schemaVersion: 1, collection: name, contentVersion: version,
    ...api.encodeCollection(docs), hashes: described.hashes };
  const bytes = zlib.gzipSync(JSON.stringify(payload), { level: 9 });
  fs.writeFileSync(path.join(bundle, `${name}.json.gz`), bytes);
  manifest.collections[name] = { file: `${name}.json.gz`, contentVersion: version,
    contentDate: new Date(version).toISOString(), count: docs.length, digest: described.digest,
    storedBytes: described.bytes, bundleBytes: bytes.length };
}
if (args.includes('--apply-bundle')) {
  manifest.contentVersion = Math.max(manifest.contentVersion, version);
  manifest.contentDate = new Date(manifest.contentVersion).toISOString();
  fs.writeFileSync(path.join(bundle, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
}
console.log(JSON.stringify({ mode: args.includes('--apply-bundle') ? 'local-bundle' : 'dry-run',
  contentVersion: version, properTextsRevision: 4, bindings: 29, changes }, null, 2));
