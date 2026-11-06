// Refresh the first long psalm in all themes/modes after the full scene matrix.
const {connect,boot,command,psalmMiddle}=require('./visual-audit.cjs');
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const out=__dirname;
(async()=>{
 const {browser,page}=await connect(Number(process.argv[2]));
 const visual=JSON.parse(fs.readFileSync(path.join(out,'visual-result.json')));
 async function snap(name) {
  await page.waitForTimeout(900);
  const {texts,...state}=JSON.parse(await command(page,'inspect'));
  const mode=name.split('-psalmody-')[1]||'leftBreak';
  if(state.psalmodyMode!==mode)throw Error('Unexpected mode '+name);
  await page.screenshot({path:path.join(out,name+'.png')});
  const index=visual.records.findIndex(r=>r.name===name);
  if(index<0)throw Error('Missing matrix scene '+name);
  visual.records[index]={name,sandbox:'namespace+seccomp-bpf',viewport:page.viewportSize(),...state,textCount:texts.length,textHash:crypto.createHash('sha256').update(JSON.stringify(texts)).digest('hex')};
  fs.writeFileSync(path.join(out,'visual-result.json'),JSON.stringify(visual,null,2));
  console.log(name,state.psalmodyMode);
 }
 for(const platform of ['android','ios'])for(const width of [390,1440]) {
  await boot(page,width,'marian',1,platform);await command(page,'tap','Не зараз');
  await command(page,'tap','Ютрань');await page.waitForTimeout(900);
  const route=JSON.parse(await command(page,'inspect')).route;
  for(const mode of ['leftBreak','leftBreakIndent','alternatingStanzas']) {
   await command(page,'psalmody',mode);await page.waitForTimeout(900);await psalmMiddle(page);
   await snap(`${platform}-${width}-marian-${mode==='leftBreak'?'laudes-middle':'psalmody-'+mode}`);
  }
  await command(page,'psalmody','leftBreak');
  for(const theme of ['light','dark']) {
   await command(page,'theme',theme);await command(page,'route',route);await page.waitForTimeout(900);await psalmMiddle(page);
   await snap(`${platform}-${width}-${theme}-laudes-middle`);
  }
 }
 await browser.close();
})();
