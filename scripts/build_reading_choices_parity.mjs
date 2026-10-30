/** Offline Web oracle for D-1 (choice of one legal reading of an Office field). No text
 * duplication: the fixture holds only hashes of what Web `getReadingChoices` returns for
 * every office-reading field of the Flutter bundle (Commons incl. seasonal variants, Propers);
 * the Dart test recomputes the same inputs from the bundle.
 * node scripts/build_reading_choices_parity.mjs --web ../mybrev [--allow-unmerged-web]
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { resolveWeb } from './lib/web_source.mjs';

const source = resolveWeb(process.argv.slice(2));
const api = await import(pathToFileURL(path.join(source.web, 'scripts/content/lib/app-content.mjs')));
const { getReadingChoices } = await import(pathToFileURL(path.join(source.web, 'src/utils/liturgicalAlternatives.js')));
const { parse } = await import(pathToFileURL(path.join(source.web, 'node_modules/node-html-parser/dist/index.js')));
const { removeLectionSectionHeading } = await import(pathToFileURL(path.join(source.web, 'src/utils/liturgicalHtml.js')));
const read = (name) => api.decodeCollection(JSON.parse(zlib.gunzipSync(fs.readFileSync(`assets/content/${name}.json.gz`))));
// the reader removes the structural heading first (Lectio.vue `title`), then offers the choices
const FIELDS = { officeOfReadingsR1: 'Першае чытанне', officeOfReadingsR2: 'Другое чытанне' };
const SEASONS = ['advent', 'christmas', 'lent', 'easter'];
const hash = (value) => createHash('sha256').update(value).digest('hex').slice(0, 16);
// serialisation of tags and entities differs between the two HTML parsers; the words and their order must not
const words = (html) => parse(html).text.replace(/\s+/gu, '');

const cases = [];
const add = (collection, doc) => {
  for (const field of Object.keys(FIELDS)) {
    const bases = [[field, doc[field]], ...SEASONS.map((s) => [`${s}:${field}`, doc._seasonalVariants?.[s]?.[field]])];
    for (const [key, html] of bases) {
      if (typeof html !== 'string' || !html.trim()) continue;
      const { notes, options } = getReadingChoices(removeLectionSectionHeading(html, FIELDS[field]));
      cases.push([`${collection}:${doc.id}:${key}`, notes.map((n) => hash(words(n.html))),
        options.map((o) => [hash(o.title), hash(words(o.html))])]);
    }
  }
};
for (const t of Object.values(read('liturgicalTemplates'))) add('liturgicalTemplates', t);
for (const p of Object.values(read('liturgicalProperTexts'))) add('liturgicalProperTexts', p);
const choices = cases.filter((c) => c[2].length > 1).length;
fs.writeFileSync('test/fixtures/reading_choices_parity.json', `${JSON.stringify({
  webCommit: source.head, webOnOriginMain: source.onOriginMain, choices,
  columns: ['source', 'noteHashes', 'options[titleHash, wordsHash]'], cases,
}, null, 1)}\n`);
console.log(JSON.stringify({ cases: cases.length, withChoice: choices, withNote: cases.filter((c) => c[1].length).length }));
