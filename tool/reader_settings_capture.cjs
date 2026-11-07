// Connect to the ONE Chrome launched by Flutter; never starts another browser.
// Usage: node tool/reader_settings_capture.cjs <CDP port> <output directory>
// Requires Playwright in the Node environment. See evidence README for fonts.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
(async () => {
  const browser = await chromium.connectOverCDP(`http://127.0.0.1:${process.argv[2]}`);
  const page = browser.contexts()[0].pages().find(p => p.url().startsWith('http://localhost:5241/'));
  if (!page) throw new Error('Expected Flutter tab at http://localhost:5241/');
  const out = path.resolve(process.argv[3] || 'audit-evidence/reader-settings');
  fs.mkdirSync(out, { recursive: true });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.waitForFunction(() => typeof marianAuditCommand === 'function', null, { timeout: 180000 });
  async function command(action, value) {
    await page.evaluate(([a, v]) => marianAuditCommand(a, v), [action, value]);
    await delay(400);
  }
  const snapshots = [];
  async function capture(name) {
    await page.mouse.move(1, 1);
    await delay(800);
    const state = JSON.parse(await page.evaluate(() => marianAuditCommand('inspect', '')));
    const viewport = page.viewportSize();
    if (Math.abs(state.mediaSize[0] - viewport.width) > 1 || Math.abs(state.mediaSize[1] - viewport.height) > 1) {
      throw new Error(`MediaQuery differs from viewport in ${name}: ${state.mediaSize} vs ${JSON.stringify(viewport)}`);
    }
    await page.screenshot({ path: path.join(out, `${name}.png`) });
    snapshots.push({ name, url: page.url(), ...state });
    console.log(name);
  }
  await page.setViewportSize({ width: 393, height: 852 });
  await command('platform', 'android');
  await command('theme', 'light');
  await command('family', 'literata');
  await command('alignment', 'start');
  await command('psalmody', 'leftBreak');
  await command('route', '/settings');
  await command('collapse', '');
  await delay(1200);
  await capture('after-settings-collapsed-393');
  await command('expand', '');
  await capture('after-settings-expanded-393');
  await command('text', 'Шрыфт чытання');
  let state = JSON.parse(await page.evaluate(() => marianAuditCommand('inspect', '')));
  const fontBounds = state.bounds['settings-reader-font'];
  if (!fontBounds) throw new Error('Font selector bounds missing');
  await page.mouse.click(fontBounds[0] + fontBounds[2] - 20, fontBounds[1] + 30);
  await capture('after-settings-five-fonts-393');
  await page.keyboard.press('Escape');
  for (const family of ['literata', 'sourceSerif4', 'oldStandardTT', 'kurale', 'system']) {
    await command('family', family);
    await command('scroll', '0');
    await capture(`after-font-${family}-393`);
  }
  await command('family', 'literata');
  for (const mode of ['leftBreak', 'leftBreakIndent', 'alternatingStanzas']) {
    await command('psalmody', mode);
    await command('text', 'Псальмодыя');
    await capture(`after-psalmody-${mode}-393`);
  }
  // Bundled Catechism is real reader content, with rich emphasis and references.
  await command('route', '/prayers/compendium/question/1');
  await delay(1000);
  for (const align of ['start', 'justify']) {
    await command('alignment', align);
    await capture(`after-reader-${align}-393`);
  }
  await command('sheet', 'reader');
  await capture('after-sheet-reader-393');
  await command('back', '');
  await command('route', '/hours/ora/2026-02-08/ordinary-w5-d1/laudes?diocese=minsk-mohilev');
  await delay(1800);
  await capture('after-ora-justify-selected-393');
  const oraState = snapshots[snapshots.length - 1];
  if (oraState.texts.some(t => /Дзень не знойдзены|Няма літургічнага дня/.test(t))) throw new Error('Ora must contain real bundled text');
  await command('key', 'app-overflow-open');
  await capture('after-overflow-reader-393');
  await command('back', '');
  await command('sheet', 'ora');
  await capture('after-sheet-ora-393');
  await command('back', '');
  await command('route', '/hours?date=2026-02-08&diocese=minsk-mohilev');
  await command('key', 'app-overflow-open');
  await capture('after-overflow-home-393');
  await command('back', '');
  for (const theme of ['light', 'dark', 'marian']) {
    await command('theme', theme);
    await command('route', '/settings');
    await command('expand', '');
    await capture(`after-theme-${theme}-393`);
    await command('route', '/prayers/compendium/question/1');
    await command('key', 'app-overflow-open');
    await capture(`after-overflow-${theme}-393`);
    await command('back', '');
  }
  for (const width of [360, 320]) {
    await page.setViewportSize({ width, height: 740 });
    await command('scale', '2');
    await command('route', '/settings');
    await command('expand', '');
    await command('scroll', '0');
    await capture(`after-settings-${width}-scale2`);
    await command('route', '/prayers/compendium/question/1');
    await command('sheet', 'reader');
    await capture(`after-sheet-reader-${width}-scale2`);
    await command('back', '');
    await command('route', '/hours/ora/2026-02-08/ordinary-w5-d1/laudes?diocese=minsk-mohilev');
    await command('sheet', 'ora');
    await capture(`after-sheet-ora-${width}-scale2`);
    await command('back', '');
    await command('key', 'app-overflow-open');
    await capture(`after-overflow-${width}-scale2`);
    await command('back', '');
  }
  await page.setViewportSize({ width: 393, height: 852 });
  await command('scale', '1');
  await command('platform', 'ios');
  await command('theme', 'light');
  await command('route', '/settings');
  await command('expand', '');
  await capture('after-ios-adaptation-settings-393');
  await command('sheet', 'ora');
  await capture('after-ios-adaptation-sheet-393');
  await command('back', '');
  await command('platform', 'android');
  await command('theme', 'light');
  await page.setViewportSize({ width: 768, height: 1024 });
  await command('scale', '1');
  await command('route', '/settings');
  await command('collapse', '');
  await command('text', 'Псальмодыя');
  await capture('after-psalmody-wide-768');
  await page.setViewportSize({ width: 393, height: 852 });
  await delay(800);
  await command('alignment', 'justify');
  for (const [label, route] of [
    ['bible', '/bible'],
    ['readings', '/readings?date=2026-02-08&dayId=ordinary-w5-d1&diocese=minsk-mohilev'],
    ['prayerbook', '/prayers/prayer/0I7bXIWkQxoNzI2VunnX'],
    ['mass', '/prayers/prayer/eMmCtxwyJ75ogmL5rwye'],
  ]) {
    await command('route', route);
    await delay(2200);
    await capture(`after-${label}-justify-393`);
    await command('key', 'app-overflow-open');
    await capture(`after-${label}-overflow-393`);
    await command('back', '');
  }
  fs.writeFileSync(path.join(out, 'visual-states.json'), JSON.stringify({ snapshots, errors }, null, 2));
  await browser.close();
})().catch(error => { console.error(error); process.exitCode = 1; });
