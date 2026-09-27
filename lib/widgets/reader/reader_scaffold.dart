import 'package:flutter/material.dart';

import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/widgets/horizontal_swipe_navigation.dart';

/// Navigation/chrome density requested by the application shell.
///
/// The current shell can use [ReaderChromeModeScope] as a compatibility
/// bridge. A future four-tab shell can own the controller without changing
/// reader content or individual reader screens.
enum ReaderChromeMode { full, compact, hidden }

class ReaderChromeModeController extends ValueNotifier<ReaderChromeMode> {
  ReaderChromeModeController([super.value = ReaderChromeMode.full])
    : _lastVisibleMode = value == ReaderChromeMode.hidden
          ? ReaderChromeMode.compact
          : value;

  ReaderChromeMode _lastVisibleMode;

  @override
  set value(ReaderChromeMode newValue) {
    if (newValue != ReaderChromeMode.hidden) _lastVisibleMode = newValue;
    super.value = newValue;
  }

  void toggleFullscreen() {
    value = value == ReaderChromeMode.hidden
        ? _lastVisibleMode
        : ReaderChromeMode.hidden;
  }
}

class ReaderChromeModeScope
    extends InheritedNotifier<ReaderChromeModeController> {
  const ReaderChromeModeScope({
    super.key,
    required ReaderChromeModeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ReaderChromeModeController? maybeControllerOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ReaderChromeModeScope>()
          ?.notifier;
}

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

/// Shared long-form reader layout.
///
/// Context and platform chrome remain outside [ReaderContentSurface]. The
/// document itself is always rendered on a neutral, opaque surface.
class ReaderScaffold extends StatelessWidget {
  const ReaderScaffold({
    super.key,
    required this.content,
    this.contextHeader,
    this.actions = const [],
    this.secondaryActions = const [],
    this.seasonColor,
    this.chromeMode = ReaderChromeMode.compact,
    this.onChromeModeChanged,
    this.onBack,
    this.leading,
    this.drawer,
    this.scrollController,
    this.scrollKey,
    this.maxContentWidth = 760,
    this.semanticLabel,
    this.showAmbient = true,
    this.enableDoubleTapFullscreen = true,
    this.showScrollToTop = false,
    this.onSwipePrevious,
    this.onSwipeNext,
    this.overlay,
  });

  final Widget content;
  final Widget? contextHeader;
  final List<Widget> actions;
  final List<ReaderSecondaryAction> secondaryActions;
  final Color? seasonColor;
  final ReaderChromeMode chromeMode;
  final ValueChanged<ReaderChromeMode>? onChromeModeChanged;
  final VoidCallback? onBack;

  /// Optional root-level leading control (for example the application menu).
  /// Detail readers continue to use the default platform back control.
  final Widget? leading;
  final Widget? drawer;
  final ScrollController? scrollController;
  final PageStorageKey<String>? scrollKey;
  final double maxContentWidth;
  final String? semanticLabel;
  final bool showAmbient;
  final bool enableDoubleTapFullscreen;
  final bool showScrollToTop;
  final VoidCallback? onSwipePrevious;
  final VoidCallback? onSwipeNext;

  /// Reader-specific floating control layered above the text (for example the
  /// Holy Mass section navigator). Hidden together with the chrome.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final scopedController = ReaderChromeModeScope.maybeControllerOf(context);
    final resolvedMode = scopedController?.value ?? chromeMode;
    final topInset = resolvedMode == ReaderChromeMode.hidden
        ? MediaQuery.paddingOf(context).top + 16
        : MediaQuery.paddingOf(context).top + 76;

    void setMode(ReaderChromeMode mode) {
      if (scopedController != null) {
        scopedController.value = mode;
      } else {
        onChromeModeChanged?.call(mode);
      }
    }

    void toggleFullscreen() {
      if (scopedController != null) {
        scopedController.toggleFullscreen();
      } else {
        setMode(
          resolvedMode == ReaderChromeMode.hidden
              ? ReaderChromeMode.compact
              : ReaderChromeMode.hidden,
        );
      }
    }

    Widget scrollView = CustomScrollView(
      key: scrollKey,
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(key: const Key('reader-top-inset'), height: topInset),
        ),
        if (contextHeader case final header?)
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: header,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: ReaderContentSurface(
            maxContentWidth: maxContentWidth,
            semanticLabel: semanticLabel,
            child: content,
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(color: ReaderTheme.of(context).surface),
        ),
      ],
    );

    if (onSwipePrevious != null || onSwipeNext != null) {
      scrollView = HorizontalSwipeNavigation(
        onPrevious: onSwipePrevious,
        onNext: onSwipeNext,
        child: scrollView,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: drawer,
      body: Stack(
        children: [
          if (showAmbient)
            AmbientWash.hero(
              seasonColor: seasonColor ?? Theme.of(context).colorScheme.primary,
            ),
          if (enableDoubleTapFullscreen)
            _ReaderFullscreenGestureSurface(
              key: const Key('reader-double-tap-surface'),
              onToggle: toggleFullscreen,
              child: scrollView,
            )
          else
            scrollView,
          if (resolvedMode != ReaderChromeMode.hidden) ?overlay,
          if (showScrollToTop && scrollController != null)
            _ReaderScrollToTopControl(
              controller: scrollController!,
              mode: resolvedMode,
              seasonColor: seasonColor,
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ReaderChrome(
              mode: resolvedMode,
              seasonColor: seasonColor,
              actions: actions,
              secondaryActions: secondaryActions,
              onBack: onBack,
              leading: leading,
              onModeChanged: setMode,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderScrollToTopControl extends StatefulWidget {
  const _ReaderScrollToTopControl({
    required this.controller,
    required this.mode,
    required this.seasonColor,
  });

  final ScrollController controller;
  final ReaderChromeMode mode;
  final Color? seasonColor;

  @override
  State<_ReaderScrollToTopControl> createState() =>
      _ReaderScrollToTopControlState();
}

class _ReaderScrollToTopControlState extends State<_ReaderScrollToTopControl> {
  static const _showAfter = 560.0;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant _ReaderScrollToTopControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleScroll);
      widget.controller.addListener(_handleScroll);
      _handleScroll();
    }
  }

  void _handleScroll() {
    final visible =
        widget.controller.hasClients && widget.controller.offset > _showAfter;
    if (visible != _visible && mounted) setState(() => _visible = visible);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _visible && widget.mode != ReaderChromeMode.hidden;
    if (!shown) return const SizedBox.shrink();
    return Positioned(
      right: 16,
      // This local padding is the shell dock reserve in extendBody mode.
      bottom: MediaQuery.paddingOf(context).bottom + 16,
      child: AdaptiveChromeSurface(
        role: ChromeSurfaceRole.control,
        seasonColor: widget.seasonColor,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox.square(
          dimension: 48,
          child: IconButton(
            key: const Key('reader-scroll-to-top'),
            tooltip: 'Вярнуцца ўверх',
            onPressed: () => widget.controller.animateTo(
              0,
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
            ),
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 28),
          ),
        ),
      ),
    );
  }
}

class _ReaderFullscreenGestureSurface extends StatefulWidget {
  const _ReaderFullscreenGestureSurface({
    super.key,
    required this.onToggle,
    required this.child,
  });

  final VoidCallback onToggle;
  final Widget child;

  @override
  State<_ReaderFullscreenGestureSurface> createState() =>
      _ReaderFullscreenGestureSurfaceState();
}

class _ReaderFullscreenGestureSurfaceState
    extends State<_ReaderFullscreenGestureSurface> {
  DateTime? _lastTapAt;
  Offset? _lastTapPosition;
  Offset? _pointerDownPosition;
  bool _pointerMoved = false;

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.position;
    _pointerMoved = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final origin = _pointerDownPosition;
    if (origin != null && (event.position - origin).distance > 18) {
      _pointerMoved = true;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointerMoved) {
      _lastTapAt = null;
      _lastTapPosition = null;
      return;
    }
    final now = DateTime.now();
    final previousAt = _lastTapAt;
    final previousPosition = _lastTapPosition;
    if (previousAt != null &&
        previousPosition != null &&
        now.difference(previousAt) <= const Duration(milliseconds: 280) &&
        (event.position - previousPosition).distance <= 48) {
      _lastTapAt = null;
      _lastTapPosition = null;
      widget.onToggle();
      return;
    }
    _lastTapAt = now;
    _lastTapPosition = event.position;
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _onPointerDown,
    onPointerMove: _onPointerMove,
    onPointerUp: _onPointerUp,
    onPointerCancel: (_) => _pointerMoved = true,
    child: widget.child,
  );
}

class ReaderContentSurface extends StatelessWidget {
  static const double bottomSpacing = 42;
  const ReaderContentSurface({
    super.key,
    required this.child,
    this.maxContentWidth = 760,
    this.semanticLabel,
  });

  final Widget child;
  final double maxContentWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // With Scaffold.extendBody enabled, MediaQuery.padding includes the
    // floating app dock while viewPadding only includes the system inset.
    // Reserve the full padded area so the end of a document can scroll clear
    // of both the dock and the system navigation bar.
    final bottom = MediaQuery.paddingOf(context).bottom;
    Widget result = ColoredBox(
      key: const Key('reader-content-surface'),
      color: ReaderTheme.of(context).surface,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 25, 22, bottomSpacing + bottom),
            child: child,
          ),
        ),
      ),
    );
    if (semanticLabel != null) {
      result = Semantics(label: semanticLabel, container: true, child: result);
    }
    return result;
  }
}

