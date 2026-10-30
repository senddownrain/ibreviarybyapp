/** Offline Web oracle for the Pastors hymn selection. No text duplication: the fixture
 * holds only hashes of the Web output; the Dart test recomputes the same inputs from the
 * Flutter bundle (templates + Proper feast names).
 * node scripts/build_pastors_hymn_parity.mjs --web ../mybrev [--allow-unmerged-web]
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { resolveWeb } from './lib/web_source.mjs';

const source = resolveWeb(process.argv.slice(2));
const api = await import(pathToFileURL(path.join(source.web, 'scripts/content/lib/app-content.mjs')));
const { preparePastorsHymn } = await import(pathToFileURL(path.join(source.web, 'src/utils/pastorsHymn.js')));
const read = (name) => api.decodeCollection(JSON.parse(zlib.gunzipSync(fs.readFileSync(`assets/content/${name}.json.gz`))));
const templates = Object.values(read('liturgicalTemplates'));
const propers = Object.values(read('liturgicalProperTexts'));
const SEASONS = ['advent', 'christmas', 'lent', 'easter'];
const HYMNS = ['officeOfReadingsHymn', 'laudesHymn', 'vesperHymn', 'vesper1Hymn'];
const sources = [];
for (const t of templates) {
  for (const f of HYMNS) if (typeof t[f] === 'string') sources.push([`${t.id}:${f}`, t[f]]);
  for (const s of SEASONS) for (const f of HYMNS) {
    const v = t._seasonalVariants?.[s]?.[f];
    if (typeof v === 'string') sources.push([`${t.id}:${s}:${f}`, v]);
  }
}
const names = [...new Set(propers.filter((p) => (p._templates ?? []).includes('pastors')).map((p) => p._feastName)), 'Св. Невядомага', ''].sort();
const hash = (value) => createHash('sha256').update(value).digest('hex').slice(0, 16);
const cases = [];
let transformed = 0;
for (const [key, html] of sources) {
  if (!html.includes('Пра аднаго пастыра')) continue;
  for (const name of names) {
    const out = preparePastorsHymn(html, name);
    if (out !== html) transformed += 1;
    cases.push([key, name, hash(out)]);
  }
}
fs.writeFileSync('test/fixtures/pastors_hymn_parity.json', `${JSON.stringify({
  webCommit: source.head, webOnOriginMain: source.onOriginMain, transformed, columns: ['source', 'feastName', 'sha256_16'], cases,
}, null, 1)}\n`);
console.log(JSON.stringify({ sources: new Set(cases.map((c) => c[0])).size, names: names.length, cases: cases.length, transformed }));
