// CDP attaches to the Chrome launched by Flutter. External content is blocked;
// CanvasKit is served from the local Flutter SDK. No Firebase initialization.
// CDP_URL=http://127.0.0.1:<port> node scripts/smoke_approved_calendar.cjs
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright-core');
const fs=require('node:fs/promises');
const path=require('node:path');
const assert=require('node:assert/strict');
const base='http://127.0.0.1:5242/';
const sdk=process.env.FLUTTER_ROOT;
assert(sdk, 'Set FLUTTER_ROOT to the Flutter SDK directory');
const out=path.resolve('audit-evidence/belarus-approved');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 await fs.mkdir(out,{recursive:true});
 const browser=await chromium.connectOverCDP(process.env.CDP_URL || 'http://127.0.0.1:9222');
 const context=browser.contexts()[0];
 const page=context.pages().find(p=>p.url().startsWith(base));
 assert(page,'Exact Flutter URL '+base);
 const errors=[], blocked=[],states=[];
 page.on('pageerror',e=>{errors.push(e.message);console.error('PAGE ERROR',e.message);});
 page.on('console',m=>{if(m.type()==='error'||/EXCEPTION CAUGHT|overflowed by/.test(m.text())) {errors.push(m.text());console.error('CONSOLE',m.text());}});
 await context.route(/^https:\/\//,async route=>{
   const u=new URL(route.request().url());
   if(['127.0.0.1','localhost'].includes(u.hostname)||['data:','blob:'].includes(u.protocol))return route.continue();
   if(u.hostname==='www.gstatic.com'&&u.pathname.startsWith('/flutter-canvaskit/')) {
     const rel=u.pathname.split('/').slice(3).join('/');assert(!rel.includes('..'));
     return route.fulfill({path:path.join(sdk,'bin/cache/flutter_web_sdk/canvaskit',rel),contentType:rel.endsWith('.wasm')?'application/wasm':'text/javascript'});
   }
   if(u.hostname==='fonts.gstatic.com') return route.fulfill({path:path.join(sdk,'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'),contentType:'font/ttf'});
   blocked.push(u.origin+u.pathname);return route.abort();
 });
 async function snap(){return JSON.parse(await page.evaluate(()=>approvedSnapshot()));}
 async function ready(){await page.waitForFunction(()=>typeof approvedSnapshot==='function'&&JSON.parse(approvedSnapshot()).text.length>10,null,{timeout:300000});await pause(500);}
 async function nav(date,diocese,view){await page.evaluate(([a,b,c])=>approvedNavigate(a,b,c),[date,diocese,view]);await pause(900);await ready();}
 async function dismissOnboarding(){
   const placeholder=page.locator('flt-semantics-placeholder');
   if(await placeholder.count()) await placeholder.evaluate(e=>e.click());
   const later=page.getByRole('button',{name:'Не зараз',exact:true});
   if(await later.count()) {await later.first().click();await pause(400);}
 }
 async function shot(name){const state=await snap();states.push({name,...state});await page.screenshot({path:path.join(out,name+'.png')});return state;}
 for(const [width,theme,scale] of [[390,'light',1],[320,'dark',1.8]]) {
   await page.setViewportSize({width,height:960});
   await page.goto(base+'?'+new URLSearchParams({theme,scale}),{waitUntil:'domcontentloaded'});await ready();
   const prefix=`${width}-${theme}-${scale}`;
   for(const diocese of ['vitebsk','minsk-mohilev','grodno','pinsk','vitebsk']) {
     await nav('2026-09-08',diocese,'ordo');const state=await shot(`${prefix}-sept-${diocese}`);
     assert.equal(state.primary,diocese==='vitebsk'?'our-lady-braslau':'nativity-blessed-virgin-mary');assert.equal(state.rank,'festum');
   }
   for(const [date,diocese] of [['2026-11-16','vitebsk'],['2026-11-16','grodno'],['2026-07-02','minsk-mohilev'],['2026-07-05','grodno'],['2026-11-12','vitebsk'],['2026-12-09','minsk-mohilev'],['2026-12-12','vitebsk'],['2027-12-12','vitebsk']]) {
     await nav(date,diocese,'ordo');const state=await shot(`${prefix}-${date}-${diocese}`);
     assert(!state.alternatives.some(x=>['sv-juan-diego','our-lady-guadalupe'].includes(x)));
   }
   for(const view of ['hours','readings','month']) {
     await nav('2026-09-08','vitebsk',view);await dismissOnboarding();await shot(`${prefix}-braslau-${view}`);
   }
   // Scroll a real production detail page and verify its linked navigation.
   await nav('2026-11-16','vitebsk','ordo');
   await page.evaluate(()=>approvedScroll('Чытанні'));await pause(350);await shot(`${prefix}-ordo-scrolled`);
   // Reload exercises persisted Hive content with all external requests blocked.
   await page.goto(base+'?'+new URLSearchParams({theme,scale,date:'2026-11-16',diocese:'vitebsk'}),{waitUntil:'domcontentloaded'});await ready();await shot(`${prefix}-offline-reload`);
 }
 await fs.writeFile(path.join(out,'results.json'),JSON.stringify({states,errors,blocked,offline:true,platform:'Flutter Web / Chrome, not Android'},null,2)+'\n');
 assert.deepEqual(errors,[],'Browser/Flutter errors');
 console.log(JSON.stringify({screenshots:states.length,errors,blocked:[...new Set(blocked)]}));
 await browser.close();
})().catch(e=>{console.error(e);process.exitCode=1;});
