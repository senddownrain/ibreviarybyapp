// Actual Chrome launched by flutter run; production router and offline bundle.
const { chromium } = require('playwright-core');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const base = 'http://localhost:5241/';
const out = path.resolve('audit-evidence/doxologies');
const pause = ms => new Promise(r => setTimeout(r, ms));
(async () => {
 fs.mkdirSync(out, {recursive:true});
 let browser;
 for(let tries=0;tries<120;tries++) {
  const args=execFileSync('ps',['-eo','args'],{encoding:'utf8'});
  const port=args.match(/(?:chrome|chromium)[^\n]*--remote-debugging-port=(\d+)/)?.[1];
  if(port)try {
   browser=await chromium.connectOverCDP('http://127.0.0.1:'+port);
   if(browser.contexts()[0].pages().some(p=>p.url().startsWith(base)))break;
  } catch {}
  if(browser){await browser.close();browser=null;}
  await pause(5000);
 }
 assert(browser,'Flutter Chrome did not become ready');
 const page=browser.contexts()[0].pages().find(p=>p.url().startsWith(base));
 const sdk=process.env.FLUTTER_ROOT, errors=[],external=[],states=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error'||/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text())});
 await page.route('**/*',async route=>{
  const u=new URL(route.request().url());
  if(['localhost','127.0.0.1'].includes(u.hostname)||['data:','blob:'].includes(u.protocol))return route.continue();
  if(u.hostname==='fonts.gstatic.com')return route.fulfill({path:path.join(sdk,'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'),contentType:'font/ttf'});
  if(u.hostname==='www.gstatic.com'&&u.pathname.startsWith('/flutter-canvaskit/')){
   const rel=u.pathname.split('/').slice(3).join('/');assert(!rel.includes('..'));
   return route.fulfill({path:path.join(sdk,'bin/cache/flutter_web_sdk/canvaskit',rel),contentType:rel.endsWith('.wasm')?'application/wasm':'text/javascript'});
  }
  external.push(u.origin+u.pathname);return route.abort();
 });
 const jos='12-11-sv-josaphat-minsk-mohilev-pinsk--pinsk';
 const cases=[
  {name:'josaphat-martyr',date:'2026-11-12',dayId:jos,hour:'lectionis'},
  {name:'josaphat-pastors',date:'2026-11-12',dayId:jos+'--pastors',hour:'lectionis'},
  ...['lectionis','terz','sext','non','vespers','completorium'].map(hour=>({name:'dead-'+hour,date:'2026-11-02',dayId:'office-for-dead',hour})),
  {name:'dead-laudes-146',date:'2026-11-02',dayId:'office-for-dead',hour:'laudes',psalm:'душа мая'},
  {name:'dead-laudes-150',date:'2026-11-02',dayId:'office-for-dead',hour:'laudes',psalm:'гукам трубы',alternative:true},
  {name:'ordinary',date:'2026-11-05',dayId:'ordinary-w31-d5',hour:'laudes'},
  {name:'daniel',date:'2026-11-01',dayId:'01-11-all-saints',hour:'laudes',needle:'Благаславім Айца і Сына'},
  {name:'solemnity-I',date:'2026-10-31',dayId:'ordinary-w30-d7',hour:'vespers'},
  {name:'solemnity-II',date:'2026-11-01',dayId:'01-11-all-saints',hour:'vespers'},
 ];
 const scroll=async needle=>{
  await page.waitForFunction(()=>typeof highPriestScrollTo==='function');
  await page.waitForFunction(async n => await highPriestScrollTo(n), needle, {timeout:30000});
  await pause(400);
 };
 try {
  for(const profile of [{width:390,height:844,theme:'light',scale:'normal',mode:'leftBreak'},{width:1280,height:900,theme:'dark',scale:'normal',mode:'alternatingStanzas'},{width:390,height:844,theme:'dark',scale:'large',mode:'leftBreakIndent'}]){
   await page.setViewportSize({width:profile.width,height:profile.height});
   for(const c of cases){
    console.log('Checking',JSON.stringify({...c,...profile}));
    await page.goto(base+'?'+new URLSearchParams({...c,...profile}),{waitUntil:'domcontentloaded'});
    await page.locator('flt-semantics-placeholder').waitFor({timeout:90000});
    await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
    await page.getByRole('button',{name:'Назад',exact:true}).first().waitFor({timeout:90000});
    const dismiss=page.getByRole('button',{name:'Не зараз',exact:true});if(await dismiss.count())await dismiss.first().click();
    if(c.alternative){
     await scroll('@any:Псальм ·');
     await page.getByRole('button',{name:/Выбар псальма/}).last().click();
     await page.getByRole('button',{name:/Псальм 150/}).first().click();
     await pause(400);
    }
    await scroll(c.needle||'Хвала Айцу і Сыну');
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
    await page.screenshot({path:path.join(out,`${profile.width}-${profile.theme}-${profile.scale}-${c.name}.png`)});
    states.push({case:c.name,...profile,url:page.url(),endingReached:true});
   }
  }
  assert.deepEqual(errors,[]);assert.deepEqual(external,[]);
 }catch(e){
  await page.screenshot({path:path.join(out,'failure.png')});
  fs.writeFileSync(path.join(out,'failure-semantics.html'),await page.content());throw e;
 }finally{
  fs.writeFileSync(path.join(out,'results.json'),JSON.stringify({states,errors,external},null,2)+'\n');
  console.log('DOXOLOGY_VISUAL_RESULTS',JSON.stringify({states,errors,external}));
  await browser.close();
 }
 console.log(JSON.stringify({screenshots:states.length,allPassed:true}));
})().catch(e=>{console.error(e);process.exitCode=1});
