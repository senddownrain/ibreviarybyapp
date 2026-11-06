"""Check captured colors/dimensions and compare original light/dark PNGs."""
import json, math
from pathlib import Path
from PIL import Image, ImageChops
root = Path(__file__).resolve().parent
visual = json.loads((root / 'visual-result.json').read_text())
checks = {'screenshots': len(visual['records']), 'viewports': [], 'reader_surfaces': [], 'paper_pixels': [], 'legacy_png_comparison': []}
for record in visual['records']:
    name = record['name']
    expected_size = [record['viewport']['width'], record['viewport']['height']]
    checks['viewports'].append({'name': name, 'pass': record['mediaSize'] == expected_size})
    if '-marian-' in name and record['readerSurfaces']:
        checks['reader_surfaces'].append({'name': name, 'pass': all(c == 'fffbfdff' for c in record['readerSurfaces'])})
    if '-marian-' in name and any(name.endswith(suffix) for suffix in ['-middle', '-end']):
        image = Image.open(root / (name + '.png')).convert('RGB')
        colors = [image.getpixel((2, y)) for y in [200, 450, 700]]
        checks['paper_pixels'].append({'name': name, 'colors': colors, 'pass': all(c == (251, 253, 255) for c in colors)})
for baseline in sorted((root / 'baseline').glob('*.png')):
    if baseline.stem.endswith('-200'):
        continue
    candidate = root / baseline.name
    a, b = Image.open(baseline).convert('RGB'), Image.open(candidate).convert('RGB')
    exact = a.size == b.size and ImageChops.difference(a, b).getbbox() is None
    checks['legacy_png_comparison'].append({'name': baseline.stem, 'pixel_identical': exact, 'expected_theme_choice_change': baseline.stem.endswith('-settings')})

def luminance(value):
    rgb = [int(value[i:i+2], 16) / 255 for i in (0, 2, 4)]
    linear = [v / 12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    return sum(a*b for a,b in zip(linear, [.2126,.7152,.0722]))
def contrast(a, b):
    x, y = sorted([luminance(a), luminance(b)])
    return (y+.05)/(x+.05)
checks['reader_contrast'] = {name: round(contrast(color, 'FBFDFF'), 3) for name, color in {'ink':'202D39','muted':'52687A','primary':'244D78','rubric':'9B302A'}.items()}
checks['secondary_contrast'] = round(contrast('477DAA','000000'), 3)
checks['psalmody_mode_images'] = [{'name': r['name'], 'mode': r.get('psalmodyMode'), 'pass': r.get('psalmodyMode') == r['name'].split('-psalmody-')[1]} for r in visual['records'] if '-psalmody-' in r['name']]
checks['psalmody_default'] = all(r.get('psalmodyMode') == 'leftBreak' for r in visual['records'] if '-psalmody-' not in r['name'])
checks['console'] = {'widget_messages': visual['errors'], 'debug_transport_message_count': len(visual.get('transportErrors', []))}
checks['source'] = {'flutter_base': '9bf2925f537d648fd29fb87cec2235b98ea80412', 'web_reference': '3aa7ba0f5cd186922d67e4e5e18a980e287a030c'}
(root / 'audit-checks.json').write_text(json.dumps(checks, indent=2) + '\n')
print(json.dumps({
    'screenshots': checks['screenshots'],
    'viewport_failures': [x['name'] for x in checks['viewports'] if not x['pass']],
    'surface_failures': [x['name'] for x in checks['reader_surfaces'] if not x['pass']],
    'paper_failures': [x['name'] for x in checks['paper_pixels'] if not x['pass']],
    'legacy_identical': sum(x['pixel_identical'] for x in checks['legacy_png_comparison']),
    'legacy_total': len(checks['legacy_png_comparison']),
    'contrast': checks['reader_contrast'],
}, indent=2))
assert checks['screenshots'] == 129
assert len({r['name'] for r in visual['records']}) == 129
assert all(r['pass'] for key in ['viewports', 'reader_surfaces', 'paper_pixels', 'psalmody_mode_images'] for r in checks[key])
assert len(checks['psalmody_mode_images']) == 8 and checks['psalmody_default']
assert all(value >= 4.5 for value in checks['reader_contrast'].values())
assert checks['secondary_contrast'] >= 4.5
