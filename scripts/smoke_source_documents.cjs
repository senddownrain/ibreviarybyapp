// Real Flutter Chrome UI; only the three external document requests are aborted.
// This verifies browser opening, not publication of the remote Web documents.
// NODE_PATH=<playwright parent> FLUTTER_ROOT=<sdk> CDP_URL=<Flutter Chrome CDP> node scripts/smoke_source_documents.cjs
const { chromium } = require('playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const base = 'http://localhost:5241/';
const out = path.resolve('audit-evidence/source-documents');
const sdk = process.env.FLUTTER_ROOT;
assert(sdk, 'FLUTTER_ROOT is required');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const errors = [], external = [], states = [], documentRequests = [];
let page;
async function snapshot() {
  const result = JSON.parse(await page.evaluate(() => sourceSmokeSnapshot()));
  assert.deepEqual(result.overflow, [], 'No overflow or truncated Flutter paragraphs');
  return result;
}
async function waitText(text) {
  await page.waitForFunction(s => JSON.parse(sourceSmokeSnapshot()).text.includes(s), text, { timeout: 120000 });
}
async function waitRoute(route) {
  await page.waitForFunction(s => JSON.parse(sourceSmokeSnapshot()).route === s, route, { timeout: 120000 });
}
async function scrollTo(text) {
  assert(await page.evaluate(s => sourceSmokeScroll(s), text), 'Rendered text: ' + text);
  await pause(150);
}
async function click(label) {
  await page.bringToFront();
  if (label === 'Закрыць') {
    await page.getByRole('button', { name: /^Закрыць(?:\s|$)/ }).first().click();
    await page.mouse.move(1, 1);
  } else {
    await scrollTo(label);
    await page.getByRole('button', { name: label, exact: true }).last().click();
  }
  await pause(450);
}
async function capture(name) {
  await page.bringToFront();
  await snapshot();
  await page.screenshot({ path: path.join(out, name + '.png'), timeout: 90000 });
}
async function load(width, theme, scale, launchError = false) {
  await page.setViewportSize({ width, height: width === 390 && scale === 1 && !launchError ? 1240 : 844 });
  await page.goto(base + '?' + new URLSearchParams({ theme, scale, path: '/about', launchError }), { waitUntil: 'domcontentloaded' });
  await page.bringToFront();
  await page.waitForFunction(() => typeof sourceSmokeSnapshot === 'function', null, { timeout: 120000 });
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 120000 });
  await placeholder.evaluate(e => e.click());
  await waitText('Распрацоўшчык @davin_dev');
  await click('Крыніцы і аўтарскія правы');
  await waitRoute('/sources');
  await waitText('Святое Пісанне');
}
(async () => {
  await fs.mkdir(out, { recursive: true });
  const browser = await chromium.connectOverCDP(process.env.CDP_URL || 'http://127.0.0.1:9222');
  try {
    const context = browser.contexts()[0];
    page = context.pages().find(p => p.url().startsWith(base));
    assert(page, 'Exact Flutter URL: ' + base);
    await page.goto('about:blank');
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => {
      if (m.type() === 'error' || /EXCEPTION CAUGHT|overflowed by/.test(m.text())) errors.push(m.text());
    });
    // Opening a new browser tab is real. Remote document content is not fetched
    // by this UI smoke, and its publication remains a separate acceptance gate.
    await context.route('https://ibreviaryby.web.app/**', route => {
      documentRequests.push(route.request().url());
      return route.abort();
    });
    await page.route('**/*', async route => {
      const u = new URL(route.request().url());
      if (['localhost', '127.0.0.1'].includes(u.hostname) || ['data:', 'blob:'].includes(u.protocol)) return route.continue();
      if (u.hostname === 'fonts.gstatic.com') return route.fulfill({ path: u.pathname.includes('/notosans/') ? '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf' : path.join(sdk, 'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'), contentType: 'font/ttf' });
      if (u.hostname === 'www.gstatic.com' && u.pathname.startsWith('/flutter-canvaskit/')) {
        const rel = u.pathname.split('/').slice(3).join('/');
        assert(!rel.includes('..'));
        return route.fulfill({ path: path.join(sdk, 'bin/cache/flutter_web_sdk/canvaskit', rel), contentType: rel.endsWith('.wasm') ? 'application/wasm' : 'text/javascript' });
      }
      external.push(u.origin + u.pathname);
      return route.abort();
    });
    for (const [width, theme, scale] of [[390, 'light', 1], [320, 'light', 1], [320, 'dark', 2], [390, 'dark', 2]]) {
      console.log(`${width}-${theme}-${scale} starting`);
      await load(width, theme, scale);
      const result = await snapshot();
      for (const text of ['Святое Пісанне', 'Чытанні', 'Літургія гадзінаў', 'Кампендый ККК', 'Дакументы', '«Літургія гадзінаў» (Мінск, 2012–2020)', '© Канферэнцыя Каталіцкіх Біскупаў Беларусі']) assert(result.text.includes(text), text);
      assert(!result.text.join('\n').includes('Libreria'));
      assert(!result.text.join('\n').includes('pending'));
      assert.equal(result.links.length, 3);
      for (const doc of result.links) assert.equal(result.text.filter(t => t === doc.label).length, 1);
      if (width === 390 && scale === 1) {
        await capture('sources-390-light');
        for (const doc of result.links) {
          const request = context.waitForEvent('request', r => r.url() === doc.url);
          const popup = page.waitForEvent('popup');
          await click(doc.label);
          await request;
          const tab = await popup;
          await tab.close();
          await page.bringToFront();
          assert.equal((await snapshot()).route, '/sources');
        }
        assert.deepEqual(documentRequests, result.links.map(d => d.url));
      }
      if (width === 320 && scale === 2) {
        await scrollTo('Дакументы');
        await capture('sources-320-dark-large');
      }
      await click('Закрыць');
      await waitRoute('/about');
      await waitText('Распрацоўшчык @davin_dev');
      states.push({ width, theme, textScale: scale, rights: 6, externalLinks: 3, back: 'pass' });
      console.log(`${width}-${theme}-${scale} PASS`);
    }
    await load(390, 'light', 1, true);
    const links = (await snapshot()).links;
    await scrollTo('Дакументы');
    await click(links[1].label);
    await waitText('Не ўдалося адкрыць старонку. Праверце інтэрнэт-злучэнне');
    assert.equal((await snapshot()).route, '/sources');
    await capture('sources-browser-error-390');
    assert.deepEqual(external, []);
    assert.deepEqual(errors, []);
    await fs.writeFile(path.join(out, 'visual-result.json'), JSON.stringify({ url: base, states, errors, external, documentRequests, browserFailure: 'Belarusian message displayed, no native document fallback', publication: 'UNVERIFIED: managed proxy denies the Web host; this smoke intentionally aborts document content requests', native: 'Android/iOS devices unavailable; externalApplication mode covered by widget tests, Chrome opens separate real tabs' }, null, 2) + '\n');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
