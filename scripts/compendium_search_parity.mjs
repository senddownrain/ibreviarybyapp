import { readFileSync } from 'node:fs';
// Regenerates test/fixtures/compendium_search_parity.json from the MyBrev
// reference implementation, so the Dart port can be checked result by result:
//   node scripts/compendium_search_parity.mjs ../mybrev > test/fixtures/compendium_search_parity.json
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const root = pathToFileURL(resolve(process.argv[2] ?? '../mybrev') + '/').href;
const { indexCompendium } = await import(root + 'src/utils/compendiumData.js');
const { createCompendiumSearchIndex, searchCompendium, normalizeSearchText } = await import(root + 'src/utils/compendiumSearch.js');
const dataset = JSON.parse(readFileSync(new URL('src/data/compendium/compendium.json', root), 'utf8'));
const aliases = JSON.parse(readFileSync(new URL('src/data/compendium/compendium_search_aliases.json', root), 'utf8'));
const index = indexCompendium(dataset);
const search = createCompendiumSearchIndex(index.questions, aliases);
const queries = ['1', '100', '598', '№ 42', '#7', '42.', '1066', '0', '999', 'Бог', 'вера', 'Касцёл', 'сакрамэнт', 'хрост', 'Эўхарыстыя', 'ЭЎХАРЫСТЫЯ', 'малітва', 'грэх', 'што такое малітва', 'Святы Дух', 'Дзева Марыя', 'дзесяць запаведзяў', 'крещение', 'исповедь', 'причастие', 'грех', 'священник', 'таинство брака', 'молитва', 'церковь', 'Иисус Христос', 'отче наш', 'зззззз', '   ', 'Пісанне', 'ПIСАННЕ', 'аб’яўленне', "аб'яўленне", 'Эўхарыстыя 1322', 'шлюб', 'Fiat', 'Езус Хрыстос', 'пакаянне і паяднанне', 'ёсць', 'ангелы', 'касцел', 'еухарыстыя'];
const out = {
  normalize: Object.fromEntries(['Эўхарыстыя', 'Касцёл', 'Аб’яўленне', 'ПIСАННЕ', 'Пісанне', 'Ёсць «Бог» — і (усё)!', 'Fiat mihi', 'Іісус', 'ЎЁЙЇ', 'Café naïve', 'pак', 'сaм'].map((t) => [t, normalizeSearchText(t)])),
  results: Object.fromEntries(queries.map((q) => [q, searchCompendium(search, q).slice(0, 25).map((r) => [r.question.number, r.field, Math.round(r.score * 1e6) / 1e6])])),
  counts: Object.fromEntries(queries.map((q) => [q, searchCompendium(search, q).length])),
};
console.log(JSON.stringify(out));
