import json
from pathlib import Path
base=Path(__file__).resolve().parent
r=base/'results'
summary={}
for p in sorted(r.glob('*.meta.json')):
 name=p.name.removesuffix('.meta.json'); item={'run':json.loads(p.read_text())}
 ep=r/f'{name}.events.json';rp=r/f'{name}.resources.json'
 if ep.exists():
  events=json.loads(ep.read_text());ends=[e for e in events if e['event']=='test.end']
  if ends:
   end=ends[-1];begin=next(e for e in events if e['event']=='test.begin')
   item.update(testMs=(end['us']-begin['us'])/1000,totals=end['totals'],pendingAtEnd=end['pending'],
    pendingAtTeardown=[e['pending'] for e in events if e['event']=='teardown.begin'],
    deadlineSnapshots=[e for e in events if e['event']=='deadline29'])
 if rp.exists():
  samples=json.loads(rp.read_text());target=[s for s in samples if s.get('target') and 'utime' in s['target']]
  if samples:
   def counters(s):return {k:int(v) for k,v in (line.split() for line in s['cpuStat'].splitlines())}
   c0=counters(samples[0]);c1=counters(samples[-1])
   item['resources']={'samples':len(samples),'cgroupDelta':{k:c1[k]-c0[k] for k in c0},
    'maxTargetRssMiB':max([s['target']['rssPages']*4096/1048576 for s in target],default=0)}
   by_pid={}
   for sample in target:by_pid.setdefault(sample['target']['pid'],[]).append(sample)
   observations=[]
   for pid,rows in by_pid.items():
    a,b=rows[0],rows[-1]
    observations.append({'pid':pid,'sampleCount':len(rows),
     'cpuSeconds':(b['target']['utime']+b['target']['stime']-a['target']['utime']-a['target']['stime'])/100,
     'sampleWallSeconds':b['elapsed']-a['elapsed']})
   item['resources']['perTargetPid']=observations
   if len(observations)==1:
    item['resources'].update(targetCpuSeconds=observations[0]['cpuSeconds'],targetSampleWallSeconds=observations[0]['sampleWallSeconds'])

 summary[name]=item
(base/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
for name,item in summary.items():
 print(name,item['run'].get('exitCode','RUNNING'),item['run'].get('elapsedSeconds'))
