import 'package:mybrev_flutter/widgets/reader_text_settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/discovery/ui/discovery_hint_host.dart';
import 'package:mybrev_flutter/discovery/ui/p1_hint_hosts.dart';
import 'package:mybrev_flutter/widgets/psalmody_mode_selector.dart';
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
            tooltip: 'Шрыфт',
            onPressed: () {
              HapticFeedback.selectionClick();
              showTextScalePanel(context);
            },
            icon: const PhosphorIcon(PhosphorIconsRegular.textAa, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Opens the reader appearance sheet after contextual menus are dismissed.
/// Psalmody controls are available only in the Liturgy of the Hours.
Future<void> showTextScalePanel(
  BuildContext context, {
  bool showPsalmody = false,
}) {
  if (usesCupertinoGlass(context)) {
    return showCupertinoModalPopup<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (_) => Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: _TextScalePanel(showPsalmody: showPsalmody),
        ),
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
    builder: (_) => SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: 6),
      child: _TextScalePanel(showPsalmody: showPsalmody),
    ),
  );
}

class _TextScalePanel extends ConsumerWidget {
  const _TextScalePanel({this.showPsalmody = false});

  final bool showPsalmody;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final fontSize = settings.fontSize;
    final notifier = ref.read(settingsProvider.notifier);
    final percent = readerFontScalePercent(fontSize);
    final canDecrease = fontSize > kMinReaderFontSize + 0.01;
    final canIncrease = fontSize < kMaxReaderFontSize - 0.01;
    final cs = Theme.of(context).colorScheme;
    final accent = GlassTokens.of(context).accentOnSurface(cs.tertiary);

    final media = MediaQuery.of(context);
    final panel = Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    (media.size.height -
                            media.viewInsets.bottom -
                            media.viewPadding.vertical -
                            24)
                        .clamp(0.0, media.size.height) *
                    .9,
              ),
              child: SingleChildScrollView(
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final titleStyle = Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700);
                          final percentStyle = Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700);
                          double textWidth(String text, TextStyle? style) {
                            final painter = TextPainter(
                              text: TextSpan(text: text, style: style),
                              textDirection: Directionality.of(context),
                              textScaler: media.textScaler,
                            )..layout();
                            final width = painter.width;
                            painter.dispose();
                            return width;
                          }

                          final stacked =
                              constraints.maxWidth <
                              23 +
                                  10 +
                                  textWidth('Шрыфт', titleStyle) +
                                  textWidth('$percent%', percentStyle) +
                                  20 +
                                  4 +
                                  48 +
                                  8;
                          final badge = AnimatedContainer(
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
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          );
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                                      'Шрыфт',
                                      maxLines: 1,
                                      style: titleStyle,
                                    ),
                                  ),
                                  if (!stacked) badge,
                                  if (!stacked) const SizedBox(width: 4),
                                  IconButton(
                                    key: const Key('text-scale-close'),
                                    tooltip: 'Закрыць',
                                    onPressed: () => Navigator.pop(context),
                                    icon: const PhosphorIcon(
                                      PhosphorIconsRegular.x,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              if (stacked)
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: badge,
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _ScaleStepButton(
                            key: const Key('text-scale-decrease'),
                            tooltip: 'Паменшыць тэкст',
                            icon: PhosphorIconsBold.minus,
                            onPressed: canDecrease
                                ? notifier.decreaseFontSize
                                : null,
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 5,
                                activeTrackColor: accent,
                                inactiveTrackColor: cs.onSurfaceVariant
                                    .withValues(alpha: 0.16),
                                thumbColor: accent,
                                overlayColor: cs.tertiary.withValues(
                                  alpha: 0.12,
                                ),
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
                            onPressed: canIncrease
                                ? notifier.increaseFontSize
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const ReaderFontPicker(
                        key: Key('text-scale-font-family'),
                      ),
                      const SizedBox(height: 16),
                      if (!showPsalmody) const ReaderAlignmentControl(),
                      if (showPsalmody) ...[
                        const Divider(height: 28),
                        PsalmodyControlRow(
                          selectorKey: const Key('text-scale-psalmody-modes'),
                          value: settings.psalmodyMode,
                          onChanged: notifier.setPsalmodyMode,
                        ),
                        const HintInlineSlot(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return showPsalmody ? PsalmLayoutHintHost(child: panel) : panel;
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
