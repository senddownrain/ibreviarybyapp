// Attach to the Chromium instance launched by Flutter; no Firebase operations.
// NODE_PATH=<playwright node_modules> CDP_URL=http://localhost:<port> node scripts/smoke_reader_settings.cjs
// flutter run -d chrome -t tool/reader_settings_smoke.dart --web-port 5241 --no-web-resources-cdn
const { chromium } = require('playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const base = 'http://localhost:5241/';
const out = path.resolve('audit-evidence/reader-settings');
const errors = [], rows = [], fontAssets = [];
let page;
const pause = ms => new Promise(r => setTimeout(r, ms));
async function command(action, value = '') {
  return page.evaluate(([a,v]) => window.marianAuditCommand(a,v), [action, value]);
}
async function inspect() { return JSON.parse(await command('inspect')); }
async function capture(name) { await pause(200); await page.screenshot({path:path.join(out, name+'.png')}); }
async function keyRect(key) {
  const state = await inspect();
  const found = Object.entries(state.rects).find(([name]) => name.includes("'"+key+"'"));
  assert(found, 'Key exists: '+key);
  return found[1];
}
async function clickKey(key) {
  const [x,y,w,h] = await keyRect(key); await page.mouse.click(x+w/2,y+h/2); await pause(250);
}
async function load(width, theme='light', platform='android', scale=1) {
  await page.setViewportSize({width,height:852});
  await page.goto(base+'?'+new URLSearchParams({theme,platform,scale}),{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>typeof window.marianAuditCommand==='function');
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await command('route','/settings');await pause(500);
}
async function fontSheet(ora, name) {
  await clickKey('app-overflow-open');
  const [mx,my,mw] = await keyRect('app-overflow-content');
  await page.mouse.click(mx+mw/2,my+32);await pause(650);
  const state=await inspect();
  assert(state.texts.includes('Шрыфт чытання'));
  assert.equal(state.texts.includes('Псальмодыя'),ora);
  assert.equal(state.texts.includes('Выраўноўванне тэксту'),!ora);
  await capture(name);
  await clickKey('text-scale-close');await pause(400);
}
(async()=>{
  await fs.mkdir(out,{recursive:true});
  const browser=await chromium.connectOverCDP(process.env.CDP_URL || 'http://localhost:9222');
  try {
    page=browser.contexts()[0].pages().find(p=>p.url().startsWith(base));
    assert(page,'Use the exact local Flutter tab at '+base);
    // The engine's default UI fonts are external on Web. An optional, real
    // local Roboto avoids the blocked CDN; reader faces always use app assets.
    if(process.env.AUDIT_ROBOTO) await page.route('https://fonts.gstatic.com/**',r=>r.fulfill({path:process.env.AUDIT_ROBOTO,contentType:'font/ttf',headers:{'access-control-allow-origin':'*'}}));
    page.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push({url:page.url(),text:m.text()});});
    page.on('pageerror',e=>errors.push(e.message));
    page.on('response',r=>{if(r.url().includes('/assets/google_fonts/') && r.url().endsWith('.ttf')) fontAssets.push({url:r.url(),status:r.status()});});
    for(const platform of ['android','ios']) for(const theme of ['light','dark','marian']) {
      console.log(platform,theme);
      await load(393,theme,platform);
      await capture(`${platform}-393-${theme}-collapsed`);
      await command('tap','Тэкст');await pause(250);
      await capture(`${platform}-393-${theme}-expanded`);
      await clickKey('settings-reader-font'); await capture(`${platform}-393-${theme}-font-options`); await page.mouse.click(4,100); await pause(400);
      for(const family of ['literata','sourceSerif4','oldStandardTT','kurale','system']) {
        await command('family',family);await pause(150);
        const state=await inspect();assert.equal(state.family,family);
        if(family!=='system') { const preview=state.paragraphs.find(p=>p.text==='Пан — маё святло і маё збаўленне.'); assert(preview && preview.family.toLowerCase().startsWith(family.toLowerCase()),'Actual loaded reader face: '+family); }
        await capture(`${platform}-393-${theme}-font-${family}`);
      }
      // Close Text to show the complete real psalm sample near the top.
      await command('tap','Тэкст');await pause(250);
      await command('family','literata');
      for(const mode of ['leftBreak','leftBreakIndent','alternatingStanzas']) {
        await command('psalmody',mode);await capture(`${platform}-393-${theme}-psalmody-${mode}`);
      }
      await command('route','/hours?date=2026-02-08&diocese=minsk-mohilev');await pause(300);
      await clickKey('app-overflow-open');
      const rect=await keyRect('app-overflow-content');assert(rect[2]<=280);assert(rect[0]>=8);
      await capture(`${platform}-393-${theme}-menu-home`);
      await page.mouse.click(4,100);await pause(400);
      await command('route','/hours/ora/2026-08-27/27-08-sv-monica/laudes?diocese=minsk-mohilev');await pause(500);
      await command('alignment','start');
      for(let i=0;i<50;i++) { const s=await inspect(); if(s.paragraphs.some(p=>p.text.startsWith('Крыніца:'))) break; await pause(150); }
      const before=(await inspect()).paragraphs.map(p=>[p.text,p.align]);
      assert(before.some(([text])=>text.startsWith('Крыніца:')),'Office source footer is ready before comparison');
      await command('alignment','justify');
      assert.deepEqual((await inspect()).paragraphs.map(p=>[p.text,p.align]),before,'Hours stays unchanged');
      await capture(`${platform}-393-${theme}-ora-justify-isolated`);
      await clickKey('app-overflow-open');await capture(`${platform}-393-${theme}-menu-reader`);
      await page.mouse.click(4,100);await pause(400);
      await fontSheet(true,`${platform}-393-${theme}-sheet-ora`);
      await command('route','/bible');await pause(1200);
      for(const alignment of ['start','justify']) {
        await command('alignment',alignment);await capture(`${platform}-393-${theme}-bible-${alignment}`);
        const body=(await inspect()).paragraphs.filter(p=>p.text.length>50);
        assert(body.some(p=>p.align===alignment),'Bible uses '+alignment);
      }
      await fontSheet(false,`${platform}-393-${theme}-sheet-bible`);
      rows.push({platform,theme,width:393,fonts:5,psalmody:3,alignments:2});
    }
    for(const width of [320,360,1440]) {
      await load(width,'marian','android',width===320?2:1);
      await command('tap','Тэкст');await capture(`android-${width}-marian-expanded-scale-${width===320?2:1}`);
      await command('text','Шрыфт чытання'); await clickKey('settings-reader-font'); await capture(`android-${width}-font-options-scale-${width===320?2:1}`); await page.mouse.click(4,100); await pause(150);
      await command('route','/bible');await pause(500);
      await fontSheet(false,`android-${width}-marian-sheet-scale-${width===320?2:1}`);
      await command('route','/hours/ora/2026-08-27/27-08-sv-monica/laudes?diocese=minsk-mohilev');await pause(500);
      await fontSheet(true,`android-${width}-marian-ora-sheet-scale-${width===320?2:1}`);
      rows.push({width,theme:'marian',scale:width===320?2:1});
    }
    assert(fontAssets.some(f=>f.url.includes('OldStandardTT-Regular.ttf') && f.status===200));
    assert(fontAssets.some(f=>f.url.includes('Kurale-Regular.ttf') && f.status===200));
    assert.deepEqual(errors,[]);
  } finally {
    await fs.writeFile(path.join(out,'chrome-results.json'),JSON.stringify({url:base,rows,errors,fontAssets,nativeSmoke:'unavailable; Android/iOS appearance in Flutter Web only'},null,2));
    await browser.close();
  }
})().catch(e=>{console.error(e);process.exitCode=1;});
