import 'package:flutter/material.dart';

import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/app_overflow_menu.dart';

/// Floating top controls inspired by Samsung One UI.
///
/// This is intentionally NOT an AppBar:
/// controls float independently above page content.
///
/// Catalog screens own their direct actions and the shared right-hand menu.
class FloatingTopActions extends StatelessWidget {
  final List<Widget> actions;
  final bool showOverflow;

  /// Show a separate floating back button on the left.
  ///
  /// Branch roots leave the left side empty.
  final bool showBack;

  final VoidCallback? onBack;

  /// Optional custom widget on the left instead of the back button.
  final Widget? leading;

  /// Compatibility argument. Generic top actions keep a neutral surface.
  final Color? seasonColor;

  const FloatingTopActions({
    super.key,
    this.actions = const [],
    this.showOverflow = true,
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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null)
              AdaptiveChromeSurface(
                role: ChromeSurfaceRole.control,
                borderRadius: BorderRadius.circular(24),
                child: SizedBox.square(dimension: 48, child: leading),
              )
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
                borderRadius: BorderRadius.circular(24),
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: actions.length == 1 ? 48 : null,
                    height: 48,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      // Keep a single 48dp action centred in its surface.
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: actions,
                    ),
                  ),
                ),
              ),
            if (showOverflow) ...[
              const SizedBox(width: 8),
              const AppOverflowMenu(),
            ],
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
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(width: 48, height: 48, child: Center(child: child)),
        ),
      ),
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(message: tooltip!, child: button);
  }
}
