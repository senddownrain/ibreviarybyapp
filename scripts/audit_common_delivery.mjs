/** Read-only, explicitly scoped delivery audit. Never publishes anything.
 * node scripts/audit_common_delivery.mjs --web ../mybrev
 */
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
assert(process.argv.includes('--web'), 'Pass --web <production Web checkout>');
const web = path.resolve(process.argv[process.argv.indexOf('--web') + 1]);
const webCommit = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: web, encoding: 'utf8' }).trim();
assert.equal(webCommit, '0612d534cacbc847ab6c6b7e0102137333f07211');
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
  const live = await db.collection('liturgicalProperTexts').get();
  const docs = live.docs.map(d => api.storedDocument(d.id, d.data()));
  const local = fs.readdirSync(path.join(web, 'patchs/db-feasts')).filter(n => n.endsWith('.json')).map(n => {
    const { _id, ...data } = JSON.parse(fs.readFileSync(path.join(web, 'patchs/db-feasts', n)));
    return api.storedDocument(_id, data);
  });
  assert.equal(api.describeDocuments(local).digest, api.describeDocuments(docs).digest,
    'Generated Proper sources must equal the live public collection');
  const templateDigest = current.collections.liturgicalTemplates.digest;
  const report = { webCommit,
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
