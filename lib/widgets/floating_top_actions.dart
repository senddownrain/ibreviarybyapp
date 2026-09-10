import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';

/// Floating top controls inspired by Samsung One UI.
///
/// This is intentionally NOT an AppBar:
/// controls float independently above page content.
///
/// The global menu button can live in AppShell, while individual screens
/// can place their own actions on the right.
class FloatingTopActions extends ConsumerWidget {
  final List<Widget> actions;

  /// Show a separate floating back button on the left.
  ///
  /// Keep this false for screens inside AppShell if AppShell already
  /// displays the global menu button there.
  final bool showBack;

  final VoidCallback? onBack;

  /// Optional custom widget on the left instead of the back button.
  final Widget? leading;

  /// Optional override for liturgical/glass tint.
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
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedSeasonColor =
        seasonColor ??
        ref.watch(liturgicalSeasonColorProvider) ??
        Colors.transparent;

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
                seasonColor: resolvedSeasonColor,
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
                role: ChromeSurfaceRole.group,
                seasonColor: resolvedSeasonColor,
                borderRadius: BorderRadius.circular(28),
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    height: 52,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
  final Color seasonColor;
  final VoidCallback onTap;
  final Widget child;
  final String? tooltip;

  const _FloatingTopButton({
    required this.seasonColor,
    required this.onTap,
    required this.child,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = AdaptiveChromeSurface(
      role: ChromeSurfaceRole.control,
      seasonColor: seasonColor,
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
