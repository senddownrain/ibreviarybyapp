import os,sys,json,time,datetime,subprocess,threading,resource,hashlib
from pathlib import Path
out=Path('/workspace/issue66-diagnostics/results');out.mkdir(exist_ok=True)
flutter='/workspace/toolchains/flutter/bin/flutter'
case='corrections and app releases a new app bundle absorbs the patches it contains'
roots={'main':Path('/workspace/ibreviarybyapp-baseline'),'pr':Path('/workspace/ibreviarybyapp')}

def stats(pid):
 try:
  raw=Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()
  return {'pid':pid,'utime':int(raw[11]),'stime':int(raw[12]),'rssPages':int(raw[21])}
 except (OSError,ValueError,IndexError):return {'pid':pid,'exited':True}

def run(name,branch,whole=False,workers=0,profile=True,prefix=False):
 cwd=roots[branch]; command=[flutter,'test','--no-pub','test/content_offline_test.dart']
 if prefix:
  files=json.loads((roots['pr']/'audit-evidence/pr62-acceptance/main-prefix-files.json').read_text())
  command=[flutter,'test','--no-pub']+files[:files.index('test/content_offline_test.dart')+1]
 elif not whole:command+=['--plain-name',case]
 env=os.environ.copy();env['ISSUE66_PROFILE']='1' if profile else '0'
 record={'name':name,'branch':branch,'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=cwd,text=True).strip(),
  'testSha256':hashlib.sha256((cwd/'test/content_offline_test.dart').read_bytes()).hexdigest(),
  'workingTreeDiff':subprocess.check_output(['git','diff','--name-only'],cwd=cwd,text=True).splitlines(),
  'command':command,'instrumented':profile,'workers':workers,'startedUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
  'cpuMax':Path('/sys/fs/cgroup/cpu.max').read_text().strip(),'clockTicks':os.sysconf('SC_CLK_TCK')}
 (out/(name+'.meta.json')).write_text(json.dumps(record,indent=2)+'\n')
 print('START '+name,flush=True);start=time.monotonic();loads=[];target=None;stop=threading.Event(); samples=[];events=[]
 process=subprocess.Popen(command,cwd=cwd,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
 def sample():
  while not stop.wait(.5):
   sampled_target=target
   if sampled_target is None:
    for entry in Path('/proc').iterdir():
     try:
      if entry.name.isdigit() and (entry/'comm').read_text().strip()=='flutter_tester':
       sampled_target=int(entry.name);break
     except OSError:pass
   samples.append({'elapsed':round(time.monotonic()-start,3),'target':stats(sampled_target) if sampled_target else None,
    'loads':[stats(p.pid) for p in loads],
    'cpuStat':Path('/sys/fs/cgroup/cpu.stat').read_text(),'cpuPressure':Path('/proc/pressure/cpu').read_text() if Path('/proc/pressure/cpu').exists() else None})
 sampler=threading.Thread(target=sample,daemon=True);sampler.start()
 with (out/(name+'.log')).open('w') as stream:
  for line in process.stdout:
   stream.write(line);stream.flush()
   if workers and not profile and not loads and case in line and 'loading ' not in line and '[E]' not in line:
    for _ in range(workers):
     loads.append(subprocess.Popen([sys.executable,'-c',
      'import time\nend=time.monotonic()+120\nwhile time.monotonic()<end:\n sum(i*i for i in range(20000))'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL))
    record['loadStartedElapsed']=round(time.monotonic()-start,3)
   if 'ISSUE66 {' in line:

    try:
     event=json.loads(line[line.index('ISSUE66 ')+8:]);events.append(event)
     if event.get('event')=='test.begin':
      target=event['pid']
      if workers and not loads:
       for _ in range(workers):
        loads.append(subprocess.Popen([sys.executable,'-c',
         'import time\nend=time.monotonic()+120\nwhile time.monotonic()<end:\n sum(i*i for i in range(20000))'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL))
       record['loadStartedElapsed']=round(time.monotonic()-start,3)
    except (ValueError,KeyError):pass
 code=process.wait();stop.set();sampler.join()
 for p in loads:
  if p.poll() is None:p.terminate()
 for p in loads:p.wait()
 record.update(exitCode=code,elapsedSeconds=round(time.monotonic()-start,3),endedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat())
 (out/(name+'.meta.json')).write_text(json.dumps(record,indent=2)+'\n')
 (out/(name+'.events.json')).write_text(json.dumps(events,indent=2)+'\n')
 (out/(name+'.resources.json')).write_text(json.dumps(samples,indent=2)+'\n')
 print('END '+json.dumps(record),flush=True)

if __name__=='__main__':
 task=sys.argv[1]
 if task=='single':
  run('main-original-single','main');run('pr-original-single','pr')
 elif task=='load':
  run('main-original-load5','main',workers=5);run('pr-original-load5','pr',workers=5)
 elif task=='raw':
  run('main-raw-load5','main',workers=5,profile=False);run('pr-raw-load5','pr',workers=5,profile=False)
 elif task=='fixed':
  run('main-fixed-load5','main',workers=5,profile=False);run('pr-fixed-load5','pr',workers=5,profile=False)
 elif task=='fixed-whole':
  run('main-fixed-whole','main',whole=True,profile=False);run('pr-fixed-whole','pr',whole=True,profile=False)
 elif task=='fixed-prefix':
  run('main-fixed-prefix','main',prefix=True,profile=False);run('pr-fixed-prefix','pr',prefix=True,profile=False)
 elif task=='whole':
  run('main-original-whole','main',whole=True);run('pr-original-whole','pr',whole=True)
 else:raise ValueError(task)
