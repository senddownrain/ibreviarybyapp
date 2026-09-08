"""Export public text only. Never reads user data or connects to Firebase."""
import gzip
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ora = (ROOT / 'lib/screens/ora_screen.dart').read_text(encoding='utf-8')
constants = {}
for name in ['StandardIntro', 'InvitIntro', 'Benedictus', 'Magnificat', 'NuncDimittis', 'EndOfSext', 'EndOfComplineBlessing']:
    match = re.search(r'const _k' + name + r'\s*=\s*(.*?);', ora, re.S)
    if match:
        constants[name] = ''.join(re.findall(r"'((?:[^'\\]|\\.)*)'", match[1]))

bible = {}
with gzip.open(ROOT / 'assets/bible_seed_bel.json.gz', 'rt', encoding='utf-8') as f:
    canonical = [b['id'] for b in json.load(f)['books']]
russian_only = {'tob', 'jdt', '1mac', '2mac', 'wis', 'sir', 'bar'}
for language in ['bel', 'ru']:
    with gzip.open(ROOT / f'assets/bible_seed_{language}.json.gz', 'rt', encoding='utf-8') as f:
        books = json.load(f)['books']
    # Seed identifiers differ: ru jn = Jonah, ru jo = John; bel rom = Romans.
    # Same canonical-index rule as BibleRepository.getParallelBook, retaining extra RU books.
    ru_canonical = [b for b in books if b['id'] not in russian_only]
    ids = {b['id'] if language == 'bel' else ('ru-'+b['id'] if b['id'] in russian_only else canonical[ru_canonical.index(b)]): b['id'] for b in books}
    bible[language] = []
    for target_id, source_id in ids.items():
        book = next(b for b in books if b['id'] == source_id)
        chapters = [[{'num': v.get('num', i+1), 'text': v['text']} if isinstance(v, dict) else {'num': i+1, 'text': v} for i, v in enumerate(chapter)] for chapter in book['chapters']]
        bible[language].append({**book, 'id': target_id, 'sourceId': source_id, 'newTestament': books.index(book) >= next(i for i,b in enumerate(books) if b['id']=='mt'), 'chapters': chapters})

# These are public, checked-in liturgical patches in the UX reference project.
reference = ROOT.parent / 'mybrev/patchs/db-feasts'
feasts = {}
for key, filename in [('mary', '08-09-nativity-blessed-virgin-mary.json'), ('peter', '09-09-sv-peter-claver--pastors.json'), ('peterMercy', '09-09-sv-peter-claver--works-of-mercy.json')]:
    raw = json.loads((reference / filename).read_text(encoding='utf-8-sig'))
    feasts[key] = {k: v for k, v in raw.items() if isinstance(v, str) and '<p' in v}

data = {'constants': constants, 'bible': bible, 'feasts': feasts,
        'provenance': {'bible': 'Complete assets/bible_seed_{bel,ru}.json.gz; canonical-index translation mapping from BibleRepository.getParallelBook',
                       'ora': 'lib/screens/ora_screen.dart: shared constants',
                       'feasts': 'mybrev/patchs/db-feasts: 08-09-nativity-blessed-virgin-mary; 09-09-sv-peter-claver--pastors',
                       'calendar': 'Explicit demo fixtures, not a production calendar export',
                       'personal': 'Demo favorites and collections; no real personal data'}}
(OUT / 'fixtures.js').write_text('globalThis.UX_FIXTURES = ' + json.dumps(data, ensure_ascii=False, separators=(',', ':')) + ';\n', encoding='utf-8')
print('Public fixtures exported:', (OUT / 'fixtures.js').stat().st_size, 'bytes')
