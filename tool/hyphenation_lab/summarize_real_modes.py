"""Summary of out/real_modes.json (real readings; A | AD | B2 | D).
Bad-line shares are judged by the alignment actually in effect, so compare
within a family only: justify (A, B2, and AD's justified paragraphs) or left
(D, and AD's left paragraphs)."""
import json,collections
r=json.load(open('out/real_modes.json'))
def agg(f):
    d=collections.defaultdict(lambda:[0,0,0,0,0])
    for x in r:
        if not f(x): continue
        a=d[x['mode']];a[0]+=x['lines'];a[1]+=x['bad'];a[2]+=x['hyph'];a[3]+=1
        a[4]+=x['lines'] if x['justified'] else 0
    return d
def show(t,f):
    print(t)
    for m in ['A','AD','B2','D']:
        a=agg(f)[m]
        print(f"  {m:>2}: lines={a[0]:>6} bad={a[1]:>6} ({a[1]/a[0]:.1%})  hyphenated={a[2]/a[0]:.1%}  justified-lines={a[4]/a[0]:.0%}")
show('ALL (4 fonts x 4 widths x 3 scales, ~38 real readings)',lambda x:True)
for s in (1.0,1.5,1.8): show(f'scale {s}',lambda x,s=s:x['scale']==s)
show('narrow (<=360) and scale>=1.5',lambda x:x['width']<=360 and x['scale']>=1.5)
for w in (320,360,390,430): show(f'width {w}',lambda x,w=w:x['width']==w)
