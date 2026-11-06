import datetime,json,subprocess,time
from pathlib import Path
root=Path('/workspace/ibreviarybyapp');out=Path('/workspace/issue66-diagnostics')
commands=[['/workspace/toolchains/flutter/bin/dart','format','--output=none','--set-exit-if-changed','.'],['/workspace/toolchains/flutter/bin/flutter','analyze','--no-pub','--no-fatal-infos'],['/workspace/toolchains/flutter/bin/flutter','test','--no-pub','test/ordo_content_update_test.dart','test/psalmody_preferences_test.dart']]
records=[]
for index,command in enumerate(commands):
 record={'command':command,'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'startedUtc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 start=time.monotonic()
 with (out/f'validation.{index}.log').open('w') as log:result=subprocess.run(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
 record.update(exitCode=result.returncode,elapsedSeconds=round(time.monotonic()-start,3),endedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat());records.append(record)
 (out/'validation.json').write_text(json.dumps(records,indent=2)+'\n');print(json.dumps(record),flush=True)
