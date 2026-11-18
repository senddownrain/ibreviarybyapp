#!/usr/bin/env node
/**
 * Delivery-chain fixture (read-only on the web checkout): what an installed
 * app receives for `readings` through the published version manifest.
 *
 * Reads the production snapshot (manifest documents + `readings`) and the
 * app bundle (`assets/content/readings.json.gz`) and writes:
 *   - the published manifest (`current`, `readings` hashes/sizes/digest),
 *   - the bundle identity (contentVersion, count, digest),
 *   - the documents the bundle lacks or has in another version (id → stored
 *     document as Firestore serves it) and the ones the bundle has too many,
 *   - for every drifted document which top-level fields differ.
 *
 *   node scripts/lectionary/build_delivery_fixture.mjs \
 *     --web ../mybrev --snapshot <dir> --bundle assets/content \
 *     --old-bundle <historical assets/content> --applied <applied report> \
 *     --planned-manifest <reviewed publication plan, if still pending> \
 *     --out test/fixtures/lectionary_delivery.json.gz
 */
import fs from 'node:fs';
import assert from 'node:assert/strict';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';
import zlib from 'node:zlib';

const args = process.argv.slice(2);
const arg = (name, fallback = null) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : fallback; };
const OUT = arg('--out');
if (!arg('--web') || !arg('--snapshot') || !OUT) throw new Error('Usage: --web <mybrev> --snapshot <dir> --out <file> [--bundle assets/content] [--old-bundle <dir>] [--applied <file>] [--planned-manifest <file>]');
const WEB = path.resolve(arg('--web'));
const SNAPSHOT = path.resolve(arg('--snapshot'));
const BUNDLE = path.resolve(arg('--bundle', 'assets/content'));
// An app released earlier (e.g. the 2026-10-07 bundle) that receives the manifest patch.
const APPLIED = arg('--applied') ? path.resolve(arg('--applied')) : null;
const OLD_BUNDLE = arg('--old-bundle') ? path.resolve(arg('--old-bundle')) : null;
const PLANNED = arg('--planned-manifest');

const web = (rel) => import(pathToFileURL(path.join(WEB, rel)).href);
const { openFirestoreSnapshot } = await web('scripts/lib/firestore-snapshot.mjs');
const content = await web('scripts/content/lib/app-content.mjs');

const snapshot = await openFirestoreSnapshot(SNAPSHOT);
const entries = (await snapshot.collectionEntries('readings')).map(({ id, data }) => content.storedDocument(id, data));
const manifestEntries = await snapshot.collectionEntries('contentManifest');
const manifest = Object.fromEntries(manifestEntries.map(({ id, data }) => [id, data]));

const production = Object.fromEntries(entries.map((doc) => [doc.id, doc]));
const productionIndex = content.describeDocuments(entries);
const productionHashes = productionIndex.hashes;

const bundleJson = JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(BUNDLE, 'readings.json.gz'))).toString('utf8'));
const bundleDocs = content.decodeCollection(bundleJson);
const bundleHashes = bundleJson.hashes;
const bundleManifest = JSON.parse(fs.readFileSync(path.join(BUNDLE, 'manifest.json'), 'utf8'));

// The bundle's own hashes must be what the documents hash to.
const recomputed = Object.fromEntries(Object.values(bundleDocs).map((doc) => [doc.id, content.documentHash(doc)]));
const bundleHashErrors = Object.keys(recomputed).filter((id) => recomputed[id] !== bundleHashes[id]);
assert.deepEqual(recomputed, bundleHashes, 'Bundled readings hash index');
assert.equal(content.collectionDigest(recomputed), bundleManifest.collections.readings.digest, 'Bundled readings digest');
assert.equal(Object.keys(recomputed).length, bundleManifest.collections.readings.count, 'Bundled readings count');

const added = Object.keys(production).filter((id) => !(id in bundleDocs)).sort();
const removed = Object.keys(bundleDocs).filter((id) => !(id in production)).sort();
const changed = Object.keys(production).filter((id) => id in bundleDocs && productionHashes[id] !== bundleHashes[id]).sort();

const topLevelDiff = (before, after) => {
  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
  return [...keys].filter((key) => !content.BOOKKEEPING_FIELDS.has(key)
    && content.canonicalJson(before[key]) !== content.canonicalJson(after[key])).sort();
};
/** Same words, only paragraph/whitespace layout differs. */
const squash = (value) => JSON.stringify(value ?? null).replace(/\\[nrt]/g, '').replace(/\s+/g, '');
const drift = [...added, ...changed].map((id) => ({
  id,
  state: added.includes(id) ? 'added' : 'changed',
  fields: added.includes(id) ? [] : topLevelDiff(bundleDocs[id], production[id]),
  layoutOnly: !added.includes(id)
    && topLevelDiff(bundleDocs[id], production[id]).every((key) => squash(bundleDocs[id][key]) === squash(production[id][key])),
  bundleHash: bundleHashes[id] || null,
  productionHash: productionHashes[id],
}));

