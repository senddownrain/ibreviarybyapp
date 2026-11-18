import 'package:flutter/material.dart';
import 'package:mybrev_flutter/widgets/liturgical_date_navigation_row.dart';
import 'package:mybrev_flutter/widgets/liturgical_heading_text.dart';
import 'package:mybrev_flutter/providers/liturgical_day_presentation_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';

/// Shared hierarchy and typography for both daily sections.
class LiturgicalDayHeader extends StatelessWidget {
  const LiturgicalDayHeader({
    super.key,
    required this.sectionTitle,
    required this.presentation,
    required this.onDateTap,
    required this.onPrevious,
    required this.onNext,
    required this.onVariants,
    required this.keyPrefix,
    this.onToday,
    this.metadata,
    this.showVariants = true,
    this.dateHint,
    this.variantsHint,
  });

  final String sectionTitle;
  final String keyPrefix;
  final LiturgicalDayPresentation presentation;
  final VoidCallback onDateTap;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onVariants;
  final VoidCallback? onToday;
  final String? metadata;
  final bool showVariants;

  /// Contextual-discovery slots below date navigation and below the
  /// tappable celebration area; empty when no hint is shown.
  final Widget? dateHint;
  final Widget? variantsHint;

  @override
  Widget build(BuildContext context) {
    final p = presentation;
    final cs = Theme.of(context).colorScheme;
    // Reading-year metadata is supplied explicitly by ReadingsScreen. Do not
    // repeat the psalter week here: it belongs inside the individual Hour.
    final metadataSuffix = (metadata ?? '')
        .replaceFirst(p.weekday, '')
        .replaceFirst(RegExp(r'^\s*·\s*'), '')
        .trim();
    final rank = p.rank.trim();
    // A Sunday or an ordinary weekday already has its rank in the day label.
    final showRank =
        rank.isNotEmpty &&
        rank != p.weekday &&
        rank != 'Будні дзень' &&
        rank != 'Будзень';

    // A rank (feast/memorial/solemnity) is the important metadata for a
    // celebration. For an ordinary day, emphasize the weekday instead.
    final emphasizedMetadata = showRank ? rank : p.weekday;
    final quietMetadata = [
      if (showRank) p.weekday,
      if (metadataSuffix.isNotEmpty) metadataSuffix,
    ];
    final metadataTail = quietMetadata.isEmpty
        ? ''
        : ' · ${quietMetadata.join(' · ')}';

    // Display local diocesan context in one quiet line ABOVE the celebration
    // title. Explicit union badges take precedence over _place (which may
    // describe a broader source); neither is shown for a common weekday.
    final diocesanLabels = (p.badges.isNotEmpty
            ? p.badges.map(_fullDioceseLabel)
            : p.place
                .split(',')
                .map((label) => _fullDioceseLabel(label.trim())))
        .where((label) => label.isNotEmpty)
        .toSet()
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiturgicalHeadingText(
            sectionTitle,
            style: ReaderTheme.of(context).documentTitle(),
          ),
          const SizedBox(height: 12),
          LiturgicalDateNavigationRow(
            date: p.date,
            keyPrefix: keyPrefix,
            onDateTap: onDateTap,
            onPrevious: onPrevious,
            onNext: onNext,
            onToday: onToday,
          ),
          ?dateHint,
          const SizedBox(height: 12),
          _CelebrationSelectionSurface(
            keyPrefix: keyPrefix,
            enabled: showVariants,
            onTap: onVariants,
            semanticsLabel: 'Іншыя варыянты літургічнага дня: ${p.title}',
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    key: Key('$keyPrefix-celebration-accent'),
                    duration: const Duration(milliseconds: 300),
                    width: 4,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: p.accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (diocesanLabels.isNotEmpty) ...[
                          Text(
                            diocesanLabels.join(' · '),
                            key: Key('$keyPrefix-celebration-dioceses'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 12.5,
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        LiturgicalHeadingText(
                          p.title,
                          key: Key('$keyPrefix-celebration-title'),
                          maxWidth: constraints.maxWidth - 18,
                          style: ReaderTheme.of(context)
                              .displayTitle(29)
                              .copyWith(color: cs.onSurface, height: 1.18),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text.rich(
                                key: Key('$keyPrefix-day-metadata'),
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: emphasizedMetadata,
                                      style: Theme.of(context).textTheme.titleMedium
                                          ?.copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: cs.onSurface,
                                          ),
                                    ),
                                    TextSpan(text: metadataTail),
                                  ],
                                ),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontSize: 14.5,
                                      color: cs.onSurfaceVariant,
                                    ),
                              ),
                            ),
                            if (showVariants) ...[
                              const SizedBox(width: 12),
                              // Not a separate button: the entire celebration
                              // surface opens the variants selector.
                              Icon(
                                Icons.edit_outlined,
                                key: Key('$keyPrefix-celebration-edit-icon'),
                                size: 19,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showVariants) ...[
            ?variantsHint,
          ],
        ],
      ),
    );
  }
}

/// The celebration itself is the selector. Its title stays full-width,
/// while a small edit glyph quietly signals the affordance at the bottom.
/// Keep the stable key on the entire interactive surface for the product tour.
class _CelebrationSelectionSurface extends StatelessWidget {
  const _CelebrationSelectionSurface({
    required this.keyPrefix,
    required this.enabled,
    required this.onTap,
    required this.semanticsLabel,
    required this.child,
  });

  final String keyPrefix;
  final bool enabled;
  final VoidCallback onTap;
  final String semanticsLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('$keyPrefix-alternatives-control'),
          onTap: onTap,
          borderRadius: radius,
          // Make the entire day respond to a press, without turning the
          // reading-style heading into a prominent outlined button.
          overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.pressed)) {
              return ink.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.focused) ||
                states.contains(WidgetState.hovered)) {
              return ink.withValues(alpha: 0.04);
            }
            return null;
          }),
          child: Ink(
            decoration: BoxDecoration(
              color: ink.withValues(alpha: dark ? 0.035 : 0.025),
              borderRadius: radius,
            ),
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Accepts either a union badge or a document locality and returns a single
/// readable Belarusian diocesan name without a chip or a duplicate caption.
String _fullDioceseLabel(String label) {
  if (label.isEmpty) return '';
  final normalized = label.toLowerCase();
  for (final entry in kDioceseNames.entries) {
    final id = entry.key;
    if (normalized == entry.value.toLowerCase() ||
        normalized == kDioceseShortNames[id]?.toLowerCase() ||
        normalized == kDioceseBadges[id]?.toLowerCase()) {
      return entry.value;
    }
  }
  return label;
}
