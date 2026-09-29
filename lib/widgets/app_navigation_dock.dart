import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';

class AppNavigationDock extends StatelessWidget {
  const AppNavigationDock({
    super.key,
    required this.activeBranch,
    required this.mode,
    required this.seasonColor,
    required this.onSelect,
    required this.onExpand,
  });

  final AppBranch activeBranch;
  final ReaderChromeMode mode;
  final Color seasonColor;
  final ValueChanged<AppBranch> onSelect;
  final VoidCallback onExpand;

  static const _items =
      <({String label, PhosphorIconData icon, PhosphorIconData selected})>[
        (
          label: 'Літургія',
          icon: PhosphorIconsRegular.sunHorizon,
          selected: PhosphorIconsFill.sunHorizon,
        ),
        (
          label: 'Чытанні',
          icon: PhosphorIconsRegular.bookOpenText,
          selected: PhosphorIconsFill.bookOpenText,
        ),
        (
          label: 'Малітоўнік',
          icon: PhosphorIconsRegular.handsPraying,
          selected: PhosphorIconsFill.handsPraying,
        ),
        (
          label: 'Біблія',
          icon: PhosphorIconsRegular.bookOpen,
          selected: PhosphorIconsFill.bookOpen,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    if (mode == ReaderChromeMode.hidden) {
      return const SizedBox.shrink(key: Key('app-dock-hidden'));
    }
    final ios = usesCupertinoGlass(context);
    final platformKey = Key(ios ? 'app-dock-ios' : 'app-dock-android');
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final systemNavigationStripColor = Theme.of(
      context,
    ).colorScheme.surface.withValues(alpha: 0.72);
    return Container(
      key: platformKey,
      height: (mode == ReaderChromeMode.full ? 78 : 72) + bottom,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            systemNavigationStripColor.withValues(alpha: 0),
            systemNavigationStripColor.withValues(alpha: ios ? 0.42 : 0.50),
            systemNavigationStripColor.withValues(alpha: 0.72),
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Align(
                alignment: Alignment.topCenter,
                child: mode == ReaderChromeMode.full
                    ? _FullDock(
                        activeBranch: activeBranch,
                        items: _items,
                        seasonColor: seasonColor,
                        onSelect: onSelect,
                      )
                    : _CompactDock(
                        branch: activeBranch,
                        item: _items[activeBranch.index],
                        seasonColor: seasonColor,
                        onExpand: onExpand,
                      ),
              ),
            ),
          ),
          SizedBox(
            key: const Key('app-dock-system-navigation-strip'),
            height: bottom,
            child: ColoredBox(color: systemNavigationStripColor),
          ),
        ],
      ),
    );
  }
}

class _FullDock extends StatelessWidget {
  const _FullDock({
    required this.activeBranch,
    required this.items,
    required this.seasonColor,
    required this.onSelect,
  });

  final AppBranch activeBranch;
  final List<({String label, PhosphorIconData icon, PhosphorIconData selected})>
  items;
  final Color seasonColor;
  final ValueChanged<AppBranch> onSelect;

  @override
  Widget build(BuildContext context) {
    final ios = usesCupertinoGlass(context);
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: AdaptiveChromeSurface(
        key: const Key('app-dock-full'),
        role: ChromeSurfaceRole.navigation,
        seasonColor: seasonColor,
        borderRadius: BorderRadius.circular(ios ? 30 : 24),
        child: SizedBox(
          height: ios ? 62 : 60,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _DockDestination(
                    item: items[index],
                    selected: index == activeBranch.index,
                    colorScheme: cs,
                    ios: ios,
                    onTap: () => onSelect(AppBranch.values[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockDestination extends StatelessWidget {
  const _DockDestination({
    required this.item,
    required this.selected,
    required this.colorScheme,
    required this.ios,
    required this.onTap,
  });

  final ({String label, PhosphorIconData icon, PhosphorIconData selected}) item;
  final bool selected;
  final ColorScheme colorScheme;
  final bool ios;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: item.label,
    child: InkResponse(
      key: Key('app-destination-${item.label}'),
      onTap: onTap,
      containedInkWell: true,
      highlightShape: BoxShape.rectangle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        child: DecoratedBox(
          decoration: selected
              ? BoxDecoration(
                  color: ios
                      ? colorScheme.primary.withValues(alpha: 0.13)
                      : colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(18),
                )
              : const BoxDecoration(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                selected ? item.selected : item.icon,
                size: 22,
                color: selected
                    ? (ios
                          ? colorScheme.primary
                          : colorScheme.onSecondaryContainer)
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CompactDock extends StatelessWidget {
  const _CompactDock({
    required this.branch,
    required this.item,
    required this.seasonColor,
    required this.onExpand,
  });

  final AppBranch branch;
  final ({String label, PhosphorIconData icon, PhosphorIconData selected}) item;
  final Color seasonColor;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AdaptiveChromeSurface(
      key: const Key('app-dock-compact'),
      role: ChromeSurfaceRole.navigation,
      seasonColor: seasonColor,
      borderRadius: BorderRadius.circular(28),
      child: Semantics(
        button: true,
        label: '${item.label}. Паказаць усе раздзелы',
        child: InkWell(
          key: const Key('app-dock-expand'),
          onTap: onExpand,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(item.selected, size: 23, color: cs.primary),
                  const SizedBox(width: 9),
                  Text(
                    item.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 7),
                  const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
