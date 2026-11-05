// Attach to the exact Chrome instance launched by Flutter, never another app.
// NODE_PATH=<playwright parent> FLUTTER_ROOT=<sdk> node scripts/smoke_source_documents.cjs
const { chromium } = require('playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const base = 'http://localhost:5241/';
const out = path.resolve('audit-evidence/source-documents');
const sdk = process.env.FLUTTER_ROOT;
assert(sdk, 'FLUTTER_ROOT is required');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const errors = [], external = [], states = [];
let page;
async function snapshot() {
  const result = JSON.parse(await page.evaluate(() => sourceSmokeSnapshot()));
  assert.deepEqual(result.overflow, [], 'No rendered Flutter paragraph outside viewport');
  return result.text;
}
async function waitText(text) {
  await page.waitForFunction(s => JSON.parse(sourceSmokeSnapshot()).text.includes(s), text, { timeout: 120000 });
}
async function waitRoute(route) {
  await page.waitForFunction(s => JSON.parse(sourceSmokeSnapshot()).route === s, route, { timeout: 120000 });
}
async function scrollTo(text) {
  assert(await page.evaluate(s => sourceSmokeScroll(s), text), 'Rendered text: ' + text);
  await pause(100);
}
async function click(label) {
  if (label !== 'Закрыць') await scrollTo(label);
  await page.getByRole('button', { name: label, exact: true }).last().click();
  await pause(450);
}
async function capture(name) {
  await snapshot();
  await page.screenshot({ path: path.join(out, name + '.png') });
}
async function load(width, theme, scale, route = '/about') {
  await page.setViewportSize({ width, height: 844 });
  await page.goto(base + '?' + new URLSearchParams({ theme, scale, path: route }), { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => typeof sourceSmokeSnapshot === 'function', null, { timeout: 120000 });
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 120000 });
  await placeholder.evaluate(e => e.click());
  await page.getByRole('button', { name: 'Закрыць', exact: true }).waitFor();
  await pause(350);
}
(async () => {
  await fs.mkdir(out, { recursive: true });
  const browser = await chromium.connectOverCDP(process.env.CDP_URL || 'http://127.0.0.1:9222');
  try {
    page = browser.contexts()[0].pages().find(p => p.url().startsWith(base));
    assert(page, 'Exact Flutter URL: ' + base);
    await page.goto('about:blank');
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => {
      if (m.type() === 'error' || /EXCEPTION CAUGHT|overflowed by/.test(m.text())) errors.push(m.text());
    });
    await page.route('**/*', async route => {
      const u = new URL(route.request().url());
      if (['localhost', '127.0.0.1'].includes(u.hostname) || ['data:', 'blob:'].includes(u.protocol)) return route.continue();
      // Flutter engine boot resources are served from this SDK, not the Internet.
      if (u.hostname === 'fonts.gstatic.com') return route.fulfill({ path: u.pathname.includes('/notosans/') ? '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf' : path.join(sdk, 'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'), contentType: 'font/ttf' });
      if (u.hostname === 'www.gstatic.com' && u.pathname.startsWith('/flutter-canvaskit/')) {
        const rel = u.pathname.split('/').slice(3).join('/');
        assert(!rel.includes('..'));
        return route.fulfill({ path: path.join(sdk, 'bin/cache/flutter_web_sdk/canvaskit', rel), contentType: rel.endsWith('.wasm') ? 'application/wasm' : 'text/javascript' });
      }
      external.push(u.origin + u.pathname);
      return route.abort();
    });
    const decrees = JSON.parse(await fs.readFile('assets/legal/liturgy-hours-decrees.json'));
    const calendar = JSON.parse(await fs.readFile('assets/legal/proper-calendar.json'));
    const sources = JSON.parse(await fs.readFile('assets/legal/sources.json'));
    const cases = [[390, 'light', 1], [320, 'dark', 2],
      ...[320, 390].flatMap(w => ['light', 'dark'].flatMap(t => [1, 2].map(s => [w, t, s])))
        .filter(([w, t, s]) => !(w === 390 && t === 'light' && s === 1) && !(w === 320 && t === 'dark' && s === 2))];
    for (const [width, theme, scale] of cases) {
      const state = `${width}-${theme}-${scale}`;
      console.log(state + ' starting');
      await load(width, theme, scale);
      await waitText('Распрацоўшчык @davin_dev');
      await snapshot();
      if (state === '390-light-1') await capture('about-390-light');
      await click('Крыніцы і аўтарскія правы');
      await waitRoute('/sources');
      await waitText('Святое Пісанне');
      console.log(state + ' sources');
      const sourceText = await snapshot();
      for (const text of ['Святое Пісанне', 'Чытанні', 'Літургія гадзінаў', 'Кампендый ККК', 'Дакументы', '© Libreria Editrice Vaticana, 2005']) {
        assert(sourceText.includes(text), text);
      }
      for (const entry of sources.entries) {
        assert(!sourceText.join('\n').includes(entry.verification.status), 'No technical status');
      }
      assert(!sourceText.join('\n').includes('пераклад ККББ'));
      assert.equal(sourceText.filter(t => t === 'Дэкрэты Літургіі гадзінаў').length, 1);
      await scrollTo('Крыніцы і аўтарскія правы');
      if (state === '390-light-1') await capture('sources-390-light');
      if (state === '320-dark-2') await capture('sources-320-dark-large');
      await click('Дэкрэты Літургіі гадзінаў');
      await waitRoute('/documents/liturgy-hours-decrees');
      await waitText('№ 32/P/12');
      console.log(state + ' decrees');
      const text = await snapshot();
      for (const d of decrees.documents) {
        for (const s of [d.issuer.join('\n'), '№ ' + d.number, d.heading, ...d.paragraphs, d.dateLines.join('\n'), d.signature.join('\n')]) {
          assert(text.includes(s), 'Complete decree: ' + s.slice(0, 60));
        }
        await click('Том ' + d.roman);
      }
      if (state === '390-light-1') await capture('decree-IV-390-light');
      await click('Закрыць');
      await waitRoute('/sources');
      await waitText('Святое Пісанне');
      assert((await snapshot()).includes('Крыніцы і аўтарскія правы'));
      await click('Уласны каляндар дыяцэзій на Беларусі');
      await waitRoute('/documents/proper-calendar');
      await waitText('СТУДЗЕНЬ');
      console.log(state + ' calendar');
      const article = await snapshot();
      const intro = calendar.pages.flatMap(p => p.rows).filter(r => r.kind === 'intro').map(r => r.runs.map(s => s.text).join('')).join(' ');
      assert(article.includes(intro), 'One complete introduction paragraph');
      let cursor = article.indexOf(intro) + 1;
      let dates = 0;
      for (const p of calendar.pages) for (const row of p.rows) {
        if (row.kind === 'intro') continue;
        const expected = row.kind === 'month' ? [row.text] : [
          ...(row.date ? [row.date + '.'] : []),
          ...(row.runs.length ? [row.runs.map(s => s.text).join('')] : []),
          ...(row.rank.length ? [row.rank.map(s => s.text).join('')] : []),
        ];
        if (row.date) dates++;
        for (const s of expected) {
          const index = article.indexOf(s, cursor);
          assert(index >= cursor, 'Calendar text and order: ' + s);
          cursor = index + 1;
        }
      }
      assert.equal(dates, 365);
      for (const month of calendar.months) {
        if (state !== '390-light-1' && ![1, 7, 11, 12].includes(month.number)) continue;
        await click(month.title);
        console.log(state + ' month ' + month.number);
        if (state === '390-light-1' && [1, 11, 12].includes(month.number)) await capture(`calendar-${month.number}-390-light`);
        if (state === '320-dark-2' && month.number === 7) await capture('calendar-7-320-dark-large');
      }
      await click('Закрыць');
      await waitRoute('/sources');
      await waitText('Святое Пісанне');
      assert((await snapshot()).includes('Крыніцы і аўтарскія правы'));
      await click('Закрыць');
      await waitRoute('/about');
      await waitText('Распрацоўшчык @davin_dev');
      assert((await snapshot()).some(s => s.includes('Распрацоўшчык @davin_dev')));
      states.push({ width, theme, textScale: scale, decrees: 4, pages: 13, dates, months: 12, back: 'pass' });
      console.log(state + ' PASS');
    }
    // Real offline PDF download through share_plus's web fallback.
    await load(390, 'light', 1, '/documents/proper-calendar');
    await scrollTo('Арыгінал PDF');
    const pendingDownload = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Арыгінал PDF', exact: true }).click();
    const download = await pendingDownload;
    const data = await fs.readFile(await download.path());
    assert.equal(crypto.createHash('sha256').update(data).digest('hex'), calendar.sourceSha256);
    assert.deepEqual(external, [], 'No content/Firebase/font fetch from external servers');
    assert.deepEqual(errors, [], 'No browser/Flutter errors');
    await fs.writeFile(path.join(out, 'visual-result.json'), JSON.stringify({ url: base, states, errors, external, pdf: 'Offline downloaded bytes match original SHA-256', native: 'Android/iOS not available; share sheet not verified on device' }, null, 2) + '\n');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
