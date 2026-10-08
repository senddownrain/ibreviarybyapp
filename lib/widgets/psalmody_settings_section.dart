import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';

/// Shared by global settings and the Office's local Aa panel.
class PsalmodySettingsSection extends ConsumerWidget {
  const PsalmodySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Псальмодыя', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Размяшчэнне вершаў',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final layout in PsalmVerseLayout.values)
              ChoiceChip(
                key: ValueKey('psalm-layout-${layout.name}'),
                label: Text(
                  layout == PsalmVerseLayout.alternatingIndent
                      ? 'Чаргаванне'
                      : 'Па адным краі',
                ),
                selected: settings.psalmVerseLayout == layout,
                onSelected: (_) => notifier.setPsalmVerseLayout(layout),
              ),
          ],
        ),
        SwitchListTile.adaptive(
          key: const Key('psalm-marker-break'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Перанос пасля * і †'),
          value:
              settings.psalmMarkerBreakMode ==
              PsalmMarkerBreakMode.breakAfterMarker,
          onChanged: (value) => notifier.setPsalmMarkerBreakMode(
            value
                ? PsalmMarkerBreakMode.breakAfterMarker
                : PsalmMarkerBreakMode.inline,
          ),
        ),
      ],
    );
  }
}
