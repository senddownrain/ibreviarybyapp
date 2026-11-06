import 'package:flutter/material.dart';
import 'package:mybrev_flutter/widgets/liturgical_selector_components.dart';

import 'package:mybrev_flutter/models/mass_reading_sets.dart';

/// «3 варыянты» — Belarusian plural of «варыянт» (as the web).
String massSetVariantWord(int count) {
  final lastTwo = count % 100;
  final last = count % 10;
  if (last == 1 && lastTwo != 11) return 'варыянт';
  if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
    return 'варыянты';
  }
  return 'варыянтаў';
}

/// Compact choice between the Mass reading sets of one celebration
/// («Св. Імша ў вігілію» / «Св. Імша ўдзень», the three Masses of
/// Christmas, the procession and the Mass of Palm Sunday). Labels come from
/// the source. Shown only when the celebration has more than one set.
class MassSetSelector extends StatelessWidget {
  const MassSetSelector({
    super.key,
    required this.sets,
    required this.selectedId,
    required this.onSelected,
    this.accentColor,
  });

  final List<MassReadingSet> sets;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    if (sets.length < 2) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      container: true,
      label: 'Набор чытанняў',
      child: Padding(
        key: const Key('readings-mass-set-selector'),
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LiturgicalSelectorHeading('ЧЫТАННІ ІМШЫ'),
            const SizedBox(height: 2),
            Text(
              'Магчымасці цэлебрацыі',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final set in sets)
                  ChoiceChip(
                    key: ValueKey('readings-mass-set-${set.id}'),
                    label: Text(set.label),
                    selected: set.id == selectedId,
                    showCheckmark: true,
                    selectedColor: cs.surfaceContainerHigh,
                    side: BorderSide(
                      color: set.id == selectedId
                          ? cs.outline
                          : cs.outlineVariant,
                    ),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: set.id == selectedId
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    onSelected: (_) {
                      if (set.id != selectedId) onSelected(set.id);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
