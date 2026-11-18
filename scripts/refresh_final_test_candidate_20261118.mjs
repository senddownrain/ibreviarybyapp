#!/usr/bin/env node
/** Apply the November 18 edits to the existing PR #117 bundle, using saved evidence. */
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { gzipSync, gunzipSync } from 'node:zlib';

const BASE = '2d2b9c3c1fb4d695114f22ce1967527b9575a320';
const DEVOTION_REVIEW = '1eef3a7485c139b4df50571c2e0a18cef7d7f793';
const WEB_SOURCE = 'd199022b7769c1c815351e1f0808f0573ef87623';
const PRAYER_SNAPSHOT_SHA = '2476754746f69b28b26b87e5d7a9e66ea47f6d701258cc9ee8b0fa11ed9fdaf4';
const PROCESSION_REVIEW_ID = 'devotion-euharystychnaja-pracesija';
const PROCESSION_ID = 'Fd9rN0S9NU1mAmqb2isZ';
const BASILICAS = 'dedication-basilicas-peter-paul';
const REMOVED_PUBLIC_IDS = ['d_bd_0d9099c5139b3386', 'import-03-sakrament-pakayannya-spovedz'];
const SOURCE_FIELDS = ['source', 'sourceBook'];
const CHANGED_COLLECTIONS = ['prayers', 'liturgicalCelebrations', 'liturgicalCalendarMeta'];
const REPORT = 'docs/release/final-test/nov18-refresh-report.json';

const argv = process.argv.slice(2);
function option(name) {
  const i = argv.indexOf(name);
  assert(i >= 0 && argv[i + 1] && !argv[i + 1].startsWith('--'), `Missing ${name}`);
  return argv[i + 1];
}

const check = argv.includes('--check');
const web = path.resolve(option('--web'));
const assets = path.resolve(option('--assets'));
const sha = (data) => createHash('sha256').update(data).digest('hex');
const gitRead = (repo, revision, file) =>
  execFileSync('git', ['show', `${revision}:${file}`], { cwd: repo, maxBuffer: 8 * 1024 * 1024 });
assert.equal(execFileSync('git', ['rev-parse', 'HEAD'], { cwd: web, encoding: 'utf8' }).trim(), WEB_SOURCE);
const codec = await import(pathToFileURL(path.join(web, 'scripts/content/lib/app-content.mjs')));
const { PRAYER_SOURCE_REGISTRY, resolvePrayerSource } =
  await import(pathToFileURL(path.join(web, 'src/utils/prayerSource.mjs')));
const approvedEditions = new Set(PRAYER_SOURCE_REGISTRY.map((e) => e.canonicalValue).filter(Boolean));
const oldAsset = (file) => gitRead('.', BASE, `assets/content/${file}`);
const oldManifest = JSON.parse(oldAsset('manifest.json'));
assert.equal(oldManifest.schemaVersion, 1);
const next = structuredClone(oldManifest);
const saved = check ? JSON.parse(fs.readFileSync(REPORT)) : null;
next.contentDate = saved?.contentDate ?? option('--content-date');
next.contentVersion = Date.parse(next.contentDate);
assert(Number.isSafeInteger(next.contentVersion) && next.contentVersion > oldManifest.contentVersion);
assert.equal(new Date(next.contentVersion).toISOString(), next.contentDate);

function unpack(name) {
  const payload = JSON.parse(gunzipSync(oldAsset(oldManifest.collections[name].file)));
  assert.equal(payload.collection, name);
  assert.equal(payload.schemaVersion, 1);
  return codec.decodeCollection(payload);
}

const prayers = unpack('prayers');
const sourceGroups = new Map();
function recordSource(id, field, from, to) {
  assert(SOURCE_FIELDS.includes(field) && approvedEditions.has(to) && from !== to);
  assert.equal(resolvePrayerSource(from).value, to, `Unapproved source for ${id}/${field}`);
  assert.equal(prayers[id][field], from);
  const key = JSON.stringify([field, from, to]);
  const group = sourceGroups.get(key) ?? { field, from, to, ids: [] };
  group.ids.push(id);
  sourceGroups.set(key, group);
  prayers[id][field] = to;
}

