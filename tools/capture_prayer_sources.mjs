import {createRequire} from 'node:module';import fs from 'node:fs/promises';import assert from 'node:assert/strict';
const {chromium}=createRequire(process.env.PLAYWRIGHT_PACKAGE || new URL('../../mybrev/package.json', import.meta.url))('playwright-core');
const cdp=process.env.FLUTTER_CDP_URL;
if(!cdp || !['127.0.0.1','localhost'].includes(new URL(cdp).hostname))throw Error('FLUTTER_CDP_URL must identify the locally launched Chrome debug port');
if(!process.env.FLUTTER_ROOT || !process.env.SMOKE_ROBOTO)throw Error('FLUTTER_ROOT and cached SMOKE_ROBOTO font are required for offline rendering');
const browser=await chromium.connectOverCDP(cdp);const context=browser.contexts()[0],page=context.pages().find(p=>p.url().startsWith('http://127.0.0.1:5237'));
const output=process.env.SOURCE_EVIDENCE_DIR || 'audit-evidence/prayer-sources';await fs.mkdir(output,{recursive:true});
const blocked=[],errors=[];page.on('pageerror',e=>errors.push(e.message));
await context.route('**/*',async route=>{const url=new URL(route.request().url());if(url.origin==='http://127.0.0.1:5237')return route.continue();
if(url.hostname==='www.gstatic.com'&&url.pathname.includes('/flutter-canvaskit/')){const suffix=url.pathname.split('/e4b8dca3f1b4ede4c30371002441c88c12187ed6/')[1];if(suffix&&/^(chromium\/)?canvaskit\.(js|wasm)$/.test(suffix))return route.fulfill({path:process.env.FLUTTER_ROOT+'/bin/cache/flutter_web_sdk/canvaskit/'+suffix,contentType:suffix.endsWith('.js')?'application/javascript':'application/wasm',headers:{'access-control-allow-origin':'*'}});}
if(url.hostname==='fonts.gstatic.com')return route.fulfill({path:process.env.SMOKE_ROBOTO,contentType:'font/woff2',headers:{'access-control-allow-origin':'*'}});blocked.push(url.origin);return route.abort();});
const semantics=()=>page.locator('flt-semantics').evaluateAll(es=>es.map(e=>(e.getAttribute('aria-label')||'')+' '+e.textContent).join('\n'));
const rows=[];
try{for(const office of [false,true])for(const dark of [false,true]){
 const width=390,scale=dark?2:1,name=`${office?'office':'ordinary'}-${dark?'dark-200':'light'}-390`;
 await page.setViewportSize({width,height:844});await page.goto(`http://127.0.0.1:5237/?office=${office?1:0}&theme=${dark?'dark':'light'}&scale=${scale}`);await page.waitForTimeout(1500);
 await page.locator('flt-semantics-placeholder').evaluateAll(es=>{for(const e of es)e.dispatchEvent(new MouseEvent('click',{bubbles:true}));});
 await page.waitForFunction(()=>{const root=document.querySelector('flutter-view');return !!root;});await page.waitForTimeout(600);
 await page.screenshot({path:`${output}/${name}-top.jpg`,type:'jpeg',quality:75});
 if(office){await page.mouse.move(200,650);await page.mouse.wheel(0,100000);await page.waitForTimeout(700);}
 const text=await semantics(),source=office?'Літургія гадзін':'Бог добры';assert.ok(text.includes('Крыніца: '+source),text.slice(-500));
 if(!office)assert.ok(text.includes('Пс 23, 1–6. Ян 3, 16'));
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 await page.screenshot({path:`${output}/${name}-source.jpg`,type:'jpeg',quality:75});
 rows.push({office,dark,width,scale,source,scripturePreserved:office?null:true,horizontalOverflow:false,url:page.url()});
 if(!office&&!dark){const link=page.getByText('Іншая малітва',{exact:true}).first();assert.ok(await link.count());await link.click();await page.waitForTimeout(500);assert.ok((await semantics()).includes('Крыніца: Рымскі Імшал'));rows.at(-1).linkNavigation=true;}
 }
 assert.deepEqual(errors,[]);await fs.writeFile(output+'/visual.json',JSON.stringify({browser:await browser.version(),fixture:'tool/prayer_source_smoke.dart',rows,errors,blocked:[...new Set(blocked)],productionFirestoreRequests:0,canvasKit:'Local SDK engine e4b8dca3f1b4ede4c30371002441c88c12187ed6',font:'Cached engine bootstrap Roboto; no external app requests'},null,2));console.log(rows);
}finally{await browser.close()}
