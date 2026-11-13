/** Local release candidate only. Never reads/writes Firestore or publishes a manifest.
 * node scripts/refresh_approved_calendar.mjs --web <checkout> --work <scratch-dir>
 *   [--allow-unmerged-web] [--expect-web-commit <sha>]
 * Uses the canonical Web content:app-bundle generator, preserving every other
 * collection and its original version. The same snapshot feeds Web parity.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { resolveWeb } from './lib/web_source.mjs';
const args = process.argv.slice(2);
const arg = key => args[args.indexOf(key) + 1];
assert(args.includes('--work'), 'Pass --work <scratch directory outside the repository>');
const source = resolveWeb(args);
const web = source.web;
const work = path.resolve(arg('--work'));
assert(!work.startsWith(process.cwd() + path.sep) && work !== process.cwd(),
  'Keep the derived snapshot outside the repository');
assert.equal(execFileSync('git',['status','--porcelain','--',
  'public/documents/proper-calendar.pdf',
  'docs/audits/belarus-own-calendar-2026/approved-evidence/reference-2026-11-06.json'],
  {cwd:web,encoding:'utf8'}).trim(),'', 'Source PDF/reference must be clean');
assert(!fs.existsSync(work), 'Use a new scratch directory');
const api = await import(pathToFileURL(path.join(web, 'scripts/content/lib/app-content.mjs')));
const { buildTransferOverrideTargets } = await import(pathToFileURL(path.join(web, 'src/utils/ordo/transferOverrides.js')));
const { LOCAL_CALENDAR_REFERENCES } = await import(pathToFileURL(path.join(web, 'src/data/ordo/layers.js')));
const manifest = JSON.parse(fs.readFileSync('assets/content/manifest.json'));
const definitions = JSON.parse(fs.readFileSync(path.join(web, 'src/data/ordo/calendar-definitions.json')));
const pdf = fs.readFileSync(path.join(web, 'public/documents/proper-calendar.pdf'));
const sha = value => createHash('sha256').update(value).digest('hex');
const sourceSha256 = sha(pdf);
assert.equal(sourceSha256, 'a55dc34c89317bd0a4b683ea84b46941213aa2b981d0a9de1fe3ebeb71dc9696');
const version = Date.parse(execFileSync('git', ['show', '-s', '--format=%cI', source.head], {cwd:web,encoding:'utf8'}).trim());
const auto = new Map(buildTransferOverrideTargets({years:Array.from({length:11},(_,i)=>2025+i)}).map(d=>[d.id,d]));
const target = {liturgicalCelebrations: definitions.celebrations,
  liturgicalDioceseOverrides: definitions.dioceseOverrides, liturgicalYearOverrides: definitions.yearOverrides};
const all = {}; const groups = new Map(); const record = {};
const snapshot = (dir, collections, exportedAt) => {
  fs.mkdirSync(dir, {recursive:true});
  fs.writeFileSync(path.join(dir,'manifest.json'), JSON.stringify({schemaVersion:1,
    projectId:'flutter-approved-candidate-offline', exportedAt:new Date(exportedAt).toISOString(), collections},null,2)+'\n');
};
for (const [name, entry] of Object.entries(manifest.collections)) {
  const payload = JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join('assets/content',entry.file))));
  const original = api.decodeCollection(payload);
  assert.equal(api.describeDocuments(Object.values(original)).digest, entry.digest, `${name}: source checksum`);
  let docs = Object.values(original);
  if (target[name]) {
    const desired = new Map(target[name].map(d=>[d.id,d]));
    for (const old of docs) if (!desired.has(old.id)) {
      if (name === 'liturgicalYearOverrides') {
        assert.equal(old.source, 'auto-transfer', `Unreviewed manual override ${old.id}`);
        const computed = auto.get(old.id);
        assert(computed, `Stale transfer ${old.id} requires review`);
        desired.set(old.id, {...old, computedDate:computed.computedDate, effectiveDate:computed.effectiveDate,
          ...(Object.hasOwn(old,'to') ? {to:computed.effectiveDate} : {})});
      } else desired.set(old.id, {...old, enabled:false});
    }
    docs = [...desired.values()];
  }
  if (name === 'liturgicalCalendarMeta') docs = [{...original.current,
    schemaVersion:definitions.schemaVersion, revision:definitions.revision, sourceSha256,
    counts:{celebrations:target.liturgicalCelebrations.length,
      dioceseOverrides:definitions.dioceseOverrides.length}}];
  docs.sort((a,b)=>a.id<b.id?-1:1);
  assert.deepEqual(api.validateCollection(name,docs),[],name);
  const changed = target[name] || name === 'liturgicalCalendarMeta';
  const contentVersion = changed ? Math.max(entry.contentVersion, version) : entry.contentVersion;
  const dir = path.join(work, String(contentVersion));
  fs.mkdirSync(dir,{recursive:true});
  const text = JSON.stringify({schemaVersion:1,collectionPath:name,documents:docs.map(({id,...data})=>({id,data}))});
  const file = `${name}.json`;
  fs.writeFileSync(path.join(dir,file),text);
  const descriptor = {file:path.relative(work,path.join(dir,file)),documentCount:docs.length,sha256:sha(text)};
  all[name] = descriptor;
  if (!groups.has(contentVersion)) groups.set(contentVersion,{});
  groups.get(contentVersion)[name] = {...descriptor,file};
  record[name] = {...api.describeDocuments(docs), contentVersion};
  delete record[name].hashes; delete record[name].sizes;
}
// Counts refer to retained documents, including disabled records.
const metaGroup = [...groups].find(([,c])=>c.liturgicalCalendarMeta);
const metaPath = path.join(work,String(metaGroup[0]),'liturgicalCalendarMeta.json');
const metaPayload = JSON.parse(fs.readFileSync(metaPath));
metaPayload.documents[0].data.counts = {celebrations:record.liturgicalCelebrations.count,
  dioceseOverrides:record.liturgicalDioceseOverrides.count};
const metaText = JSON.stringify(metaPayload);
fs.writeFileSync(metaPath,metaText);
all.liturgicalCalendarMeta.sha256 = sha(metaText);
metaGroup[1].liturgicalCalendarMeta.sha256 = sha(metaText);
for (const [v,c] of groups) snapshot(path.join(work,String(v)),c,v);
snapshot(work,all,Math.max(...groups.keys()));
execFileSync('npm',['run','content:app-bundle','--',...[...groups.keys()].flatMap(v=>['--snapshot',path.join(work,String(v))]),
  '--out',path.join(work,'generated-bundle')],{cwd:web,stdio:'inherit'});
const generated = JSON.parse(fs.readFileSync(path.join(work,'generated-bundle/manifest.json')));
for (const name of Object.keys(manifest.collections)) {
  if (target[name] || name === 'liturgicalCalendarMeta') {
    fs.copyFileSync(path.join(work,'generated-bundle',generated.collections[name].file),
      path.join('assets/content',generated.collections[name].file));
    manifest.collections[name] = generated.collections[name];
  } else assert.equal(generated.collections[name].digest, manifest.collections[name].digest, `${name}: text changed`);
}
manifest.contentVersion = Math.max(...Object.values(manifest.collections).map(e=>e.contentVersion));
manifest.contentDate = new Date(manifest.contentVersion).toISOString();
fs.writeFileSync('assets/content/manifest.json', JSON.stringify(manifest,null,2)+'\n');
fs.mkdirSync('test/fixtures/belarus-approved',{recursive:true});
fs.copyFileSync(path.join(web,'docs/audits/belarus-own-calendar-2026/approved-evidence/reference-2026-11-06.json'),
  'test/fixtures/belarus-approved/reference.json');
fs.writeFileSync('test/fixtures/belarus-approved/local-assignments.json',JSON.stringify(LOCAL_CALENDAR_REFERENCES,null,2)+'\n');
fs.mkdirSync('reports/belarus-approved',{recursive:true});
const finalManifest = JSON.parse(fs.readFileSync('assets/content/manifest.json'));
fs.writeFileSync('reports/belarus-approved/source.json',JSON.stringify({webCommit:source.head,
  webOnOriginMain:source.onOriginMain, sourceSha256, sourceRows:262,effectiveAssignments:959,
  candidateOnly:!source.onOriginMain, serverPublicationVerified:false,
  releaseGate:'Verify completed Firestore revision4 then separately accepted revision5, regenerate from final snapshot; no store release before acceptance.',
  collections:Object.fromEntries(Object.entries(finalManifest.collections).map(([name,e])=>[name,{...e,
    sha256:sha(fs.readFileSync(path.join('assets/content',e.file)))}]))},null,2)+'\n');
console.log(`Same-snapshot parity: npm run ordo:flutter-fixture -- --snapshot ${work} --from 2025 --to 2035 --out ${path.resolve('test/fixtures/ordo_parity.json.gz')}`);
