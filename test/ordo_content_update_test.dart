// A publication of the calendar is one generation: new definitions never
// meet old Propers. One update changes a celebration's colour (definitions)
// and its Proper text (liturgicalProperTexts); the engine and the Hours see
// both or neither — also after a crash at any phase.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ordo-update-');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> open() async {
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  }

  const marker = '<p>Малітва (абноўленая)</p>';
  final version = DateTime(2030).millisecondsSinceEpoch;

  Future<void> publish({ContentCommitPhase? crashAfter}) async {
    final store = ContentStore.instance;
    final celebrations = store.collection('liturgicalCelebrations');
    final propers = store.collection('liturgicalProperTexts');
    final bruno = {
      ...Map<String, dynamic>.from(celebrations.get('sv-bruno') as Map),
      'color': 'ruber',
    };
    final proper = {
      ...Map<String, dynamic>.from(propers.get('06-10-sv-bruno') as Map),
      'laudesPr': marker,
    };
    await store.commit(
      {
        'liturgicalCelebrations': celebrations.planUpdate(
          {'sv-bruno': bruno},
          {'sv-bruno': documentHash(bruno)},
          version,
        ),
        'liturgicalProperTexts': propers.planUpdate(
          {'06-10-sv-bruno': proper},
          {'06-10-sv-bruno': documentHash(proper)},
          version,
        ),
      },
      version,
      stopAfter: crashAfter,
    );
  }

  (String, Object?) observed() {
    final color = OrdoRuntime.engine
        .resolve('2026-10-06')
        .option('sv-bruno')!
        .color;
    final bruno = LiturgicalContentService()
        .contentForDate(DateTime(2026, 10, 6))
        .options
        .firstWhere((o) => o.optionId == 'sv-bruno');
    return (color, bruno.day!.data['laudesPr']);
  }

  test('a completed publication: definitions and Proper together', () async {
    await open();
    expect(observed().$1, 'albus');
    await publish();
    expect(observed(), ('ruber', marker));
  });

  for (final phase in ContentCommitPhase.values) {
    test('crash after ${phase.name}: never new colour with old text', () async {
      await open();
      await publish(crashAfter: phase);
      final (color, prayer) = observed();
      expect(color == 'ruber', prayer == marker);
      await Hive.close();
      await open();
      final (afterColor, afterPrayer) = observed();
      expect(afterColor == 'ruber', afterPrayer == marker);
    });
  }
}
