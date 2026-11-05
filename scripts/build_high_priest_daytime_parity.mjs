/** Read-only Web oracle from exactly the Flutter bundle + proposed patch.
 * node scripts/build_high_priest_daytime_parity.mjs --web ../mybrev
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { pathToFileURL } from 'node:url';
import { resolveWeb } from './lib/web_source.mjs';
const source = resolveWeb(process.argv.slice(2));
const web = rel => import(pathToFileURL(path.join(source.web, rel)));
const api = await web('scripts/content/lib/app-content.mjs');
const resolution = await web('src/utils/liturgicalDayResolution.js');
const assembly = await web('src/utils/daysResult.js');
const { resolveLiturgicalDate } = await web('src/utils/ordo/index.js');
const { setCalendarDefinitions } = await web('src/utils/ordo/definitions.js');
const { computeYearAnchors } = await web('src/utils/ordo/movableFeasts.js');
const { default: moment } = await web('src/utils/moment-be.js');
const read = name => api.decodeCollection(JSON.parse(zlib.gunzipSync(fs.readFileSync(`assets/content/${name}.json.gz`))));
setCalendarDefinitions({
  celebrations: Object.values(read('liturgicalCelebrations')),
  dioceseOverrides: Object.values(read('liturgicalDioceseOverrides')),
  yearOverrides: Object.values(read('liturgicalYearOverrides')),
});
const docs = read('days');
const id = 'feast-christthehighpriest';
const patch = JSON.parse(fs.readFileSync('reports/liturgy/christ-high-priest-daytime-patch.json')).updates.find(u => u.id === id).set;
const cases = [];
const suffixes = ['Hymn', 'Ant1', 'Ant2', 'Ant3', 'Ps1', 'Ps2', 'Ps3', 'R', 'Pr'];
const hourFields = day => Object.fromEntries([1, 2, 3].flatMap(h => suffixes.map(s => [`sext${h}${s}`, resolution.getDaytimeHourField(day, h, s)])));
for (let year = 2025; year <= 2035; year++) {
  const date = computeYearAnchors(year).christTheHighPriest;
  for (const diocese of ['pinsk', 'grodno', 'vitebsk', 'minsk-mohilev']) {
    const ordo = resolveLiturgicalDate(date, { diocese });
    if (ordo.primary.id !== 'christ-the-high-priest') throw new Error(`${date}/${diocese}: feast absent`);
    const context = { periodType: ordo.period, periodWeek: ordo.week, dayOfWeek: ordo.dayOfWeek };
    const rawPeriod = docs[`${ordo.period}-w${ordo.week}-d${ordo.dayOfWeek}`];
    let period = resolution.resolveDayAgainstPeriod(rawPeriod, null);
    const fallbackId = assembly.periodPsalterFallbackId(period, ordo.period, ordo.week, ordo.dayOfWeek);
    if (fallbackId) period = assembly.applyPeriodPsalterFallback(period, docs[fallbackId], ordo.period);
    const proper = { ...docs[id], ...patch };
    const result = assembly.assembleDaysResult({ mDate: moment(date), context, dynamicFeastCodes: [id], periodDay: period, dynamicEntries: [[id, [proper]]] });
    cases.push({ date, diocese, primary: ordo.primary.id, context,
      // The raw baseline also goes through the same JS resolver, without the
      // Web-only unconditional canonical overlay. This checks the Dart port
      // on identical unpatched input, including the legacy HTML formatting.
      baseline: hourFields(resolution.resolveDayAgainstPeriod(docs[id], period, { fillMissingDaytime: true })),
      patched: hourFields(result.dynamicDaysByFeast.get(id)[0]),
    });
  }
}
const out = 'test/fixtures/high_priest_daytime_parity.json.gz';
fs.writeFileSync(out, zlib.gzipSync(JSON.stringify({ webCommit: source.head, source: 'assets/content (unchanged) + reviewed field patch', cases }), { level: 9 }));
console.log(JSON.stringify({ out, webCommit: source.head, cases: cases.length, fieldsPerState: 27 }));
