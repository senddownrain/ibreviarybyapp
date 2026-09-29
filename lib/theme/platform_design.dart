import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mybrev_flutter/theme/glass.dart';

/// The platform-specific chrome layered over the shared iBreviary content.
enum AppPlatformDesign { materialAmbient, cupertinoGlass }

/// Compile-time visual preview for machines that cannot run an iOS simulator.
///
/// Example: `--dart-define=IBREVIARY_PLATFORM=ios`. This changes Flutter's
/// widget styling only; it does not pretend to be a native iOS build.
const String _platformPreview = String.fromEnvironment('IBREVIARY_PLATFORM');

TargetPlatform appTargetPlatform() => switch (_platformPreview.toLowerCase()) {
  'ios' => TargetPlatform.iOS,
  'android' => TargetPlatform.android,
  _ => defaultTargetPlatform,
};

bool get isPlatformPreviewEnabled =>
    _platformPreview == 'ios' || _platformPreview == 'android';

AppPlatformDesign platformDesignOf(BuildContext context) {
  return switch (Theme.of(context).platform) {
    TargetPlatform.iOS ||
    TargetPlatform.macOS => AppPlatformDesign.cupertinoGlass,
    _ => AppPlatformDesign.materialAmbient,
  };
}

bool usesCupertinoGlass(BuildContext context) =>
    platformDesignOf(context) == AppPlatformDesign.cupertinoGlass;

enum ChromeSurfaceRole { control, group, navigation }

/// A platform-aware surface used only for navigation and controls.
///
/// iOS receives translucent, blurred glass. Android receives an opaque tonal
/// Material surface, keeping the floating Ambient composition without making
/// Material controls imitate Liquid Glass.
class AdaptiveChromeSurface extends StatelessWidget {
  const AdaptiveChromeSurface({
    super.key,
    required this.child,
    this.seasonColor,
    this.role = ChromeSurfaceRole.control,
    this.borderRadius,
    this.padding,
  });

  final Widget child;
  final Color? seasonColor;
  final ChromeSurfaceRole role;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoGlass(context)) {
      return KeyedSubtree(
        key: const Key('adaptive-chrome-glass'),
        child: GlassSurface(
          style: GlassStyle.pill,
          seasonColor: seasonColor,
          borderRadius: borderRadius ?? _defaultRadius,
          padding: padding,
          child: child,
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final radius = borderRadius ?? _defaultRadius;
    final base = switch (role) {
      ChromeSurfaceRole.control => cs.surfaceContainerHigh,
      ChromeSurfaceRole.group => cs.surfaceContainer,
      ChromeSurfaceRole.navigation => cs.surfaceContainerHigh,
    };
    final fill = seasonColor == null
        ? base
        : Color.alphaBlend(seasonColor!.withValues(alpha: 0.055), base);
    final shadowAlpha = Theme.of(context).brightness == Brightness.dark
        ? 0.20
        : 0.085;

    Widget content = child;
    if (padding != null) content = Padding(padding: padding!, child: content);

    return KeyedSubtree(
      key: const Key('adaptive-chrome-ambient'),
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: radius,
          border: Border.all(color: cs.outlineVariant, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: shadowAlpha),
              blurRadius: role == ChromeSurfaceRole.navigation ? 16 : 10,
              spreadRadius: -3,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: content,
      ),
    );
  }

  BorderRadius get _defaultRadius => BorderRadius.circular(switch (role) {
    ChromeSurfaceRole.control => 24,
    ChromeSurfaceRole.group => 24,
    ChromeSurfaceRole.navigation => 32,
  });
}
