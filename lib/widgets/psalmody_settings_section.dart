import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/widgets/psalm_choir_html.dart';
import 'package:mybrev_flutter/widgets/psalmody_mode_selector.dart';

// The exact same excerpt as Web src/constants/psalmodyPreview.js.
const _previewHtml =
    '<p>Божа, мой Божа, Цябе шукаю, *<br />Цябе прагне душа мая.</p>'
    '<p>Маё цела па Табе тужыць *<br />у зямлі пустыннай, засохлай і бязводнай.</p>'
    '<p>Так, у святыні я ўглядаюся ў Цябе, *<br />каб убачыць Тваю сілу і славу.</p>';

class PsalmodySettingsSection extends ConsumerStatefulWidget {
  const PsalmodySettingsSection({super.key});

  @override
  ConsumerState<PsalmodySettingsSection> createState() =>
      _PsalmodySettingsSectionState();
}

class _PsalmodySettingsSectionState
    extends ConsumerState<PsalmodySettingsSection> {
  final ValueNotifier<int?> _choir = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _choir.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final reader = ReaderTheme.of(context);
    final body = reader.body(settings.fontSize, family: settings.fontFamily);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Text(
              'Псальмодыя',
              style: Theme.of(context).textTheme.titleSmall,
            );
            final selector = PsalmodyModeSelector(
              key: const Key('settings-psalmody-mode'),
              value: settings.psalmodyMode,
              onChanged: ref.read(settingsProvider.notifier).setPsalmodyMode,
            );
            // Match the text-alignment control: shared 48dp height, 22dp icon
            // scale, and a fully rounded segmented outline. Stack only
            // when the label or controls would be cramped.
            final inline =
                constraints.maxWidth >= 260 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.3;
            if (!inline) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [title, const SizedBox(height: 8), selector],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 8),
                SizedBox(width: 144, child: selector),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: PsalmodyScope(
            controller: _choir,
            mode: settings.psalmodyMode,
            child: IgnorePointer(
              child: PsalmChoirHtml(
                key: const Key('settings-psalmody-preview'),
                html: formatPsalmHtml(_previewHtml),
                style: {
                  'body': Style(
                    fontFamily: body.fontFamily,
                    fontSize: FontSize(body.fontSize ?? 16),
                    color: body.color,
                    lineHeight: LineHeight(body.height ?? ReaderTheme.bodyHeight),
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ),
                  'p': Style(margin: Margins.only(bottom: 8)),
                },
                textColor: reader.ink,
                rubricColor: reader.rubric,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
