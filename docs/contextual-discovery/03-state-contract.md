# Contextual Discovery — state contract (Stage 2)

Scope: the engine in `lib/discovery/`. It is **not wired into any production
screen yet** (Stages 3–6 do that). Nothing in the liturgy, resolver, content
or existing Hive boxes is touched. No network, Firebase or analytics code.

## Module map

| File | Role |
|---|---|
| `hint_definition.dart` | `HintDefinition` (stable `id`, `version`, `priority`, `screenId`, `anchorId`, Belarusian copy, `requirements`, `status`, `maxShows`) |
| `hints/p0_hints.dart`, `p1_hints.dart`, `p2_hints.dart` | The 16 catalog IDs of MASTER_SPEC, one file per tier |
| `hint_catalog.dart` | `HintCatalog` registry, rejects duplicate IDs |
| `discovery_context.dart` | Typed input: `DiscoveryContext` (`status` loading/ready/error/unknown, anchors, facts, `DiscoveryUiState`) |
| `hint_eligibility.dart` | `HintPolicy` — pure `decide(...)`, time passed in |
| `discovery_state.dart` | `DiscoveryState`/`HintRecord`, JSON, migration/defaults |
| `discovery_storage.dart` | `DiscoveryStorage`; `HiveDiscoveryStorage`, `MemoryDiscoveryStorage` |
| `discovery_repository.dart` | In-memory state + serialized writes + session counters |
| `discovery_coordinator.dart` | One presenter, one request in flight, count-after-mount |
| `discovery_providers.dart` | Riverpod seams (clock, storage, catalog, presenter, coordinator) |
| `qa/` | Debug-only harness (never imported by the app) |

## Local storage

* Own Hive box **`discovery_v1`** (string box), key **`discovery.v1.state`**,
  one JSON document. The user's `settings`, favourites, prayers, caches and
  priest-access data are never opened, read or written by this module
  (`discovery_storage_test.dart` proves it).
* Schema version is in the box name, the key and the document (`"schema": 1`).

```json
{
  "schema": 1,
  "hintsEnabled": true,
  "tourStatus": "not_offered | declined | completed | skipped | in_progress",
  "sessionCount": 3,
  "autoShownAt": [1793448000000],
  "records": {
    "readings.day_variants": {
      "seenCount": 1, "lastSeenAt": 1793448000000,
      "dismissed": false, "completed": false, "hintVersion": 1,
      "snoozeCount": 0, "snoozedSession": null, "snoozedVisit": null
    }
  }
}
```

* `autoShownAt` — epoch ms of automatic displays, pruned to the last 7 days
  (max 64). Manual displays (tour) never write here.
* No user/device identifier is stored.

### Defaults, migration, bad data

| Situation | Result |
|---|---|
| no / empty / non-JSON / wrong-type document | defaults (hints on, nothing seen) |
| single malformed record | that record skipped, others kept |
| unknown `hint_id` in `records` | kept and written back untouched; ignored by the catalog |
| `schema` > 1 (written by a newer build) | read as defaults, **never written back** (no downgrade damage) |
| storage read/write throws | in-memory state for the session; no exception reaches UI |
| timestamp > now + 1 day (clock moved back) | clamped to now on load (cooldown restarts, no months-long lock) |

Schema changes go through a new `kDiscoverySchema` and a decoder branch;
global Hive migrations are not used.

## Policy (defaults in `DiscoveryPolicyConfig`)

Order of evaluation per hint: hint rules, then shared rules. Highest priority
(P0 > P1 > P2, then catalog order) that passes wins; exactly one hint.

