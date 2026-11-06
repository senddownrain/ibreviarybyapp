#!/usr/bin/env python3
"""Verify the pinned import offline; optionally compare a checked-out Web tree.

python3 scripts/check_web_source_import.py [--web-root ../mybrev-reference]
Updating the lock is an intentional review step, never an automatic operation.
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--web-root', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
lock = json.loads((root / 'docs/sources/web-import-lock.json').read_text())
assert lock['commit'] == '33577e1fb265b02160a5e6d94cfc83a8df15b9a3'
assert [e['flutter'] for e in lock['files']] == ['assets/legal/sources.json']
if args.web_root:
    head = subprocess.check_output(
        ['git', '-C', str(args.web_root), 'rev-parse', 'HEAD'], text=True).strip()
    assert head == lock['commit'], f'Unexpected Web HEAD: {head}'
for entry in lock['files'] + lock['bibleCorpora']:
    data = (root / entry['flutter']).read_bytes()
    assert hashlib.sha256(data).hexdigest() == entry['sha256'], entry['flutter']
    if args.web_root:
        upstream = (args.web_root / entry['web']).read_bytes()
        if entry in lock['bibleCorpora']:
            assert json.loads(gzip.decompress(data)) == json.loads(
                gzip.decompress(upstream)), entry['flutter']
        else:
            assert data == upstream, entry['flutter']
print('PASS: local rights registry matches Web PR #192; two Bible corpora unchanged')
