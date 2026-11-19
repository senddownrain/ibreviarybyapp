import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/feedback/feedback_models.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
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
    final button = context.findRenderObject()! as RenderBox;
    // A nested Scaffold can consume viewInsets for its body. The root overlay
    // still knows the keyboard and the full display's safe area.
    final media = MediaQuery.of(navigator.overlay!.context);
    final textScale = media.textScaler.scale(1);
    // Match a roomy, native-style overflow: around 80% of a phone screen,
    // with sensible limits for narrow displays, tablets and large text.
    final width = math.min(
      media.size.width - 24,
      math.max(
        280.0,
        math.min(360.0, media.size.width * 0.80 + (textScale - 1) * 24),
      ),
    );
    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    final bottom =
        media.size.height -
        math.max(media.viewInsets.bottom, media.viewPadding.bottom);
    final menuTop = origin.dy + button.size.height + 8;
    final availableHeight = math.max(48.0, bottom - menuTop - 8);
    var position = RelativeRect.fromRect(
      Rect.fromLTWH(origin.dx, menuTop, button.size.width, 0),
      Offset.zero & overlay.size,
    );
    final actions = widget.actions;
    // One consistent "report an error" entry on every material. A screen may
    // supply its own action (with a title); otherwise the route gives the context.
    final router = GoRouter.maybeOf(context);
    final reportLocation =
        router == null || actions.any((a) => a.label == kReportErrorLabel)
        ? null
        : feedbackLocationForMenuUri(_visibleUri(router));
    if (widget.showTextScale) analyticsFeature('text_settings_open');
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
          final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
          position = RelativeRect.fromRect(
            Rect.fromLTWH(
              origin.dx,
              origin.dy + button.size.height + 8,
              button.size.width,
              0,
            ),
            Offset.zero & overlay.size,
          );
        }
        return position;
      },
      items: [
        _OverflowEntry(
          child: Builder(
            builder: (popupContext) {
              _popupRoute = ModalRoute.of(popupContext);
              return _OverflowContent(
                showTextScale: widget.showTextScale,
                actions: actions,
                showReport: reportLocation != null,
                onSelected: (value) => Navigator.pop(popupContext, value),
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
    if (result == 'settings' || result == 'about') {
      context.push('/$result');
    } else if (result == 'report') {
      context.push(reportLocation!);
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
      child: IconButton(
        key: const Key('app-overflow-open'),
        tooltip: 'Меню',
        onPressed: _showMenu,
        icon: const Icon(Icons.more_horiz_rounded, size: 24),
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
    required this.showReport,
    required this.onSelected,
  });

  final bool showTextScale;
  final List<ReaderSecondaryAction> actions;
  final bool showReport;
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
          if (showTextScale) _fontSizeRow(),
          for (var index = 0; index < actions.length; index++)
            if (actions[index].label != kReportErrorLabel)
              _item(actions[index].label, actions[index].icon, '$index'),
          if (showTextScale ||
              actions.any((action) => action.label != kReportErrorLabel))
            const Divider(height: 16),
          _item('Налады', PhosphorIconsRegular.gear, 'settings'),
          _item('Інфармацыя', PhosphorIconsRegular.info, 'about'),
          for (var index = 0; index < actions.length; index++)
            if (actions[index].label == kReportErrorLabel) ...[
              const Divider(height: 16),
              _item(kReportErrorLabel, actions[index].icon, '$index'),
            ],
          if (showReport) ...[
            const Divider(height: 16),
            _item(kReportErrorLabel, Icons.flag_outlined, 'report'),
          ],
        ],
      ),
    ),
  );

  Widget _fontSizeRow() => Consumer(
    builder: (context, ref, _) {
      final fontSize = ref.watch(
        settingsProvider.select((settings) => settings.fontSize),
      );
      final notifier = ref.read(settingsProvider.notifier);
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      return Padding(
        key: const Key('text-scale-inline'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          children: [
            const PhosphorIcon(PhosphorIconsRegular.textAa, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Шрыфт',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${readerFontScalePercent(fontSize)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _fontSizeButton(
              key: const Key('text-scale-inline-decrease'),
              label: 'Паменшыць шрыфт',
              text: 'A−',
              onPressed: fontSize > kMinReaderFontSize + 0.01
                  ? () {
                      HapticFeedback.selectionClick();
                      notifier.decreaseFontSize();
                    }
                  : null,
            ),
            const SizedBox(width: 8),
            _fontSizeButton(
              key: const Key('text-scale-inline-increase'),
              label: 'Павялічыць шрыфт',
              text: 'A+',
              onPressed: fontSize < kMaxReaderFontSize - 0.01
                  ? () {
                      HapticFeedback.selectionClick();
                      notifier.increaseFontSize();
                    }
                  : null,
            ),
          ],
        ),
      );
    },
  );

  Widget _fontSizeButton({
    required Key key,
    required String label,
    required String text,
    required VoidCallback? onPressed,
  }) => IconButton.filledTonal(
    key: key,
    tooltip: label,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size.square(44),
      fixedSize: const Size.square(44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    ),
    icon: Text(
      text,
      textScaler: TextScaler.noScaling,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  );

  Widget _item(String label, IconData icon, String value) => ListTile(
    minTileHeight: 48,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    minLeadingWidth: 24,
    horizontalTitleGap: 10,
    leading: Icon(icon, size: 22),
    title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
    onTap: () => onSelected(value),
  );
}

/// The location the reader actually sees. A page opened with `context.push` is
/// an imperative match with its own match list, while `routeInformationProvider`
/// and `currentConfiguration.uri` keep naming the page underneath it.
Uri _visibleUri(GoRouter router) {
  final configuration = router.routerDelegate.currentConfiguration;
  final last = configuration.lastOrNull;
  return (last is ImperativeRouteMatch ? last.matches : configuration).uri;
}
