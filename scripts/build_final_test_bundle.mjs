/** One final candidate from actual verified public snapshots. No Firebase I/O. */
import fs from 'node:fs';import path from 'node:path';import {pathToFileURL} from 'node:url';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {resolveWeb} from './lib/web_source.mjs';
const args=process.argv.slice(2),get=k=>args[args.indexOf(k)+1];
for(const k of ['--web','--liturgical-snapshot','--public-snapshot','--baseline-manifest','--out','--report'])assert(args.includes(k),`Missing ${k}`);
const source=resolveWeb(args),api=await import(pathToFileURL(path.join(source.web,'scripts/content/lib/app-content.mjs'))),builder=await import(pathToFileURL(path.join(source.web,'scripts/content/build-app-bundle.mjs')));
const sha=b=>createHash('sha256').update(b).digest('hex');
const lit=get('--liturgical-snapshot'),pub=get('--public-snapshot'),baseline=JSON.parse(fs.readFileSync(get('--baseline-manifest'))),published=JSON.parse(fs.readFileSync(path.join(lit,'published-manifests.json')))['contentManifest/current'];
const input=await builder.readCollections([lit,pub]),collections=api.publicAppCollections(input.collections);
const negativePrayers=new Set(baseline.priestCacheCleanup?.protectedPrayerIds||[]),negativeCategories=new Set(baseline.priestCacheCleanup?.protectedCategoryIds||[]);
assert(!collections.get('prayers').some(d=>negativePrayers.has(d.id)||d.isDraft===true||d.draft===true||['draft','needs_review'].includes(d.status)),'Private/draft prayer in final public bundle');
assert(!collections.get('prayerCategories').some(d=>negativeCategories.has(d.id)),'Private category in public bundle');
const invalid=[...collections].flatMap(([n,d])=>api.validateCollection(n,d));assert.deepEqual(invalid,[],'Invalid actual public content');
const manifest=builder.writeBundle(collections,input.versions,input.contentVersion,get('--out'));
manifest.priestCacheCleanup=baseline.priestCacheCleanup;
const ahead={};
for(const [name,entry] of Object.entries(manifest.collections)){
 const remote=published.collections[name];
 if(remote&&remote.digest!==entry.digest){entry.minimumRemoteVersion=remote.version+1;ahead[name]={published:remote,bundled:{digest:entry.digest,count:entry.count,bytes:entry.storedBytes},minimumRemoteVersion:entry.minimumRemoteVersion};}
}
const manifestBytes=Buffer.from(JSON.stringify(manifest,null,2)+'\n');fs.writeFileSync(path.join(get('--out'),'manifest.json'),manifestBytes);
const files=Object.fromEntries(['manifest.json',...Object.values(manifest.collections).map(e=>e.file)].sort().map(f=>{const b=fs.readFileSync(path.join(get('--out'),f));return[f,{sha256:sha(b),bytes:b.length}];}));
const report={schema:1,status:'single-final-test-candidate-not-mobile-release',webCommit:source.head,contentVersion:manifest.contentVersion,contentDate:manifest.contentDate,bundleSha256:sha(api.canonicalJson(files)),bundleManifestSha256:sha(manifestBytes),files,collections:manifest.collections,actualFirestoreParity:Object.fromEntries([...collections].map(([n,d])=>[n,api.describeDocuments(d)])),publishedManifestAhead:ahead,verifiedLiturgical:JSON.parse(fs.readFileSync(path.join(lit,'VERIFIED.json'))),snapshotManifestShas:{liturgical:sha(fs.readFileSync(path.join(lit,'manifest.json'))),public:sha(fs.readFileSync(path.join(pub,'manifest.json')))},privacy:{publicPrayers:collections.get('prayers').length,publicCategories:collections.get('prayerCategories').length,protectedOrDraftIncluded:0,sourceValues:'verbatim from Firestore; no source migration or disputed-source normalization'},firebaseReads:0,firebaseWrites:0};
fs.mkdirSync(path.dirname(get('--report')),{recursive:true});fs.writeFileSync(get('--report'),JSON.stringify(report,null,2)+'\n');
const metadata={schema:1,scope:'manifest-only-review-needed-outside-PR255-authorization',currentManifestSha256:sha(api.canonicalJson(published)),beforeContentVersion:published.contentVersion,sourceSnapshotManifestSha256:report.snapshotManifestShas.public,contentWrites:0,collections:Object.fromEntries(Object.keys(ahead).map(n=>[n,{before:published.collections[n],after:{...report.actualFirestoreParity[n],version:published.collections[n].version+1}}]))};
fs.writeFileSync(path.join(path.dirname(get('--report')),'additional-manifest-plan.json'),JSON.stringify(metadata,null,2)+'\n');
console.log(JSON.stringify({bundleSha256:report.bundleSha256,contentVersion:report.contentVersion,counts:Object.fromEntries(Object.entries(manifest.collections).map(([n,e])=>[n,e.count])),ahead:Object.keys(ahead),metadataPlanSha256:sha(api.canonicalJson(metadata)),sourceReads:0,sourceWrites:0},null,2));
