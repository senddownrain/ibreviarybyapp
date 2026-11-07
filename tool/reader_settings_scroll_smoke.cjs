// Reuses the real offline Flutter app and its provider; no page/data substitute.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
(async () => {
  const browser = await chromium.connectOverCDP(`http://127.0.0.1:${process.argv[2]}`);
  const page = browser.contexts()[0].pages().find(p => p.url().startsWith('http://localhost:5241/'));
  const out = path.resolve(process.argv[3] || 'audit-evidence/reader-settings');
  const command = async (a, v) => {
    const result = await page.evaluate(([a, v]) => marianAuditCommand(a, v), [a, v]);
    await page.waitForTimeout(500);
    return result;
  };
  const state = async () => JSON.parse(await command('inspect', ''));
  const documentScroll = s => s.scrolls.reduce((a, b) => a[1] > b[1] ? a : b, [0, 0]);
  await page.setViewportSize({ width: 393, height: 852 });
  await command('platform', 'android');
  await command('theme', 'light');
  await command('font', '16');
  await command('family', 'literata');
  await command('route', '/prayers/prayer/0I7bXIWkQxoNzI2VunnX');
  await page.waitForTimeout(1500);
  await command('scroll', '.35');
  const before = await state();
  if (documentScroll(before)[0] <= 0) throw Error('Expected a scrolled real prayer');
  await command('sheet', 'reader');
  await command('family', 'oldStandardTT');
  await command('font', '20');
  await command('alignment', 'justify');
  const during = await state();
  if (Math.abs(documentScroll(during)[0] - documentScroll(before)[0]) > 1) {
    throw Error(`Reader scrolled: ${JSON.stringify([before.scrolls, during.scrolls])}`);
  }
  await page.mouse.move(1, 1);
  await page.screenshot({ path: path.join(out, 'after-live-sheet-reader-font-393.png') });
  await command('back', '');
  const after = await state();
  if (Math.abs(documentScroll(after)[0] - documentScroll(before)[0]) > 1) throw Error('Closing reset the prayer');
  await command('route', '/settings');
  await command('expand', '');
  await command('scroll', '0');
  const settings = await state();
  if (settings.fontFamily !== 'oldStandardTT' || settings.fontSize !== 20) throw Error('Settings and sheet differ');
  await page.screenshot({ path: path.join(out, 'after-live-settings-font-393.png') });
  await command('font', '16');
  await command('family', 'literata');
  fs.writeFileSync(path.join(out, 'scroll-preservation.json'), JSON.stringify({ before, during, after, settings }, null, 2));
  console.log('PASS: real prayer scroll retained through font, size and alignment changes; Settings synchronized');
  await browser.close();
})().catch(error => { console.error(error); process.exitCode = 1; });
