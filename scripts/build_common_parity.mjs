/** Offline Web oracle over exactly the Flutter bundle. No text duplication.
 * node scripts/build_common_parity.mjs --web ../mybrev [--full] [--allow-unmerged-web] [--expect-web-commit <sha>]
 * The Web commit is the one checked out (clean, contained in origin/main) and is
 * recorded in the fixture together with the digests of the bundle it was built on.
 * Also creates a temporary public-only snapshot for the existing full Ordo oracle.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { resolveWeb } from './lib/web_source.mjs';
const source = resolveWeb(process.argv.slice(2));
const web = source.web;
const load = name => import(pathToFileURL(path.join(web, name)));
const api = await load('scripts/content/lib/app-content.mjs');
const { assembleOffice, assemblyChoices } = await load('src/utils/ordo/officeAssembly.js');
const { buildOfficeDescriptor } = await load('src/utils/ordo/office.js');
const { computeSeason } = await load('src/utils/ordo/season.js');
const { OFFICE_CONTENT_FIELDS, OFFICE_TEXT_FIELDS } = await load('src/constants/officeFields.js');
const { resolveRuntimeDay } = await load('src/utils/ordo/runtime.js');
const { setCalendarDefinitions } = await load('src/utils/ordo/definitions.js');
const read = name => api.decodeCollection(JSON.parse(zlib.gunzipSync(fs.readFileSync(`assets/content/${name}.json.gz`))));
const manifest = JSON.parse(fs.readFileSync('assets/content/manifest.json'));
const all = Object.fromEntries(Object.keys(manifest.collections).map(name => [name, read(name)]));
setCalendarDefinitions({ celebrations: Object.values(all.liturgicalCelebrations),
  dioceseOverrides: Object.values(all.liturgicalDioceseOverrides), yearOverrides: Object.values(all.liturgicalYearOverrides) });
const cases = [];
const currentDay = Object.fromEntries(OFFICE_TEXT_FIELDS.map(f => [f, `day:${f}`]));
for (const [id, date] of [
  ['19-10-sv-paul-of-cross', '2026-10-19'], ['04-10-sv-francis-assisi', '2027-10-04'],
  ['11-08-sv-clare', '2026-08-11'], ['17-02-seven-servite-founders', '2026-02-17'],
  ['04-07-sv-elizabeth-portugal', '2026-07-04'], ['27-01-sv-angela-merici', '2026-01-27'],
]) {
  const proper = all.liturgicalProperTexts[id];
  if (!proper) throw new Error(`Unknown Proper ${id}`);
  const resolved = resolveRuntimeDay(date, { diocese: 'minsk-mohilev' });
  const office = [resolved.officeResolution.primary, ...resolved.officeResolution.alternatives]
    .find(o => o.optionId === proper._celebrationId);
  if (!office) throw new Error(`No legal Office ${id} ${date}`);
  for (const choice of assemblyChoices(proper, office)) {
    const assembled = assembleOffice({ proper, office, templates: all.liturgicalTemplates, currentDay,
      choice, season: computeSeason(date) });
    cases.push({ id, date, choice,
      fields: Object.fromEntries(OFFICE_CONTENT_FIELDS.map(f => [f, createHash('sha256')
        .update(api.canonicalJson(assembled.day[f] ?? null)).digest('hex')])),
      provenance: assembled.provenance, missing: assembled.missing, integrity: assembled.integrity,
      assembly: assembled.day._assembly });
  }
}
const bundleDigests = Object.fromEntries(Object.entries(manifest.collections).map(([name, c]) => [name, c.digest]));
fs.writeFileSync('test/fixtures/common_office_parity.json', `${JSON.stringify({
  webCommit: source.head, webOnOriginMain: source.onOriginMain, bundleContentVersion: manifest.contentVersion,
  bundleDigests, currentDay, cases }, null, 2)}\n`);
// Refresh the pre-existing small oracle with its original input documents.
const oldPath = 'test/fixtures/office_assembly_parity.json';
const small = JSON.parse(fs.readFileSync(oldPath));
for (const c of small.cases) {
  const office = buildOfficeDescriptor({ id: c.id, officeKind: c.officeKind }, computeSeason(c.date));
  for (const choice of Object.keys(c.results)) {
    const result = assembleOffice({ proper: c.proper, office, templates: small.templates,
      currentDay: small.currentDay, choice });
    c.results[choice] = Object.fromEntries(Object.keys(c.results[choice]).map(f => [f, result.day[f] ?? null]));
  }
}
fs.writeFileSync(oldPath, `${JSON.stringify(small)}\n`);
const snapshot = '.dart_tool/common-office-snapshot';
fs.mkdirSync(snapshot, { recursive: true });
const snapshotManifest = { schemaVersion: 1, exportedAt: manifest.contentDate, collections: {} };
for (const [name, docs] of Object.entries(all)) {
  const entries = Object.entries(docs).map(([id, data]) => ({ id, data }));
  const file = `${name}.json`;
  fs.writeFileSync(path.join(snapshot, file), JSON.stringify({ schemaVersion: 1, collectionPath: name, documents: entries }));
  snapshotManifest.collections[name] = { file, documentCount: entries.length };
}
fs.writeFileSync(path.join(snapshot, 'manifest.json'), JSON.stringify(snapshotManifest));
console.log(JSON.stringify({ cases: cases.length, snapshot: path.resolve(snapshot) }));
if (process.argv.includes('--full')) {
  const entry = pathToFileURL(path.join(web, 'scripts/ordo/build-flutter-parity-fixture.mjs'));
  // Its CLI guard compares file:// URLs; normalize the Windows argv path.
  process.argv = ['node', entry.href.slice('file://'.length), '--snapshot', path.resolve(snapshot),
    '--out', path.resolve('test/fixtures/ordo_parity.json.gz'), '--from', '2025', '--to', '2035'];
  await import(entry.href);
}
