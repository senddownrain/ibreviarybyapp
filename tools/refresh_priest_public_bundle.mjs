// Local snapshots only. Uses mybrev's reviewed storage plan and bundle codec.
// Private texts/proof are never written to output or diagnostic logs.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';
import zlib from 'node:zlib';

const args = process.argv.slice(2);
const option = (name) => args[args.indexOf(name) + 1];
for (const name of ['--web-dir', '--snapshot', '--policy', '--out']) {
  if (!args.includes(name) || !option(name)) throw new Error(`Required: ${name}`);
}
const web = path.resolve(option('--web-dir'));
const moduleAt = (file) => import(pathToFileURL(path.join(web, file)).href);
const { openFirestoreSnapshot } = await moduleAt('scripts/lib/firestore-snapshot.mjs');
const { canonicalPrayerContent, prayerStoragePlan } = await moduleAt('src/utils/prayerStoragePlan.mjs');
const { storedDocument, describeDocuments, encodeCollection, validateCollection } = await moduleAt('scripts/content/lib/app-content.mjs');
const snapshot = await openFirestoreSnapshot(option('--snapshot'));
const source = new Map();
for (const name of ['prayers', 'prayerCategories', 'priestProtectedPrayers', 'priestProtectedCategories']) {
  const docs = await snapshot.collection(name);
  if (!docs) throw new Error(`Incomplete snapshot: ${name}`);
  source.set(name, docs);
}
const policy = JSON.parse(fs.readFileSync(option('--policy'), 'utf8'));
const content = canonicalPrayerContent(source);
for (const flag of policy.categoryFlags || []) {
  const category = content.categories.find((item) => item.id === flag.id);
  if (!category || typeof flag.priestOnly !== 'boolean') throw new Error('Invalid reviewed category policy');
  category.priestOnly = flag.priestOnly;
}
const { desired } = prayerStoragePlan(source, content);
if ((policy.mustRemainPublic || []).some((id) => !desired.get('prayers').some((item) => item.id === id))) {
  throw new Error('Reviewed public prayer would be missing or restricted');
}
const out = path.resolve(option('--out'));
const manifest = JSON.parse(fs.readFileSync(path.join(out, 'manifest.json'), 'utf8'));
const version = Date.parse(snapshot.manifest.exportedAt);
if (!Number.isSafeInteger(version) || snapshot.manifest.projectId !== 'ibreviaryby') throw new Error('Invalid source metadata');
const protectedPrayerIds = desired.get('priestProtectedPrayers').map((item) => item.id).sort();
const protectedCategoryIds = desired.get('priestProtectedCategories').map((item) => item.id).sort();
const cleanupDigest = createHash('sha256').update(JSON.stringify({ protectedPrayerIds, protectedCategoryIds })).digest('hex');
const cleanup = { digest: cleanupDigest, protectedPrayerIds, protectedCategoryIds };
const prepared = new Map();
const forbidden = (value) => value && typeof value === 'object' && Object.entries(value).some(([key, item]) =>
  ['activationProof', 'activeCodeProof', 'secretHash', 'codeHash', 'refreshToken'].includes(key) || forbidden(item));
for (const name of ['prayers', 'prayerCategories']) {
  const docs = desired.get(name).map(({ id, ...data }) => storedDocument(id, data)).sort((a, b) => a.id < b.id ? -1 : 1);
  if (validateCollection(name, docs).length || docs.some(forbidden)) throw new Error(`Unsafe public collection: ${name}`);
  const described = describeDocuments(docs);
  const encoded = encodeCollection(docs);
  const bytes = zlib.gzipSync(Buffer.from(JSON.stringify({ schemaVersion: manifest.schemaVersion, collection: name,
    contentVersion: version, ...encoded, hashes: described.hashes })), { level: 9 });
  bytes.writeUInt32LE(0, 4);
  const file = `${name}.json.gz`;
  prepared.set(file, bytes);
  manifest.collections[name] = { file, contentVersion: version, contentDate: new Date(version).toISOString(),
    count: described.count, digest: described.digest, storedBytes: described.bytes, bundleBytes: bytes.length };
}
manifest.contentVersion = Math.max(manifest.contentVersion, version);
manifest.contentDate = new Date(manifest.contentVersion).toISOString();
// IDs only: a one-time cleanup of formerly public plaintext, never an access grant.
manifest.priestCacheCleanup = cleanup;
const report = { projectId: snapshot.manifest.projectId, snapshotVersion: snapshot.manifest.snapshotVersion,
  publicPrayers: desired.get('prayers').length, publicCategories: desired.get('prayerCategories').length,
  protectedPrayers: protectedPrayerIds.length, protectedCategories: protectedCategoryIds.length,
  cleanupDigest, contentVersion: version,
  formerlyProtectedPrayerIdsInBundle: protectedPrayerIds.filter((id) =>
    id in JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(out, 'prayers.json.gz')))).docs).length };
console.log(JSON.stringify(report, null, 2));
if (args.includes('--write')) {
  prepared.set('manifest.json', Buffer.from(`${JSON.stringify(manifest, null, 2)}\n`));
  for (const [file, bytes] of prepared) fs.writeFileSync(path.join(out, `${file}.pending`), bytes);
  // Manifest last: a failed preparation never activates a partial catalogue.
  for (const file of prepared.keys()) fs.renameSync(path.join(out, `${file}.pending`), path.join(out, file));
}
