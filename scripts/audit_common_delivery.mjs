/** Read-only, explicitly scoped delivery audit. Never publishes anything.
 *
 *   node scripts/audit_common_delivery.mjs --web ../mybrev --approval <id> --max-reads 400
 *
 * This is a PRODUCTION READ (projectId ibreviaryby). It refuses to start without
 * `--approval <id>` of a written read approval and a `--max-reads` budget; the
 * documents read are liturgicalProperTexts (+ meta/current, contentManifest/current)
 * and the run aborts if that would exceed the budget. The Web commit is recorded
 * (clean checkout contained in origin/main), not pinned to a historical SHA.
 * Compared: digests of the generated Web sources against the live collections.
 */
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { resolveWeb } from './lib/web_source.mjs';
const argv = process.argv.slice(2);
const value = (key) => (argv.includes(key) ? argv[argv.indexOf(key) + 1] : undefined);
assert(value('--approval'), 'Production read needs --approval <id of the written approval>');
const maxReads = Number(value('--max-reads'));
assert(Number.isInteger(maxReads) && maxReads > 0, 'Pass --max-reads <budget from the approval>');
const { web, head: webCommit, onOriginMain } = resolveWeb(argv);
const requireWeb = createRequire(path.join(web, 'package.json'));
const admin = requireWeb('firebase-admin');
const api = await import(pathToFileURL(path.join(web, 'scripts/content/lib/app-content.mjs')));
const app = admin.initializeApp({ credential: admin.credential.cert(
  JSON.parse(fs.readFileSync(path.join(web, 'patchs/serviceAccountKey.json')))) });
try {
  const db = admin.firestore(app);
  db.settings({ preferRest: true });
  const current = (await db.doc('contentManifest/current').get()).data();
  const meta = (await db.doc('liturgicalCalendarMeta/current').get()).data();
  const live = await db.collection('liturgicalProperTexts').limit(maxReads).get();
  assert(live.size + 3 <= maxReads, `Read budget ${maxReads} is too small for ${live.size} documents`);
  const docs = live.docs.map(d => api.storedDocument(d.id, d.data()));
  const local = fs.readdirSync(path.join(web, 'patchs/db-feasts')).filter(n => n.endsWith('.json')).map(n => {
    const { _id, ...data } = JSON.parse(fs.readFileSync(path.join(web, 'patchs/db-feasts', n)));
    return api.storedDocument(_id, data);
  });
  assert.equal(api.describeDocuments(local).digest, api.describeDocuments(docs).digest,
    'Generated Proper sources must equal the live public collection');
  const templateDigest = current.collections.liturgicalTemplates.digest;
  const report = { webCommit, webOnOriginMain: onOriginMain, approval: value('--approval'), maxReads,
    readAt: new Date().toISOString(), mode: 'read-only', properTextsRevision: meta.properTextsRevision,
    templatesRevision: meta.templatesRevision, properCount: docs.length,
    properDigest: api.describeDocuments(docs).digest, templateDigest,
    publishedProper: current.collections.liturgicalProperTexts ?? null,
    publishedContentVersion: current.contentVersion,
    bindings: docs.reduce((n, d) => n + Object.keys(d._commonBase ?? {}).length, 0),
    boundDocuments: docs.filter(d => d._commonBase).length };
  fs.mkdirSync('audit-evidence/common-office', { recursive: true });
  fs.writeFileSync('audit-evidence/common-office/delivery-audit.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify(report, null, 2));
} finally { await app.delete(); }
