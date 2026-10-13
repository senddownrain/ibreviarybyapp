"""Verify artwork pixels and existing identity in an actually built debug APK."""
from pathlib import Path
import argparse
import hashlib
import io
import json
import subprocess
import zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--aapt', type=Path, required=True)
    args = parser.parse_args()
    badging = subprocess.check_output([str(args.aapt), 'dump', 'badging', str(args.apk)], text=True)
    package = next(line for line in badging.splitlines() if line.startswith('package:'))
    label = next(line for line in badging.splitlines() if line.startswith('application-label:'))
    application = next(line for line in badging.splitlines() if line.startswith('application:'))
    assert "name='by.mybrev.playtest2026'" in package
    assert "versionCode='6'" in package and "versionName='1.0.0'" in package
    assert label == "application-label:'MyBrev Test'"
    assert 'mipmap-anydpi-v33/ic_launcher.xml' in application
    compared = []
    with zipfile.ZipFile(args.apk) as archive:
        for name in ('ic_launcher_foreground.png', 'ic_launcher_monochrome.png', 'brand_splash_icon.png'):
            matches = [path for path in archive.namelist() if path.endswith('/'+name)]
            assert len(matches) == 1, (name, matches)
            with Image.open(io.BytesIO(archive.read(matches[0]))) as packaged, Image.open(ROOT / 'android/app/src/main/res/drawable-nodpi' / name) as source:
                assert packaged.size == source.size
                assert packaged.convert('RGBA').tobytes() == source.convert('RGBA').tobytes(), name
            compared.append(matches[0])
    result = {'apkSHA256': hashlib.sha256(args.apk.read_bytes()).hexdigest(),
              'packageBadging': package, 'applicationLabel': label,
              'applicationBadging': application, 'compiledArtworkPixelMatches': compared}
    (ROOT / 'branding/validation/integration-apk.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
