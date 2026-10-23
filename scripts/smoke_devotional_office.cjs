// Attach to the Google Chrome instance started by Flutter (no extra browser).
// Requires playwright on NODE_PATH. See docs/devotional-office-reader.md.
const { chromium } = require('playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const base = 'http://localhost:5239/';
const evidence = path.resolve('audit-evidence/devotional-office');
const scratch = process.env.SMOKE_SCRATCH || path.resolve('work/devotional-office');
const ids = [
  'mybrev-devotion-office-for-dead-laudes',
  'mybrev-devotion-office-for-dead-vesper',
  'mybrev-devotion-blessed-virgin-mary-laudes',
  'mybrev-devotion-blessed-virgin-mary-vesper',
  'catholicby-yearcycle-100116',
];
const intentions = ['За аднаго памерлага', 'За адну памерлую', 'За некалькіх', 'За братоў, блізкіх і дабрадзеяў'];
const maryPrayers = ['Агульная', 'Аб прабачэнні', 'Аб выпраўленні жыцця', 'Аб абароне', 'Аб Божай ласцы'];
const errors = [], external = [], rows = [];
let page;
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
async function text() {
  return page.locator('flt-semantics').evaluateAll(es => es.map(e => (e.getAttribute('aria-label') || '') + ' ' + e.textContent).join('\n'));
}
async function scrollTo(locator, y = 100) {
  if (!await locator.count()) {
    await page.mouse.move(150, 500); await page.mouse.wheel(0, -100000); await pause(120);
  }
  for (let i = 0; i < 120; i++) {
    const box = await locator.count() ? await locator.boundingBox() : null;
    if (box && Math.abs(box.y - y) < 8) return;
    const delta = box ? Math.max(-2400, Math.min(2400, box.y - y)) : 600;
    await page.mouse.move(150, 500);
    await page.mouse.wheel(0, delta);
    await pause(80);
    if (box && i > 10 && box.y >= 64 && box.y < 650) return;
  }
  const box = await locator.boundingBox();
  assert(box && box.y >= 64 && box.y < 650, 'Target reachable by reader scrolling');
}
async function load(id, {width = 390, height = 844, theme = 'light', scale = 1, layout = 'alternating', breaks = 0} = {}) {
  await page.setViewportSize({width, height});
  await page.goto(base + '?' + new URLSearchParams({prayer: id, theme, scale, layout, breaks}), {waitUntil: 'domcontentloaded'});
  await page.locator('flt-semantics-placeholder').waitFor({timeout: 30000});
  await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
  await page.getByRole('button', {name: 'Меню', exact: true}).waitFor({timeout: 30000});
  // At 200%, the long original document title can defer the content surface.
  for (let i = 0; i < 6 && !await page.locator('flt-semantics[aria-label^="Тэкст малітвы"]').count(); i++) {
    await page.mouse.move(150, 500); await page.mouse.wheel(0, 600); await pause(150);
  }
  await page.locator('flt-semantics[aria-label^="Тэкст малітвы"]').waitFor({timeout: 30000});
  assert(page.url().startsWith(base), 'Exact local Flutter URL');
  await pause(150);
}
async function choose(label) {
  const chip = page.getByRole('checkbox', {name: label, exact: true});
  await scrollTo(chip, 170);
  await chip.click();
  await pause(150);
  assert.equal(await chip.getAttribute('aria-checked'), 'true', label);
}
async function geometry() {
  const {width} = page.viewportSize();
  const escaped = await page.locator('flt-semantics[role="checkbox"]').evaluateAll((es, width) => es.filter(e => {
    const r = e.getBoundingClientRect(); return r.x < -1 || r.right > width + 1;
  }).map(e => e.getAttribute('aria-label')), width);
  assert.deepEqual(escaped, [], 'Choice labels fit mobile width at current scale');
  assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), 'No horizontal page scroll');
}
async function capture(id, settings, heading, setup) {
  await load(id, settings);
  if (setup) await setup();
  await scrollTo(page.getByText(heading, {exact: true}).first(), 100);
  await pause(200);
  await geometry();
  await page.screenshot({path: path.join(evidence, id + '.png')});
}
(async () => {
  await fs.mkdir(evidence, {recursive: true}); await fs.mkdir(scratch, {recursive: true});
  const browser = await chromium.connectOverCDP(process.env.CDP_URL || 'http://localhost:9222');
  try {
    page = browser.contexts()[0].pages().find(p => p.url().startsWith(base));
    assert(page, 'Use the tab launched by flutter run at localhost:5239');
    const version = await browser.version();
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => {if (m.type() === 'error' || /EXCEPTION CAUGHT|overflowed by/.test(m.text())) errors.push(m.text());});
    // Flutter's default Material fallback font is supplied from the SDK, so
    // acceptance remains offline. The book fonts come from the app bundle.
    const roboto = path.join(process.env.FLUTTER_ROOT, 'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
    await page.route('**/*', route => {
      const url = new URL(route.request().url());
      if (url.hostname === 'localhost' || url.hostname === '127.0.0.1' || ['data:', 'blob:'].includes(url.protocol)) return route.continue();
      if (url.hostname === 'fonts.gstatic.com') return route.fulfill({path: roboto, contentType: 'font/ttf'});
      external.push(url.origin + url.pathname); return route.abort();
    });
    for (const id of ids) {
      let scenario = 0;
      for (const width of [390, 320]) for (const theme of ['light', 'dark']) for (const scale of [1, 2]) {
        const layout = scenario % 2 ? 'aligned' : 'alternating';
        const breaks = Math.floor(scenario / 2) % 2;
        const state = {width, theme, scale, layout, breaks};
        await load(id, state);
        const before = await text();
        assert(!before.includes('Іншыя варыянты частак Гадзіны'), 'Import headings hidden');
        if (id.includes('for-dead')) {
          await scrollTo(page.getByText('Гімн', {exact: true}));
          assert.equal(await page.getByRole('checkbox').count(), 4);
          assert.equal(await page.locator('[role="checkbox"][aria-checked="true"]').count(), 0, 'No default intention');
          const intention = scenario % 4;
          await choose(intentions[intention]);
          const body = await text();
          assert(!body.includes('Абярыце намерэнне перад гімнам'), 'Both dependent sections resolved');
          if (intention === 1) assert(body.includes(id.endsWith('laudes') ? 'Сястры, што спіць у спакоі' : 'Ты пакліч сястру'));
          if (intention === 2) assert(body.includes('(N. і N.)'));
          if (intention === 3) assert(body.includes('нашых родных, сяброў і дабрадзеяў'));
        } else if (id.includes('virgin')) {
          await scrollTo(page.getByText('Просьбы', {exact: true}));
          assert.equal(await page.getByRole('checkbox').count(), 2, 'Two meaningful intercession choices in view');
          await choose(id.endsWith('laudes') ? 'Аб чысціні і нябеснай славе' : 'Аб сям’і і тых, хто ў патрэбе');
          await choose(maryPrayers[scenario % 5]);
          assert(!(await text()).includes('Або іншыя:'), 'Editorial option label hidden');
        } else {
          assert.equal(await page.getByRole('checkbox').count(), 0);
          await scrollTo(page.getByText('Гімн', {exact: true}).first());
          assert(await page.getByText('Гімн', {exact: true}).count() >= 1);
          assert((await text()).includes('Кантар:'));
        }
        await geometry();
        // Reach the compact responsory and then the original final text.
        if (!id.startsWith('catholicby')) await scrollTo(page.getByText('Кароткі рэспансорый', {exact: true}));
        await scrollTo(page.getByText(id.startsWith('catholicby') ? 'Ахвяраванне Гадзінак' : 'Завяршэнне', {exact: true}));
        if (width === 320 && theme === 'dark' && scale === 2 && layout === 'aligned' && breaks === 1) {
          await page.screenshot({path: path.join(scratch, id + '-320-dark-200.png')});
        }
        rows.push({id, ...state, pass: true});
        scenario++;
        console.log(`PASS ${id}: ${JSON.stringify(state)}`);
      }
      console.log(`PASS ${id}: ${scenario} Chrome states`);
    }
    await capture(ids[0], {height: 1200}, 'Гімн', () => choose(intentions[1]));
    await capture(ids[1], {theme: 'dark'}, 'Малітва', () => choose(intentions[2]));
    await capture(ids[2], {theme: 'dark'}, 'Псальм 63 (62), 2-9');
    await capture(ids[3], {}, 'Просьбы', () => choose('Аб сям’і і тых, хто ў патрэбе'));
    await capture(ids[4], {height: 1120}, 'Гімн');
    assert.deepEqual(external, [], 'No remote service calls'); assert.deepEqual(errors, [], 'No JS/Flutter errors');
    const report = {browser: 'Google Chrome ' + version, url: base, timestamp: new Date().toISOString(), source: 'assets/content/prayers.json.gz via decodeContentCollection, public policy checked', states: rows.length, rows, errors, externalRequests: external, fontFallback: 'Roboto-Regular.ttf from installed Flutter SDK; book fonts from unchanged app bundle', nativeSmoke: 'нужен перед мобильным релизом'};
    await fs.writeFile(path.join(evidence, 'chrome-smoke.json'), JSON.stringify(report, null, 2) + '\n');
    console.log(`PASS ${rows.length} states, 5 real Chrome PNG screenshots; zero JS/Flutter errors or remote service calls`);
  } catch (error) {
    if (page) await page.screenshot({path: path.join(scratch, 'failure.png')}).catch(() => {});
    await fs.writeFile(path.join(scratch, 'failure.json'), JSON.stringify({error: String(error), errors, external, completed: rows}, null, 2));
    throw error;
  } finally { await browser.close(); }
})().catch(error => {console.error(error); process.exitCode = 1;});
