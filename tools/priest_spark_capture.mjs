import http from 'node:http';
import {spawnSync} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
const device=process.env.PRIEST_TEST_DEVICE || 'emulator-5654';
if(!/^emulator-\d+$/.test(device)) throw new Error('An Android emulator is required');
const adb=resolve(process.env.LOCALAPPDATA,'Android/Sdk/platform-tools/adb.exe');
const out=resolve('audit-evidence/priest-spark');mkdirSync(out,{recursive:true});
http.createServer((req,res)=>{
 if(req.method!=='POST'||req.url!=='/screen'){res.writeHead(404).end();return;}
 let name='';req.on('data',data=>name+=data);req.on('end',()=>{
  if(!/^[a-z-]{1,60}$/.test(name)){res.writeHead(400).end();return;}
  const shot=spawnSync(adb,['-s',device,'exec-out','screencap','-p'],{windowsHide:true,maxBuffer:8*1024*1024});
  if(shot.status!==0){res.writeHead(500).end();return;}
  writeFileSync(resolve(out,`${name}.png`),shot.stdout);res.end('ok');
 });
}).listen(8784,'127.0.0.1',()=>console.log('Local Android screenshot helper :8784'));
