import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';

/// Frosted-glass AppBar for full-screen routes (iOS + Android).
class IosGlassAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;

  const IosGlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  IosGlassAppBar.text(String text, {super.key, this.actions, this.leading})
    : title = Text(text);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.canPop(context);

    // On older Android without blur perf concerns still use glass; fall back
    // only when explicitly preferring stock Material (unused currently).
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return AppBar(title: title, actions: actions, leading: leading);
    }

    return GlassBar(
      seasonColor: seasonColor,
      child: NavigationToolbar(
        leading:
            leading ??
            (canPop
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: cs.onSurface,
                    onPressed: () => Navigator.maybePop(context),
                  )
                : null),
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
        centerMiddle: true,
      ),
    );
  }
}
