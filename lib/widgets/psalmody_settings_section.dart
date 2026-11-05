import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/widgets/psalmody_mode_selector.dart';

class PsalmodySettingsSection extends ConsumerWidget {
  const PsalmodySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Псальмодыя', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      PsalmodyModeSelector(
        value: ref.watch(settingsProvider).psalmodyMode,
        onChanged: ref.read(settingsProvider.notifier).setPsalmodyMode,
      ),
    ],
  );
}
