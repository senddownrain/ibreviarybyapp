# Issue #66: reproducible baseline timeout

Outcome: **B — pre-existing main test-fixture CPU sensitivity**, independent of PR #62. See [report](../../docs/issue66-offline-timeout.md) for measurements, negative results and limits. This directory supplements, rather than replaces, [the original acceptance evidence](../pr62-acceptance/).

## Reading the evidence

- `environment.json`: versions, CPU quota, original source backup hashes, identical content inputs, fixed fixture commit.
- `*-original-single.log`: temporary profiling, normal load, both pass. Phase JSON is embedded in `ISSUE66` lines.
- `*-original-load5.log`: same temporary profiling with five bounded CPU workers; both timeout. `deadline29` and `teardown.begin` retain the still-running publication/apply/commit/Hive chain.
- **`main-raw-load5.log`, `pr-raw-load5.log`**: restored original sources, no probes; clean main and original PR both reproduce the 30-second timeout followed by closed-Hive errors. These are the baseline reproduction, not just successful retries.
- `*-fixed-load5.log`: only the per-publication FakeRemote cache applied; both still timeout under the same extreme load. This is deliberately retained as a negative result.
- `*-fixed-whole.log`: identical fixed fixture on main/PR, whole offline file, ordinary load, 38 passed each.
- `*-fixed-prefix.log`: the same ordered first 31 files of the historical full suite, ending with the entire offline file. No extra CPU workers.
- `*.meta.json`: exact command, source HEAD, UTC timestamps, duration, exit code. Later runs also include working-tree paths and test SHA-256. A fixed main run is **main + the test-fixture patch**, not clean main.
- `*.resources.json.gz`: unmodified half-second resource samples, gzip-compressed. First two normal profiled runs have empty arrays because the initial sampler assumed a missing cgroup `cpu.pressure`; their phase timings remain complete. Subsequent sampling uses `/proc/pressure/cpu`.
- `summary.json`: aggregated phase totals, pending Future snapshots and resource summaries. Embedded log phase totals remain the raw source of truth; nested phases overlap and must not be added.
- `validation.*`: additional checks on the committed fixture; no second hour-long full run.

Historical full suite remains **1806 passed / 9 skipped / 8 failed** on d4aba29 (exit 1); it is not a result for the new fixture. The other seven failures and their existing main reproductions remain documented in the acceptance report. No timeouts were raised.

## Repeating the bounded experiment

Use isolated detached checkouts of main `6b74fbe07f949ad5ecc9027cc284471c26e43578` and PR `c78eaf7b903cd048b6e55c8526be96a37e6d1096`, matching Flutter/Dart dependencies and environment. The archived scripts use the original `/workspace/ibreviarybyapp[-baseline]` and `/workspace/issue66-diagnostics` locations; adjust those paths for other checkouts. Never run the instrumentation script over unrelated work: it backs up the three files it temporarily instruments.

1. Copy `probe.dart.txt` to the diagnostics directory as `probe.dart`, plus `instrument.py`, `run.py` and `summarize.py`. Set the Flutter environment (the original runs sourced `/workspace/cloud-setup/env.sh`).
2. On original source checkouts, `python3 instrument.py apply`, then `python3 run.py single` and `python3 run.py load`. Read raw phases, not only pass/fail.
3. `python3 instrument.py restore` restores and verifies byte-exact originals. **Restore before applying the fixture fix.** Run `python3 run.py raw` to reproduce on original main/PR without probes.
4. Apply `fixture-fix.patch` to both original test files. Run `python3 run.py fixed`, then `fixed-whole` and `fixed-prefix` sequentially. The artificial load is five identical Python workers in the same two-core quota, each capped at 120 seconds, stopped when the command finishes. The fixed stress runs can still fail; ordinary whole/prefix runs are the functional verification.
5. `python3 summarize.py` reads phase events/resource samples in the runner's `results` directory. In this archive the duplicate parsed events are omitted to save space; their exact JSON is retained inside the raw `.log` files.

No scripts/probes from this directory are compiled into the app. Temporary patches are evidence only. No production offline content logic, Firestore data or bundle was changed.