class ReaderChrome extends StatelessWidget {
  const ReaderChrome({
    super.key,
    required this.mode,
    required this.onModeChanged,
    this.actions = const [],
    this.secondaryActions = const [],
    this.seasonColor,
    this.onBack,
    this.leading,
  });

  final ReaderChromeMode mode;
  final ValueChanged<ReaderChromeMode> onModeChanged;
  final List<Widget> actions;
  final List<ReaderSecondaryAction> secondaryActions;
  final Color? seasonColor;
  final VoidCallback? onBack;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    if (mode == ReaderChromeMode.hidden) {
      return const SizedBox.shrink(key: Key('reader-chrome-hidden'));
    }

    final cupertino = usesCupertinoGlass(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              if (leading != null)
                AdaptiveChromeSurface(
                  role: ChromeSurfaceRole.control,
                  seasonColor: seasonColor,
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox.square(dimension: 48, child: leading),
                )
              else
                _ReaderChromeButton(
                  key: const Key('reader-chrome-back'),
                  tooltip: 'Назад',
                  icon: cupertino
                      ? Icons.arrow_back_ios_new
                      : Icons.arrow_back_rounded,
                  iconSize: cupertino ? 18 : 22,
                  seasonColor: seasonColor,
                  onPressed: onBack ?? () => Navigator.maybePop(context),
                ),
              const Spacer(),
              ...actions.expand((action) => [action, const SizedBox(width: 8)]),
              if (secondaryActions.isNotEmpty)
                AdaptiveChromeSurface(
                  role: ChromeSurfaceRole.control,
                  seasonColor: seasonColor,
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox.square(
                    dimension: 48,
                    child: PopupMenuButton<ReaderSecondaryAction>(
                      key: const Key('reader-chrome-overflow'),
                      tooltip: 'Дзеянні чытання',
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (action) => action.onSelected(),
                      itemBuilder: (context) => [
                        for (final action in secondaryActions)
                          PopupMenuItem(
                            value: action,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(action.icon),
                              title: Text(action.label),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderChromeButton extends StatelessWidget {
  const _ReaderChromeButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.seasonColor,
    required this.onPressed,
    this.iconSize = 22,
  });

  final String tooltip;
  final IconData icon;
  final Color? seasonColor;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) => AdaptiveChromeSurface(
    role: ChromeSurfaceRole.control,
    seasonColor: seasonColor,
    borderRadius: BorderRadius.circular(24),
    child: SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
      ),
    ),
  );
}

/// Shared context header used above neutral reader documents.
class ReaderContextHeader extends StatelessWidget {
  const ReaderContextHeader({
    super.key,
    required this.title,
    this.accentColor,
    this.eyebrow,
    this.subtitle,
    this.metadata,
    this.details,
    this.onTitleTap,
    this.titleActionLabel,
    this.eyebrowStyle,
    this.subtitleStyle,
    this.actions = const [],
  });

  final String title;
  final Color? accentColor;
  final String? eyebrow;
  final String? subtitle;
  final String? metadata;
  final Widget? details;
  final VoidCallback? onTitleTap;
  final String? titleActionLabel;
  final TextStyle? eyebrowStyle;
  final TextStyle? subtitleStyle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentColor ?? cs.primary;
    final titleText = Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: cs.onSurface,
        fontSize: 27,
        fontWeight: FontWeight.w600,
        height: 1.18,
      ),
    );

