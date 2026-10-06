import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// The loading language of the app: one look for every screen.
///
///   texts being opened at launch  → [AppLoadingState]
///   an update next to the content → [AppRefreshBar] (content stays)
///   nothing could be opened       → [AppErrorState]
///   a block that is still coming  → [LoadingPlaceholder]
///
/// The texts are on the device, so there is no «offline» state: being
/// offline changes nothing on a reading screen.
///
/// Everything here is calm on purpose: thin lines, the text colours of the
/// current theme, no percentages that are not real, no technical wording.

/// Shape of the quiet skeleton under a first load.
enum LoadingShape { none, text, tiles }

/// First load only — there is nothing to show yet.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    this.label,
    this.detail,
    this.shape = LoadingShape.none,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
  });

  final String? label;
  final String? detail;
  final LoadingShape shape;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      label: label ?? 'Загрузка',
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 132, child: AppProgressLine()),
            if (label != null) ...[
              const SizedBox(height: 14),
              ExcludeSemantics(
                child: Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: cs.outline),
              ),
            ],
            if (shape != LoadingShape.none) ...[
              const SizedBox(height: 26),
              LoadingPlaceholder(shape: shape),
            ],
          ],
        ),
      ),
    );
  }
}

/// A thin progress line. Determinate only when [value] is real progress.
class AppProgressLine extends StatelessWidget {
  const AppProgressLine({super.key, this.value, this.color});

  final double? value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // With «reduce motion» the line is a still hint instead of an animation.
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value ?? (still ? 0.35 : null),
        minHeight: 2,
        color: color ?? cs.onSurfaceVariant.withValues(alpha: 0.7),
        backgroundColor: cs.outlineVariant.withValues(alpha: 0.45),
      ),
    );
  }
}

/// Refresh of content that is already on screen. It always occupies the same
/// two pixels, so nothing moves when a refresh starts or ends.
class AppRefreshBar extends StatelessWidget {
  const AppRefreshBar({
    super.key,
    required this.active,
    this.value,
    this.color,
  });

  final bool active;
  final double? value;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 2,
    child: AnimatedOpacity(
      opacity: active ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: active
          ? Semantics(
              label: 'Абнаўленне',
              child: AppProgressLine(value: value, color: color),
            )
          : const SizedBox.expand(),
    ),
  );
}

/// Nothing to show and the request failed.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Не ўдалося загрузіць даныя',
    this.message,
    this.onRetry,
    this.retryLabel = 'Паўтарыць',
    this.icon,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final PhosphorIconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            icon ?? PhosphorIconsLight.cloudSlash,
            size: 44,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: text.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ],
      ),
    );
  }
}

/// Still outline of the content that is coming: lines of a text or rows of
/// a list. It does not shimmer — next to liturgical text a moving skeleton
/// would compete with reading — and it keeps the geometry of the real
/// content, so the page does not jump when the text arrives.
class LoadingPlaceholder extends StatelessWidget {
  const LoadingPlaceholder({
    super.key,
    this.shape = LoadingShape.text,
    this.count,
  });

  final LoadingShape shape;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = cs.onSurface.withValues(alpha: 0.07);
    Widget bar({double? width, double height = 12}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    if (shape == LoadingShape.none) return const SizedBox.shrink();
    if (shape == LoadingShape.tiles) {
      return ExcludeSemantics(
        child: Column(
          children: [
            for (var index = 0; index < (count ?? 4); index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    bar(width: 40, height: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(height: 13),
                          const SizedBox(height: 8),
                          bar(width: 120, height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    const widths = [1.0, 0.94, 0.98, 0.62, 1.0, 0.9, 0.96, 0.5];
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(width: 150, height: 15),
          const SizedBox(height: 18),
          for (var index = 0; index < (count ?? 8); index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: FractionallySizedBox(
                widthFactor: widths[index % widths.length],
                child: bar(),
              ),
            ),
        ],
      ),
    );
  }
}
