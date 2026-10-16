import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';

class CatalogYearSelector extends StatelessWidget {
  const CatalogYearSelector({
    super.key,
    required this.year,
    required this.onChanged,
  });

  final int year;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('picker-year-previous'),
          tooltip: 'Папярэдні год',
          onPressed: year > kCalendarFirstDate.year
              ? () => onChanged(year - 1)
              : null,
          icon: const PhosphorIcon(PhosphorIconsRegular.caretLeft, size: 18),
        ),
        TextButton(
          key: const Key('picker-year'),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () async {
            final picked = await showModalBottomSheet<int>(
              context: context,
              useRootNavigator: true,
              useSafeArea: true,
              isScrollControlled: true,
              builder: (_) => _CatalogYearGrid(selected: year),
            );
            if (picked != null) onChanged(picked);
          },
          child: Text(
            '$year',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
        ),
        IconButton(
          key: const Key('picker-year-next'),
          tooltip: 'Наступны год',
          onPressed: year < kCalendarLastDate.year
              ? () => onChanged(year + 1)
              : null,
          icon: const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 18),
        ),
      ],
    );
  }
}

class _CatalogYearGrid extends StatelessWidget {
  const _CatalogYearGrid({required this.selected});
  final int selected;

  @override
  Widget build(BuildContext context) {
    final years = [
      for (var y = kCalendarFirstDate.year; y <= kCalendarLastDate.year; y++) y,
    ];
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final columns = ((MediaQuery.sizeOf(context).width - 32) / (76 * scale))
        .floor()
        .clamp(2, 6);
    final rowHeight = 40.0 + 20 * scale;
    final row = years.indexOf(selected) ~/ columns;
    final controller = ScrollController(
      initialScrollOffset: (row - 1).clamp(0, 1000) * rowHeight,
    );
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Год', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (MediaQuery.sizeOf(context).height * 0.65).clamp(
                  100,
                  rowHeight * 5,
                ),
              ),
              child: GridView.builder(
                key: const Key('picker-year-grid'),
                controller: controller,
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: rowHeight,
                ),
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final isSelected = year == selected;
                  return Padding(
                    padding: const EdgeInsets.all(4),
                    child: isSelected
                        ? FilledButton(
                            key: Key('picker-year-$year'),
                            onPressed: () => Navigator.pop(context, year),
                            child: Text('$year'),
                          )
                        : OutlinedButton(
                            key: Key('picker-year-$year'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: year == DateTime.now().year
                                  ? cs.primary
                                  : null,
                            ),
                            onPressed: () => Navigator.pop(context, year),
                            child: Text('$year'),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
