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
    final metadataSuffix = (metadata ?? p.metadata)
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

    // _place and badges can independently identify the same diocese.
    // Diocesan identity is represented only by chips, never repeated below
    // as a full locality subtitle. Keep any non-diocesan place text.
    final placeParts = p.place
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final placeBadges = <String>{};
    final otherPlaces = <String>[];
    for (final place in placeParts) {
      final badge = _dioceseBadgeForPlace(place);
      if (badge != null) {
        placeBadges.add(badge);
      } else {
        otherPlaces.add(place);
      }
    }
    // The union badges explicitly indicate which dioceses have this option,
    // so they take priority over inferred locality labels.
    final dioceseChips = p.badges.isNotEmpty ? p.badges.toSet() : placeBadges;

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
                      LiturgicalHeadingText(
                        p.title,
                        key: Key('$keyPrefix-celebration-title'),
                        maxWidth: constraints.maxWidth - 18,
                        style: ReaderTheme.of(context)
                            .displayTitle(29)
                            .copyWith(color: cs.onSurface, height: 1.18),
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (dioceseChips.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          key: Key('$keyPrefix-celebration-dioceses'),
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final badge in dioceseChips)
                              Chip(
                                label: Text(badge),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                      ],
                      if (otherPlaces.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          otherPlaces.join(', '),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onToday != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('$keyPrefix-today'),
                onPressed: onToday,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Сёння'),
              ),
            ),
          if (showVariants) ...[
            const SizedBox(height: 2),
            TextButton(
              key: Key('$keyPrefix-alternatives-control'),
              style: TextButton.styleFrom(
                foregroundColor: ink,
                textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                minimumSize: const Size(48, 48),
              ),
              onPressed: onVariants,
              child: const Row(
                children: [
                  Expanded(child: Text('Іншыя варыянты')),
                  Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
            ?variantsHint,
          ],
        ],
      ),
    );
  }
}

/// Full labels in liturgical content are normalized to short UI badges.
String? _dioceseBadgeForPlace(String place) {
  final normalized = place.trim().toLowerCase();
  for (final entry in kDioceseNames.entries) {
    if (normalized == entry.value.toLowerCase() ||
        normalized == kDioceseShortNames[entry.key]?.toLowerCase() ||
        normalized == kDioceseBadges[entry.key]?.toLowerCase()) {
      return kDioceseBadges[entry.key];
    }
  }
  return null;
}
