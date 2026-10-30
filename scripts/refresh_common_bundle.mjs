/** Local bundle only; no network and no Firestore access.
 *
 *   node scripts/refresh_common_bundle.mjs --web ../mybrev \
 *     --proper-revision <N> --templates-revision <N>                (dry-run)
 *   ... --apply-bundle [--allow-text-drift id1,id2] [--allow-added id,..] [--allow-removed id,..]
 *
 * Source of truth is the generated Web content of the checked-out Web commit
 * (`patchs/db-feasts`, `patchs/db-templates`), which is what the next publication
 * of that commit carries. The Web commit is recorded, never pinned: a reviewer
 * who needs a pin passes `--expect-web-commit`, and `--expect-proper-digest` /
 * `--expect-templates-digest` pin the result to digests taken from a published
 * manifest. Only `liturgicalProperTexts`, `liturgicalTemplates` and
 * `liturgicalCalendarMeta/current` can change.
 *
 * The revisions live only in the published `liturgicalCalendarMeta/current`;
 * they cannot be derived offline and must be passed in by the release manager.
 *
 * A dry-run classifies every change per document: `text` (any field other than
 * `_commonBase`, `_fieldRules`, bookkeeping), `rules`, `base`. Text drift of an
 * existing Proper/Common, additions and removals are refused on apply unless the
 * exact ids are listed — an editorial change must be a conscious decision.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
import { resolveWeb } from './lib/web_source.mjs';

const args = process.argv.slice(2);
const arg = (key) => (args.includes(key) ? args[args.indexOf(key) + 1] : undefined);
const idList = (key) => new Set((arg(key) ?? '').split(',').map((id) => id.trim()).filter(Boolean));
const source = resolveWeb(args);
const web = source.web;
const apply = args.includes('--apply-bundle');
const properRevision = Number(arg('--proper-revision'));
const templatesRevision = Number(arg('--templates-revision'));
assert(Number.isInteger(properRevision) && Number.isInteger(templatesRevision),
  'Pass --proper-revision and --templates-revision (from the published liturgicalCalendarMeta/current)');
const allow = { text: idList('--allow-text-drift'), added: idList('--allow-added'), removed: idList('--allow-removed') };

const api = await import(pathToFileURL(path.join(web, 'scripts/content/lib/app-content.mjs')));
const bundle = path.resolve('assets/content');
const manifest = JSON.parse(fs.readFileSync(path.join(bundle, 'manifest.json')));
const read = (name) => api.decodeCollection(JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(bundle, `${name}.json.gz`)))));
const generated = (dir) => fs.readdirSync(path.join(web, 'patchs', dir)).filter((n) => n.endsWith('.json')).sort().map((n) => {
  const { _id, ...data } = JSON.parse(fs.readFileSync(path.join(web, 'patchs', dir, n), 'utf8'));
  return api.storedDocument(_id, data);
});
const FIELD_CLASS = { _commonBase: 'base', _fieldRules: 'rules' };
const classOf = (key) => (api.BOOKKEEPING_FIELDS.has(key) ? null : FIELD_CLASS[key] ?? 'text');

/** Per-field difference of two stored documents, grouped by class. */
function fieldDiff(before, after) {
  const out = { text: [], rules: [], base: [] };
  for (const key of new Set([...Object.keys(before), ...Object.keys(after)])) {
    const kind = classOf(key);
    if (!kind) continue;
    if (api.canonicalJson(before[key] ?? null) !== api.canonicalJson(after[key] ?? null)) out[kind].push(key);
  }
  return out;
}

const updates = { liturgicalProperTexts: generated('db-feasts'), liturgicalTemplates: generated('db-templates') };
const meta = read('liturgicalCalendarMeta');
meta.current.properTextsRevision = properRevision;
meta.current.templatesRevision = templatesRevision;
updates.liturgicalCalendarMeta = Object.values(meta);

const changes = [];
const refusals = [];
for (const [name, docs] of Object.entries(updates)) {
  assert.deepEqual(api.validateCollection(name, docs), [], `${name} fails the content schema`);
  const old = read(name);
  const described = api.describeDocuments(docs);
  const added = docs.filter((d) => !old[d.id]).map((d) => d.id);
  const removed = Object.keys(old).filter((id) => !docs.some((d) => d.id === id));
  const changed = {};
  for (const doc of docs) {
    if (!old[doc.id] || api.documentHash(old[doc.id]) === api.documentHash(doc)) continue;
    changed[doc.id] = fieldDiff(old[doc.id], doc);
  }
  changes.push({ collection: name, before: manifest.collections[name].digest, after: described.digest,
    count: docs.length, added, removed,
    changed: Object.fromEntries(Object.entries(changed).map(([id, d]) =>
      [id, Object.fromEntries(Object.entries(d).filter(([, keys]) => keys.length))])) });
  if (name !== 'liturgicalCalendarMeta') {
    for (const id of added) if (!allow.added.has(id)) refusals.push(`${name}: added ${id}`);
    for (const id of removed) if (!allow.removed.has(id)) refusals.push(`${name}: removed ${id}`);
    for (const [id, d] of Object.entries(changed)) {
      if (d.text.length && !allow.text.has(id)) refusals.push(`${name}: text drift ${id} [${d.text.join(', ')}]`);
    }
  }
}
const digest = (name) => changes.find((c) => c.collection === name).after;
if (arg('--expect-proper-digest')) assert.equal(digest('liturgicalProperTexts'), arg('--expect-proper-digest'));
if (arg('--expect-templates-digest')) assert.equal(digest('liturgicalTemplates'), arg('--expect-templates-digest'));

if (apply) {
  assert.deepEqual(refusals, [], `Refused (list the exact ids to accept them):\n${refusals.join('\n')}`);
  // Only the Web checkout decides the content version: the newest of the sources
  // that changed is not knowable offline, so a new version is the Web commit time.
  const version = Math.max(manifest.contentVersion, Date.parse(
    execFileSync('git', ['show', '-s', '--format=%cI', source.head], { cwd: web, encoding: 'utf8' }).trim()));
  for (const [name, docs] of Object.entries(updates)) {
    const described = api.describeDocuments(docs);
    const payload = { schemaVersion: 1, collection: name, contentVersion: version,
      ...api.encodeCollection(docs), hashes: described.hashes };
    const bytes = zlib.gzipSync(JSON.stringify(payload), { level: 9 });
    fs.writeFileSync(path.join(bundle, `${name}.json.gz`), bytes);
    manifest.collections[name] = { file: `${name}.json.gz`, contentVersion: version,
      contentDate: new Date(version).toISOString(), count: docs.length, digest: described.digest,
      storedBytes: described.bytes, bundleBytes: bytes.length };
  }
  manifest.contentVersion = version;
  manifest.contentDate = new Date(version).toISOString();
  fs.writeFileSync(path.join(bundle, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
}
console.log(JSON.stringify({ mode: apply ? 'local-bundle' : 'dry-run', webCommit: source.head,
  webOnOriginMain: source.onOriginMain, properTextsRevision: properRevision, templatesRevision,
  refusedOnApply: refusals, changes }, null, 2));
