// Local synthetic output only. Run against the unmodified Web PR checkout.
// node tool/generate_prayer_category_fixture.mjs /path/to/web-pr246
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

const web = path.resolve(process.argv[2]);
const { writeBundle } = await import(pathToFileURL(path.join(web, 'scripts/content/build-app-bundle.mjs')));
const fixture = JSON.parse(fs.readFileSync(path.join(web, 'shared/prayer-categories/fixture.json')));
const out = new URL('../test/fixtures/prayer-categories/', import.meta.url);
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(new URL('fixture.json', out), `${JSON.stringify(fixture, null, 2)}\n`);
const collections = new Map([
  ['prayers', fixture.prayers],
  ['prayerCategories', [...fixture.categories, {
    id: 'codec-probe', name: 'Synthetic string table category with a long name',
    tags: [], prayerIds: ['synthetic-opaque-prayer-reference-longer-than-32'],
    parentId: null, order: 50, priestOnly: false, iconKey: 'folder',
    icon: 'synthetic-existing-icon', iconId: 'synthetic-existing-icon-id',
  }]],
]);
writeBundle(collections, new Map([...collections.keys()].map(k => [k, 1000])), 1000, fileURLToPath(out));
