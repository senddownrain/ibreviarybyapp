// flutter run -d chrome -t tool/devotional_office_smoke.dart --web-port 5239
// ?prayer=<allowlisted ID>&theme=dark&scale=2&layout=aligned&breaks=1
// Uses the existing public bundle only. No Firebase initialization or imports.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/dev/devotional_office_harness.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/models/psalmody_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/services/priest_access_policy.dart';
import 'package:mybrev_flutter/utils/devotional_office.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final collection = decodeContentCollection(
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
  final prayers = <Prayer>[];
  for (final id in devotionalOfficeProfiles.keys) {
    final data = collection.docs[id];
    if (data == null || policy.prayerRestricted(data)) {
      throw StateError('Public bundled office unavailable: $id');
    }
    final prayer = Prayer.fromMap(data, id);
    if (parseDevotionalOffice(prayer) == null) {
      throw StateError('Unexpected bundled structure: $id');
    }
    prayers.add(prayer);
  }
  final q = Uri.base.queryParameters;
  final id = q['prayer'] ?? prayers.first.id;
  if (!devotionalOfficeProfiles.containsKey(id)) {
    throw ArgumentError.value(id, 'prayer');
  }
  runApp(
    DevotionalOfficeHarness(
      prayers: prayers,
      initialId: id,
      dark: q['theme'] == 'dark',
      scale: q['scale'] == '2' ? 2 : 1,
      settings: SettingsState(
        psalmodyMode: resolvePsalmodyMode(
          storedMode: q['mode'],
          legacyLayout: q['layout'] == 'aligned' ? 'alignedLeft' : null,
          legacyBreakMode: q['breaks'] == '1' ? 'breakAfterMarker' : null,
        ),
      ),
    ),
  );
}
