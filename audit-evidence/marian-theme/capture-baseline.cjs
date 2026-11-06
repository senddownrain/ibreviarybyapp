const {connect,boot,command}=require('./visual-audit.cjs');
const fs=require('fs'),path=require('path'),crypto=require('crypto');
(async()=>{
 const {browser,page}=await connect(Number(process.argv[2]));
 const out=process.env.AUDIT_OUTPUT_DIR;fs.mkdirSync(out,{recursive:true});
 const records=process.env.AUDIT_RESUME && fs.existsSync(path.join(out,'visual-result.json'))?JSON.parse(fs.readFileSync(path.join(out,'visual-result.json'))):[],errors=[];
 page.on('console',m=>{if(/overflowed|EXCEPTION CAUGHT BY/i.test(m.text()))errors.push(m.text());});
 async function snap(name) {
  await page.waitForTimeout(900);
  const {texts,...state}=JSON.parse(await command(page,'inspect'));
  await page.bringToFront();
  await page.screenshot({path:path.join(out,name+'.png'), timeout:90000});
  const previous=records.findIndex(r=>r.name===name);if(previous>=0)records.splice(previous,1);
  records.push({name,...state,textCount:texts.length,textHash:crypto.createHash('sha256').update(JSON.stringify(texts)).digest('hex')});
  fs.writeFileSync(path.join(out,'visual-result.json'),JSON.stringify(records,null,2));
  console.log(name);
 }
 for(const platform of (process.env.AUDIT_PLATFORMS||'android,ios').split(','))for(const width of [390,1440])for(const theme of ['light','dark']) {
  await boot(page,width,theme,1,platform);await command(page,'tap','Не зараз');
  const prefix=`${platform}-${width}-${theme}`;
  await snap(prefix+'-home');
  await command(page,'tap','Ютрань');await page.waitForTimeout(900);
  const state=JSON.parse(await command(page,'inspect'));
  const idx=state.texts.findIndex(t=>/^Псальм /.test(t));
  const verses=state.texts.slice(idx+1).filter(t=>t.includes('*')&&t.length>45&&!/ант\.|^Хвала|^Як была/.test(t));
  if(verses.length>3)await command(page,'text',verses[3]);else await command(page,'scroll','.35');
  await snap(prefix+'-laudes-middle');
  await command(page,'route','/settings');await snap(prefix+'-settings');
 }
 await boot(page,320,'light',2,'android');await command(page,'tap','Не зараз');
 await command(page,'route','/settings');await snap('android-320-light-settings-200');
 fs.writeFileSync(path.join(out,'errors.json'),JSON.stringify(errors,null,2));
 await browser.close();
})();
