import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/services/priest_access_policy.dart';
import 'package:mybrev_flutter/dev/prayer_formatting_harness.dart';

/// Run with flutter run -d chrome -t tool/prayer_formatting_smoke.dart.
/// Reads the existing public bundle; never connects to Firebase or writes data.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final prayers = decodeContentCollection(
    (await rootBundle.load(
      'assets/content/prayers.json.gz',
    )).buffer.asUint8List(),
  );
  final categories = decodeContentCollection(
    (await rootBundle.load(
      'assets/content/prayerCategories.json.gz',
    )).buffer.asUint8List(),
  );
  final policy = PriestAccessPolicy(categories.docs);
  final public = [
    for (final entry in prayers.docs.entries)
      if (!policy.prayerRestricted(entry.value))
        Prayer.fromMap(entry.value, entry.key),
  ]..sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
  runApp(PrayerFormattingHarness(realPrayers: public));
}
