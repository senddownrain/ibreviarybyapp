"""Validate bundled reader fonts with fontTools; write a reproducible inventory.

Run: python tool/audit_reader_fonts.py > audit-evidence/reader-settings/fonts.json
This development check never downloads fonts or changes the application.
"""
import hashlib
import json
from pathlib import Path
from fontTools.ttLib import TTFont

root = Path(__file__).resolve().parents[1]
required = 'ўЎіІёЁ†*'
rows = []
for path in sorted((root / 'assets/google_fonts').glob('*.ttf')):
    font = TTFont(path)
    cmap = font.getBestCmap()
    missing = [c for c in required if ord(c) not in cmap]
    assert not missing, f'{path.name}: missing {missing}'
    rows.append({
        'file': str(path.relative_to(root)),
        'family': font['name'].getDebugName(1),
        'glyphs_checked': required,
        'glyphs_present': True,
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
    })
for name in ['oldstandardtt', 'kurale']:
    assert 'SIL OPEN FONT LICENSE' in (root / f'assets/google_fonts/OFL-{name}.txt').read_text()
print(json.dumps(rows, ensure_ascii=False, indent=2))
