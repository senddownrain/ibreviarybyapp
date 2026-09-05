import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/theme/glass.dart';

/// Vertical space (pts) to reserve below the status bar so content clears the
/// floating [ShellMenuButton]: button top-offset (10) + button height (52).
const kShellMenuButtonClearance = 62.0;

/// Provides AppShell context to descendants (PlatformAppBar, screens).
class AppShellScope extends InheritedWidget {
  final VoidCallback openDrawer;

  const AppShellScope({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  static AppShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellScope>();

  @override
  bool updateShouldNotify(AppShellScope old) => false;
}

/// Floating glass-pill drawer button for shell screens without PlatformAppBar.
/// Place it inside a Stack using [AppShellScope.maybeOf] from the screen's
/// build context.
class ShellMenuButton extends StatelessWidget {
  final VoidCallback onTap;

  const ShellMenuButton({super.key, required this.onTap});

  /// Builds via [AppShellScope] from [context].
  /// Returns [SizedBox.shrink] when not inside an [AppShell].
  static Widget fromScope(BuildContext context) {
    final scope = AppShellScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    return ShellMenuButton(onTap: scope.openDrawer);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Меню',
      child: GlassSurface(
        style: GlassStyle.pill,
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Center(
                child: PhosphorIcon(
                  PhosphorIconsRegular.list,
                  size: 24,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
