import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/widgets/psalm_choir_html.dart';

// Exact Web PR #202 excerpt, commit 38e94e65, Psalm 63 (62), 2–3.
// Source: patchs/json/ordinary-w5-d1-fixed-day.json, laudesPs1.
const psalmodyExampleHtml =
    r'''<p>Божа, мой Божа, Цябе шукаю, *<br />Цябе прагне душа мая.</p>
<p>Маё цела па Табе тужыць *<br />у зямлі пустыннай, засохлай і бязводнай.</p>
<p>Так, у святыні я ўглядаюся ў Цябе, *<br />каб убачыць Тваю сілу і славу.</p>''';

class PsalmodyExample extends ConsumerStatefulWidget {
  const PsalmodyExample({super.key});

  @override
  ConsumerState<PsalmodyExample> createState() => _PsalmodyExampleState();
}

class _PsalmodyExampleState extends ConsumerState<PsalmodyExample> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Прыклад', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        PsalmodyScope(
          controller: _choir,
          mode: settings.psalmodyMode,
          child: PsalmChoirHtml(
            html: formatPsalmHtml(psalmodyExampleHtml),
            style: liturgicalDocumentStyles(
              reader: reader,
              body: reader.body(settings.fontSize, family: settings.fontFamily),
            ),
            textColor: reader.ink,
            rubricColor: reader.rubric,
          ),
        ),
      ],
    );
  }
}
