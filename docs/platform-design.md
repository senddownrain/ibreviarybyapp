# iBreviary platform design

> **HISTORICAL platform note (2 October 2026).** Current visual authority:
> [DESIGN_CONCEPT](design/DESIGN_CONCEPT.md) and
> [DESIGN_SYSTEM](design/DESIGN_SYSTEM.md). The content-GlassSurface rule and
> deleted AppBottomNav/ReadingsBottomNav names below describe an earlier design.
> Target: opaque page/modal content, platform material in chrome, one shared
> hierarchy. Keep this note as rationale, not a competing implementation guide.

iBreviary has one content design system and two platform chrome treatments. It
does not maintain separate screen trees for Android and iOS.

## Shared content layer

- Liturgical colours, ambient page washes, reader typography, cards, spacing,
  icons and information architecture are identical on both platforms.
- `GlassSurface` remains a content surface. It must not be used as the default
  implementation of navigation or system controls.
- Pill and circular shapes are part of the iBreviary identity and are shared.

## Platform chrome

`AdaptiveChromeSurface` is the boundary for navigation and control surfaces.

| Area | Android | iOS |
| --- | --- | --- |
| Design basis | Material 3 Expressive / Ambient composition | Cupertino / Liquid Glass |
| Surface | Opaque tonal Material | Translucent blurred glass |
| Top bar | Floating back/menu and action groups; title stays in content hierarchy | Separate glass control groups; title is not placed in a full-width glass slab |
| Bottom controls | Tonal floating navigation with Material selection capsule | Floating glass capsule with subtle selected circle |
| Back affordance | Material back arrow and predictive-back transition | iOS chevron and Cupertino transition |
| Date picker | Calendar dialog | Cupertino wheel in a bottom popup |
| Slider and switch | Material adaptive controls | Cupertino adaptive controls |

## Implementation rules

1. Put shared screen content in the normal widgets and theme.
2. Use `AdaptiveAppBar`, `AdaptiveChromeSurface`, `AppBottomNav` and
   `ReadingsBottomNav` for platform chrome.
3. Detect the platform through `Theme.of(context).platform`, not scattered
   `Platform.isIOS` checks; this keeps previews and widget tests deterministic.
4. Keep content edge-to-edge beneath floating chrome and reserve the exported
   app-bar inset in scroll padding.
5. Add platform branches only for behavior or chrome that users expect to be
   native. Do not duplicate repositories, providers or entire screens.

This division intentionally keeps roughly 80–85% of the UI shared and confines
the platform adaptation to the remaining navigation and control layer.

## Preview without Apple hardware

The visual platform can be selected at compile time without changing normal
application behavior:

```powershell
# iOS / Liquid Glass preview in Chrome
flutter run -d chrome --dart-define=IBREVIARY_PLATFORM=ios

# Android / Ambient Material preview in Chrome
flutter run -d chrome --dart-define=IBREVIARY_PLATFORM=android
```

Use Chrome DevTools device mode with an iPhone-sized viewport such as 390 x 844.
The same flag also works with `-d windows`. The iOS preview covers layout,
surfaces, controls and transitions, but it does not replace a final native test
on an iPhone or an Xcode simulator.
