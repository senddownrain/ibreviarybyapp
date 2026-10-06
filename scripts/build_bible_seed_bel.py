#!/usr/bin/env python3
"""Rebuilds assets/bible_seed_bel.json.gz: Old Testament = the bundled
Chernyavski translation (kept byte-for-byte), New Testament = Catholic.by
(27 books, recovered from the seed that preceded commit 19016da).

The Catholic.by text is normalised: chapters/verses whose markup was lost in
the EPUB are split again, section headings and the copyright footer glued to
verse ends are removed, Latin look-alike letters are replaced. NT verses are
stored as {"num", "text"} so verses omitted by the translation (Mt 17:21 …)
keep the canonical numbering. Output is deterministic (gzip mtime 0).

Usage: python3 scripts/build_bible_seed_bel.py  (from the repository root)
"""
import collections, gzip, io, json, os, re, subprocess, sys

ASSET = 'assets/bible_seed_bel.json.gz'
CATHOLIC_BY_REV = '19016da3932bed22709ac250d77393b88bfdd6e6^'
MYBREV_NT = os.path.join('..', 'mybrev', 'scripts', 'bible', 'bible_seed_bel_nt.json.gz')

cur = json.load(gzip.open(ASSET))
old = json.loads(gzip.decompress(subprocess.check_output(['git', 'show', f'{CATHOLIC_BY_REV}:{ASSET}'])))
src_nt = old['books'][next(i for i, b in enumerate(old['books']) if b['id'] == 'mt'):]
assert len(src_nt) == 27
if os.path.exists(MYBREV_NT):  # optional cross-check with the MyBrev copy of the same parse
    assert json.load(gzip.open(MYBREV_NT))['books'] == src_nt, 'Catholic.by sources disagree'
src = {b['id']: b for b in src_nt}
cur_books=cur['books']
nt_start=next(i for i,b in enumerate(cur_books) if b['id']=='mt')
ot=cur_books[:nt_start]; cur_nt=cur_books[nt_start:]
assert [b['id'] for b in cur_nt]==[b['id'] for b in src_nt]
log=collections.defaultdict(list)
FOOTER=re.compile(r'\s*©\s*Канферэнцыя Каталіцкіх Біскупаў у Беларусі, Мінск 2017\s*$')
HEAD=re.compile(r'^(.*[.!?»”…)])\s+([А-ЯЁІЎ][^.;!?«»“”„()\[\]0-9]{1,80}[^\W\d_])$', re.S)
# Verses whose verse marker was lost in the EPUB, split per standard versification.
MANUAL_SPLITS={
 ('1co',15,37):[(36,'Неразумны! Тое, што ты сееш, не ажыве, перш чым не памрэ.'),(37,None)],
 ('acts',8,36):[(36,'Калі яны ехалі па дарозе, наблізіліся да нейкай вады, і еўнух сказаў: «Вось вада. Што перашкаджае мне ахрысціцца?»'),(38,None)],
 ('acts',24,6):[(6,'Ён асмеліўся нават зняважыць святыню, і мы схапілі яго.'),(8,None)],
}
# Section headings phrased as questions (the generic rule only catches headings without final punctuation).
QUESTION_HEADINGS=['Каго баяцца?','Чаму Езус навучае ў прыпавесцях?','Што робіць чалавека нячыстым?','Хто большы?','Каго запрашаць на гасціну?','Хто можа быць вучнем Езуса?']
HOMO=str.maketrans('aocepyxiAOCEPXIKMHTB','аосерухіАОСЕРХІКМНТВ')
def fix_letters(t):
  # Latin look-alike letters inside Belarusian words (EPUB artefacts) break search.
  t=t.replace('нарzzадзіў','нарадзіў')
  def w(m):
    x=m.group()
    if re.search('[А-Яа-яЁёІіЎў]',x) or x in ('a','A','i','I','o','y','c'): return x.translate(HOMO)
    return x
  return re.sub(r'[^\W\d_]+',w,t)
