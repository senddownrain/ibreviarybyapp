const {test}=require('node:test');
const assert=require('node:assert/strict');
const M=require('./model.js');

test('Hours opens first ordered fixture immediately; disabled alternative remains visible',()=>{
  const s=M.createState();assert.equal(s.hours.choice,0);assert.equal(M.CALENDAR[s.hours.date][s.hours.choice].id,'mary');assert.equal(M.CALENDAR[s.hours.date][2].disabled,true);assert.equal(M.HOURS.length,8);
});
test('Non-today Ora forwards only date, selects default readings and returns to the exact office',()=>{
  const s=M.createState();M.dateChange(s,'hours','2026-09-09');s.hours.choice=1;s.hours.ora='laudes';s.scroll[M.key(s)]=418;
  M.oraToReadings(s);assert.equal(s.tab,'readings');assert.equal(s.readings.date,'2026-09-09');assert.equal(M.readingGroups(s.readings.date)[s.readings.group].id,'ordinary');assert.equal(s.readings.cycle,'2');
  M.backToOra(s);assert.equal(s.tab,'hours');assert.equal(s.hours.choice,1);assert.equal(s.hours.ora,'laudes');assert.equal(s.scroll[M.key(s)],418);
});
test('Ordinary tab switching preserves dates, manual variants, reader and scroll independently',()=>{
  const s=M.createState();M.dateChange(s,'hours','2026-09-09');s.hours.ora='vespers';const key=M.key(s);s.scroll[key]=323;s.tab='readings';s.readings.group=1;s.readings.manual=true;s.readings.cycle='1';s.tab='hours';assert.equal(M.key(s),key);assert.equal(s.scroll[key],323);assert.equal(s.readings.date,M.TODAY);assert.equal(s.readings.cycle,'1');
});
test('A new date resets manual choices and contextual return; Today is a single action',()=>{
  const s=M.createState();M.dateChange(s,'hours','2026-09-09');s.hours.choice=1;s.hours.ora='office';M.oraToReadings(s);s.readings.manual=true;s.readings.group=1;M.dateChange(s,'readings',M.TODAY);assert.equal(s.readings.group,0);assert.equal(s.readings.manual,false);assert.equal(s.readings.returnTo,null);M.dateChange(s,'hours',M.TODAY);assert.equal(s.hours.date,M.TODAY);assert.equal(s.hours.choice,0);assert.equal(s.hours.ora,null);
});
test('Empty date is explicit; no invented fallback calendar day',()=>{
  const s=M.createState();M.dateChange(s,'hours','2026-09-07');assert.equal(M.CALENDAR[s.hours.date],undefined);assert.deepEqual(M.readingGroups('2026-09-07'),[]);M.resetReadings(s,'2026-09-07');assert.equal(s.readings.cycle,'');
});
test('Cycles follow existing Flutter liturgical-year rules including Advent',()=>{
  assert.deepEqual(M.cycles('2026-09-08'),{sunday:'A',weekday:'2'});assert.deepEqual(M.cycles('2026-11-28'),{sunday:'A',weekday:'2'});assert.deepEqual(M.cycles('2026-11-29'),{sunday:'B',weekday:'1'});assert.deepEqual(M.cycles('2025-09-08'),{sunday:'C',weekday:'1'});
});
test('Only applicable cycles appear; absent desired cycle falls back to first',()=>{
  const groups=M.readingGroups(M.TODAY);assert.deepEqual(groups[0].cycles,[]);assert.deepEqual(groups[1].cycles,['1','2']);assert.equal(M.defaultCycle(M.TODAY,{cycles:['C']}),'C');assert.equal(M.defaultCycle(M.TODAY,{cycles:[]}),'');
});
test('Favorite order is stable, all six are available and removal supports empty state',()=>{
  const s=M.createState(),before=[...s.favorites];assert.equal(before.length,6);M.toggleFavorite(s,'night');assert.deepEqual(s.favorites,before.filter(x=>x!=='night'));M.toggleFavorite(s,'night');assert.equal(s.favorites.at(-1),'night');for(const id of [...s.favorites])M.toggleFavorite(s,id);assert.deepEqual(s.favorites,[]);
});
test('Reader positions are keyed by document, variant, translation and chapter',()=>{
  const s=M.createState();s.tab='bible';const first=M.key(s);s.bible.chapter=2;assert.notEqual(M.key(s),first);s.bible.chapter=1;s.bible.translation='ru';assert.notEqual(M.key(s),first);
});
test('Date arithmetic crosses month/year and leap-day boundaries',()=>{
  assert.equal(M.plusDate('2026-12-31',1),'2027-01-01');assert.equal(M.plusDate('2024-03-01',-1),'2024-02-29');
});
test('Fixture text is local, nonempty and contains both complete chapter corpora',()=>{
  require('./fixtures.js');const f=globalThis.UX_FIXTURES;
  for(const lang of ['bel','ru']) {assert.equal(f.bible[lang].length,6);assert.equal(f.bible[lang].find(b=>b.id==='jn').chapters.length,21);assert.ok(f.bible[lang].every(b=>b.chapters.every(c=>c.length>0&&c.every(v=>typeof v.text==='string'&&v.text.length>0&&typeof v.num==='number'))));}
  assert.match(f.bible.bel.find(b=>b.id==='jn').chapters[0][0].text,/На пачатку было Слова/);
  assert.match(f.bible.ru.find(b=>b.id==='jn').chapters[0][0].text,/В начале было Слово/);
  assert.match(f.constants.StandardIntro,/Божа/);assert.match(f.constants.Magnificat,/Велічае/);assert.ok(f.feasts.mary.laudesPr);assert.ok(f.feasts.peter.officeOfReadingsPr);
});
