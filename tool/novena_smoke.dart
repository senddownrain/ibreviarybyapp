import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/dev/novena_harness.dart';
import 'package:mybrev_flutter/models/priest_access_content.dart';
import 'package:mybrev_flutter/novena/novena_definition.dart';
import 'package:mybrev_flutter/novena/novena_store.dart';

import 'novena_smoke_data.dart';

// Visual check of the novena tracker, isolated from Firebase.
//   flutter run -d chrome -t tool/novena_smoke.dart --web-port 5237
// Query: ?today=2027-03-12&theme=dark&scale=1.6&seed=1&reset=1
// Progress is kept in this browser origin's own Hive box.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final query = Uri.base.queryParameters;

  Future<Map<String, Map<String, dynamic>>> bundled(String name) async {
    final data = await rootBundle.load('$kContentAssetDir/$name.json.gz');
    return decodeContentCollection(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    ).docs;
  }

  final content = PrayerAccessContent(
    await bundled('prayers'),
    await bundled('prayerCategories'),
  ).publicOnly;
  final definitions = [
    for (final item in jsonDecode(kNovenaSmokeDefinitions) as List)
      NovenaHarness.published(item as Map),
  ];

  await Hive.initFlutter();
  await NovenaStore.open();
  final box = HiveNovenaBox(Hive.box<String>(kNovenaBoxName));
  if (query['reset'] == '1') {
    for (final key in box.keys.toList()) {
      await box.remove(key);
    }
  }
  final today =
      DateTime.tryParse(query['today'] ?? '') ?? DateTime(2027, 3, 12);

  // Two running novenas, a few days in.
  if (query['seed'] == '1' && box.keys.isEmpty) {
    final store = NovenaStore(box);
    final prayers = {
      for (final MapEntry(:key, :value) in content.prayers.entries)
        key: NovenaPrayer.fromMap(value, key),
    };
    String iso(DateTime date) => date.toIso8601String().substring(0, 10);
    for (final (id, ago, marked) in [
      ('cn_05b28c5bea797880', 2, [1, 2]),
      ('Iiufha8NyLABTw92rA5S', 4, [1, 2, 4]),
    ]) {
      final definition = NovenaDefinition.tryParse(
        definitions.firstWhere((item) => item['novenaId'] == id),
      )!;
      final start = DateTime(today.year, today.month, today.day - ago);
      final session = await store.start(
        definition,
        definition.resolveAll(prayers)!,
        iso(start),
      );
      for (final day in marked) {
        await store.setDay(session.sessionId, day, true, iso(today));
      }
    }
  }

  runApp(
    NovenaHarness(
      content: content,
      definitions: definitions,
      box: box,
      clock: () => today,
      initialLocation: query['go'] ?? '/prayers',
      scheme: query['theme'] ?? 'light',
      scale: double.tryParse(query['scale'] ?? '') ?? 1,
    ),
  );
}
