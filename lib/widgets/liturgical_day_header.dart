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

  /// Contextual-discovery slots right below the date row and below the
  /// «Іншыя варыянты» control; empty when no hint is shown.
  final Widget? dateHint;
  final Widget? variantsHint;

  @override
  Widget build(BuildContext context) {
    final p = presentation;
    final cs = Theme.of(context).colorScheme;
    final ink = cs.onSurface;
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
          IntrinsicHeight(
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
                      LayoutBuilder(
                        builder: (context, metadataConstraints) {
                          final metadataStyle = Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontSize: 14.5,
                                color: cs.onSurfaceVariant,
                              );
                          final metadataSpan = TextSpan(
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
                          );
                          final metadataLabel = Text.rich(
                            metadataSpan,
                            key: Key('$keyPrefix-day-metadata'),
                            style: metadataStyle,
                          );
                          if (!showVariants) return metadataLabel;

                          // Retain the same key for the product tour, contextual
                          // hints and existing selector tests.
                          final variantsButton = TextButton.icon(
                            key: Key('$keyPrefix-alternatives-control'),
                            onPressed: onVariants,
                            style: TextButton.styleFrom(
                              foregroundColor: ink,
                              backgroundColor: cs.onSurface.withValues(
                                alpha: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.10
                                    : 0.06,
                              ),
                              side: BorderSide(
                                color: cs.outlineVariant.withValues(alpha: 0.6),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.padded,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: Icon(
                              Icons.layers_outlined,
                              size: 17,
                              color: cs.onSurfaceVariant,
                            ),
                            label: const Text('Варыянты'),
                          );
                          final textPainter = TextPainter(
                            text: TextSpan(
                              style: metadataStyle,
                              children: metadataSpan.children,
                            ),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                            maxLines: 1,
                          )..layout();
                          final metadataWidth = textPainter.width;
                          textPainter.dispose();

                          // Keep the button beside a short weekday. On narrow
                          // screens or with longer rank/year metadata, place it
                          // on the next line, still aligned to the right.
                          if (metadataWidth + 148 <=
                              metadataConstraints.maxWidth) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: metadataLabel),
                                const SizedBox(width: 10),
                                variantsButton,
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              metadataLabel,
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: variantsButton,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
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
