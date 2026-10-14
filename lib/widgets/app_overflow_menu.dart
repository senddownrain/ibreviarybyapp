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
    var anchor =
        button.localToGlobal(Offset.zero, ancestor: overlay) & button.size;
    final actions = widget.actions;
    final showTextScale = widget.showTextScale;
    final showPsalmody = widget.showPsalmody;
    final route = _OverflowPopupRoute(
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (popupContext) => LayoutBuilder(
        builder: (context, constraints) {
          // Layout follows the source after rotation, text-scale and keyboard
          // changes. Retain the last anchor during its removal frame.
          if (button.attached && overlay.attached && button.hasSize) {
            anchor =
                button.localToGlobal(Offset.zero, ancestor: overlay) &
                button.size;
          }
          final media = MediaQuery.of(context);
          final size = constraints.biggest;
          final left = math.max(media.padding.left, media.viewPadding.left) + 8;
          final right =
              size.width -
              math.max(media.padding.right, media.viewPadding.right) -
              8;
          final top = math.max(media.padding.top, media.viewPadding.top) + 8;
          final bottom =
              size.height -
              math.max(media.viewInsets.bottom, media.viewPadding.bottom) -
              8;
          final growLeft =
              anchor.center.dx > size.width / 2 ||
              (anchor.center.dx == size.width / 2 &&
                  Directionality.of(context) == TextDirection.rtl);
          final preferred = _preferredMenuWidth(
            context,
            showTextScale,
            showPsalmody,
            actions,
          );
          final anchorSpace = growLeft
              ? anchor.right - left
              : right - anchor.left;
          final width = math.min(
            preferred,
            math.max(48.0, math.min(right - left, anchorSpace)),
          );
          final x = (growLeft ? anchor.right - width : anchor.left)
              .clamp(left, math.max(left, right - width))
              .toDouble();
          final minimumVisible = math.min(160.0, math.max(48.0, bottom - top));
          final y = (anchor.bottom + 8)
              .clamp(top, math.max(top, bottom - minimumVisible))
              .toDouble();
          return Stack(
            children: [
              Positioned(
                left: x,
                top: y,
                width: width,
                child: ConstrainedBox(
                  key: const Key('app-overflow-popup'),
                  constraints: BoxConstraints(
                    maxHeight: math.max(48.0, bottom - y),
                  ),
                  child: Semantics(
                    scopesRoute: true,
                    namesRoute: true,
                    explicitChildNodes: true,
                    label: 'Меню',
                    child: AdaptiveChromeSurface(
                      role: ChromeSurfaceRole.group,
                      borderRadius: BorderRadius.circular(24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SingleChildScrollView(
                          child: _OverflowContent(
                            showTextScale: showTextScale,
                            showPsalmody: showPsalmody,
                            actions: actions,
                            onSelected: (value) =>
                                Navigator.pop(popupContext, value),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    _popupRoute = route;
    final result = await navigator.push<String>(route);
    await route.completed;
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

// Unlike Material showMenu's intrinsic 56dp width steps, this route accepts
// exact, content-dependent sizes and recomputes geometry while it is open.
class _OverflowPopupRoute extends PopupRoute<String> {
  _OverflowPopupRoute({required this.themes, required this.builder})
    : super(traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop);

  final CapturedThemes themes;
  final WidgetBuilder builder;
  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => 'Закрыць меню';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => themes.wrap(Builder(builder: builder));
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.disableAnimationsOf(context)
      ? child
      : FadeTransition(opacity: animation, child: child);
}

// Normal menus stay compact; only content and accessibility scaling widen them.
double _preferredMenuWidth(
  BuildContext context,
  bool showTextScale,
  bool showPsalmody,
  List<ReaderSecondaryAction> actions,
) {
  double measure(String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _menuLabelStyle(context)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  var width = showPsalmody ? 316.0 : 256.0;
  for (final label in [
    'Налады',
    'Інфармацыя',
    if (showTextScale) 'Шрыфт',
    ...actions.map((action) => action.label),
  ]) {
    // Include row chrome, the surface border and glyph rounding at large scales.
    width = math.max(width, measure(label) + 100);
  }
  if (showPsalmody) {
    for (final label in ['Перанос пасля * і †', 'Па левым краі']) {
      width = math.max(width, measure(label) + 96);
    }
  }
  return math.min(width, 360);
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
    color: Colors.transparent,
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
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 18,
              ),
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
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: control,
                    ),
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
