/** One final candidate from actual verified public snapshots. No Firebase I/O. */
import fs from 'node:fs';import path from 'node:path';import {pathToFileURL} from 'node:url';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {resolveWeb} from './lib/web_source.mjs';
const args=process.argv.slice(2),get=k=>args[args.indexOf(k)+1];
for(const k of ['--web','--liturgical-snapshot','--public-snapshot','--baseline-manifest','--approved-calendar-baseline','--out','--report'])assert(args.includes(k),`Missing ${k}`);
const source=resolveWeb(args),api=await import(pathToFileURL(path.join(source.web,'scripts/content/lib/app-content.mjs'))),builder=await import(pathToFileURL(path.join(source.web,'scripts/content/build-app-bundle.mjs')));
const sha=b=>createHash('sha256').update(b).digest('hex');
const lit=get('--liturgical-snapshot'),pub=get('--public-snapshot'),baseline=JSON.parse(fs.readFileSync(get('--baseline-manifest'))),published=JSON.parse(fs.readFileSync(path.join(lit,'published-manifests.json')))['contentManifest/current'];
const input=await builder.readCollections([lit,pub]),collections=api.publicAppCollections(input.collections);
const negativePrayers=new Set(baseline.priestCacheCleanup?.protectedPrayerIds||[]),negativeCategories=new Set(baseline.priestCacheCleanup?.protectedCategoryIds||[]);
assert(!collections.get('prayers').some(d=>negativePrayers.has(d.id)||d.isDraft===true||d.draft===true||['draft','needs_review'].includes(d.status)),'Private/draft prayer in final public bundle');
assert(!collections.get('prayerCategories').some(d=>negativeCategories.has(d.id)),'Private category in public bundle');
// Preserve the already accepted calendar from main when the live revision is older.
// This never replaces a newer production document or pretends server parity.
const firestoreSnapshot=Object.fromEntries([...collections].map(([n,d])=>[n,api.describeDocuments(d)]));
const acceptedDir=get('--approved-calendar-baseline'),accepted=JSON.parse(fs.readFileSync(path.join(acceptedDir,'manifest.json'))),proof=JSON.parse(fs.readFileSync('reports/belarus-approved/source.json'));
const calendarNames=['liturgicalCalendarMeta','liturgicalCelebrations','liturgicalDioceseOverrides','liturgicalYearOverrides'];
assert.equal(proof.sourceSha256,'a55dc34c89317bd0a4b683ea84b46941213aa2b981d0a9de1fe3ebeb71dc9696');
assert.equal(accepted.approvedCommit,'aacfd044546d6f2a8e1cc5eff2589fde6bd1ee99');
const calendarPreservation={policy:'retain-confirmed-main-calendar-over-older-Firestore-revision',approvedCommit:accepted.approvedCommit,sourcePdfSha256:proof.sourceSha256,firestoreWrites:0,collections:{}};
for(const name of calendarNames){
 const entry=accepted.collections[name],bytes=fs.readFileSync(path.join(acceptedDir,entry.file));
 assert.equal(sha(bytes),proof.collections[name].sha256,`Accepted calendar SHA ${name}`);
 const payload=JSON.parse((await import('node:zlib')).default.gunzipSync(bytes)),docs=Object.values(api.decodeCollection(payload));
 const snapshot=JSON.parse(fs.readFileSync(path.join(pub,name+'.json')));
 assert(snapshot.documents.every(d=>d.updateTime.seconds*1000<entry.contentVersion),`A newer production calendar document must not be overwritten: ${name}`);
 const after=api.describeDocuments(docs);assert.equal(after.digest,entry.digest);
 calendarPreservation.collections[name]={before:firestoreSnapshot[name],after,acceptedFileSha256:sha(bytes),sourceUpdateTimesBeforeAcceptedVersion:true};
 collections.set(name,docs);input.versions.set(name,entry.contentVersion);
}
const acceptedMeta=collections.get('liturgicalCalendarMeta').find(d=>d.id==='current');
const rawMeta=JSON.parse(fs.readFileSync(path.join(pub,'liturgicalCalendarMeta.json'))).documents.find(d=>d.id==='current').data;
assert.equal(rawMeta.revision,3);assert.equal(acceptedMeta.revision,4);
calendarPreservation.firestoreRevision=rawMeta.revision;calendarPreservation.acceptedRevision=acceptedMeta.revision;
const invalid=[...collections].flatMap(([n,d])=>api.validateCollection(n,d));assert.deepEqual(invalid,[],'Invalid actual public content');
const manifest=builder.writeBundle(collections,input.versions,input.contentVersion,get('--out'));
for(const name of calendarNames){fs.copyFileSync(path.join(acceptedDir,accepted.collections[name].file),path.join(get('--out'),manifest.collections[name].file));manifest.collections[name]={...accepted.collections[name],minimumRemoteVersion:2};}
manifest.priestCacheCleanup=baseline.priestCacheCleanup;
const ahead={};
for(const [name,entry] of Object.entries(manifest.collections)){
 const remote=published.collections[name];
 if(calendarNames.includes(name)&&!remote){ahead[name]={published:null,bundled:{digest:entry.digest,count:entry.count,bytes:entry.storedBytes},minimumRemoteVersion:2,reason:'accepted-main-calendar-ahead-of-Firestore-r3'};}
 if(remote&&remote.digest!==entry.digest){entry.minimumRemoteVersion=remote.version+1;ahead[name]={published:remote,bundled:{digest:entry.digest,count:entry.count,bytes:entry.storedBytes},minimumRemoteVersion:entry.minimumRemoteVersion};}
}
const manifestBytes=Buffer.from(JSON.stringify(manifest,null,2)+'\n');fs.writeFileSync(path.join(get('--out'),'manifest.json'),manifestBytes);
const files=Object.fromEntries(['manifest.json',...Object.values(manifest.collections).map(e=>e.file)].sort().map(f=>{const b=fs.readFileSync(path.join(get('--out'),f));return[f,{sha256:sha(b),bytes:b.length}];}));
const report={schema:1,status:'single-final-test-candidate-not-mobile-release',webCommit:source.head,contentVersion:manifest.contentVersion,contentDate:manifest.contentDate,bundleSha256:sha(api.canonicalJson(files)),bundleManifestSha256:sha(manifestBytes),files,collections:manifest.collections,actualFirestoreSnapshot:firestoreSnapshot,actualFirestoreParity:Object.fromEntries([...collections].filter(([n])=>!calendarNames.includes(n)).map(([n,d])=>[n,api.describeDocuments(d)])),approvedCalendarPreservation:calendarPreservation,publishedManifestAhead:ahead,verifiedLiturgical:JSON.parse(fs.readFileSync(path.join(lit,'VERIFIED.json'))),snapshotManifestShas:{liturgical:sha(fs.readFileSync(path.join(lit,'manifest.json'))),public:sha(fs.readFileSync(path.join(pub,'manifest.json')))},privacy:{publicPrayers:collections.get('prayers').length,publicCategories:collections.get('prayerCategories').length,protectedOrDraftIncluded:0,sourceValues:'verbatim from Firestore; no source migration or disputed-source normalization'},firebaseReads:0,firebaseWrites:0};
fs.mkdirSync(path.dirname(get('--report')),{recursive:true});fs.writeFileSync(get('--report'),JSON.stringify(report,null,2)+'\n');
const metadata={schema:1,scope:'manifest-only-review-needed-outside-PR255-authorization',currentManifestSha256:sha(api.canonicalJson(published)),beforeContentVersion:published.contentVersion,sourceSnapshotManifestSha256:report.snapshotManifestShas.public,contentWrites:0,collections:Object.fromEntries(Object.keys(ahead).filter(n=>published.collections[n]).map(n=>[n,{before:published.collections[n],after:{...report.actualFirestoreParity[n],version:published.collections[n].version+1}}]))};
fs.writeFileSync(path.join(path.dirname(get('--report')),'calendar-preservation.json'),JSON.stringify(calendarPreservation,null,2)+'\n');
fs.writeFileSync(path.join(path.dirname(get('--report')),'additional-manifest-plan.json'),JSON.stringify(metadata,null,2)+'\n');
console.log(JSON.stringify({bundleSha256:report.bundleSha256,contentVersion:report.contentVersion,counts:Object.fromEntries(Object.entries(manifest.collections).map(([n,e])=>[n,e.count])),ahead:Object.keys(ahead),metadataPlanSha256:sha(api.canonicalJson(metadata)),sourceReads:0,sourceWrites:0},null,2));
