import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/reader_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Shared by Settings and the contextual appearance sheet.
class ReaderFontPicker extends ConsumerWidget {
  const ReaderFontPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(settingsProvider.select((s) => s.fontFamily));
    return DropdownButtonFormField<String>(
      key: ValueKey('reader-font-$family'),
      initialValue: family,
      isExpanded: true,
      itemHeight: null,
      decoration: const InputDecoration(labelText: 'Шрыфт чытання'),
      selectedItemBuilder: (context) => [
        for (final option in kAvailableReaderFonts)
          Text(option.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
      items: [
        for (final option in kAvailableReaderFonts)
          DropdownMenuItem(
            value: option.id,
            child: Text(
              option.label,
              style: ReaderTheme.of(context).body(16, family: option.id),
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          ref.read(settingsProvider.notifier).setFontFamily(value);
        }
      },
    );
  }
}

class ReaderAlignmentControl extends ConsumerWidget {
  const ReaderAlignmentControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingsProvider.select((s) => s.textAlignment));
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Выраўноўванне тэксту',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final alignment in ReaderTextAlignment.values)
                Expanded(
                  child: Semantics(
                    key: ValueKey('reader-alignment-${alignment.name}'),
                    label: alignment.label,
                    excludeSemantics: true,
                    onTap: () => ref
                        .read(settingsProvider.notifier)
                        .setTextAlignment(alignment),
                    selected: alignment == value,
                    button: true,
                    inMutuallyExclusiveGroup: true,
                    child: Tooltip(
                      message: alignment.label,
                      excludeFromSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Material(
                          color: alignment == value
                              ? cs.primaryContainer
                              : cs.surfaceContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: alignment == value
                                  ? cs.primary
                                  : cs.outlineVariant,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setTextAlignment(alignment),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      alignment == ReaderTextAlignment.start
                                          ? PhosphorIconsRegular.textAlignLeft
                                          : PhosphorIconsRegular
                                                .textAlignJustify,
                                      size: 22,
                                      color: alignment == value
                                          ? cs.onPrimaryContainer
                                          : cs.onSurface,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      alignment.label,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: alignment == value
                                                ? cs.onPrimaryContainer
                                                : cs.onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
