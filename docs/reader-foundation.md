# Reader foundation migration

This stage introduces the production long-form reader boundary and migrates
Ora as the first vertical slice. It deliberately does not migrate the shell,
Readings, Prayer Detail, or Bible Chapter.

## Shared contract

- `ReaderScaffold` composes ambient context, floating platform chrome, one
  scrollable document, and safe-area padding.
- `ReaderContentSurface` is an opaque neutral reading surface. It never uses
  `GlassSurface`.
- `ReaderContextHeader` keeps date, celebration, reader title, and contextual
  actions outside the long-form document.
- `ReaderChromeMode` defines `full`, `compact`, and `hidden`.
- `ReaderChromeModeScope` and `ReaderChromeModeController` are the bridge for
  the future AppShell to own reader navigation density.
- `readingsRouteForContext` and `oraRouteForContext` preserve date/day context
  while the current GoRouter structure remains in service.

## Existing component disposition

| Component | Status in this stage | Notes |
| --- | --- | --- |
| `AdaptiveChromeSurface` | KEEP | Platform material boundary for reader controls. |
| `GlassSurface` | KEEP | Still used elsewhere; removed from Ora document/context content. |
| `TextScaleControl` | KEEP | Existing persisted 70–180% reader-size state is reused. |
| `ReadingScaffold` | DEPRECATE LATER | Typography compatibility wrapper remains for unmigrated readers and Ora. |
| `AdaptiveAppBar` | KEEP / REPLACE PER READER | Loading/error compatibility remains; loaded Ora uses `ReaderChrome`. |
| Old reader-specific layouts | DEPRECATE | Migrate individually after Ora; do not remove in this stage. |
| Existing bottom navigation | REMOVE LATER | The four-tab AppShell migration will replace it. |

## Next AppShell stage

The future shell should own one `ReaderChromeModeController` per tab branch,
provide it through `ReaderChromeModeScope`, and render Full/Compact/Hidden
navigation without teaching reader content about iOS glass or Android tonal
Material. It should keep branch navigation stacks and scroll state alive.
