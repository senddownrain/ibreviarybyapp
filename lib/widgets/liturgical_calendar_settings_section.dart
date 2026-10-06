import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/ordo/definitions.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';

/// Settings → «Літургічны каляндар»: one or several dioceses.
class LiturgicalCalendarSettingsSection extends ConsumerWidget {
  const LiturgicalCalendarSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(dioceseSelectionProvider);
    final notifier = ref.read(dioceseSelectionProvider.notifier);
    final theme = Theme.of(context);
    return Column(
      key: const Key('settings-liturgical-calendar'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Літургічны каляндар', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Паказваць святкаванні выбраных дыяцэзій у Літургіі гадзін і '
          'календары.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text('Дыяцэзіі', style: theme.textTheme.labelLarge),
        for (final id in kDioceses)
          CheckboxListTile.adaptive(
            key: Key('settings-diocese-$id'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: selection.contains(id),
            title: Text(kDioceseShortNames[id]!),
            subtitle: selection.isMultiple && selection.primary == id
                ? const Text('Асноўная: яе варыянт адкрываецца першым')
                : null,
            secondary:
                selection.isMultiple &&
                    selection.contains(id) &&
                    selection.primary != id
                ? IconButton(
                    key: Key('settings-diocese-primary-$id'),
                    tooltip: 'Зрабіць асноўнай',
                    onPressed: () => notifier.setPrimary(id),
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.star,
                      size: 20,
                    ),
                  )
                : selection.isMultiple && selection.primary == id
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: PhosphorIcon(PhosphorIconsFill.star, size: 20),
                  )
                : null,
            onChanged: (_) {
              if (!notifier.toggle(id)) {
                ScaffoldMessenger.maybeOf(context)
                  ?..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Патрэбна хоць адна дыяцэзія.'),
                    ),
                  );
              }
            },
          ),
      ],
    );
  }
}
