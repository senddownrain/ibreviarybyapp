import 'package:flutter/material.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/providers/liturgical_day_presentation_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final p = presentation;
    final cs = Theme.of(context).colorScheme;
    final ink = cs.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(sectionTitle, style: ReaderTheme.of(context).documentTitle()),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              key: Key('$keyPrefix-previous-day'),
              tooltip: 'Папярэдні дзень',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: p.date.isAfter(kCalendarFirstDate) ? onPrevious : null,
              icon: const Icon(Icons.chevron_left, size: 22),
            ),
            Expanded(
              child: TextButton(
                key: Key('$keyPrefix-date-action'),
                style: TextButton.styleFrom(
                  foregroundColor: ink,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: onDateTap,
                child: Text(
                  p.dateLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            IconButton(
              key: Key('$keyPrefix-next-day'),
              tooltip: 'Наступны дзень',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: p.date.isBefore(kCalendarLastDate) ? onNext : null,
              icon: const Icon(Icons.chevron_right, size: 22),
            ),
          ],
        ),
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
                    Text(
                      p.title,
                      key: Key('$keyPrefix-celebration-title'),
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
                            text: p.weekday,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                          ),
                          TextSpan(
                            text: (metadata ?? p.metadata).replaceFirst(
                              p.weekday,
                              '',
                            ),
                          ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (p.badges.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final badge in p.badges)
                            Chip(label: Text(badge)),
                        ],
                      ),
                    ],
                    if (p.place.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        p.place,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
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
        ],
      ],
    );
  }
}
