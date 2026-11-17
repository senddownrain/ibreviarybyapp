// Offline source-label acceptance in the production prayer screen.
// No Firebase initialization, network content, or writes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/dev/devotional_office_harness.dart';
import 'package:mybrev_flutter/models/prayer.dart';

const sourceSmokePrayer = Prayer(
  id: 'local_source_smoke',
  title: 'Крыніца малітвы',
  body: 'Пс 23, 1–6. Ян 3, 16\n\n[Іншая малітва](/prayer/source-linked)',
  textFormat: 'mybrev-markdown',
  source: 'Бог добры',
  isLocal: true,
);
const sourceLinkedPrayer = Prayer(
  id: 'source-linked',
  title: 'Іншая малітва',
  body: 'Амэн.',
  textFormat: 'mybrev-markdown',
  source: 'Рымскі Імшал',
);
const sourceOfficeId = 'mybrev-devotion-blessed-virgin-mary-laudes';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final bundle = decodeContentCollection(
    (await rootBundle.load(
      'assets/content/prayers.json.gz',
    )).buffer.asUint8List(),
  );
  // This exact title is confirmed by Web source mapping, not inferred from text.
  final office = Prayer.fromMap(
    bundle.docs[sourceOfficeId]!,
    sourceOfficeId,
  ).copyWith(source: 'Літургія гадзін');
  final query = Uri.base.queryParameters;
  runApp(
    DevotionalOfficeHarness(
      prayers: [sourceSmokePrayer, sourceLinkedPrayer, office],
      initialId: query['office'] == '1' ? sourceOfficeId : sourceSmokePrayer.id,
      dark: query['theme'] == 'dark',
      scale: query['scale'] == '2' ? 2 : 1,
      systemFonts: true,
    ),
  );
}