if (check) {
  assert.equal(saved.prayerSnapshotSha256, PRAYER_SNAPSHOT_SHA);
  for (const { field, from, to, ids } of saved.sourceChanges) {
    for (const id of ids) recordSource(id, field, from, to);
  }
} else {
  const bytes = fs.readFileSync(option('--prayer-snapshot'));
  assert.equal(sha(bytes), PRAYER_SNAPSHOT_SHA, 'Wrong confirmed public snapshot');
  const snapshot = JSON.parse(bytes);
  assert.equal(snapshot.collectionPath, 'prayers');
  const byId = new Map(snapshot.documents.map(({ id, data }) => [id, data]));
  assert.equal(byId.size, snapshot.documents.length, 'Duplicate snapshot prayer');
  assert.deepEqual(Object.keys(prayers).filter((id) => !byId.has(id)).sort(), REMOVED_PUBLIC_IDS);
  for (const [id, prayer] of Object.entries(prayers)) {
    const observed = byId.get(id);
    if (!observed) continue;
    for (const field of SOURCE_FIELDS) {
      const from = prayer[field];
      const to = observed[field];
      if (from !== to && approvedEditions.has(to) && resolvePrayerSource(from).value === to) {
        recordSource(id, field, from, to);
      }
    }
  }
}
for (const id of REMOVED_PUBLIC_IDS) {
  assert(Object.hasOwn(prayers, id), `Missing saved baseline prayer ${id}`);
  delete prayers[id];
}

const categories = unpack('prayerCategories');
const readReview = (file) =>
  gitRead(web, DEVOTION_REVIEW, `docs/content-imports/four-devotions-2026-11-18/${file}`);
const review = JSON.parse(readReview('manifest.json'));
assert.equal(review.proofreadingStatus, 'PAGE_IMAGES_VERIFIED');
assert.equal(review.publicationStatus, 'FIRESTORE_APPLIED_READBACK_REPORTED');
assert.equal(review.documents.length, 4);
assert.equal(review.source, '«Літургічная агенда» (Мінск, 2010)');
assert.equal(categories.devotions.name, review.categoryDisplayName);
assert(categories.devotions.tags.includes(review.categoryTag));
const added = [];
const devotions = review.documents.map((item) => {
  const replacing = item.id === PROCESSION_REVIEW_ID;
  const id = replacing ? PROCESSION_ID : item.id;
  const bytes = readReview(item.filename);
  assert.equal(sha(bytes), item.sha256, `Reviewed Markdown changed for ${id}`);
  assert.equal(item.publicationStatus, 'firestore-applied-readback-reported');
  const text = bytes.toString('utf8');
  const body = {
    title: item.title,
    text,
    textFormat: item.textFormat,
    textFormatVersion: item.textFormatVersion,
    source: review.source,
  };
  if (replacing) {
    const old = prayers[id];
    assert(old?.tags.includes(review.categoryTag) && !prayers[item.id]);
    prayers[id] = {
      ...old, ...body,
      ...(old.titleVersions || old.textVersions ? {
        titleVersions: { ...old.titleVersions, be: item.title },
        textVersions: { ...old.textVersions, be: text },
      } : {}),
    };
  } else {
    assert(!prayers[id], `Existing prayer occupies new ID ${id}`);
    prayers[id] = {
      ...body, id, tags: item.tags, priestOnly: false, effectivePriestOnly: false,
    };
    added.push(id);
  }
  return { id, title: item.title, sha256: item.sha256, source: review.source };
});
assert(devotions.some(({ id }) => id === PROCESSION_ID));
for (const { id, title } of devotions) {
  assert.deepEqual(Object.values(prayers).filter((p) => p.title === title).map((p) => p.id), [id]);
  assert(prayers[id].tags.includes(review.categoryTag));
}
const prayerDocs = Object.values(prayers);
const publicPrayers = codec.publicAppCollections(new Map([
  ['prayers', prayerDocs], ['prayerCategories', Object.values(categories)],
])).get('prayers');
assert.equal(publicPrayers.length, prayerDocs.length);
const protectedIds = new Set(oldManifest.priestCacheCleanup.protectedPrayerIds);
assert(prayerDocs.every((p) =>
  !protectedIds.has(p.id) && p.isDraft !== true && p.draft !== true &&
  !['draft', 'needs_review'].includes(p.status)));

const celebrations = unpack('liturgicalCelebrations');
const celebration = celebrations[BASILICAS];
assert.equal(celebration.category, 'dedication');
assert.equal(celebration.dateRule.month, 11);
assert.equal(celebration.dateRule.day, 18);
assert.equal(celebration.color, 'ruber');
const webCalendar = JSON.parse(gitRead(web, WEB_SOURCE, 'src/data/ordo/calendar-definitions.json'));
assert.equal(webCalendar.celebrations.find((item) => item.id === BASILICAS).color, 'albus');
celebration.color = 'albus';
assert.equal(celebrations['sv-juan-diego'].enabled, false);
assert.equal(celebrations['our-lady-guadalupe'].enabled, false);
const meta = unpack('liturgicalCalendarMeta');
assert.equal(meta.current.schemaVersion, 1);
assert(meta.current.revision === 4 || meta.current.revision === 5);
meta.current.revision = 6;

