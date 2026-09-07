import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';

/// Space reserved by content scrolling behind the floating top controls.
const double kFloatingAppBarContentInset = 76;
const double kFloatingReaderAppBarContentInset = kFloatingAppBarContentInset;

/// Shared app-bar contract with platform-specific chrome.
///
/// The page title remains part of the content hierarchy. Only navigation and
/// actions receive a floating surface: glass on iOS, Material tonal on Android.
class AdaptiveAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const AdaptiveAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  AdaptiveAppBar.text(String text, {super.key, this.actions, this.leading})
    : title = Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);

  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
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
    final readerAction = actions?.whereType<TextScaleControl>().firstOrNull;
    final pageActions = actions
        ?.where((action) => action is! TextScaleControl)
        .toList(growable: false);

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
                    seasonColor: seasonColor,
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
                if (pageActions != null && pageActions.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  AdaptiveChromeSurface(
                    seasonColor: seasonColor,
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
                if (readerAction != null) ...[
                  const SizedBox(width: 8),
                  readerAction,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
