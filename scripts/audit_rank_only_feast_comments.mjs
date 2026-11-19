/** Report rank-only day comments in the shipped Flutter content bundle.
 *
 *   node scripts/audit_rank_only_feast_comments.mjs
 *
 * Reads only local, compressed content assets. Does not contact Firestore
 * or change any source material. Use the reported IDs to review a separate
 * source-data cleanup before rebuilding and publishing a content bundle.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const bundleDir = path.resolve('assets/content');
const manifest = JSON.parse(fs.readFileSync(path.join(bundleDir, 'manifest.json'), 'utf8'));
const labels = new Set([
  'урачыстасць', 'ўрачыстасць', 'solemnitas', 'solemnity',
  'свята', 'festum', 'feast', 'успамін', 'memoria',
  'неабавязковы ўспамін', 'memoria ad libitum',
]);
const isRankOnly = (value) => {
  if (typeof value !== 'string') return false;
  const text = value
    .replace(/<[^>]*>/g, ' ')
    .replace(/&(?:nbsp|#160|#x0*a0);/gi, ' ')
    .replace(/\s+/g, ' ').trim()
    .replace(/[.!]+$/, '').trim().toLowerCase();
  return labels.has(text);
};
const matches = [];
const totals = {};
for (const name of ['days', 'liturgicalProperTexts', 'liturgicalTemplates']) {
  const entry = manifest.collections[name];
  if (!entry) continue;
  const payload = JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(bundleDir, entry.file))));
  const strings = payload.strings;
  const deref = (value) => typeof value === 'string' && value.startsWith('\u0001')
    ? strings[Number(value.slice(1))]
    : value;
  const docs = payload.docs ?? {};
  totals[name] = Object.keys(docs).length;
  for (const [id, doc] of Object.entries(docs)) {
    for (const field of ['feastComment', 'comment']) {
      const value = deref(doc[field]);
      if (isRankOnly(value)) matches.push({
        collection: name, id, field, value,
        title: deref(doc.feastName ?? doc._feastName ?? doc.title ?? doc._title) ?? '',
        rank: deref(doc.rank ?? doc._rank) ?? '',
      });
    }
  }
}
console.log(JSON.stringify({
  bundleContentDate: manifest.contentDate,
  scannedDocuments: totals,
  matches,
  matchCount: matches.length,
}, null, 2));