| Rule | Value |
|---|---|
| global `hintsEnabled=false` | silences all automatic hints; survives restart |
| `tourStatus == in_progress` | automatic hints off |
| unknown source (empty `screenId`), wrong screen, data `loading/error/unknown`, missing fact, missing anchor | no-op (`none`) |
| UI busy: scrolling, active reading, dragging, keyboard, modal/sheet open, route/date transition | no-op |
| hints per screen visit | 1 |
| first session (`sessionCount == 1`) | max 2 |
| later sessions | max 3 in a rolling window of 168 absolute hours |
| gap between automatic hints | ≥ 5 min (P2: ≥ 24 h) |
| «Пазней» | ≤ 2 per hint; hidden for the rest of that visit; returns only on a new visit; the 3rd display has no «Пазней» |
| `maxShows` per hint (default 3 = first + 2 repeats) | then silent; a higher `hintVersion` restarts the count |
| «Не паказваць» (`dismissed`) / acted or «Зразумела» (`completed`) | silent until an explicit reset; **`hintVersion++` never revives them** |
| `reduce motion` | not a blocker: the presenter must show without animation (accessibility; deliberate deviation from "перенести") |

A/B/C/D alternatives are separate fact keys (`readings.day_variant_count`,
`readings.allowed_alternative_count`, `readings.other_cycle_loaded`, …); a hint
reads only its own key, counts are never summed.

### `eligible` ≠ `shown`

`DiscoveryCoordinator.request` asks the presenter; `seenCount`, `lastSeenAt`
and the quota stamp are written **only after** `present()` completes with
`true` (overlay really mounted) and the visit is still current. A stale
`visitId`, a visit that ended during `present()`, or a failed mount counts as
nothing.

### Manual tour vs automatic hints

A user-started tour only changes `tourStatus`; it does not call
`recordShown(automatic: true)`, so it spends no quota and un-hides nothing.

### Reset

`DiscoveryRepository.resetHistory()` clears `records` and `autoShownAt` only
(keeps `hintsEnabled`, `tourStatus`, `sessionCount`). Intended for the QA
profile and Stage 6's confirmed «Скінуць падказкі».

## Adding a hint (Stages 3–6) without touching shared code

1. Edit **only your tier file** in `lib/discovery/hints/` (or add a new file
   and include it in `HintCatalog.standard()` — one line).
2. Set `status: HintStatus.deferred` for IDs the Stage 1 matrix does not
   confirm; they stay in the catalog, stable, and never show.
3. In your screen: `final visit = coordinator.beginVisit('<screenId>')`, then
   `coordinator.request(DiscoveryContext(...))` with real anchors/facts when
   the screen is calm; `endVisit` on leave.
4. Supply the real coachmark by overriding `hintPresenterProvider` (one per
   app). Default is `NullHintPresenter`: the engine is inert until then.
5. Report answers with `coordinator.respond(id, HintResponse.…)`.

## Test seams

`DiscoveryClock` (`FakeDiscoveryClock`), `DiscoveryStorage`
(`MemoryDiscoveryStorage`, `HiveDiscoveryStorage(boxName: …)`),
`HintPresenter`, `HintCatalog`, `DiscoveryPolicyConfig` — all Riverpod
providers, overridable in tests and in the QA harness (same production logic).

## QA harness (debug only)

Entry: `flutter run -d <device> -t lib/discovery/qa/discovery_qa_main.dart`.
It uses a separate Hive directory (`discovery_qa`) and box
(`discovery_qa_v1`) — the app's data is never read or erased.

Absent from release because:

1. nothing under `lib/` imports `lib/discovery/qa/` (guarded by
   `test/discovery/qa_isolation_test.dart`), so no release build of the app
   compiles it;
2. the QA `main()` throws in `kReleaseMode`;
3. the harness class names are searched for in the release binaries (see the
   evidence in the Stage 2 report).

Synthetic scenarios exercise the engine only; they are **not** proof that an
alternative is liturgically allowed on a real date.

### 60-second check

See the Stage 2 report: four taps — `Ёсць варыянты` → `Няма варыянтаў` →
`Памылка` (or `Loading`) → `Выключана`; result line shows `readings.day_variants`,
`none`, `none`, `none`; then `Паказаць hint / no-op` → `Не паказваць` →
`Імітаваць перазапуск` keeps `none`.
