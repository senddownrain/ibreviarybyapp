import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mybrev_flutter/providers/songs_provider.dart';
import 'package:mybrev_flutter/widgets/adaptive_segmented_control.dart';

/// Songbook display preferences (MyBrev `SongSettings`).
Future<void> showSongSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (_) => const SongSettingsPanel(),
    );

class SongSettingsPanel extends ConsumerWidget {
  const SongSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(songPreferencesProvider);
    final notifier = ref.read(songPreferencesProvider.notifier);
    final theme = Theme.of(context);
    final heading = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          key: const Key('song-settings-panel'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Налады спеўніка',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text('Спіс спеваў', style: heading),
            SwitchListTile.adaptive(
              key: const Key('song-compact-list-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Кампактны спіс'),
              subtitle: const Text('Карацейшыя радкі без тэгаў'),
              value: prefs.compactList,
              onChanged: notifier.setCompactList,
            ),
            const Divider(height: 24),
            Text('Акорды', style: heading),
            SwitchListTile.adaptive(
              key: const Key('song-show-chords-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Паказваць акорды'),
              subtitle: const Text('У тэксце спеваў'),
              value: prefs.showChords,
              onChanged: notifier.setShowChords,
            ),
            const SizedBox(height: 8),
            Text('Пазіцыя акордаў', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Semantics(
              container: true,
              label: 'Пазіцыя акордаў',
              child: AdaptiveSegmentedControl<SongChordLayout>(
                key: const Key('song-chord-layout'),
                value: prefs.chordLayout,
                showSelectedIcon: false,
                segments: [
                  for (final layout in SongChordLayout.values)
                    AdaptiveSegment(
                      value: layout,
                      label: Text(layout.label, textAlign: TextAlign.center),
                    ),
                ],
                onChanged: notifier.setChordLayout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