let old = null;
if (OLD_BUNDLE) {
  const oldJson = JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(OLD_BUNDLE, 'readings.json.gz'))).toString('utf8'));
  const oldDocs = content.decodeCollection(oldJson);
  const oldManifest = JSON.parse(fs.readFileSync(path.join(OLD_BUNDLE, 'manifest.json'), 'utf8'));
  const oldIndex = content.describeDocuments(Object.values(oldDocs));
  assert.deepEqual(oldIndex.hashes, oldJson.hashes, 'Historical readings hashes');
  assert.equal(oldIndex.digest, oldManifest.collections.readings.digest, 'Historical readings digest');
  const oldChanged = Object.keys(production).filter((id) => id in oldDocs && productionHashes[id] !== oldJson.hashes[id]).sort();
  const oldAdded = Object.keys(production).filter((id) => !(id in oldDocs)).sort();
  const oldRemoved = Object.keys(oldDocs).filter((id) => !(id in production)).sort();
  old = {
    contentVersion: oldManifest.contentVersion,
    collection: oldManifest.collections.readings,
    added: oldAdded,
    removed: oldRemoved,
    changed: oldChanged,
    hashes: Object.fromEntries([...oldChanged, ...oldRemoved].map((id) => [id, oldJson.hashes[id]])),
    documents: Object.fromEntries([...oldChanged, ...oldRemoved].map((id) => [id, oldDocs[id]])),
    productionBytes: [...oldChanged, ...oldAdded].reduce((sum, id) => sum + productionIndex.sizes[id], 0),
    collectionBytes: productionIndex.bytes,
  };
}
const readingsManifest = manifest.readings;
const { digest, count, bytes } = productionIndex;
const publishedReadings = manifest.current.collections.readings;
assert.equal(publishedReadings.digest, readingsManifest.digest, 'Published readings index digest');
assert.equal(publishedReadings.version, readingsManifest.version, 'Published readings index version');
assert.equal(content.collectionDigest(readingsManifest.hashes), readingsManifest.digest, 'Published readings hashes');
assert.equal(Object.keys(readingsManifest.hashes).length, publishedReadings.count, 'Published readings count');
let planned = null;
if (PLANNED) {
  const plan = JSON.parse(fs.readFileSync(PLANNED, 'utf8'));
  assert.deepEqual(plan.expected.readings, productionIndex, 'Planned readings index must match the verified snapshot');
  assert(plan.changedCollections.includes('readings'));
  assert.notEqual(publishedReadings.digest, digest, 'Readings plan already published');
  const { planManifest } = await web('scripts/content/publish-manifest.mjs');
  // Use the reviewed bundle timestamp as a fixed clock for the offline plan.
  const { current } = planManifest({ readings: productionIndex }, manifest.current, plan.bundleContentVersion, { partial: true });
  const { version } = current.collections.readings;
  planned = {
    current,
    readings: { digest, version, hashes: productionHashes, sizes: productionIndex.sizes },
  };
}
const fixture = {
  schema: 1,
  generatedAt: new Date().toISOString(),
  snapshot: { version: snapshot.manifest.snapshotVersion, exportedAt: snapshot.manifest.exportedAt, source: snapshot.manifest.source },
  manifest: {
    current: manifest.current,
    readings: { digest: readingsManifest.digest, version: readingsManifest.version, hashes: readingsManifest.hashes, sizes: readingsManifest.sizes },
  },
  ...(planned ? { planned } : {}),
  production: { count, digest },
  bundle: {
    contentVersion: bundleManifest.contentVersion,
    collection: bundleManifest.collections.readings,
    recomputedDigest: content.collectionDigest(recomputed),
    hashErrors: bundleHashErrors,
  },
  added,
  removed,
  changed,
  drift,
  documents: Object.fromEntries([...added, ...changed, ...(old ? [...old.added, ...old.changed] : [])].map((id) => [id, production[id]])),
  ...(old ? { old } : {}),
  // The documents the web migration rewrote (reports/lectionary/resync-plan.applied.json).
  ...(APPLIED ? { rewritten: JSON.parse(fs.readFileSync(APPLIED, 'utf8')).changes.map((c) => ({ id: c.id, afterHash: c.afterHash, wave: c.wave })) } : {}),
};
const gz = zlib.gzipSync(Buffer.from(JSON.stringify(fixture)), { level: 9 });
gz.writeUInt32LE(0, 4);
fs.mkdirSync(path.dirname(path.resolve(OUT)), { recursive: true });
fs.writeFileSync(OUT, gz);
console.log(JSON.stringify({
  out: OUT,
  productionDigest: fixture.production.digest,
  manifestDigest: fixture.manifest.readings.digest,
  ...(planned ? { plannedDigest: planned.readings.digest } : {}),
  bundleDigest: fixture.bundle.collection.digest,
  added: added.length, removed: removed.length, changed: changed.length,
  ...(old ? { oldChanged: old.changed.length, oldAdded: old.added.length, oldRemoved: old.removed.length } : {}),
  bytes: gz.length,
}, null, 2));
