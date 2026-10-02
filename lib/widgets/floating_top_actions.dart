import 'package:flutter/material.dart';

import 'package:mybrev_flutter/theme/platform_design.dart';

/// Floating top controls inspired by Samsung One UI.
///
/// This is intentionally NOT an AppBar:
/// controls float independently above page content.
///
/// The global menu button can live in AppShell, while individual screens
/// can place their own actions on the right.
class FloatingTopActions extends StatelessWidget {
  final List<Widget> actions;

  /// Show a separate floating back button on the left.
  ///
  /// Keep this false for screens inside AppShell if AppShell already
  /// displays the global menu button there.
  final bool showBack;

  final VoidCallback? onBack;

  /// Optional custom widget on the left instead of the back button.
  final Widget? leading;

  /// Compatibility argument. Generic top actions keep a neutral surface.
  final Color? seasonColor;

  const FloatingTopActions({
    super.key,
    this.actions = const [],
    this.showBack = false,
    this.onBack,
    this.leading,
    this.seasonColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cupertino = usesCupertinoGlass(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null)
              leading!
            else if (showBack)
              _FloatingTopButton(
                tooltip: 'Назад',
                onTap: onBack ?? () => Navigator.maybePop(context),
                child: Icon(
                  cupertino
                      ? Icons.arrow_back_ios_new
                      : Icons.arrow_back_rounded,
                  size: cupertino ? 18 : 22,
                  color: cs.onSurface,
                ),
              ),

            const Spacer(),

            if (actions.isNotEmpty)
              AdaptiveChromeSurface(
                key: const Key('floating-top-actions-surface'),
                role: actions.length == 1
                    ? ChromeSurfaceRole.control
                    : ChromeSurfaceRole.group,
                borderRadius: BorderRadius.circular(28),
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: actions.length == 1 ? 52 : null,
                    height: 52,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      // A single action sits in a fixed 52dp circle; without
                      // centring, its 48dp IconButton hugs the left edge.
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: actions,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatingTopButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final String? tooltip;

  const _FloatingTopButton({
    required this.onTap,
    required this.child,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = AdaptiveChromeSurface(
      role: ChromeSurfaceRole.control,
      borderRadius: BorderRadius.circular(28),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(width: 52, height: 52, child: Center(child: child)),
        ),
      ),
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(message: tooltip!, child: button);
  }
}
