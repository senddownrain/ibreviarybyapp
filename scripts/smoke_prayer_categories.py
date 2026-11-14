"""Inspect the real Flutter Chrome session; synthetic harness only.

python3 scripts/smoke_prayer_categories.py --cdp http://127.0.0.1:<Flutter Chrome port> \
  --flutter-sdk /path/to/flutter
Requires Playwright Python. Does not launch another browser or touch Firebase.
"""
import argparse
import json
import re
from pathlib import Path
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('--cdp', required=True)
parser.add_argument('--flutter-sdk', type=Path, required=True)
parser.add_argument('--resume', action='store_true', help='Retain screenshots from already passed cases')
args = parser.parse_args()
out = Path('audit-evidence/prayer-subcategories')
out.mkdir(parents=True, exist_ok=True)
root_name = 'Штодзённыя малітвы з доўгай назвай катэгорыі'
middle_name = 'Малітвы на кожны дзень'
leaf_name = 'Ранішнія і вячэрнія малітвы'
results = []

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp(args.cdp, timeout=30000)
    context = browser.contexts[0]
    page = next(page for page in context.pages
                if page.url.startswith(('http://localhost:5237/', 'http://0.0.0.0:5237')))
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    cache = args.flutter_sdk / 'bin/cache'

    def local_canvaskit(route):
        # Engine-matched resources already installed by the Flutter SDK.
        suffix = route.request.url.split('/flutter-canvaskit/', 1)[1].split('/', 1)[1]
        candidate = cache / 'flutter_web_sdk/canvaskit' / suffix
        candidate = candidate.resolve()
        assert candidate.is_relative_to((cache / 'flutter_web_sdk/canvaskit').resolve())
        route.fulfill(path=str(candidate), headers={'Access-Control-Allow-Origin': '*'})

    page.route('https://www.gstatic.com/flutter-canvaskit/**', local_canvaskit)
    page.route('https://fonts.gstatic.com/**', lambda route: route.fulfill(
        path=str(cache / 'artifacts/material_fonts/Roboto-Regular.ttf'),
        headers={'Access-Control-Allow-Origin': '*'}))

    def reveal_button(name):
        button = page.get_by_role('button', name=name, exact=True)
        # Flutter ListView lazily builds rows; browser DOM scrolling cannot
        # reveal a row that has not yet entered Flutter's layout/cache extent.
        for _ in range(12):
            if button.count():
                box = button.bounding_box()
                if box and box['y'] >= 100 and box['y'] + box['height'] <= 850:
                    return button
                if box:
                    delta = box['y'] - 200 if box['y'] < 100 else box['y'] + box['height'] - 800
                    page.mouse.move(page.viewport_size['width'] / 2, 650)
                    page.mouse.wheel(0, delta)
                    page.wait_for_timeout(150)
                    continue
            page.mouse.move(page.viewport_size['width'] / 2, 650)
            page.mouse.wheel(0, 400)
            page.wait_for_timeout(120)
        raise AssertionError(f'Button not built: {name}')

    page.set_viewport_size({'width': 375, 'height': 900})
    page.goto('http://localhost:5237/')
    page.wait_for_selector('flt-semantics, flt-semantics-placeholder', state='attached')
    placeholder = page.locator('flt-semantics-placeholder')
    if placeholder.count():
        placeholder.evaluate('(e) => e.click()')
    page.get_by_role('button', name='Theme', exact=True).wait_for()
    root = reveal_button(root_name)
    assert root.get_attribute('aria-expanded') == 'false'
    assert page.get_by_role('button', name=middle_name, exact=True).count() == 0
    current_scale = 1
    for theme in ['light', 'dark', 'marian']:
        page.get_by_role('button', name='Theme', exact=True).click()
        page.get_by_role('menuitem', name=theme, exact=True).click()
        for width in [320, 375, 768]:
            for scale in [1, 2]:
                filename = f'{theme}-{width}-scale{scale}.png'
                if args.resume and (out / filename).exists():
                    results.append({'theme': theme, 'width': width, 'scale': scale,
                                    'screenshot': filename, 'status': 'PASS', 'resumed': True})
                    print(filename, 'PASS (retained)', flush=True)
                    continue
                page.set_viewport_size({'width': width, 'height': 900})
                if current_scale != scale:
                    page.get_by_role('button', name='Text size', exact=True).click()
                    current_scale = scale
                page.mouse.move(width / 2, 500)
                page.mouse.wheel(0, -5000)
                page.wait_for_timeout(200)
                root = reveal_button(root_name)
                if root.get_attribute('aria-expanded') == 'false':
                    root.click()
                middle = reveal_button(middle_name)
                if middle.get_attribute('aria-expanded') == 'false':
                    middle.click()
                leaf = reveal_button(leaf_name)
                page.wait_for_timeout(300)
                assert root.get_attribute('aria-expanded') == 'true'
                assert middle.get_attribute('aria-expanded') == 'true'
                text = page.locator('body').inner_text() + ' '.join(page.locator('[aria-label]').evaluate_all('(es) => es.map(e => e.getAttribute("aria-label"))'))
                assert 'PRIVATE' not in text and 'Empty fixture folder' not in text
                assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
                assert leaf.bounding_box()['width'] >= 48
                filename = f'{theme}-{width}-scale{scale}.png'
                page.screenshot(path=str(out / filename))
                results.append({'theme': theme, 'width': width, 'scale': scale,
                                'url': page.url, 'screenshot': filename, 'status': 'PASS'})
                print(filename, 'PASS', flush=True)

    # Ordinary direct list and the real reader, then the app's Back twice.
    # GoRouter imperative pushes retain the application's existing URL policy.
    root = reveal_button(root_name)
    if root.get_attribute('aria-expanded') == 'false':
        root.click()
    middle = reveal_button(middle_name)
    if middle.get_attribute('aria-expanded') == 'false':
        middle.click()
    page.get_by_role('button', name='Малітвы гэтай катэгорыі', exact=True).click()
    page.get_by_role('button', name=re.compile('^Асобна дададзеная малітва')).wait_for()
    assert page.get_by_role('button', name=re.compile('^Малітва ў падкатэгорыі')).count() == 0
    assert not page.locator('[aria-label*="PRIVATE"]').count()
    page.get_by_role('button', name=re.compile('Назад')).first.click()
    page.mouse.move(350, 400)
    page.wait_for_timeout(250)
    leaf = reveal_button(leaf_name)
    leaf.click()
    page.get_by_role('button', name=re.compile('^Малітва ў падкатэгорыі')).click()
    page.wait_for_function('document.body.innerText.includes("Тэкст у другім узроўні ўкладзенасці.") || [...document.querySelectorAll("[aria-label]")].some(e => (e.getAttribute("aria-label") || "").includes("Тэкст у другім узроўні ўкладзенасці."))')
    page.screenshot(path=str(out / 'reader.png'))
    page.get_by_role('button', name=re.compile('Назад')).first.click()
    page.mouse.move(350, 400)
    page.wait_for_timeout(250)
    page.get_by_role('button', name=re.compile('Назад')).first.click()
    page.mouse.move(350, 400)
    page.wait_for_timeout(250)
    leaf = reveal_button(leaf_name)
    page.screenshot(path=str(out / 'reader-back.png'))
    assert page.get_by_role('button', name=root_name, exact=True).get_attribute('aria-expanded') == 'true'
    assert not errors, errors
    (out / 'results.json').write_text(json.dumps({
        'browser': browser.version, 'cases': results, 'reader_back': 'PASS',
        'direct_only': 'PASS', 'page_errors': errors,
        'back_method': 'Existing in-app Back controls; GoRouter URL policy preserved',
        'resources': 'Engine-matched local SDK CanvasKit and Roboto; external CDN unavailable',
    }, ensure_ascii=False, indent=2) + '\n')
    print('direct-only list / leaf reader / app Back: PASS', flush=True)
