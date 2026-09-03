import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Shared floating reader-size control used by every reading surface.
class TextScaleControl extends ConsumerWidget {
  const TextScaleControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(
      settingsProvider.select((settings) => settings.fontSize),
    );
    final notifier = ref.read(settingsProvider.notifier);
    final canDecrease = fontSize > kMinReaderFontSize + 0.01;
    final canIncrease = fontSize < kMaxReaderFontSize - 0.01;

    return Semantics(
      container: true,
      label: 'Памер тэксту, ${readerFontScalePercent(fontSize)} адсоткаў',
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: GlassSurface(
          style: GlassStyle.pill,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 46,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ScaleButton(
                  key: const Key('text-scale-decrease'),
                  tooltip: 'Паменшыць тэкст',
                  icon: PhosphorIconsBold.minus,
                  onPressed: canDecrease ? notifier.decreaseFontSize : null,
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: GlassTokens.of(context).pillBorder,
                ),
                _ScaleButton(
                  key: const Key('text-scale-increase'),
                  tooltip: 'Павялічыць тэкст',
                  icon: PhosphorIconsBold.plus,
                  onPressed: canIncrease ? notifier.increaseFontSize : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScaleButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ScaleButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: PhosphorIcon(icon, size: 18),
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 38, height: 40),
    visualDensity: VisualDensity.compact,
    splashRadius: 20,
  );
}