const updated = {
  prayers: prayerDocs,
  liturgicalCelebrations: Object.values(celebrations),
  liturgicalCalendarMeta: Object.values(meta),
};
const generated = new Map();
const files = {};
for (const [name, entry] of Object.entries(next.collections)) {
  const file = path.join(assets, entry.file);
  const actual = fs.readFileSync(file);
  const before = oldAsset(entry.file);
  if (!check || !CHANGED_COLLECTIONS.includes(name)) {
    assert(actual.equals(before), `Unexpected baseline file change: ${entry.file}`);
  }
  if (!CHANGED_COLLECTIONS.includes(name)) {
    files[entry.file] = { sha256: sha(actual), bytes: actual.length };
    continue;
  }
  const docs = updated[name].sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  assert.deepEqual(codec.validateCollection(name, docs), [], `Invalid ${name}`);
  const described = codec.describeDocuments(docs);
  const encoded = codec.encodeCollection(docs);
  const payload = Buffer.from(JSON.stringify({
    schemaVersion: 1,
    collection: name,
    contentVersion: next.contentVersion,
    strings: encoded.strings,
    docs: encoded.docs,
    hashes: described.hashes,
  }));
  const gz = check ? actual : gzipSync(payload, { level: 9 });
  assert(gunzipSync(gz).equals(payload), `Incorrect payload in ${entry.file}`);
  generated.set(file, gz);
  next.collections[name] = {
    ...entry,
    contentVersion: next.contentVersion,
    contentDate: next.contentDate,
    count: described.count,
    digest: described.digest,
    storedBytes: described.bytes,
    bundleBytes: gz.length,
  };
  if (name === 'prayers') {
    // The published version used when preparing the previous refresh can lag the new texts.
    next.collections[name].minimumRemoteVersion = Math.max(entry.minimumRemoteVersion ?? 0, 6);
  }
  files[entry.file] = { sha256: sha(gz), bytes: gz.length };
}

const manifestFile = path.join(assets, 'manifest.json');
const manifestBytes = Buffer.from(JSON.stringify(next, null, 2) + '\n');
files['manifest.json'] = { sha256: sha(manifestBytes), bytes: manifestBytes.length };
const sourceChanges = [...sourceGroups.values()].sort((a, b) =>
  a.field.localeCompare(b.field) || a.from.localeCompare(b.from, 'be'));
sourceChanges.forEach((group) => group.ids.sort());
const report = {
  schema: 1,
  status: 'verified-offline-bundle',
  baselineCommit: BASE,
  reviewedDevotionsCommit: DEVOTION_REVIEW,
  sourceEditionWebPr: 278,
  prayerSnapshotSha256: PRAYER_SNAPSHOT_SHA,
  sourceChanges,
  sourceFieldsUpdated: sourceChanges.reduce((sum, group) => sum + group.ids.length, 0),
  processionSourceUpdated: unpack('prayers')[PROCESSION_ID].source !== review.source,
  removedPublicPrayers: REMOVED_PUBLIC_IDS,
  added,
  devotions,
  prayerCount: prayerDocs.length,
  calendarRevision: meta.current.revision,
  basilicasColor: celebration.color,
  calendarReadbackRun: 44342368712,
  contentDate: next.contentDate,
  contentVersion: next.contentVersion,
  bundleSha256: sha(codec.canonicalJson(files)),
  bundleManifestSha256: files['manifest.json'].sha256,
  files,
  collections: next.collections,
  firestoreReads: 0,
  firestoreWrites: 0,
};
if (check) {
  assert(fs.readFileSync(manifestFile).equals(manifestBytes), 'Bundle manifest differs');
  assert.deepEqual(saved, report, 'Release report differs');
} else {
  assert(fs.readFileSync(manifestFile).equals(oldAsset('manifest.json')), 'Unexpected baseline manifest');
  for (const [file, data] of generated) fs.writeFileSync(file, data);
  fs.writeFileSync(manifestFile, manifestBytes);
  fs.writeFileSync(REPORT, JSON.stringify(report, null, 2) + '\n');
}

console.log(JSON.stringify({
  prayerCount: report.prayerCount,
  devotionCount: report.devotions.length,
  sourceFieldsUpdated: report.sourceFieldsUpdated,
  processionSourceUpdated: report.processionSourceUpdated,
  calendarRevision: report.calendarRevision,
  basilicasColor: report.basilicasColor,
  contentVersion: report.contentVersion,
  bundleSha256: report.bundleSha256,
  bundleManifestSha256: report.bundleManifestSha256,
}));
