// Browser capture of the real Flutter ReadingsScreen in the offline harness.
const { chromium } = require('playwright-core');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const base = 'http://localhost:5242/';
const output = path.resolve('audit-evidence/readings-header-20261109');
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

(async () => {
  fs.mkdirSync(output, { recursive: true });
  let browser;
  for (let attempt = 0; attempt < 120; attempt++) {
    const processes = execFileSync('ps', ['-eo', 'args'], { encoding: 'utf8' });
    const port = processes.match(/(?:chrome|chromium)[^\n]*--remote-debugging-port=(\d+)/)?.[1];
    if (port) {
      try {
        browser = await chromium.connectOverCDP('http://127.0.0.1:' + port);
        if (browser.contexts()[0]?.pages().some((page) => page.url().startsWith(base))) break;
        await browser.close();
        browser = undefined;
      } catch { browser = undefined; }
    }
    await pause(5000);
  }
  assert(browser, 'Flutter Chrome did not become ready');

  const page = browser.contexts()[0].pages().find((p) => p.url().startsWith(base));
  assert(page, 'Expected live Flutter Chrome page');
  const sdk = process.env.FLUTTER_ROOT;
  const errors = [];
  const results = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.route('**/*', async (route) => {
    const url = new URL(route.request().url());
    if (['localhost', '127.0.0.1'].includes(url.hostname) ||
        ['data:', 'blob:'].includes(url.protocol)) return route.continue();
    if (url.hostname === 'fonts.gstatic.com')
      return route.fulfill({
        path: path.join(sdk, 'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'),
        contentType: 'font/ttf',
      });
    if (url.hostname === 'www.gstatic.com' &&
        url.pathname.startsWith('/flutter-canvaskit/')) {
      const rel = url.pathname.split('/').slice(3).join('/');
      assert(!rel.includes('..'));
      return route.fulfill({
        path: path.join(sdk, 'bin/cache/flutter_web_sdk/canvaskit', rel),
        contentType: rel.endsWith('.wasm') ? 'application/wasm' : 'text/javascript',
      });
    }
    return route.abort();
  });

  try {
    for (const profile of [
      { name: 'flutter-mobile-light', width: 390, height: 844, theme: 'light' },
      { name: 'flutter-mobile-dark', width: 390, height: 844, theme: 'dark' },
      { name: 'flutter-desktop-light', width: 1280, height: 900, theme: 'light' },
    ]) {
      await page.setViewportSize({ width: profile.width, height: profile.height });
      await page.goto(base + '?theme=' + profile.theme, { waitUntil: 'domcontentloaded' });
      const semantics = page.locator('flt-semantics-placeholder');
      await semantics.waitFor({ timeout: 90000 });
      await semantics.evaluate((element) => element.click());
      const dismiss = page.getByRole('button', { name: 'Не зараз', exact: true });
      if (await dismiss.count()) await dismiss.first().click();

      await page.waitForFunction(() => {
        return [...document.querySelectorAll('flt-semantics')].some((element) =>
          ((element.getAttribute('aria-label') || '') + (element.textContent || ''))
            .includes('Чытанні дня'));
      }, null, { timeout: 60000 });
      await pause(800);
      await page.screenshot({
        path: path.join(output, profile.name + '.png'),
        animations: 'disabled',
      });
      results.push({ ...profile, titleVisibleInSemantics: true, url: page.url() });
      console.log('PASS', profile.name, 'rendered Flutter header Чытанні дня');
    }
    assert.deepEqual(errors, [], 'Flutter browser errors');
  } catch (error) {
    await page.screenshot({ path: path.join(output, 'flutter-failure.png') });
    fs.writeFileSync(path.join(output, 'failure.html'), await page.content());
    throw error;
  } finally {
    fs.writeFileSync(path.join(output, 'results.json'), JSON.stringify({ results, errors }, null, 2));
    await browser.close();
  }
})().catch((error) => { console.error(error); process.exitCode = 1; });
