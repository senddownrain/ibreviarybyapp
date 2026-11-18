import 'package:flutter/material.dart';
import 'package:mybrev_flutter/constants/prayer_category_icons.dart';
import 'package:mybrev_flutter/widgets/category_icon.dart';

/// «Значок катэгорыі»: shows the current icon; tapping opens a compact sheet
/// with the 48 icons in four groups. Nothing changes until an icon is chosen,
/// and the choice only becomes part of the category when the form is saved.
class CategoryIconField extends StatelessWidget {
  const CategoryIconField({
    super.key,
    required this.iconKey,
    required this.onChanged,
  });

  final String iconKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spec = categoryIconSpec(iconKey);
    return Semantics(
      button: true,
      label: 'Значок катэгорыі: ${spec?.label ?? 'не абраны'}',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('category-icon-field'),
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final chosen = await showCategoryIconPicker(context, iconKey);
          if (chosen != null) onChanged(chosen);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: CategoryIcon(
                  iconKey,
                  size: 26,
                  color: cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Значок катэгорыі',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      spec?.label ?? 'Абраць значок',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Returns the chosen key, or null when dismissed (the saved value stays).
Future<String?> showCategoryIconPicker(BuildContext context, String current) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) =>
            _IconPickerSheet(current: current, controller: controller),
      ),
    );

class _IconPickerSheet extends StatelessWidget {
  const _IconPickerSheet({required this.current, required this.controller});
  final String current;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      key: const Key('category-icon-picker'),
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(
          'Значок катэгорыі',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        for (final group in kCategoryIconGroups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Text(
              group.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 6.0;
              final columns = constraints.maxWidth >= 520 ? 6 : 4;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final icon in kCategoryIcons.where(
                    (icon) => icon.group == group.id,
                  ))
                    _IconOption(
                      spec: icon,
                      width: width.floorToDouble(),
                      selected: icon.key == current,
                      onTap: () => Navigator.pop(context, icon.key),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.spec,
    required this.width,
    required this.selected,
    required this.onTap,
  });
  final CategoryIconSpec spec;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('category-icon-option-${spec.key}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: width,
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? cs.secondaryContainer : null,
            border: Border.all(
              color: selected ? cs.primary : Colors.transparent,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CategoryIcon(
                spec.key,
                size: 26,
                color: selected ? cs.onSecondaryContainer : cs.onSurface,
              ),
              const SizedBox(height: 6),
              Text(
                spec.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0,
                  height: 1.15,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
