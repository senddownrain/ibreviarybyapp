"""Check approved brand exports, platform metadata, masks and regeneration.

Run with the pinned branding/toolchain environment from any working directory.
This audits native assets and the optional Flutter Web runner only.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_SOURCE = 'fa8ac6990b67f4a48e5907d00c86aa7306fb44921f079dd5bc92c7bba682a294'
ANDROID = ROOT / 'android/app/src/main/res'
IOS = ROOT / 'ios/Runner/Assets.xcassets'
IVORY = (245, 241, 232)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    inventory_path = ROOT / 'branding/asset-manifest.json'
    inventory_bytes = inventory_path.read_bytes()
    inventory = json.loads(inventory_bytes)
    assert digest(ROOT / 'branding/source/approved-icon.png') == EXPECTED_SOURCE
    assert inventory['approved_source_sha256'] == EXPECTED_SOURCE
    exports = inventory['files']
    for entry in exports:
        assert digest(ROOT / entry['path']) == entry['sha256'], entry['path']

    catalog = json.loads((IOS / 'AppIcon.appiconset/Contents.json').read_text())
    for entry in catalog['images']:
        size = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
        with Image.open(IOS / 'AppIcon.appiconset' / entry['filename']) as image:
            assert image.size == (size, size)
            assert image.mode == 'RGB', entry['filename']
            assert image.getpixel((0, 0)) == IVORY

    foreground = ANDROID / 'drawable-nodpi/ic_launcher_foreground.png'
    with Image.open(foreground) as image:
        assert image.size == (432, 432) and image.mode == 'RGBA'
        bbox = image.getchannel('A').getbbox()
        assert bbox == (86, 86, 346, 346), bbox
        assert all(v >= 84 for v in bbox[:2]) and all(v <= 348 for v in bbox[2:])
    with Image.open(ANDROID / 'drawable-nodpi/ic_launcher_monochrome.png') as image:
        assert image.size == (432, 432) and image.mode == 'RGBA'
        assert image.getchannel('A').getextrema() == (0, 255)
        opaque = [rgba for rgba in image.getdata() if rgba[3] == 255]
        assert opaque and all(rgba[:3] == (255, 255, 255) for rgba in opaque)

    parsed = []
    for pattern in ('drawable*/launch_background.xml', 'mipmap-anydpi*/ic_launcher.xml',
                    'values*/brand_colors.xml', 'values*/styles.xml'):
        for path in sorted(ANDROID.glob(pattern)):
            ET.parse(path)
            parsed.append(path.relative_to(ROOT).as_posix())
    ns = {'a': 'http://schemas.android.com/apk/res/android'}
    adaptive = ET.parse(ANDROID / 'mipmap-anydpi-v33/ic_launcher.xml').getroot()
    assert adaptive.find('monochrome').get('{'+ns['a']+'}drawable') == '@drawable/ic_launcher_monochrome'
    for folder, expected in [('values', '#F2F1EE'), ('values-night', '#0F110F')]:
        colors = ET.parse(ANDROID / folder / 'brand_colors.xml')
        actual = colors.find(".//color[@name='brand_launch_background']").text
        assert actual.upper() == expected
        code = (ROOT / 'lib/theme/ib_colors.dart').read_text()
        assert '0xFF'+expected[1:] in code
    for folder in ('values-v31', 'values-night-v31'):
        items = {x.attrib['name']: x.text for x in ET.parse(ANDROID / folder / 'styles.xml').findall('.//item')}
        assert items['android:windowSplashScreenAnimatedIcon'] == '@drawable/brand_splash_icon'
        assert items['android:windowBackground'] == '@color/brand_launch_background'

    storyboard = ET.parse(ROOT / 'ios/Runner/Base.lproj/LaunchScreen.storyboard')
    assert storyboard.find('.//view/color').attrib['name'] == 'LaunchBackground'
    assert storyboard.find('.//imageView').attrib['image'] == 'LaunchImage'
    for path in IOS.glob('Launch*/Contents.json'):
        json.loads(path.read_text())

    web = json.loads((ROOT / 'web/manifest.json').read_text())
    assert web['start_url'] == '.' and web['display'] == 'standalone'
    for entry in web['icons']:
        with Image.open(ROOT / 'web' / entry['src']) as image:
            size = int(entry['sizes'].split('x')[0])
            assert image.size == (size, size) and image.mode == 'RGB'
            if entry.get('purpose') == 'maskable':
                # Every pixel beyond the central 80% circle is the flat
                # background, so critical artwork survives any native mask.
                pixels = image.load()
                for y in range(size):
                    for x in range(size):
                        if (x + .5 - size/2)**2 + (y + .5 - size/2)**2 > (.4*size)**2:
                            assert pixels[x, y] == IVORY, (entry['src'], x, y)

    subprocess.run([sys.executable, str(ROOT / 'tools/generate_brand_assets.py')], check=True)
    assert inventory_path.read_bytes() == inventory_bytes, 'Regeneration changed the manifest'
    for entry in exports:
        assert digest(ROOT / entry['path']) == entry['sha256'], 'Regeneration changed '+entry['path']
    result = {'approvedSourceSHA256': EXPECTED_SOURCE, 'pngExportCount': len(exports),
              'appIconCount': len(catalog['images']), 'appIconsRGBWithoutAlpha': True,
              'adaptiveAlphaBBox': list(bbox), 'monochromeCutouts': True,
              'maskableSafeZone': True, 'xmlFilesParsed': parsed,
              'splashMatchesCurrentIbColors': True, 'deterministicRegeneration': True}
    (ROOT / 'branding/validation/integration-assets.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
