import json,statistics as st,collections,sys
KEY=sys.argv[1] if len(sys.argv)>1 else 'badShare'
r=json.load(open('out/real_threshold.json'))
print('rows',len(r),'texts',len({x['id']+x['field'] for x in r}))
bins=[(0,14),(14,18),(18,22),(22,26),(26,30),(30,34),(34,40),(40,50),(50,70),(70,999)]
print('cpl-bin       n   median-bad  mean-bad  p90-bad  share(bad<=15%)  share(bad<=25%)')
for lo,hi in bins:
    xs=[x[KEY] for x in r if lo<=x['cpl']<hi]
    if not xs: continue
    xs.sort()
    print(f'{lo:>3}-{hi:<4} {len(xs):>7}   {st.median(xs):.2f}       {st.mean(xs):.2f}     {xs[int(.9*len(xs))]:.2f}    {sum(v<=.15 for v in xs)/len(xs):.2f}            {sum(v<=.25 for v in xs)/len(xs):.2f}')
print('\nthreshold T: if cpl>=T justify else left. Justified texts kept vs their mean bad share')
for T in [20,24,26,28,30,32,34,36,40]:
    keep=[x[KEY] for x in r if x['cpl']>=T]
    drop=[x[KEY] for x in r if x['cpl']<T]
    print(f'T={T}: kept {len(keep)/len(r):.0%} mean-bad {st.mean(keep):.3f} p90 {sorted(keep)[int(.9*len(keep))]:.2f} | switched-to-left {len(drop)/len(r):.0%} (their justified mean-bad {st.mean(drop) if drop else 0:.2f})')
print('\nper-config cpl for app sizes (Literata):')
seen=collections.OrderedDict()
for x in r:
    if x['font']=='Literata' and x['width'] in (288,328,358,398) and x['scale'] in (1.0,1.5,1.8):
        seen[(x['width'],x['scale'])]=x['cpl']
for k,v in seen.items(): print(k,v)
