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
 *     --out test/fixtures/lectionary_delivery.json.gz
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';
import zlib from 'node:zlib';

const args = process.argv.slice(2);
const arg = (name, fallback = null) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : fallback; };
const WEB = path.resolve(arg('--web'));
const SNAPSHOT = path.resolve(arg('--snapshot'));
const BUNDLE = path.resolve(arg('--bundle', 'assets/content'));
const OUT = arg('--out');
// An app released earlier (e.g. the 2026-10-07 bundle) that receives the manifest patch.
const APPLIED = arg('--applied') ? path.resolve(arg('--applied')) : null;
const OLD_BUNDLE = arg('--old-bundle') ? path.resolve(arg('--old-bundle')) : null;
if (!arg('--web') || !arg('--snapshot') || !OUT) throw new Error('Usage: --web <mybrev> --snapshot <dir> --out <file> [--bundle assets/content]');

const web = (rel) => import(pathToFileURL(path.join(WEB, rel)).href);
const { openFirestoreSnapshot } = await web('scripts/lib/firestore-snapshot.mjs');
const content = await web('scripts/content/lib/app-content.mjs');

const snapshot = await openFirestoreSnapshot(SNAPSHOT);
const entries = (await snapshot.collectionEntries('readings')).map(({ id, data }) => content.storedDocument(id, data));
const manifestEntries = await snapshot.collectionEntries('contentManifest');
const manifest = Object.fromEntries(manifestEntries.map(({ id, data }) => [id, data]));

const production = Object.fromEntries(entries.map((doc) => [doc.id, doc]));
const productionHashes = Object.fromEntries(entries.map((doc) => [doc.id, content.documentHash(doc)]));

const bundleJson = JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(BUNDLE, 'readings.json.gz'))).toString('utf8'));
const bundleDocs = content.decodeCollection(bundleJson);
const bundleHashes = bundleJson.hashes;
const bundleManifest = JSON.parse(fs.readFileSync(path.join(BUNDLE, 'manifest.json'), 'utf8'));

// The bundle's own hashes must be what the documents hash to.
const recomputed = Object.fromEntries(Object.values(bundleDocs).map((doc) => [doc.id, content.documentHash(doc)]));
const bundleHashErrors = Object.keys(recomputed).filter((id) => recomputed[id] !== bundleHashes[id]);

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
  const oldChanged = Object.keys(production).filter((id) => id in oldDocs && productionHashes[id] !== oldJson.hashes[id]).sort();
  old = {
    contentVersion: oldManifest.contentVersion,
    collection: oldManifest.collections.readings,
    added: Object.keys(production).filter((id) => !(id in oldDocs)).sort(),
    removed: Object.keys(oldDocs).filter((id) => !(id in production)).sort(),
    changed: oldChanged,
    hashes: Object.fromEntries(oldChanged.map((id) => [id, oldJson.hashes[id]])),
    documents: Object.fromEntries(oldChanged.map((id) => [id, oldDocs[id]])),
    productionBytes: oldChanged.reduce((sum, id) => sum + Buffer.byteLength(JSON.stringify(production[id])), 0),
    collectionBytes: Object.values(production).reduce((sum, doc) => sum + Buffer.byteLength(JSON.stringify(doc)), 0),
  };
}
const readingsManifest = manifest.readings;
const fixture = {
  schema: 1,
  generatedAt: new Date().toISOString(),
  snapshot: { version: snapshot.manifest.snapshotVersion, exportedAt: snapshot.manifest.exportedAt },
  manifest: {
    current: manifest.current,
    readings: { digest: readingsManifest.digest, version: readingsManifest.version, hashes: readingsManifest.hashes, sizes: readingsManifest.sizes },
  },
  production: { count: entries.length, digest: content.collectionDigest(productionHashes) },
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
  documents: Object.fromEntries([...added, ...changed, ...(old ? old.changed : [])].map((id) => [id, production[id]])),
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
  bundleDigest: fixture.bundle.collection.digest,
  added: added.length, removed: removed.length, changed: changed.length,
  ...(old ? { oldChanged: old.changed.length, oldAdded: old.added.length, oldRemoved: old.removed.length } : {}),
  bytes: gz.length,
}, null, 2));
