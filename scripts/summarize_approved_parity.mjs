// Report every measured result, including differences; never bless a failed
// comparison or substitute an older report for this source/fixture.
import fs from 'node:fs';
import zlib from 'node:zlib';
import assert from 'node:assert/strict';
const read=p=>JSON.parse(fs.readFileSync(p));
const fixture=JSON.parse(zlib.gunzipSync(fs.readFileSync('test/fixtures/ordo_parity.json.gz')));
const ordo=read('reports/flutter-ordo-parity.json');
const hours=read('reports/flutter-hours-parity.json');
const readings=read('reports/flutter-reading-references.json');
const screen=read('reports/flutter-lectionary-parity.json');
const source=read('reports/belarus-approved/source.json');
const manifest=read('assets/content/manifest.json');
assert.deepEqual(fixture.years,[2025,2035]);
assert.equal(ordo.daysCompared,16068);
assert.equal(ordo.generatedFrom.fixtureGeneratedAt,fixture.generatedAt);
assert.equal(hours.fixtureSnapshot,fixture.snapshot);assert.equal(hours.daysCompared,16068);
assert.equal(readings.daysCompared,16068);
assert.equal(screen.heads.web,source.webCommit,'Readings screen report is from another source');
assert.equal(screen.webDataset.exportedAt,fixture.snapshot,'Readings screen report is from another snapshot');
assert.equal(screen.compared.dates,16068);
assert.equal(screen.bundle.digest,manifest.collections.readings.digest);
assert.equal(screen.bundle.count,manifest.collections.readings.count);
const rows=[];
for(const [diocese,days]of Object.entries(fixture.days))for(let year=2025;year<=2035;year++){
 const group=days.filter(d=>d.date.startsWith(String(year)));
 const count={};for(const day of group)for(const r of day.readings)count[r.status]=(count[r.status]||0)+1;
 const officeDifferences=hours.mismatchesByDioceseYear?.[diocese]?.[year];
 assert(officeDifferences,'Run HOURS_PARITY_REPORT=1 with the current test');
 rows.push({diocese,year,dates:group.length,primary:group.length,
 alternatives:group.reduce((n,d)=>n+d.alternatives.length,0),
 suppressed:group.reduce((n,d)=>n+d.suppressed.length,0),
 hoursAssemblies:group.reduce((n,d)=>n+d.hours.reduce((m,o)=>m+o.templates.length,0),0),
 readings:count,firstVespers:group.filter(d=>d.evening.type==='first').length,
 secondVespers:group.filter(d=>d.evening.type==='second').length,
 hoursDifferences:officeDifferences,
 readingsScreenDifferences:(screen.mismatches||[]).filter(m=>m.diocese===diocese&&m.date?.startsWith(String(year))).length});
}
const differences={ordo:ordo.mismatches,readingReferences:readings.mismatches,
 hoursStructure:hours.structureMismatches,hoursText:hours.officeTextMismatches,
 readingsScreen:screen.compared.mismatches,readingsScreenByKind:screen.compared.byKind};
const passed=Object.keys(ordo.mismatches).length===0&&readings.mismatches===0&&
 hours.structureMismatches===0&&hours.officeTextMismatches===0&&screen.compared.mismatches===0;
assert.equal(rows.length,44);
fs.writeFileSync('reports/belarus-approved/parity-matrix.json',JSON.stringify({
 webCommit:source.webCommit,sourceSha256:source.sourceSha256,snapshot:fixture.snapshot,
 fixtureGeneratedAt:fixture.generatedAt,mode:'approved-Web-candidate vs Flutter, same snapshot',
 productionFirestoreVerified:false,status:passed?'PASS':'DIFFERENCES_REQUIRE_REVIEW',
 dates:16068,assembliesCompared:hours.assembliesCompared,readingsSections:screen.compared.sections,
 coverageNotes:['Hours text hashes are compared only on dates whose card structure matches; all other dates remain structural failures.',
 'The raw Readings report inherits historical delivery-fixture bundle metadata; actual candidate manifest metadata is recorded here. Readings digest/count match both.'],
 candidateBundle:{contentVersion:manifest.contentVersion,readings:manifest.collections.readings},
 measuredHeads:{hours:hours.heads,readingsScreen:screen.heads},
 differences,fields:ordo.fieldsCompared,rows},null,2)+'\n');
console.log(JSON.stringify({rows:rows.length,dates:16068,passed,differences}));
if(!passed)process.exitCode=1;
