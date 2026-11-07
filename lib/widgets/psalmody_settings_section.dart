import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/widgets/psalmody_mode_selector.dart';
import 'package:mybrev_flutter/widgets/psalmody_example.dart';

class PsalmodySettingsSection extends ConsumerWidget {
  const PsalmodySettingsSection({super.key, this.showExample = true});

  final bool showExample;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final selector = PsalmodyModeSelector(
            key: showExample
                ? const Key('settings-psalmody-modes')
                : const Key('text-scale-psalmody-modes'),
            value: ref.watch(settingsProvider).psalmodyMode,
            onChanged: ref.read(settingsProvider.notifier).setPsalmodyMode,
          );
          final title = Text(
            'Псальмодыя',
            style: Theme.of(context).textTheme.titleMedium,
          );
          if (constraints.maxWidth >=
              MediaQuery.textScalerOf(context).scale(440)) {
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                SizedBox(width: 216, child: selector),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 8), selector],
          );
        },
      ),
      if (showExample) ...[const SizedBox(height: 18), const PsalmodyExample()],
    ],
  );
}