def process(book):
  bid=book['id']
  # 1. split chapters merged because a chapter heading was lost (verse numbering restarts at 1)
  chapters=[]
  for ch in book['chapters']:
    cur_ch=[]
    for v in ch:
      if cur_ch and v['num']<=cur_ch[-1]['num'] and v['num']==1:
        chapters.append(cur_ch); cur_ch=[]; log['chapter split'].append((bid,len(chapters)))
      cur_ch.append(dict(v))
    chapters.append(cur_ch)
  out=[]
  for ci,ch in enumerate(chapters,1):
    res=[]
    for v in ch:
      t=fix_letters(v['text']); n=v['num']
      if t!=v['text']: log['latin look-alikes fixed'].append((bid,ci,n))
      t2=FOOTER.sub('',t)
      if t2!=t: log['footer'].append((bid,ci,n))
      t=t2
      # chapter number + first heading of next chapter glued at a lost chapter break
      t2=re.sub(r'\s+(?:\d+\s+[А-ЯЁІЎ][^.!?]*|[А-ЯЁІЎ][^.!?\d]*\s\d+)$','',t)
      if t2!=t: log['lost chapter heading'].append((bid,ci,n,t[len(t2):].strip())); t=t2
      # inline verse numbers that were not marked up as <sup>
      parts=re.split(r'(?<=[.!?»”])\s+(\d{1,3})(?=[А-ЯЁІЎ«])',t)
      if len(parts)>1:
        res.append({'num':n,'text':parts[0].strip()})
        for k in range(1,len(parts),2):
          res.append({'num':int(parts[k]),'text':parts[k+1].strip()})
        log['inline verse split'].append((bid,ci,n,[int(x) for x in parts[1::2]]))
        continue
      key=(bid,ci,n)
      if key in MANUAL_SPLITS:
        spec=MANUAL_SPLITS[key]; first=spec[0][1]; assert t.startswith(first),key
        res.append({'num':spec[0][0],'text':first}); res.append({'num':spec[1][0],'text':t[len(first):].strip()})
        log['manual split'].append(key); continue
      res.append({'num':n,'text':t})
    # duplicate verse number (Lk 20: 31, 33, 33)
    for i in range(1,len(res)):
      if res[i]['num']==res[i-1]['num'] and (i<2 or res[i-2]['num']==res[i-1]['num']-2):
        log['duplicate number fixed'].append((bid,ci,res[i-1]['num'],res[i-1]['num']-1)); res[i-1]['num']-=1
    out.append(res)
  # 2. section headings glued to the end of the preceding verse
  flat=[v for ch in out for v in ch]
  for i,v in enumerate(flat):
    nxt=flat[i+1]['text'] if i+1<len(flat) else ''
    if re.match(r'[a-zа-яёіў]',nxt): continue
    m=HEAD.match(v['text'])
    if not m:
      for q in QUESTION_HEADINGS:
        if v['text'].endswith(' '+q) and re.search(r'[.!?»”]$',v['text'][:-len(q)-1]):
          log['heading stripped'].append((bid,v['num'],q)); log['question heading'].append((bid,v['num'],q))
          v['text']=v['text'][:-len(q)-1]
      continue
    log['heading stripped'].append((bid,v['num'],m.group(2)))
    v['text']=m.group(1)
  return out
new_nt=[]
for cb in cur_nt:
  chapters=process(src[cb['id']])
  new_nt.append({'id':cb['id'],'name':cb['name'],'order':cb['order'],'chapters':chapters})
data={'books':ot+new_nt}
# validation
for b,cb in zip(new_nt,cur_nt):
  assert len(b['chapters'])==len(cb['chapters']),(b['id'],len(b['chapters']),len(cb['chapters']))
  for ci,ch in enumerate(b['chapters'],1):
    nums=[v['num'] for v in ch]
    assert nums==sorted(set(nums)),(b['id'],ci,nums)
    assert nums[0]==1,(b['id'],ci)
    assert all(v['text'] for v in ch),(b['id'],ci)
    gaps=sorted(set(range(1,nums[-1]+1))-set(nums))
    if gaps: log['omitted verses (textual tradition)'].append((b['id'],ci,gaps))
    if nums[-1]!=len(cb['chapters'][ci-1]): log['last verse differs from Chernyavski'].append((b['id'],ci,nums[-1],len(cb['chapters'][ci-1])))
assert not any(re.search('[A-Za-z]',v['text']) for b in new_nt for ch in b['chapters'] for v in ch), 'latin letters left in NT'
assert ot==cur_books[:nt_start]
raw=json.dumps(data,ensure_ascii=False).encode()
buf=io.BytesIO()
with gzip.GzipFile(filename='',mode='wb',fileobj=buf,compresslevel=9,mtime=0) as g: g.write(raw)
open(sys.argv[1] if len(sys.argv) > 1 else ASSET,'wb').write(buf.getvalue())
for k,v in log.items():
  print(f'== {k}: {len(v)}')
  if k not in ('heading stripped', 'footer', 'latin look-alikes fixed'):
    for x in v: print('  ', x)
