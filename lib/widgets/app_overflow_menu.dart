import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart'
    show analyticsFeature;

class ReaderSecondaryAction {
  const ReaderSecondaryAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

/// One anchored menu for shell, reader and catalog chrome.
class AppOverflowMenu extends StatefulWidget {
  const AppOverflowMenu({
    super.key,
    this.showTextScale = false,
    this.showPsalmody = false,
    this.actions = const [],
  });

  final bool showTextScale;
  final bool showPsalmody;
  final List<ReaderSecondaryAction> actions;

  @override
  State<AppOverflowMenu> createState() => _AppOverflowMenuState();
}

class _AppOverflowMenuState extends State<AppOverflowMenu> {
  final _anchorKey = GlobalKey();
  Route<dynamic>? _popupRoute;
  bool _open = false;

  @override
  void dispose() {
    final route = _popupRoute;
    // Hidden chrome removes its button. Dismiss its popup too, after the
    // current build finishes, without popping a different page or sheet.
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
    super.dispose();
  }

  Future<void> _showMenu() async {
    if (_open) return;
    _open = true;
    final navigator = Navigator.of(context, rootNavigator: true);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final button = _anchorKey.currentContext!.findRenderObject()! as RenderBox;
    // A nested Scaffold can consume viewInsets for its body. The root overlay
    // still knows the keyboard and the full display's safe area.
    final media = MediaQuery.of(navigator.overlay!.context);
    RelativeRect positionForButton() {
      final corner = button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      );
      final right = corner.dx.clamp(
        media.viewPadding.left + 8,
        overlay.size.width - media.viewPadding.right - 8,
      );
      final top = corner.dy + 4;
      return RelativeRect.fromRect(
        Rect.fromLTWH(right, top, 0, 0),
        Offset.zero & overlay.size,
      );
    }

    var position = positionForButton();
    final bottom =
        media.size.height -
        math.max(media.viewInsets.bottom, media.viewPadding.bottom);
    final availableHeight = math.max(48.0, bottom - position.top - 8);
    // The prayerbook shares this menu across its root, category/catalogue
    // screens and readers. Keep category management in one place, instead of
    // rendering a second overflow button alongside it.
    final isPrayerbook =
        AppRouteEntryScope.maybeOf(context)?.entry.descriptor.branch ==
        AppBranch.prayerbook;
    final routePath = GoRouter.maybeOf(
      context,
    )?.routeInformationProvider.value.uri.path;
    final actions = [
      ...widget.actions,
      if (isPrayerbook && routePath != '/prayers/categories')
        ReaderSecondaryAction(
          label: 'Катэгорыі',
          icon: Icons.category_outlined,
          onSelected: () => context.push('/prayers/categories'),
        ),
    ];
    // Measure the actual localized labels with the user's text scaler. Short
    // menus stay compact; long contextual actions may use more of the viewport.
    final labels = [
      if (widget.showTextScale) 'Шрыфт',
      ...actions.map((a) => a.label),
      'Налады',
      'Інфармацыя',
    ];
    var labelWidth = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        textDirection: Directionality.of(context),
        textScaler: media.textScaler,
      )..layout();
      labelWidth = math.max(labelWidth, painter.width);
      painter.dispose();
    }
    final availableWidth = math.max(
      0.0,
      overlay.size.width - media.viewPadding.horizontal - 16,
    );
    final width = math.min(
      availableWidth,
      (labelWidth + 66).clamp(224.0, actions.isEmpty ? 280.0 : 360.0),
    );
    final result = await showMenu<String>(
      context: context,
      useRootNavigator: true,
      semanticLabel: 'Меню',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      menuPadding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: availableHeight,
      ),
      positionBuilder: (_, _) {
        // The source can disappear before the popup's removal frame.
        if (button.attached && overlay.attached) {
          position = positionForButton();
        }
        return position;
      },
      items: [
        _OverflowEntry(
          child: Builder(
            builder: (popupContext) {
              final popupRoute = ModalRoute.of(popupContext);
              _popupRoute = popupRoute;
              return _OverflowContent(
                showTextScale: widget.showTextScale,
                actions: actions,
                onSelected: (value) {
                  // A second tap during dismissal must never pop the reader.
                  if (popupRoute?.isCurrent == true) navigator.pop(value);
                },
              );
            },
          ),
        ),
      ],
    );
    final route = _popupRoute;
    if (route is TransitionRoute) await route.completed;
    _popupRoute = null;
    _open = false;
    if (!mounted || result == null) return;
    if (result == 'font') {
      analyticsFeature('text_settings_open');
      await showTextScalePanel(context, showPsalmody: widget.showPsalmody);
    } else if (result == 'settings' || result == 'about') {
      context.push('/$result');
    } else {
      actions[int.parse(result)].onSelected();
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 48,
    child: AdaptiveChromeSurface(
      role: ChromeSurfaceRole.control,
      borderRadius: BorderRadius.circular(24),
      child: KeyedSubtree(
        key: _anchorKey,
        child: IconButton(
          key: const Key('app-overflow-open'),
          tooltip: 'Меню',
          onPressed: _showMenu,
          icon: const Icon(Icons.more_horiz_rounded, size: 24),
        ),
      ),
    ),
  );
}

/// Keep each menu action as its own accessible node. A disabled
/// PopupMenuItem would merge all controls into a single disabled item.
class _OverflowEntry extends PopupMenuEntry<String> {
  const _OverflowEntry({required this.child});

  final Widget child;

  @override
  double get height => 48;

  @override
  bool represents(String? value) => false;

  @override
  State<_OverflowEntry> createState() => _OverflowEntryState();
}

class _OverflowEntryState extends State<_OverflowEntry> {
  @override
  Widget build(BuildContext context) => widget.child;
}

class _OverflowContent extends StatelessWidget {
  const _OverflowContent({
    required this.showTextScale,
    required this.actions,
    required this.onSelected,
  });

  final bool showTextScale;
  final List<ReaderSecondaryAction> actions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Padding(
      key: const Key('app-overflow-content'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTextScale)
            _item('Шрыфт', PhosphorIconsRegular.textAa, 'font'),
          for (var index = 0; index < actions.length; index++)
            _item(actions[index].label, actions[index].icon, '$index'),
          if (showTextScale || actions.isNotEmpty) const Divider(height: 16),
          _item('Налады', PhosphorIconsRegular.gear, 'settings'),
          _item('Інфармацыя', PhosphorIconsRegular.info, 'about'),
        ],
      ),
    ),
  );

  Widget _item(String label, IconData icon, String value) => ListTile(
    minTileHeight: 48,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    minLeadingWidth: 22,
    horizontalTitleGap: 12,
    leading: Icon(icon, size: 22),
    title: Text(label),
    onTap: () => onSelected(value),
  );
}
