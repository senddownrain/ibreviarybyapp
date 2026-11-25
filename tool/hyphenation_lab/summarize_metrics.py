import json,collections,sys
r=json.load(open('out/metrics.json'))
def tab(f,title):
    d=collections.defaultdict(lambda:collections.Counter())
    mx=collections.defaultdict(float)
    for x in r:
        if not f(x): continue
        k=x['mode']; c=d[k]
        c['lines']+=x['lines'];c['bad']+=x['bad'];c['veryLoose']+=x['veryLoose'];c['singleWord']+=x['singleWord'];c['hyph']+=x['hyphenLines'];c['consec']+=x['consecutiveHyphen'];c['cfgs']+=1;c['short']+=x['shortRagged']
        mx[k]=max(mx[k],x['maxStretch'])
    print(title)
    for k in ['A','B1','B2','C','D']:
        c=d[k]; print(f"  {k}: configs={c['cfgs']} lines={c['lines']} bad={c['bad']} ({100*c['bad']/max(c['lines'],1):.0f}%) veryLoose(>2 spaces extra)={c['veryLoose']} single={c['singleWord']} shortRagged={c['short']} hyphLines={c['hyph']} consec={c['consec']} maxStretch={mx[k]:.1f}")
tab(lambda x:x['id'].startswith('sweep_plain'),'PLAIN all')
tab(lambda x:x['id'].startswith('sweep_html'),'HTML all')
tab(lambda x:x['id'].startswith('sweep_plain') and x['scale']==1.8 and x['width']<=360,'PLAIN narrow+180%')
tab(lambda x:x['id'].startswith('sweep_plain') and x['scale']==1.0,'PLAIN 100%')
tab(lambda x:x['id'].startswith('sweep_plain') and x['scale']==1.5,'PLAIN 150%')
for f in ['Literata','SourceSerif4','OldStandardTT','Kurale']:
    tab(lambda x,f=f:x['id'].startswith('sweep_plain') and x['font']==f,'font '+f)
