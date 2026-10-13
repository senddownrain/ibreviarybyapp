import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';

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
    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    final leftInset = math.max(media.padding.left, media.viewPadding.left);
    final rightInset = math.max(media.padding.right, media.viewPadding.right);
    var availableWidth = media.size.width - leftInset - rightInset - 16;
    if (origin.dx >= media.size.width / 2) {
      availableWidth = math.min(
        availableWidth,
        origin.dx + button.size.width - leftInset - 8,
      );
    }
    final width = math.min(360.0, availableWidth);
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
                showPsalmody: widget.showPsalmody,
                actions: actions,
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
    if (result == 'font') {
      await showTextScalePanel(context);
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
      child: IconButton(
        key: const Key('app-overflow-open'),
        tooltip: 'Меню',
        onPressed: _showMenu,
        icon: const Icon(Icons.more_horiz_rounded, size: 24),
      ),
    ),
  );
}

/// Keep each action and switch as its own accessible node. A disabled
/// PopupMenuItem would merge all of these controls into one disabled item.
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
    required this.showPsalmody,
    required this.actions,
    required this.onSelected,
  });

  final bool showTextScale;
  final bool showPsalmody;
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
          if (showTextScale) ...[
            _item('Шрыфт', PhosphorIconsRegular.textAa, 'font'),
            if (showPsalmody)
              const Divider(
                height: 12,
                thickness: .7,
                indent: 12,
                endIndent: 12,
              ),
          ],
          if (showPsalmody) const PsalmodyOverflowControls(),
          for (var index = 0; index < actions.length; index++)
            _item(actions[index].label, actions[index].icon, '$index'),
          if (showTextScale || showPsalmody || actions.isNotEmpty)
            const Divider(height: 12, thickness: .7, indent: 12, endIndent: 12),
          _item('Налады', PhosphorIconsRegular.gear, 'settings'),
          _item('Інфармацыя', PhosphorIconsRegular.info, 'about'),
        ],
      ),
    ),
  );

  Widget _item(String label, IconData icon, String value) => Builder(
    builder: (context) => InkWell(
      onTap: () => onSelected(value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: _menuLabelStyle(context))),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    ),
  );
}

// Explicit platform UI typography keeps reader faces and reader size out of
// the popup. System text scaling is still applied by Text and TextPainter.
TextStyle _menuLabelStyle(BuildContext context) => TextStyle(
  inherit: false,
  fontFamily: usesCupertinoGlass(context) ? '.AppleSystemUIFont' : 'Roboto',
  fontFamilyFallback: const ['sans-serif'],
  fontSize: 15,
  fontWeight: FontWeight.w500,
  height: 1.3,
  color: Theme.of(context).colorScheme.onSurface,
);

class _OverflowSwitchTile extends StatelessWidget {
  const _OverflowSwitchTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    enabled: true,
    toggled: value,
    onTap: () => onChanged(!value),
    child: ExcludeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final style = _menuLabelStyle(context);
              final painter = TextPainter(
                text: TextSpan(text: label, style: style),
                textScaler: MediaQuery.textScalerOf(context),
                textDirection: Directionality.of(context),
              )..layout();
              final stacked = painter.width > constraints.maxWidth - 60 - 12;
              painter.dispose();
              final title = Text(label, style: style);
              final control = SizedBox(
                width: 60,
                height: 48,
                child: Switch.adaptive(value: value, onChanged: onChanged),
              );
              if (stacked) {
                return Column(
                  key: ValueKey('$label-stacked'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    Align(alignment: Alignment.centerRight, child: control),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  control,
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class PsalmodyOverflowControls extends ConsumerWidget {
  const PsalmodyOverflowControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OverflowSwitchTile(
          key: const Key('overflow-psalm-marker-break'),
          label: 'Перанос пасля * і †',
          value:
              settings.psalmMarkerBreakMode ==
              PsalmMarkerBreakMode.breakAfterMarker,
          onChanged: (value) => notifier.setPsalmMarkerBreakMode(
            value
                ? PsalmMarkerBreakMode.breakAfterMarker
                : PsalmMarkerBreakMode.inline,
          ),
        ),
        _OverflowSwitchTile(
          key: const Key('overflow-psalm-aligned-left'),
          label: 'Па левым краі',
          value: settings.psalmVerseLayout == PsalmVerseLayout.alignedLeft,
          onChanged: (value) => notifier.setPsalmVerseLayout(
            value
                ? PsalmVerseLayout.alignedLeft
                : PsalmVerseLayout.alternatingIndent,
          ),
        ),
      ],
    );
  }
}
