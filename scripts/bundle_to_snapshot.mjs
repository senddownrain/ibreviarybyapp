/** Offline Firestore-snapshot view of the Flutter bundle. No network, no Firestore.
 *
 * The Web parity fixtures (`npm run ordo:flutter-fixture`) must run on exactly
 * the documents the app ships. This writes them in the Web snapshot format:
 *
 *   node scripts/bundle_to_snapshot.mjs --web ../mybrev --out <empty dir outside Git>
 *   (cd ../mybrev && node scripts/ordo/build-flutter-parity-fixture.mjs \
 *      --snapshot <dir> --from 2025 --to 2035 --out ../ibreviarybyapp/test/fixtures/ordo_parity.json.gz)
 *
 * `--overlay-web-patchs` replaces `liturgicalProperTexts` and `liturgicalTemplates`
 * with the generated sources of the Web checkout (`patchs/db-feasts`,
 * `patchs/db-templates`): "what the app would show once the bundle is refreshed
 * to this Web commit". Without it the snapshot is exactly the shipped bundle.
 *
 * The snapshot is a derived test input; it is never committed.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';

const args = process.argv.slice(2);
const arg = (key) => (args.includes(key) ? args[args.indexOf(key) + 1] : undefined);
assert(arg('--web') && arg('--out'), 'Pass --web <Web checkout> and --out <new directory>');
const web = path.resolve(arg('--web'));
const out = path.resolve(arg('--out'));
assert(!fs.existsSync(out) || fs.readdirSync(out).length === 0, 'The output directory must be empty');
fs.mkdirSync(out, { recursive: true });

const api = await import(pathToFileURL(path.join(web, 'scripts/content/lib/app-content.mjs')));
const bundle = path.resolve('assets/content');
const manifest = JSON.parse(fs.readFileSync(path.join(bundle, 'manifest.json')));
const collections = {};
const readPatchs = (dir) => Object.fromEntries(fs.readdirSync(path.join(web, 'patchs', dir))
  .filter((n) => n.endsWith('.json')).sort().map((n) => {
    const { _id, ...data } = JSON.parse(fs.readFileSync(path.join(web, 'patchs', dir, n), 'utf8'));
    return [_id, api.storedDocument(_id, data)];
  }));
const overlay = { liturgicalProperTexts: 'db-feasts', liturgicalTemplates: 'db-templates' };
for (const [name, entry] of Object.entries(manifest.collections)) {
  const payload = JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(bundle, entry.file))));
  const docs = args.includes('--overlay-web-patchs') && overlay[name]
    ? readPatchs(overlay[name]) : api.decodeCollection(payload);
  if (!args.includes('--overlay-web-patchs') || !overlay[name]) {
    assert.equal(Object.keys(docs).length, entry.count, `${name}: count differs from manifest`);
  }
  const documents = Object.entries(docs).map(([id, { id: _own, ...data }]) => ({ id, data }));
  const text = JSON.stringify({ schemaVersion: 1, collectionPath: name, documents });
  const sha256 = createHash('sha256').update(text).digest('hex');
  const file = `${name}-${sha256.slice(0, 12)}.json`;
  fs.writeFileSync(path.join(out, file), text);
  collections[name] = { file, documentCount: documents.length, bytes: Buffer.byteLength(text), sha256 };
}
fs.writeFileSync(path.join(out, 'manifest.json'), `${JSON.stringify({
  schemaVersion: 1,
  snapshotVersion: String(manifest.contentVersion),
  projectId: 'flutter-bundle-offline',
  scope: 'flutter-bundle',
  selectedCollections: Object.keys(collections),
  exportedAt: manifest.contentDate,
  totalDocuments: Object.values(collections).reduce((n, c) => n + c.documentCount, 0),
  collections,
}, null, 2)}\n`);
console.log(JSON.stringify({ out, exportedAt: manifest.contentDate,
  collections: Object.fromEntries(Object.entries(collections).map(([k, v]) => [k, v.documentCount])) }, null, 2));
