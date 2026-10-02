# Codex task — iBreviaryBy Flutter: sync Latin Mass V4.1 Belarusian service text

## Model

Use **GPT-6 Sol High**.

## Context

Project: `ibreviarybyapp`.

MyBrev is the canonical side for the Holy Mass content/ritual contract. A focused MyBrev V4.1 migration has replaced the remaining **Russian service/editorial phrases inside the Latin (`la`) Mass** with Belarusian, while leaving the actual Latin liturgical text untouched.

Do not perform a second Firestore migration from Flutter. Do not redesign the Mass UI.

Your task is to synchronize the Flutter semantic contract with the completed MyBrev V4.1 change and verify both old cached and new synced Latin texts.

---

# 1. Inspect canonical MyBrev changes first

Before editing Flutter, inspect the current MyBrev versions of:

- `src/data/mass/order-of-mass.ritual.json`
- `docs/holy-mass.md`
- `docs/holy-mass-comparison.md`
- the V4.1 migration/tests

Determine the exact Russian → Belarusian replacement map actually applied.

Expected replacements include at least:

| Old Russian | New Belarusian |
|---|---|
| `ЧИН МЕССЫ НА ЛАТИНСКОМ ЯЗЫКЕ` | `ПАРАДАК СВЯТОЙ ІМШЫ НА ЛАЦІНСКАЙ МОВЕ` |
| `Исповедание веры` | `Вызнанне веры` |
| `Вторая Евхаристическая молитва` | `II эўхарыстычная малітва` |
| `Или:` | `Альбо:` |
| `После чтения:` | `Пасля чытання:` |
| `(После чтения)` | `(Пасля чытання)` |
| `Евангелие:` | `Евангелле:` |
| `(молитва из Миссала)` | `(малітва з Імшала)` |

Use MyBrev's actual final replacement map as authoritative if it differs or contains additional phrases.

---

# 2. Sync shared ritual metadata from MyBrev

`assets/mass/order-of-mass.ritual.json` should remain the canonical MyBrev file copied byte-for-byte where that is the existing project contract.

If MyBrev changed this JSON:

1. sync/copy the canonical JSON;
2. regenerate `lib/models/mass_ritual_data.dart` using the existing generator;
3. do not hand-edit generated Dart instead of running the generator;
4. verify generated output is clean/idempotent.

New Belarusian LA markers/classifiers should be primary.

Old Russian strings may remain only as legacy fallback markers so Flutter can parse an older cached LA prayer before sync updates it.

Do not render the Russian fallback strings as canonical UI labels.

---

# 3. Compatibility with both old cache and new Firestore text

This is important.

Flutter users may have:

### A. Old cached LA prayer
Containing Russian service phrases such as:

- `Исповедание веры`
- `Вторая Евхаристическая молитва`
- `После чтения:`
- `Евангелие:`
- `Или:`

### B. New synced LA prayer
Containing Belarusian equivalents.

For a transition period, the semantic adapter must correctly parse **both** forms into exactly the same semantic blocks/section IDs.

Add/adjust tests that feed both old-LA and new-LA content and assert equivalent semantic shape.

Do not preserve Russian visually once the newly synced Firestore content is present; compatibility is parser-level only.

---

# 4. Required semantic mapping

Verify new Belarusian service phrases resolve correctly:

- `Вызнанне веры` → `creed`
- `II эўхарыстычная малітва` → `eucharistic-prayer`
- `Пасля чытання:` → first-reading rubric/anchor
- `Евангелле:` → gospel rubric/anchor
- `Альбо:` → alternative
- `ПАРАДАК СВЯТОЙ ІМШЫ НА ЛАЦІНСКАЙ МОВЕ` → ordinary heading

The five major section IDs/titles remain unchanged:

1. `Уступныя абрады`
2. `Літургія слова`
3. `Эўхарыстычная літургія`
4. `Абрад Камуніі`
5. `Заключныя абрады`

`V.` / `R.` roles must remain exactly as before.

Do not change Latin prayer wording.

---

# 5. Data/cache behavior

Inspect how the Latin prayer document is synchronized and cached in Flutter.

Verify:

- after normal sync, the newly migrated Firestore text replaces the old cached version according to the existing sync/version policy;
- no manual cache clear is required for normal users unless the current architecture genuinely cannot detect the update;
- offline users with an old cache still get a functioning Mass reader because legacy Russian aliases remain parseable;
- after the next successful sync, Belarusian service text is displayed.

If a cache invalidation/version bump is actually necessary, implement the smallest compatible mechanism and explain why. Do not globally wipe unrelated content.

---

# 6. Do not redesign the current Mass UI

Preserve the current good V3 UI:

- language selector top right;
- no favorite button on the Mass screen;
- text scale control remains;
- bottom current-section bar;
- full current Belarusian major-section title;
- `n/5`;
- sections bottom sheet;
- global app dock hidden on Mass;
- Android inset solution using `FloatingOverlayPositioned` / shared inset helpers.

This task is content/schema compatibility, not another design pass.

---

# 7. Tests

At minimum add/update tests for:

1. canonical MyBrev ritual JSON parity;
2. generated Dart parity/idempotency;
3. old Russian LA fixture still parses correctly;
4. new Belarusian LA fixture parses to the same semantic shape;
5. `Вызнанне веры` locates `creed`;
6. `II эўхарыстычная малітва` locates `eucharistic-prayer`;
7. `Пасля чытання:` and `Евангелле:` anchors work;
8. `Альбо:` remains an alternative block;
9. `V./R.` dialogue roles are unchanged;
10. current five-section navigation survives language switching;
11. no new Android inset regressions;
12. ordinary prayer behavior remains unchanged.

Run targeted tests plus `flutter analyze`.

If the project has a practical relevant build target available, run it too.

---

# 8. Audit Russian strings

Search the Flutter Mass-specific runtime metadata, fixtures and generated data for the old Russian service phrases.

Classify each remaining occurrence:

- **allowed legacy alias/test fixture** — kept intentionally for old cached content;
- **not allowed runtime canonical/display string** — must be replaced.

The final app should never choose the Russian aliases as canonical displayed service text when it has the migrated LA document.

Do not delete old fixture strings if they are needed to test backward compatibility.

---

# 9. Final report

Report:

- whether the MyBrev ritual JSON changed and was synced byte-for-byte;
- exact Russian → Belarusian map adopted;
- generated files updated;
- how old cached LA and new synced LA are handled;
- any cache/version change required;
- tests/analyze/build results;
- all remaining Russian phrase occurrences and why each is intentionally retained or removed.

If no Flutter code change is required beyond data regeneration/tests, say so and do not invent extra refactors.
