const {chromium}=require('playwright');
const fs=require('fs');
const path=require('path');
const out=process.env.AUDIT_OUTPUT_DIR||__dirname;
const base=process.env.AUDIT_BASE_URL||'http://localhost:5241';
const sdk='/workspace/toolchains/flutter/bin/cache/flutter_web_sdk/canvaskit';
async function connect(port) {
 const browser=await chromium.connectOverCDP(`http://localhost:${port}`);
 const context=browser.contexts()[0];
 await context.route('**/*', async route=>{
  const url=new URL(route.request().url());
  if(['localhost','127.0.0.1'].includes(url.hostname)) return route.continue();
  if(url.pathname.includes('flutter-canvaskit/')) {
   const relative=url.pathname.split('/').slice(3).join('/');
   const file=path.join(sdk, relative);
   if(fs.existsSync(file)) return route.fulfill({body:fs.readFileSync(file),contentType:file.endsWith('.js')?'application/javascript':'application/wasm',headers:{'Access-Control-Allow-Origin':'*'}});
  }
  if(url.hostname==='fonts.gstatic.com') {
   return route.fulfill({body:fs.readFileSync('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'),contentType:'font/ttf',headers:{'Access-Control-Allow-Origin':'*'}});
  }
  return route.abort();
 });
 const pages=context.pages().filter(p=>p.url().startsWith(base));
 const page=pages.find(p=>p.url().includes('?theme='))||pages[0];
 // Restored audit tabs can hold IndexedDB locks across preview runs.
 for(const other of context.pages()) if(other!==page) await other.close();
 await page.bringToFront();
 return {browser,context,page};
}
async function command(page,action,value='') {
 return page.evaluate(async ({action,value})=>await window.marianAuditCommand(action,value),{action,value});
}
async function boot(page,width=390,theme='marian',scale=1,platform='android') {
 const session=await page.context().newCDPSession(page);
 await session.send('HeapProfiler.collectGarbage');await session.detach();
 await page.setViewportSize({width,height:900});
 await page.goto(`${base}/?theme=${theme}&scale=${scale}&platform=${platform}`,{waitUntil:'domcontentloaded',timeout:90000});
 // A manually reloaded Flutter debug tab can wait for the DWDS debugger.
 // Start its registered entrypoint once when no debugger has started it.
 await page.waitForFunction(()=>(typeof window.$dartRunMain==='function'&&window.$dartMainTearOffs?.length>0)||typeof window.marianAuditCommand==='function',null,{timeout:90000});
 await page.waitForTimeout(1000);
 await page.evaluate(()=>{if(!window.$dartMainExecuted&&window.$dartRunMain)window.$dartRunMain();});
 await page.waitForFunction(()=>typeof window.marianAuditCommand==='function',null,{timeout:90000});
 await page.bringToFront();
 await command(page,'psalmody','leftBreak');
 await command(page,'font','16');
 await page.waitForTimeout(1200);
}
async function psalmMiddle(page) {
 const state=JSON.parse(await command(page,'inspect'));
 const verse=state.texts.find(t=>t.includes('Душа мая насычаецца'));
 if(!verse) throw Error('Missing verse from the first long psalm');
 const result=await command(page,'text',verse);
 if(result!=='ok') throw Error(result);
}
module.exports={connect,command,boot,psalmMiddle};
if(require.main===module) (async()=>{
 const {browser,page}=await connect(Number(process.argv[2]||32769));
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await boot(page);
 const result=JSON.parse(await command(page,'inspect'));
 console.log(JSON.stringify(result).slice(0,2500));
 await page.screenshot({path:path.join(out,'android-390-marian-home.png')});
 console.log({errors});
 await browser.close();
})();
