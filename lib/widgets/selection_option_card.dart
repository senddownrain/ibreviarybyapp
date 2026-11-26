import 'package:flutter/material.dart';

/// A full-width, accessible alternative to chips and plain list rows for
/// choices that benefit from a clear selected state.
class SelectionOptionCard extends StatelessWidget {
  const SelectionOptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.accentColor,
    this.compact = false,
    this.dense = false,
    this.titleFontSize,
    this.subtitleFontSize,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final Color? accentColor;
  final bool compact;
  final bool dense;

  /// Larger text for prominent choices; null keeps the theme sizes.
  final double? titleFontSize;
  final double? subtitleFontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Liturgical white and other pale seasonal colors still need to remain
    // legible as borders and icons on a light sheet.
    final accent = Color.lerp(
      accentColor ?? colors.primary,
      colors.onSurface,
      0.24,
    )!;
    final selectedFill = Color.alphaBlend(
      accent.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.16 : 0.09,
      ),
      colors.surfaceContainerHigh,
    );
    final radius = BorderRadius.circular(compact || dense ? 12 : 18);

    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? selectedFill : colors.surfaceContainerLow,
          borderRadius: radius,
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.72)
                : colors.outlineVariant,
            width: selected && !compact && !dense ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 16,
                vertical: compact || dense ? 10 : 14,
              ),
              child: compact
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: selected ? colors.primary : colors.outline,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        if (leading != null) ...[
                          IconTheme(
                            data: IconThemeData(
                              color: selected
                                  ? accent
                                  : colors.onSurfaceVariant,
                              size: 22,
                            ),
                            child: leading!,
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colors.onSurface,
                                  fontSize: titleFontSize,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              if (subtitle case final subtitle?) ...[
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontSize: subtitleFontSize,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            key: ValueKey(selected),
                            color: selected ? accent : colors.outline,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
