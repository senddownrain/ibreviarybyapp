import 'package:flutter/material.dart';

import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/theme/reader.dart';

/// Navigation/chrome density requested by the application shell.
///
/// The current shell can use [ReaderChromeModeScope] as a compatibility
/// bridge. A future four-tab shell can own the controller without changing
/// reader content or individual reader screens.
enum ReaderChromeMode { full, compact, hidden }

class ReaderChromeModeController extends ValueNotifier<ReaderChromeMode> {
  ReaderChromeModeController([super.value = ReaderChromeMode.full]);
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
    this.scrollController,
    this.scrollKey,
    this.maxContentWidth = 760,
    this.semanticLabel,
  });

  final Widget content;
  final Widget? contextHeader;
  final List<Widget> actions;
  final List<ReaderSecondaryAction> secondaryActions;
  final Color? seasonColor;
  final ReaderChromeMode chromeMode;
  final ValueChanged<ReaderChromeMode>? onChromeModeChanged;
  final VoidCallback? onBack;
  final ScrollController? scrollController;
  final PageStorageKey<String>? scrollKey;
  final double maxContentWidth;
  final String? semanticLabel;

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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          AmbientWash.hero(
            seasonColor: seasonColor ?? Theme.of(context).colorScheme.primary,
          ),
          CustomScrollView(
            key: scrollKey,
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  key: const Key('reader-top-inset'),
                  height: topInset,
                ),
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
              SliverFillRemaining(
                hasScrollBody: false,
                child: ReaderContentSurface(
                  maxContentWidth: maxContentWidth,
                  semanticLabel: semanticLabel,
                  child: content,
                ),
              ),
            ],
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
              onModeChanged: setMode,
            ),
          ),
        ],
      ),
    );
  }
}

class ReaderContentSurface extends StatelessWidget {
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
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    Widget result = ColoredBox(
      key: const Key('reader-content-surface'),
      color: ReaderTheme.of(context).surface,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 25, 22, 42 + bottom),
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
  });

  final ReaderChromeMode mode;
  final ValueChanged<ReaderChromeMode> onModeChanged;
  final List<Widget> actions;
  final List<ReaderSecondaryAction> secondaryActions;
  final Color? seasonColor;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    if (mode == ReaderChromeMode.hidden) {
      return SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _ReaderChromeButton(
              key: const Key('reader-chrome-restore'),
              tooltip: 'Вярнуць кіраванне',
              icon: Icons.fullscreen_exit_rounded,
              seasonColor: seasonColor,
              onPressed: () => onModeChanged(ReaderChromeMode.compact),
            ),
          ),
        ),
      );
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
    this.onTitleTap,
    this.actions = const [],
  });

  final String title;
  final Color? accentColor;
  final String? eyebrow;
  final String? subtitle;
  final String? metadata;
  final VoidCallback? onTitleTap;
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

    return Padding(
      key: const Key('reader-context-header'),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((eyebrow ?? '').isNotEmpty)
            Text(
              eyebrow!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          if ((subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              label: 'Змяніць гадзіну: $title',
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
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: actions),
          ],
        ],
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
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => body,
    );
  }
  return showModalBottomSheet<T>(
    context: context,
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
