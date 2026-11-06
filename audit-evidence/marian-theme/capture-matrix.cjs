const {connect,boot,command}=require('./visual-audit.cjs');
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const out=__dirname;
(async()=>{
 const {browser,page}=await connect(Number(process.argv[2]));
 const previous=process.env.AUDIT_RESUME&&fs.existsSync(path.join(out,'visual-result.json'))?JSON.parse(fs.readFileSync(path.join(out,'visual-result.json'))):{records:[],errors:[]};
 const platforms=(process.env.AUDIT_PLATFORMS||'android,ios').split(',');
 const records=previous.records,errors=previous.errors.filter(e=>!platforms.some(p=>e.scene.startsWith(p+'-')));let scene='boot';
 page.on('pageerror',e=>errors.push({scene,message:e.message}));
 page.on('console',m=>{if(/overflowed|EXCEPTION CAUGHT BY|Error:/i.test(m.text())) errors.push({scene,message:m.text()});});
 const inspect=async()=>JSON.parse(await command(page,'inspect'));
 const pause=()=>page.waitForTimeout(900);
 async function snap(name) {
  scene=name;await pause();
  const state=await inspect();
  await page.bringToFront();
  await page.screenshot({path:path.join(out,`${name}.png`)});
  const {texts,...rest}=state;
  const previous=records.findIndex(r=>r.name===name);if(previous>=0)records.splice(previous,1);
  records.push({name,sandbox:'namespace+seccomp-bpf',viewport:page.viewportSize(),...rest,textCount:texts.length,textHash:crypto.createHash('sha256').update(JSON.stringify(texts)).digest('hex')});
  fs.writeFileSync(path.join(out,'visual-result.json'),JSON.stringify({records,errors},null,2));
  console.log(name,state.route,state.readerSurfaces.join(','));
 }
 async function middle() {
  const state=await inspect();
  const idx=state.texts.findIndex(t=>/^Псальм /.test(t));
  const verses=state.texts.slice(idx+1).filter(t=>t.includes('*')&&t.length>45&&!/ант\.|^Хвала|^Як была/.test(t));
  if(verses.length>3) {
   const result=await command(page,'text',verses[3]);
   if(result!=='ok') throw Error(result);
   return;
  }
  await command(page,'scroll','0.35');
 }
 for(const platform of platforms) for(const width of [390,1440]) {
  const prefix=`${platform}-${width}-marian`;
  await boot(page,width,'marian',1,platform);
  await command(page,'tap','Не зараз');await pause();
  await snap(`${prefix}-home`);
  const opened=await command(page,'tap','Ютрань');if(opened!=='ok')throw Error(opened);
  await pause();
  const laudesRoute=(await inspect()).route;
  console.log('OFFICE_ROUTE',laudesRoute);
  if(!laudesRoute.includes('/laudes'))throw Error('Missing active Office route: '+laudesRoute);
  await snap(`${prefix}-laudes-start`);
  await middle();await snap(`${prefix}-laudes-middle`);
  await command(page,'scroll','1');await snap(`${prefix}-laudes-end`);
  for(const [type,label] of [['vespers','vespers'],['lectionis','lectionis']]) {
   await command(page,'route',laudesRoute.replace('/laudes','/'+type));await pause();
   await snap(`${prefix}-${label}-start`);
   await command(page,'scroll','.5');await snap(`${prefix}-${label}-middle`);
   await command(page,'scroll','1');await snap(`${prefix}-${label}-end`);
  }
  await command(page,'route','/settings');await snap(`${prefix}-settings`);
  if(width===390) {
   await command(page,'tap','Марыйная');await snap(`${prefix}-settings-options`);
   await page.keyboard.press('Escape');await pause();
  }
  await command(page,'route','/hours/ordo/month?date=2026-02-08&diocese=minsk-mohilev');await snap(`${prefix}-calendar`);
  await command(page,'route','/hours?date=2026-02-08&diocese=minsk-mohilev');await pause();
  const dateTap=await command(page,'tap','8 лютага 2026');if(dateTap!=='ok')throw Error(dateTap);
  await snap(`${prefix}-calendar-dialog`);
  await page.keyboard.press('Escape');await pause();
  await command(page,'route','/bible?version=bel&book=gn&chapter=1');await pause();
  await snap(`${prefix}-bible`);
  for(const [name,route] of [
   ['readings','/readings?date=2026-02-08&diocese=minsk-mohilev'],
   ['prayer','/prayers/prayer/AAazUF2ItrRRdPXI5XKU'],
   ['mass','/prayers/prayer/eMmCtxwyJ75ogmL5rwye'],
  ]) {
   await command(page,'route',route);await pause();await snap(`${prefix}-${name}-start`);
   await command(page,'scroll','.5');await snap(`${prefix}-${name}-middle`);
   await command(page,'scroll','1');await snap(`${prefix}-${name}-end`);
  }
  // Compare Marian with the original palettes under the same Flutter geometry.
  for(const theme of ['light','dark']) {
   await command(page,'theme',theme);
   await command(page,'route','/hours?date=2026-02-08&diocese=minsk-mohilev');
   await snap(`${platform}-${width}-${theme}-home`);
   await command(page,'tap','Ютрань');await pause();await middle();
   await snap(`${platform}-${width}-${theme}-laudes-middle`);
   await command(page,'route','/settings');await snap(`${platform}-${width}-${theme}-settings`);
  }
 }
 // A real narrow screen with enlarged application text and maximum reader Aa.
 if(platforms.includes('android')) {
 await boot(page,320,'marian',2,'android');await command(page,'tap','Не зараз');
 await command(page,'route','/settings');await snap('android-320-marian-settings-200');
 await command(page,'tap','Марыйная');await snap('android-320-marian-options-200');
 await page.keyboard.press('Escape');await command(page,'font','28.8');
 await command(page,'route','/hours?date=2026-02-08&diocese=minsk-mohilev');
 await command(page,'tap','Ютрань');await pause();await middle();await snap('android-320-marian-reader-200');
 }
 console.log(JSON.stringify({screenshots:records.length,errors}));
 await browser.close();
})();
