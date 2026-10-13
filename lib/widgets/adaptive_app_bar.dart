import 'package:flutter/material.dart';

import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/app_overflow_menu.dart';

/// Space reserved by content scrolling behind the floating top controls.
const double kFloatingAppBarContentInset = 76;
const double kFloatingReaderAppBarContentInset = kFloatingAppBarContentInset;

/// Shared app-bar contract with platform-specific chrome.
///
/// The page title remains part of the content hierarchy. Only navigation and
/// actions receive a floating surface: glass on iOS, Material tonal on Android.
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdaptiveAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.seasonColor,
    this.showOverflow = false,
    this.showTextScale = false,
    this.showPsalmody = false,
  });

  AdaptiveAppBar.text(
    String text, {
    super.key,
    this.actions,
    this.leading,
    this.seasonColor,
    this.showOverflow = false,
    this.showTextScale = false,
    this.showPsalmody = false,
  }) : title = Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);

  final bool showOverflow;
  final bool showTextScale;
  final bool showPsalmody;
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;

  /// Kept for existing callers; app bar actions use neutral chrome colors.
  final Color? seasonColor;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final pageActions = actions ?? const <Widget>[];
    final cupertino = usesCupertinoGlass(context);
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.canPop(context);
    final leadingWidget =
        leading ??
        (canPop
            ? IconButton(
                tooltip: 'Назад',
                icon: Icon(
                  cupertino
                      ? Icons.arrow_back_ios_new
                      : Icons.arrow_back_rounded,
                  size: cupertino ? 18 : 22,
                ),
                color: cs.onSurface,
                onPressed: () => Navigator.maybePop(context),
              )
            : null);

    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                if (leadingWidget != null) ...[
                  AdaptiveChromeSurface(
                    role: ChromeSurfaceRole.control,
                    child: SizedBox.square(dimension: 48, child: leadingWidget),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Align(
                    alignment: cupertino
                        ? Alignment.center
                        : Alignment.centerLeft,
                    child: DefaultTextStyle(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: cupertino ? TextAlign.center : TextAlign.start,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontSize: cupertino ? 17 : 18,
                        fontWeight: cupertino
                            ? FontWeight.w600
                            : FontWeight.w700,
                        height: 1.08,
                        color: cs.onSurface,
                      ),
                      child: title,
                    ),
                  ),
                ),
                if (pageActions.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  AdaptiveChromeSurface(
                    role: ChromeSurfaceRole.group,
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: pageActions,
                      ),
                    ),
                  ),
                ],
                if (showOverflow) ...[
                  const SizedBox(width: 8),
                  AppOverflowMenu(
                    showTextScale: showTextScale,
                    showPsalmody: showPsalmody,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
