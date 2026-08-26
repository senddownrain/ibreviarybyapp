import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';

/// Frosted-glass AppBar for iOS full-screen routes.
/// Falls back to a standard Material AppBar on Android.
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

  IosGlassAppBar.text(
    String text, {
    super.key,
    this.actions,
    this.leading,
  }) : title = Text(text);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isIOS) {
      return AppBar(title: title, actions: actions, leading: leading);
    }

    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final blurBg = isDark
        ? Colors.black.withValues(alpha: 0.50)
        : cs.surface.withValues(alpha: 0.65);
    final seasonTint = seasonColor.withValues(alpha: isDark ? 0.12 : 0.07);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);

    final canPop = Navigator.canPop(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Color.alphaBlend(seasonTint, blurBg),
            border: Border(
              bottom: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: NavigationToolbar(
                leading: leading ??
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
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions!,
                      )
                    : null,
                centerMiddle: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
