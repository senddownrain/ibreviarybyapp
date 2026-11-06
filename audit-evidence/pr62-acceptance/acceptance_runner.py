import subprocess, time, json, hashlib, datetime
from pathlib import Path
root=Path('/workspace/ibreviarybyapp')
baseline=Path('/workspace/ibreviarybyapp-baseline')
out=Path('/workspace/pr62-acceptance-results'); out.mkdir(exist_ok=True)
flutter='/workspace/toolchains/flutter/bin/flutter'
records=[]
def sha(cwd): return subprocess.check_output(['git','rev-parse','HEAD'],cwd=cwd,text=True).strip()
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
manifest={
 'pr_head':sha(root),'main_head':sha(baseline),
 'flutter':subprocess.check_output([flutter,'--version'],text=True),
 'identical_inputs':{f:{'pr':digest(root/f),'main':digest(baseline/f)} for f in [
  'test/content_offline_test.dart','pubspec.lock','lib/content/content_store.dart',
  'lib/content/content_updater.dart','assets/content/manifest.json']},
 'cpu_max':Path('/sys/fs/cgroup/cpu.max').read_text().strip() if Path('/sys/fs/cgroup/cpu.max').exists() else None,
 'execution':'Sequential processes, identical inherited environment, no browser or parallel test command; default timeouts unchanged.',
}
(out/'environment.json').write_text(json.dumps(manifest,indent=2))
def run(name,cwd,args):
 start=time.monotonic()
 record={'name':name,'sha':sha(cwd),'cwd':str(cwd),'command':[flutter,*args],
  'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 print('START '+name+' '+record['sha'],flush=True)
 (out/'current.json').write_text(json.dumps(record,indent=2))
 with (out/(name+'.log')).open('w') as stream:
  result=subprocess.run([flutter,*args],cwd=cwd,stdout=stream,stderr=subprocess.STDOUT)
 record.update(exit_code=result.returncode,elapsed_seconds=round(time.monotonic()-start,3),
  ended_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
 records.append(record)
 (out/'runs.json').write_text(json.dumps(records,indent=2))
 print('END '+name+' '+json.dumps(record),flush=True)
run('main-offline',baseline,['test','--no-pub','test/content_offline_test.dart'])
run('pr-offline',root,['test','--no-pub','test/content_offline_test.dart'])
run('pr-analyze',root,['analyze','--no-pub','--no-fatal-infos'])
run('pr-full',root,['test','--no-pub'])
run('main-calendar',baseline,['test','--no-pub','test/ordo_day_flow_test.dart','test/ordo_ux_test.dart'])
(out/'complete').write_text('All commands completed. Inspect individual exit codes.\n')
