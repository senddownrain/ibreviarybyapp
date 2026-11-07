import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/constants/psalmody_preview.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/widgets/psalm_choir_html.dart';
import 'package:mybrev_flutter/widgets/psalmody_mode_selector.dart';

class PsalmodySettingsSection extends ConsumerStatefulWidget {
  const PsalmodySettingsSection({super.key});

  @override
  ConsumerState<PsalmodySettingsSection> createState() =>
      _PsalmodySettingsSectionState();
}

class _PsalmodySettingsSectionState
    extends ConsumerState<PsalmodySettingsSection> {
  final _choir = ValueNotifier<int?>(null);

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
        PsalmodyControlRow(
          value: settings.psalmodyMode,
          onChanged: ref.read(settingsProvider.notifier).setPsalmodyMode,
        ),
        const SizedBox(height: 16),
        Text('Прыклад', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          psalmodyPreviewReference,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        PsalmodyScope(
          controller: _choir,
          mode: settings.psalmodyMode,
          child: PsalmChoirHtml(
            key: const Key('settings-psalmody-preview'),
            html: formatPsalmHtml(psalmodyPreviewHtml),
            style: liturgicalDocumentStyles(reader: reader, body: body),
            textColor: reader.ink,
            rubricColor: reader.rubric,
            interactive: false,
          ),
        ),
      ],
    );
  }
}
