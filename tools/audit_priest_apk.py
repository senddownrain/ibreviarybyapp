"""Read-only audit of the canonical prayer assets actually packaged in an APK."""
import gzip
import json
import sys
import zipfile


def decode(data):
    bundle = json.loads(gzip.decompress(data))
    strings = bundle["strings"]
    used_strings = set()

    def resolve(value):
        if isinstance(value, str) and value.startswith("\x01"):
            index = int(value[1:])
            used_strings.add(index)
            return strings[index]
        if isinstance(value, list):
            return [resolve(v) for v in value]
        if isinstance(value, dict):
            return {k: resolve(v) for k, v in value.items()}
        return value

    docs = resolve(bundle["docs"])
    assert used_strings == set(range(len(strings))), "Orphaned strings in public bundle"
    return docs


with zipfile.ZipFile(sys.argv[1]) as apk:
    kernel_name = 'assets/flutter_assets/kernel_blob.bin'
    if kernel_name in apk.namelist():
        kernel = apk.read(kernel_name)
        assert b'native ordinary/priest modes' not in kernel, 'Integration-test APK must not be distributed'
        assert b'PRIVATE-SPARK-SENTINEL' not in kernel, 'Spark integration fixture in APK'
        assert b'secret single' not in kernel, 'Synthetic protected fixture in APK'
    base = "assets/flutter_assets/assets/content/"
    categories = decode(apk.read(base + "prayerCategories.json.gz"))
    prayers = decode(apk.read(base + "prayers.json.gz"))
    manifest = json.loads(apk.read(base + "manifest.json"))
    cleanup = manifest.get("priestCacheCleanup", {})
    assert not set(cleanup.get("protectedPrayerIds", [])).intersection(prayers), "Migrated private prayer in APK"
    assert not set(cleanup.get("protectedCategoryIds", [])).intersection(categories), "Migrated private category in APK"

    def restricted_category(key, visited=frozenset()):
        category = categories.get(key)
        if category is None or key in visited:
            return True
        return category.get("priestOnly") is True or category.get("effectivePriestOnly") is True or (
            bool(category.get("parentId")) and restricted_category(category["parentId"], visited | {key})
        )

    restricted_tags = {tag for key, category in categories.items() if restricted_category(key) for tag in category.get("tags", [])}
    assert not any(restricted_category(key) for key in categories), "Protected category in APK"
    for key, prayer in prayers.items():
        assert not (prayer.get("priestOnly") is True or prayer.get("effectivePriestOnly") is True), f"Protected prayer: {key}"
        assert not restricted_tags.intersection(prayer.get("tags", [])), f"Inherited protected prayer: {key}"
        ids = [prayer.get("categoryId"), *prayer.get("categoryIds", [])]
        assert not any(restricted_category(key) for key in ids if key), "Restricted category membership"
    print(f"APK public-asset audit passed: {len(prayers)} prayers, {len(categories)} categories; no protected documents.")
