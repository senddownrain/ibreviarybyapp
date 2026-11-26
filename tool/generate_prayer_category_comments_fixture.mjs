// Synthetic output only. Pass the MyBrev Web checkout for contract 118e3050.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import zlib from 'node:zlib';

const web = path.resolve(process.argv[2]);
const { writeBundle } = await import(pathToFileURL(path.join(web, 'scripts/content/build-app-bundle.mjs')));
const baseline = new URL('../test/fixtures/prayer-categories/', import.meta.url);
const names = ['prayers', 'prayerCategories'];
const collections = new Map(names.map((name) => {
  const data = JSON.parse(zlib.gunzipSync(fs.readFileSync(new URL(`${name}.json.gz`, baseline))));
  const resolve = (value) => {
    if (typeof value === 'string' && value.startsWith('\u0001')) return data.strings[Number(value.slice(1))];
    if (Array.isArray(value)) return value.map(resolve);
    if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, resolve(item)]));
    return value;
  };
  return [name, Object.entries(data.docs).map(([id, item]) => ({ ...resolve(item), id }))];
}));
const categories = collections.get('prayerCategories');
categories.find(({ id }) => id === 'root').comment = {
  title: 'Тлумачэнне',
  content: 'Сінтэтычны **тэкст** з [прыкладам](/prayer/manual).',
  sourceId: 'ojcha-nash-2022',
};
categories.push(
  { id: 'comment-parent', name: 'Synthetic parent', tags: [] },
  { id: 'comment-leaf', name: 'Synthetic comment leaf', parentId: 'comment-parent', tags: [],
    comment: { content: 'Synthetic content in a category without prayers.' } },
  { id: 'restricted', name: 'Restricted fixture', tags: [], priestOnly: true,
    comment: { content: 'Restricted fixture comment' } },
  { id: 'restricted-child', name: 'Inherited restriction fixture', tags: [], parentId: 'restricted',
    comment: { content: 'Inherited restriction fixture comment' } },
  { id: 'canonical-child', name: 'Child of canonical protected category', tags: [], parentId: 'canonical-private',
    comment: { content: 'Canonical child fixture comment' } },
  { id: 'unpublished', name: 'Unpublished fixture', status: 'draft', tags: [],
    comment: { content: 'Unpublished fixture comment' } },
  { id: 'unpublished-child', name: 'Child of unpublished fixture', tags: [], parentId: 'unpublished',
    comment: { content: 'Unpublished child fixture comment' } },
);
collections.set('protectedCategories', [
  { id: 'canonical-private', name: 'Canonical protected fixture', accessSchemaVersion: 2,
    accessSets: ['marian'], effectiveAccessSets: ['marian'],
    comment: { content: 'Canonical protected fixture comment' } },
]);
// The old bundle has two opaque references. S8 retains references to priest-mirror IDs.
collections.set('priestProtectedPrayers', [
  { id: 'shared-private' },
  { id: 'synthetic-opaque-prayer-reference-longer-than-32' },
]);
const output = new URL('../test/fixtures/prayer-category-comments/', import.meta.url);
writeBundle(collections, new Map([['prayers', 1000], ['prayerCategories', 2000]]), 2000, fileURLToPath(output));
