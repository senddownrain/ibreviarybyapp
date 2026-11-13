// Summarize only a completed, zero-difference run on the approved fixture.
import fs from 'node:fs';
import zlib from 'node:zlib';
import assert from 'node:assert/strict';
const read=p=>JSON.parse(fs.readFileSync(p));
const fixture=JSON.parse(zlib.gunzipSync(fs.readFileSync('test/fixtures/ordo_parity.json.gz')));
const ordo=read('reports/flutter-ordo-parity.json');
const hours=read('reports/flutter-hours-parity.json');
const readings=read('reports/flutter-reading-references.json');
const source=read('reports/belarus-approved/source.json');
assert.deepEqual(fixture.years,[2025,2035]);
assert.equal(ordo.daysCompared,16068);assert.deepEqual(ordo.mismatches,{});
assert.equal(ordo.generatedFrom.fixtureGeneratedAt,fixture.generatedAt);
assert.equal(hours.fixtureSnapshot,fixture.snapshot);assert.equal(hours.daysCompared,16068);
assert.equal(hours.structureMismatches,0);assert.equal(hours.officeTextMismatches,0);
assert.equal(readings.daysCompared,16068);assert.equal(readings.mismatches,0);
const rows=[];
for(const [diocese,days]of Object.entries(fixture.days))for(let year=2025;year<=2035;year++){
 const group=days.filter(d=>d.date.startsWith(String(year)));
 const count={};for(const day of group)for(const r of day.readings)count[r.status]=(count[r.status]||0)+1;
 rows.push({diocese,year,dates:group.length,primary:group.length,
 alternatives:group.reduce((n,d)=>n+d.alternatives.length,0),
 suppressed:group.reduce((n,d)=>n+d.suppressed.length,0),
 hoursAssemblies:group.reduce((n,d)=>n+d.hours.reduce((m,o)=>m+o.templates.length,0),0),
 readings:count,firstVespers:group.filter(d=>d.evening.type==='first').length,
 secondVespers:group.filter(d=>d.evening.type==='second').length,
 mismatches:0});
}
fs.writeFileSync('reports/belarus-approved/parity-matrix.json',JSON.stringify({
 webCommit:source.webCommit,sourceSha256:source.sourceSha256,snapshot:fixture.snapshot,
 fixtureGeneratedAt:fixture.generatedAt,mode:'approved-Web-candidate vs Flutter, same snapshot',
 productionFirestoreVerified:false,dates:16068,assembliesCompared:hours.assembliesCompared,
 fields:ordo.fieldsCompared,rows},null,2)+'\n');
console.log(JSON.stringify({rows:rows.length,dates:16068,assemblies:hours.assembliesCompared,mismatches:0}));
