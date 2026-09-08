const {test}=require('node:test');
const assert=require('node:assert/strict');
const M=require('./model.js');
require('./fixtures.js');require('./calendar-fixtures.js');require('./refinement.js');
const R=globalThis.UXRefinement,C=globalThis.UX_CALENDAR,F=globalThis.UX_FIXTURES;
test('Marian source rule survives, including red and solemnity precedence',()=>{
  assert.equal(R.liturgicalColor({rankCode:'festum',templates:['blessed-virgin-mary']}),'#5E9EC5');
  assert.equal(R.liturgicalColor({rankCode:'solemnitas',templates:['blessed-virgin-mary']}),'#B88719');
  assert.equal(R.liturgicalColor({rankCode:'solemnitas',title:'Святы мучанік'}),'#B33A3A');
  assert.equal(R.liturgicalColor({kind:'office-for-dead',title:'Мучанік'}),'#67546B');
  assert.equal(R.liturgicalColor({rankCode:'memoria-ad-libitum'}),'#8F7D52');
});
test('Period palette is the production liturgical_theme palette',()=>{
  assert.deepEqual(R.periodColors,{ordinary:'#4D8A5B',advent:'#7A57A7',lent:'#6F4A92',holyweek:'#5B3B83',christmas:'#B07A1E',easter:'#BD8A24'});
});
test('Exported original picker retains period coordinates, skipped weeks and exact-date routes',()=>{
  assert.equal(C.coordinates['ordinary:23:4'],'2026-09-09');assert.equal(C.coordinates['ordinary:7:1'],null);
  assert.equal(C.coordinates['holyweek:1:5'],'2026-04-02');assert.equal(C.coordinates['advent:1:1'],'2026-11-29');
  assert.equal(C.exact.advent[0],'2026-12-17');assert.equal(C.exact.advent.at(-1),'2026-12-24');
  assert.equal(C.exact.lent[0],'2026-02-18');assert.equal(C.exact.christmas.at(-1),'2027-01-10');
  assert.ok(C.fixed.length>240);assert.equal(C.dynamic.length,13);assert.ok(C.fixed.some(x=>x.place));
});
test('Full translation corpora retain canonical mapping and Russian-only books',()=>{
  assert.equal(F.bible.bel.length,66);assert.equal(F.bible.ru.length,73);
  assert.equal(F.bible.ru.find(x=>x.id==='jn').sourceId,'jo');assert.equal(F.bible.ru.find(x=>x.id==='rom').sourceId,'rm');
  assert.ok(F.bible.ru.find(x=>x.id==='ru-tob'));assert.equal(F.bible.bel.some(x=>x.id==='ru-tob'),false);
  assert.equal(F.bible.bel.filter(x=>x.newTestament).length,27);assert.equal(F.bible.ru.filter(x=>x.newTestament).length,27);
});
test('Exact Ora day identity can select a linked reading; absent identity falls back',()=>{
  const s=M.createState();M.dateChange(s,'hours','2026-09-09');s.hours.choice=1;s.hours.template='works-of-mercy';s.hours.ora='laudes';
  M.oraToReadings(s);assert.equal(s.readings.context.template,'works-of-mercy');assert.equal(s.readings.group,1);M.backToOra(s);assert.equal(s.hours.template,'works-of-mercy');
  s.hours.choice=99;M.oraToReadings(s);assert.equal(s.readings.group,0);
});
test('Calendar navigation can hydrate a context without changing another branch date',()=>{
  const s=M.createState();R.ensureDate('2026-11-29');M.dateChange(s,'hours','2026-11-29');assert.match(M.CALENDAR[s.hours.date][0].title,/Адвэнт/);assert.equal(s.readings.date,M.TODAY);
});
