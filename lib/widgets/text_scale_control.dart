import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Circular entry point for the shared reader-size panel.
class TextScaleControl extends ConsumerWidget {
  const TextScaleControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(
      settingsProvider.select((settings) => settings.fontSize),
    );
    final fontFamily = ref.watch(
      settingsProvider.select((settings) => settings.fontFamily),
    );
    return Semantics(
      button: true,
      label:
          'Выгляд тэксту, ${readerFontScalePercent(fontSize)} адсоткаў, '
          '${readerFontOption(fontFamily).label}',
      child: AdaptiveChromeSurface(
        role: ChromeSurfaceRole.control,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox.square(
          dimension: 48,
          child: IconButton(
            key: const Key('text-scale-open'),
            tooltip: 'Выгляд тэксту',
            onPressed: () {
              HapticFeedback.selectionClick();
              _showTextScalePanel(context);
            },
            icon: const PhosphorIcon(PhosphorIconsRegular.textAa, size: 22),
          ),
        ),
      ),
    );
  }
}

Future<void> _showTextScalePanel(BuildContext context) {
  if (usesCupertinoGlass(context)) {
    return showCupertinoModalPopup<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (_) => const Material(
        color: Colors.transparent,
        child: SafeArea(top: false, child: _TextScalePanel()),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (_) => const SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: 6),
      child: _TextScalePanel(),
    ),
  );
}

class _TextScalePanel extends ConsumerWidget {
  const _TextScalePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(
      settingsProvider.select((settings) => settings.fontSize),
    );
    final fontFamily = ref.watch(
      settingsProvider.select((settings) => settings.fontFamily),
    );
    final notifier = ref.read(settingsProvider.notifier);
    final percent = readerFontScalePercent(fontSize);
    final canDecrease = fontSize > kMinReaderFontSize + 0.01;
    final canIncrease = fontSize < kMaxReaderFontSize - 0.01;
    final cs = Theme.of(context).colorScheme;
    final accent = GlassTokens.of(context).accentOnSurface(cs.tertiary);

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: AdaptiveChromeSurface(
            role: ChromeSurfaceRole.group,
            seasonColor: cs.tertiary,
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIconsRegular.textAa,
                      size: 23,
                      color: accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Выгляд тэксту',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    AnimatedContainer(
                      key: const Key('text-scale-value'),
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.tertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$percent%',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Закрыць',
                      onPressed: () => Navigator.pop(context),
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.x,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ScaleStepButton(
                      key: const Key('text-scale-decrease'),
                      tooltip: 'Паменшыць тэкст',
                      icon: PhosphorIconsBold.minus,
                      onPressed: canDecrease ? notifier.decreaseFontSize : null,
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 5,
                          activeTrackColor: accent,
                          inactiveTrackColor: cs.onSurfaceVariant.withValues(
                            alpha: 0.16,
                          ),
                          thumbColor: accent,
                          overlayColor: cs.tertiary.withValues(alpha: 0.12),
                        ),
                        child: Slider.adaptive(
                          key: const Key('text-scale-slider'),
                          value: fontSize,
                          min: kMinReaderFontSize,
                          max: kMaxReaderFontSize,
                          divisions: 11,
                          label: '$percent%',
                          onChanged: notifier.setFontSize,
                          semanticFormatterCallback: (value) =>
                              '${readerFontScalePercent(value)} адсоткаў',
                        ),
                      ),
                    ),
                    _ScaleStepButton(
                      key: const Key('text-scale-increase'),
                      tooltip: 'Павялічыць тэкст',
                      icon: PhosphorIconsBold.plus,
                      onPressed: canIncrease ? notifier.increaseFontSize : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: cs.outlineVariant),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Шрыфт чытання',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in kAvailableReaderFonts)
                        ChoiceChip(
                          key: ValueKey('reader-font-${option.id}'),
                          label: Text(option.label),
                          selected: option.id == fontFamily,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            notifier.setFontFamily(option.id);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    readerFontOption(fontFamily).description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScaleStepButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ScaleStepButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: PhosphorIcon(icon, size: 18),
    constraints: const BoxConstraints.tightFor(width: 42, height: 42),
    visualDensity: VisualDensity.compact,
  );
}
