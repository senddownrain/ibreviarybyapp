#!/usr/bin/env node
/** Offline refresh of the SINGLE PR #117 bundle; no production Firestore calls. */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

const args=process.argv.slice(2);
const arg=k=>{const n=args.indexOf(k);assert(n>=0&&args[n+1],'Missing '+k);return args[n+1];};
const web=path.resolve(arg('--web')),assetDir=path.resolve(arg('--assets'));
const catalogPath=path.resolve(arg('--catalog')),check=args.includes('--check');
const api=await import(pathToFileURL(path.join(web,'scripts/content/lib/app-content.mjs')));
const {validatePublicPrayerCatalog}=await import(pathToFileURL(path.join(web,'src/utils/publicPrayerCatalog.mjs')));
const hash=b=>createHash('sha256').update(b).digest('hex');
const catalogBytes=fs.readFileSync(catalogPath),catalog=JSON.parse(catalogBytes);
validatePublicPrayerCatalog(catalog);
const publishedAt=Date.parse(catalog.publishedAt);
assert(Number.isSafeInteger(publishedAt)&&publishedAt>=Date.parse('2026-11-18T14:51:04Z'),
  'Hosting snapshot is older than the verified devotions import');
const manifest=JSON.parse(fs.readFileSync(path.join(assetDir,'manifest.json')));
assert(manifest.schemaVersion===1,'Unknown bundle schema');
const original=Object.fromEntries(Object.entries(manifest.collections).map(([name,value])=>
  [name,fs.readFileSync(path.join(assetDir,value.file))]));
const unpack=name=>{
 const payload=JSON.parse(zlib.gunzipSync(original[name]));
 assert(payload.collection===name&&payload.schemaVersion===1,'Unexpected collection '+name);
 return api.decodeCollection(payload);
};
const prior=unpack('prayers'),priorIds=new Set(Object.keys(prior));
assert(priorIds.size===393,'Expected 393 existing public prayers from PR117');
const publicById=new Map(catalog.prayers.map(x=>[x.id,x]));
assert(publicById.size===catalog.prayers.length,'Duplicate public prayer id');
const names=[
 ['devotion-vigilijny-vechar','01_vigilijny_vechar.md'],
 ['devotion-zakanchenne-goda','02_nabazhenstva_na_zakanchenne_goda.md'],
 ['devotion-vystaulenne-euharystyja','03_vystaulenne_i_blagaslaulenne.md'],
 ['Fd9rN0S9NU1mAmqb2isZ','04_euharystychnaja_pracesija.md']
];
const known=new Set(names.map(([id])=>id));
const added=[...publicById.keys()].filter(id=>!priorIds.has(id)).sort();
assert(added.length>=2&&added.length<=100,'Unexpectedly large public prayer delta');
if(!names.every(([id])=>publicById.has(id))){
 console.log('PUBLIC-ONLY DEVOTION MATCH DIAGNOSTIC',JSON.stringify({
  missingIds:names.filter(([id])=>!publicById.has(id)).map(([id])=>id),
  titleMatches:catalog.prayers.filter(p=>/вігілій|вячэр|працэс|выстаўлен|заканчэнне года/iu.test(p.title||''))
    .map(p=>({id:p.id,title:p.title,source:p.source})),
  newlyPublic:added.map(id=>({id,title:publicById.get(id)?.title,source:publicById.get(id)?.source}))
 }));
}
assert(names.every(([id])=>publicById.has(id)),'Missing an approved devotion');
assert(catalog.prayers.length===393+added.length,'Unexpected public catalog count');
assert([...priorIds].every(id=>publicById.has(id)),'Published public prayer missing in Hosting snapshot');
const protectedIds=new Set(manifest.priestCacheCleanup?.protectedPrayerIds||[]);
const protectedCategories=new Set(manifest.priestCacheCleanup?.protectedCategoryIds||[]);
assert([...publicById.keys()].every(id=>!protectedIds.has(id)),'Protected prayer in public snapshot');

