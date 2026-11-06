import json,re,subprocess,time,datetime
from pathlib import Path
out=Path('/workspace/pr62-acceptance-results'); root=Path('/workspace/ibreviarybyapp-baseline')
assert (out/'complete').exists()
files=[]
for line in (out/'pr-full.log').read_text().splitlines():
 m=re.search(r'loading /workspace/ibreviarybyapp/(test/[^\s]+\.dart)',line)
 if not m: continue
 if m[1] not in files: files.append(m[1])
 if m[1]=='test/hours_parity_test.dart': break
assert files[-1]=='test/hours_parity_test.dart'
assert all((root/f).exists() for f in files)
args=['/workspace/toolchains/flutter/bin/flutter','test','--no-pub',*files]
record={'name':'main-matching-prefix','sha':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
 'command':args,'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'purpose':'Exact test-file execution prefix of the PR full suite, through and including hours_parity_test. Same environment, default concurrency and timeouts.'}
(out/'main-prefix-files.json').write_text(json.dumps(files,indent=2)+'\n')
(out/'main-prefix-run.json').write_text(json.dumps(record,indent=2)+'\n')
print('START '+json.dumps(record),flush=True)
start=time.monotonic()
with (out/'main-matching-prefix.log').open('w') as stream:
 result=subprocess.run(args,cwd=root,stdout=stream,stderr=subprocess.STDOUT)
record.update(exit_code=result.returncode,elapsed_seconds=round(time.monotonic()-start,3),ended_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(out/'main-prefix-run.json').write_text(json.dumps(record,indent=2)+'\n')
print('END '+json.dumps(record),flush=True)
