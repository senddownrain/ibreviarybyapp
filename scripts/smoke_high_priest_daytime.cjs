// Attach only to Chrome started by Flutter, at the exact local app URL.
// NODE_PATH=<playwright parent> FLUTTER_ROOT=<sdk> node scripts/smoke_high_priest_daytime.cjs
const { chromium } = require('playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const base = 'http://localhost:5240/';
const out = path.resolve('audit-evidence/high-priest-daytime');
const sdk = process.env.FLUTTER_ROOT;
assert(sdk, 'Set FLUTTER_ROOT to the SDK used by flutter run');
const pause = ms => new Promise(r => setTimeout(r, ms));
const errors = [], external = [], rows = [];
const endOnly = process.argv.includes('--end-only');
let page;
async function scrollTo(needle) {
  await page.waitForFunction(() => typeof highPriestScrollTo === 'function');
  assert(await page.evaluate(text => highPriestScrollTo(text), needle), 'Rendered paragraph exists: ' + needle);
  await pause(250);
}
async function capture(name) {
  assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), 'No horizontal page overflow');
  await pause(200);
  await page.screenshot({ path: path.join(out, name + '.png') });
}
(async () => {
  await fs.mkdir(out, { recursive: true });
  if (endOnly) {
    const previous = JSON.parse(await fs.readFile(path.join(out, 'visual-result.json')));
    rows.push(...previous.states);
    errors.push(...previous.errors);
    external.push(...previous.external);
  }
  const browser = await chromium.connectOverCDP(process.env.CDP_URL || 'http://127.0.0.1:9222');
  try {
    page = browser.contexts()[0].pages().find(p => p.url().startsWith(base));
    assert(page, 'Exact Flutter URL ' + base);
    // Serve engine resources and its fallback font from this same SDK. Book
    // fonts remain the real unchanged app assets. Every other remote is denied.
    await page.goto('about:blank');
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error' || /EXCEPTION CAUGHT|overflowed by/.test(m.text())) errors.push(m.text()); });
    await page.route('**/*', async route => {
      const u = new URL(route.request().url());
      if (['localhost', '127.0.0.1'].includes(u.hostname) || ['data:', 'blob:'].includes(u.protocol)) return route.continue();
      if (u.hostname === 'fonts.gstatic.com') return route.fulfill({ path: path.join(sdk, 'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'), contentType: 'font/ttf' });
      if (u.hostname === 'www.gstatic.com' && u.pathname.startsWith('/flutter-canvaskit/')) {
        const rel = u.pathname.split('/').slice(3).join('/');
        assert(!rel.includes('..'));
        return route.fulfill({ path: path.join(sdk, 'bin/cache/flutter_web_sdk/canvaskit', rel), contentType: rel.endsWith('.wasm') ? 'application/wasm' : 'text/javascript' });
      }
      external.push(u.origin + u.pathname); return route.abort();
    });
    const hours = [
      ['terz', 'Гбр 7, 26-27', 'Праз Хрыста', 'Каб і ў час аб’яўлення славы Яго'],
      ['sext', '1 П 2, 4-5', 'Вы ўмацаваныя на падмурку', 'Укаранёныя і збудаваныя ў Ім'],
      ['none', '1 П 2, 9-10', 'Кожнаму з нас дадзена ласка', 'Да якога вы пакліканыя ў адным целе.'],
    ];
    for (const [hour, reference, antiphon, response] of hours) {
      for (const theme of ['light', 'dark']) {
        for (const large of [false, true]) {
          if (endOnly && !(theme === 'dark' && large)) continue;
          const state = `${hour}-${theme}-${large ? 'large' : 'normal'}`;
          await page.setViewportSize({ width: large ? 320 : 390, height: 844 });
          await page.goto(base + '?' + new URLSearchParams({ hour, theme, scale: large ? 'large' : 'normal' }), { waitUntil: 'domcontentloaded' });
          await page.locator('flt-semantics-placeholder').waitFor({ timeout: 60000 });
          await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
          await page.getByRole('button', { name: 'Назад', exact: true }).first().waitFor({ timeout: 60000 });
          // Explicitly verify the production route. Web calls this hour
          // `none`; the existing Flutter router/OraScreen uses `non`.
          const routeHour = hour === 'none' ? 'non' : hour;
          await page.evaluate(type => {
            location.hash = `/hours/ora/2026-05-28/feast-christthehighpriest/${type}?diocese=pinsk`;
          }, routeHour);
          await pause(1000);
          if (endOnly) {
            await scrollTo('Catholic.by');
            await capture(state + '-end');
            continue;
          }
          if ((theme === 'light' && !large) || (theme === 'dark' && large)) await capture(state + '-start');
          await scrollTo(antiphon);
          if ((theme === 'light' && !large) || (theme === 'dark' && large)) await capture(state + '-antiphon');
          await page.mouse.move(160, 600);
          await page.mouse.wheel(0, 350);
          await pause(200);
          await scrollTo(reference);
          await capture(state + '-reading');
          // Check actual rendered paragraphs: the reader merges semantics
          // into one document and can omit that node after scrolling.
          for (const [, other] of hours) if (other !== reference) {
            assert.equal(await page.evaluate(text => highPriestScrollTo(text), other), false, 'Another hour reading leaked');
          }
          await scrollTo(response);
          if (large) await capture(state + '-response');
          await scrollTo('Божа, Ты дзеля хвалы Тваёй велічы');
          if (theme === 'dark' && large) {
            await capture(state + '-collect');
            await scrollTo('Catholic.by');
            await capture(state + '-end');
          }
          rows.push({ hour, reference, theme, font: large ? 'maximum reader size' : 'default', width: large ? 320 : 390, scroll: 'reading reached' });
        }
      }
    }
    await fs.writeFile(path.join(out, 'visual-result.json'), JSON.stringify({ browser: await browser.version(), url: base, source: 'unchanged offline bundle; production router and OraScreen; no Firebase initialization', engineResources: 'same local Flutter SDK; Roboto fallback supplied locally', states: rows, errors, external, nativeSmoke: 'required before mobile release' }, null, 2) + '\n');
    assert.deepEqual(errors, [], 'Browser/Flutter errors');
    assert.deepEqual(external, [], 'Unexpected remote requests');
    console.log(JSON.stringify({ states: rows.length, screenshots: (await fs.readdir(out)).filter(n => n.endsWith('.png')).length, errors, external }));
  } finally {
    await browser.close();
  }
})().catch(e => { console.error(e); process.exitCode = 1; });