const edition=new Map([
 ['Парадак хросту дзяцей','«Парадак хросту дзяцей» (Мінск, 2026)'],
 ['Парадак пакаяння','«Парадак пакаяння» (Мінск, 2016)'],
 ['Парадак намашчэння хворых','«Парадак намашчэння хворых» (Мінск, 2009)'],
 ['Святая Камунія і культ эўхарыстычнай таямніцы па-за Імшой','«Святая Камунія і культ эўхарыстычнай таямніцы па-за Імшой» (Мінск, 2017)'],
 ['Літургічная агенда','«Літургічная агенда» (Мінск, 2010)'],
 ['Божа, мы Цябе ўслаўляем','«Божа, мы Цябе ўслаўляем» (Мінск, 2026)'],
 ['Ойча наш','«Ойча наш» (Мінск, 2022)'],
 ['Прасіце і атрымаеце','«Прасіце і атрымаеце» (Мінск, 2024)'],
 ['Бог Добры','«Бог Добры» (Пінск, 2022)'],
 ['Каб пазналі Цябе','«Каб пазналі Цябе» (Гродна, 2014)']
]);
const normal=s=>String(s??'').toLocaleLowerCase('be').replace(/[«»„“”"']/gu,'').replace(/\s+/gu,' ').trim();
const editions=new Map([...edition].flatMap(([short,full])=>[[normal(short),full],[normal(full),full]]));
editions.set(normal('«Бог Добры» (Пінск, 2018)'),edition.get('Бог Добры'));

const stable=['text','textVersions','textFormat','textFormatVersion'];
const unrelated=[],docChanges=[],docs=[];
for(const [id,old] of Object.entries(prior)){
 const pub=publicById.get(id),updated={...old};
 if(!known.has(id)){
  for(const field of stable)if(pub[field]!==undefined&&api.canonicalJson(pub[field])!==api.canonicalJson(old[field]))
   unrelated.push(id+'/'+field);
 }
 if(pub.source!==undefined)updated.source=pub.source;
 if(typeof old.sourceBook==='string'){
  const canonical=editions.get(normal(old.sourceBook));
  if(canonical)updated.sourceBook=canonical;
 }
 if(known.has(id))for(const field of [
   'title','titleVersions','text','textVersions','textFormat','textFormatVersion',
   'tags','categoryId','categoryIds','source','sourceManual','sourceId',
   'sourceEntryId','copyrightNotices'
 ])if(Object.hasOwn(pub,field))updated[field]=pub[field];
 if(api.documentHash(old)!==api.documentHash(updated))docChanges.push(id);
 docs.push(updated);
}
assert.deepEqual(unrelated,[],'Unreviewed prayer text changes in public snapshot');

const reviewCommit='1b4d121329f46a302fa30f064b4b3ec06ee7b3da';
const directory='docs/content-imports/four-devotions-2026-11-18/';
const gitRead=file=>execFileSync('git',['show',reviewCommit+':'+directory+file],{cwd:web});
const review=JSON.parse(gitRead('manifest.json'));
assert(review.source==='«Літургічная агенда» (Мінск, 2010)');
const reviewItems=new Map(review.documents.map(x=>[x.id,x]));
const devotions=[];
for(const [id,file]of names){
 const item=reviewItems.get(id),pub=publicById.get(id);
 assert(item?.filename===file&&pub?.title===item.title,'Wrong published devotion: '+id);
 assert(pub.source===review.source&&pub.textFormat==='mybrev-markdown','Wrong source/format: '+id);
 const md=gitRead(file);
 assert(hash(md)===item.sha256,'Reviewed Markdown changed: '+id);
 const text=pub.textVersions?.be??pub.text;
 assert(typeof text==='string'&&hash(Buffer.from(text,'utf8'))===item.sha256,
   'Published text differs from reviewed PDF/Markdown: '+id);
 devotions.push({id,title:item.title,sha256:item.sha256,source:pub.source});
}
// The public Hosting export is the already-access-controlled source of truth.
// Include other newly published PUBLIC prayers too; do not rewrite existing
// prayer texts outside the four editorially verified devotions.
for(const id of added)docs.push(api.storedDocument(id,publicById.get(id)));
assert(docs.length===catalog.prayers.length,'Public prayer count mismatch');
const cats=unpack('prayerCategories'),catById=new Map(catalog.categories.map(x=>[x.id,x]));
assert(Object.keys(cats).length===22&&catById.size===22,'Unexpected category set');
const categoryDocs=Object.entries(cats).map(([id,old])=>{
 const pub=catById.get(id);assert(pub&&old.name===pub.name&&!protectedCategories.has(id),
   'Changed/protected category '+id);
 return {...old,...(pub.prayerIds?{prayerIds:pub.prayerIds}:{})};
});
const celebrations=unpack('liturgicalCelebrations');
const target=celebrations['dedication-basilicas-peter-paul'];
assert(target?.category==='dedication'&&target?.dateRule?.month===11&&target?.dateRule?.day===18,
 'Wrong basilica celebration identity');
assert(['ruber','albus'].includes(target.color));
target.color='albus';
for(const id of ['sv-juan-diego','our-lady-guadalupe']){
 const doc=celebrations[id];assert(doc&&[true,false].includes(doc.enabled),'Missing approved December correction');
 doc.enabled=false;
}
const meta=unpack('liturgicalCalendarMeta');
assert(meta.current?.revision===4&&meta.current?.schemaVersion===1,
 'Expected preserved revision4 calendar in PR117');
meta.current.revision=6;
const changes=new Map([
 ['prayers',docs],['prayerCategories',categoryDocs],
 ['liturgicalCelebrations',Object.values(celebrations)],
 ['liturgicalCalendarMeta',Object.values(meta)]
]);
const next=structuredClone(manifest),versions={};
assert(publishedAt>manifest.contentVersion,'Public snapshot is older than PR117 candidate');
next.contentVersion=publishedAt;
next.contentDate=new Date(publishedAt).toISOString();
const generated={};
for(const [name,items]of changes){
 items.sort((a,b)=>a.id<b.id?-1:a.id>b.id?1:0);
 assert.deepEqual(api.validateCollection(name,items),[],'Invalid '+name);
 const described=api.describeDocuments(items),encoded=api.encodeCollection(items);
 const data=Buffer.from(JSON.stringify({
  schemaVersion:1,collection:name,contentVersion:publishedAt,
  strings:encoded.strings,docs:encoded.docs,hashes:described.hashes
 }));
 const gz=zlib.gzipSync(data,{level:9});gz.writeUInt32LE(0,4);
 const entry={...next.collections[name],contentVersion:publishedAt,contentDate:next.contentDate,
  count:described.count,digest:described.digest,storedBytes:described.bytes,bundleBytes:gz.length};
 if(name==='prayers')entry.minimumRemoteVersion=Math.max(entry.minimumRemoteVersion||0,6);
 next.collections[name]=entry;
 generated[entry.file]=gz;
 versions[name]={count:described.count,digest:described.digest,sha256:hash(gz)};
}
const finalManifest=Buffer.from(JSON.stringify(next,null,2)+'\n');
const report={status:'single-candidate-offline-refresh',branch:'prepare/final-test-candidate',
 catalogSha256:hash(catalogBytes),catalogPublishedAt:catalog.publishedAt,
 prayerCount:docs.length,priorPrayerCount:393,added,devotions,
 changedExistingPrayerIds:docChanges,calendarRevision:6,whiteBasilicas:true,
 calendarDecemberEntriesDisabled:2,collections:versions,
 bundleManifestSha256:hash(finalManifest),firestoreReads:0,firestoreWrites:0,
 manifestPublished:false,mobileReleased:false};
if(check){
 for(const [file,data]of Object.entries(generated))
  assert(fs.readFileSync(path.join(assetDir,file)).equals(data),'Not reproducible: '+file);
 assert(fs.readFileSync(path.join(assetDir,'manifest.json')).equals(finalManifest),
  'Not reproducible: manifest.json');
 console.log('REPRODUCIBLE',JSON.stringify(report));
}else{
 for(const [file,data]of Object.entries(generated))fs.writeFileSync(path.join(assetDir,file),data);
 fs.writeFileSync(path.join(assetDir,'manifest.json'),finalManifest);
 const dest='docs/release/final-test/nov18-refresh-report.json';
 fs.mkdirSync(path.dirname(dest),{recursive:true});
 fs.writeFileSync(dest,JSON.stringify(report,null,2)+'\n');
 console.log('OFFLINE UPDATED',JSON.stringify(report));
}