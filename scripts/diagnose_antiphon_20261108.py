#!/usr/bin/env python3
"""Read-only diagnostic of the shipped Flutter bundle for 2026-11-08.

Shows only Office antiphon fields and source metadata for Ordinary Time XXXII
Sunday. Never connects to Firestore or writes to the content bundle.
"""
import gzip
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets" / "content"
REF = "\x01"

def read_collection(name):
    payload = json.loads(gzip.decompress((ROOT / f"{name}.json.gz").read_bytes()))
    strings = payload["strings"]
    def decode(value):
        if isinstance(value, str) and value.startswith(REF):
            return strings[int(value[1:])]
        if isinstance(value, dict):
            return {key: decode(item) for key, item in value.items()}
        if isinstance(value, list):
            return [decode(item) for item in value]
        return value
    return {key: decode(val) for key, val in payload["docs"].items()}

def preview(val):
    if not isinstance(val, str):
        return repr(val)[:500]
    plain = re.sub(r"<[^>]+>", " ", val)
    plain = re.sub(r"\s+", " ", plain).strip()
    return f"html={val[:1800]!r}; visible={plain[:1000]!r}"

if __name__ == "__main__":
    for collection in ("days", "liturgicalProperTexts", "liturgicalTemplates"):
        docs = read_collection(collection)
        exact = sorted(key for key in docs if "ordinary-w32-d1" in key.lower() or "sunday-week-4" in key.lower())
        print(f"{collection}: {len(docs)} total; relevant ids={exact}")
        for key in exact:
            doc = docs[key]
            print("  DOCUMENT", key)
            for field in ("laudesAntBen", "vesperAntMag", "_fieldRules", "_commonBase", "_templates", "_periodType", "_rank"):
                if field in doc:
                    print("  ", field, preview(doc[field]))