    return SizedBox(
      width: double.infinity,
      child: Padding(
        key: const Key('reader-context-header'),
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((eyebrow ?? '').isNotEmpty)
              Text(
                eyebrow!,
                style:
                    eyebrowStyle ??
                    Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            if ((subtitle ?? '').isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                subtitle!,
                style:
                    subtitleStyle ??
                    Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
            ],
            const SizedBox(height: 9),
            if (onTitleTap == null)
              titleText
            else
              Semantics(
                button: true,
                label: titleActionLabel ?? 'Змяніць гадзіну: $title',
                child: InkWell(
                  key: const Key('reader-context-title-action'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTitleTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: titleText),
                        const SizedBox(width: 8),
                        Icon(Icons.keyboard_arrow_down_rounded, color: accent),
                      ],
                    ),
                  ),
                ),
              ),
            if ((metadata ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                metadata!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if (details != null) ...[const SizedBox(height: 8), details!],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class ReaderChoice<T> {
  const ReaderChoice({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool enabled;
}

/// Platform-adaptive choice sheet for reader context changes.
Future<T?> showReaderChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required List<ReaderChoice<T>> choices,
  T? selectedValue,
}) {
  final body = _ReaderChoiceSheet<T>(
    title: title,
    choices: choices,
    selectedValue: selectedValue,
  );
  if (usesCupertinoGlass(context)) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => body,
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (_) => body,
  );
}

class _ReaderChoiceSheet<T> extends StatelessWidget {
  const _ReaderChoiceSheet({
    required this.title,
    required this.choices,
    required this.selectedValue,
  });

  final String title;
  final List<ReaderChoice<T>> choices;
  final T? selectedValue;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          for (final choice in choices)
            ListTile(
              enabled: choice.enabled,
              leading: choice.icon == null ? null : Icon(choice.icon),
              title: Text(choice.label),
              subtitle: choice.subtitle == null ? null : Text(choice.subtitle!),
              trailing: choice.value == selectedValue
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: choice.enabled
                  ? () => Navigator.pop(context, choice.value)
                  : null,
            ),
        ],
      ),
    ),
  );
}
