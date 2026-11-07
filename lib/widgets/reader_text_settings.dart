import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/reader_alignment.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';

/// Shared by Settings and the live reader sheet; Riverpod owns the selection.
class ReaderFontSelector extends ConsumerWidget {
  const ReaderFontSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(settingsProvider.select((s) => s.fontFamily));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          // FormField's initialValue does not follow external provider updates.
          key: ValueKey('reader-family-$family'),
          initialValue: family,
          isExpanded: true,
          itemHeight: null,
          decoration: const InputDecoration(labelText: 'Шрыфт чытання'),
          selectedItemBuilder: (context) => [
            for (final option in kAvailableReaderFonts)
              Text(option.label, overflow: TextOverflow.ellipsis),
          ],
          items: [
            for (final option in kAvailableReaderFonts)
              DropdownMenuItem(
                value: option.id,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    option.label,
                    style: ReaderTheme.of(context).body(16, family: option.id),
                  ),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              ref.read(settingsProvider.notifier).setFontFamily(value);
            }
          },
        ),
        if (family == ReaderFontFamily.literata)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'рэкамендаваны',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class ReaderAlignmentSelector extends ConsumerWidget {
  const ReaderAlignmentSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingsProvider.select((s) => s.textAlignment));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Выраўноўванне тэксту',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // At large system scales keep the full labels without squeezing taps.
            final stacked =
                constraints.maxWidth <
                MediaQuery.textScalerOf(context).scale(240);
            final buttons = [
              for (final mode in ReaderAlignment.values)
                Semantics(
                  selected: mode == value,
                  inMutuallyExclusiveGroup: true,
                  child: OutlinedButton.icon(
                    key: ValueKey('reader-alignment-${mode.name}'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      backgroundColor: mode == value
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                    onPressed: () => ref
                        .read(settingsProvider.notifier)
                        .setTextAlignment(mode),
                    icon: Icon(
                      mode == ReaderAlignment.start
                          ? Icons.format_align_left
                          : Icons.format_align_justify,
                      size: 20,
                    ),
                    label: Text(mode.label, textAlign: TextAlign.center),
                  ),
                ),
            ];
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buttons[0],
                      const SizedBox(height: 6),
                      buttons[1],
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: buttons[0]),
                      const SizedBox(width: 6),
                      Expanded(child: buttons[1]),
                    ],
                  );
          },
        ),
      ],
    );
  }
}

class ReaderTextSettings extends ConsumerWidget {
  const ReaderTextSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return ExpansionTile(
      key: const PageStorageKey('settings-text'),
      title: const Text('Тэкст'),
      subtitle: const Text('Шрыфт, памер і выраўноўванне'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 16),
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Памер шрыфту · ${readerFontScalePercent(settings.fontSize)}%',
          ),
        ),
        Slider.adaptive(
          value: settings.fontSize,
          min: kMinReaderFontSize,
          max: kMaxReaderFontSize,
          divisions: 11,
          label: '${readerFontScalePercent(settings.fontSize)}%',
          onChanged: ref.read(settingsProvider.notifier).setFontSize,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Пан — маё святло і маё збаўленне.',
            style: ReaderTheme.of(
              context,
            ).body(settings.fontSize, family: settings.fontFamily),
          ),
        ),
        const SizedBox(height: 18),
        const ReaderFontSelector(key: Key('settings-reader-font')),
        const SizedBox(height: 18),
        const ReaderAlignmentSelector(),
      ],
    );
  }
}
