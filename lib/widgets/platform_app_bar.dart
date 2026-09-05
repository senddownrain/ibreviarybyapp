import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/app_shell_scope.dart';

/// Platform-adaptive frosted-glass AppBar.
///
/// iOS  — centered title, `arrow_back_ios_new` chevron.
/// Android — left-aligned title, `arrow_back` arrow.
///
/// When rendered inside [AppShell] and there is no back route ([canPop] is
/// false), the leading slot shows the drawer-open ≡ button automatically via
/// [AppShellScope]. No changes needed at call sites.
class PlatformAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;

  const PlatformAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  PlatformAppBar.text(String text, {super.key, this.actions, this.leading})
    : title = Text(text);

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.canPop(context);

    Widget? effectiveLeading;
    if (leading != null) {
      effectiveLeading = leading;
    } else if (canPop) {
      final backIcon = _isIOS
          ? const Icon(Icons.arrow_back_ios_new, size: 18)
          : const Icon(Icons.arrow_back, size: 22);
      effectiveLeading = IconButton(
        icon: backIcon,
        color: cs.onSurface,
        tooltip: 'Назад',
        onPressed: () => Navigator.maybePop(context),
      );
    } else {
      final shellScope = AppShellScope.maybeOf(context);
      if (shellScope != null) {
        effectiveLeading = IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.list, size: 22),
          color: cs.onSurface,
          tooltip: 'Меню',
          onPressed: shellScope.openDrawer,
        );
      }
    }

    return GlassBar(
      seasonColor: seasonColor,
      child: NavigationToolbar(
        leading: effectiveLeading,
        middle: DefaultTextStyle(
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
          child: title,
        ),
        trailing: actions != null && actions!.isNotEmpty
            ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
            : null,
        centerMiddle: _isIOS,
      ),
    );
  }
}
