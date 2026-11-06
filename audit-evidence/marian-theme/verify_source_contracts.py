"""Record unchanged domain inputs relative to the tested main."""
from pathlib import Path
import hashlib, json, subprocess
root = Path(__file__).resolve().parents[2]
paths = [
    'pubspec.yaml', 'pubspec.lock', 'lib/router/router.dart',
    'lib/utils/liturgical_theme.dart', 'lib/utils/liturgical_visual.dart',
    'lib/services/liturgical_content_service.dart',
    'lib/models/psalmody_preferences.dart', 'lib/widgets/psalmody_settings_section.dart',
    'lib/theme/reader.dart', 'lib/theme/platform_design.dart',
    'lib/widgets/reader/reader_scaffold.dart', 'lib/widgets/liturgical_day_header.dart',
    'lib/screens/home_screen.dart', 'lib/screens/ordo_month_screen.dart',
    'lib/content/content_store.dart', 'lib/content/content_updater.dart',
    'assets/content/manifest.json',
    'test/hours_parity_test.dart', 'test/support/ordo_fixture.dart',
    'test/fixtures/ordo_parity.json.gz',
]
def git(*args):
    return subprocess.check_output(['git', *args], cwd=root, text=True).strip()
records = []
for path in paths:
    before = git('rev-parse', f'origin/main:{path}')
    after = git('hash-object', path)
    records.append({'path': path, 'main_blob': before, 'branch_blob': after, 'identical': before == after})
assert all(r['identical'] for r in records)
assert not git('diff', '--name-only', 'origin/main', '--', 'assets')
result = {
    'base': git('rev-parse', 'origin/main'),
    'implementation': git('rev-parse', 'HEAD'),
    'all_assets_unchanged': True,
    'domain_and_reader_contracts': records,
    'palette_fixture_sha256': hashlib.sha256((root/'test/support/pre_marian_palette.json').read_bytes()).hexdigest(),
}
(root/'audit-evidence/marian-theme/source-contracts.json').write_text(json.dumps(result, indent=2)+'\n')
print(f'{len(records)} source contracts identical; all assets unchanged')
