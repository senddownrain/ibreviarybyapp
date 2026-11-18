// Regression counterpart of mybrev PR #302 (GILH 200, 236).
// Real bundled sparse Propers + the selected diocesan Ordo determine the rank.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/ordo/season.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/office_assembly.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('daytime-collect-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kLiturgicalCollections);
  });

  tearDownAll(() async {
    await ContentStore.instance.idle();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Map<String, dynamic> proper(String id) {
    final stored = HiveService.content.collection('liturgicalProperTexts').get(id);
    expect(stored, isA<Map>(), reason: 'Bundled Proper $id must exist');
    return Map<String, dynamic>.from(stored as Map);
  }

  final currentDay = <String, dynamic>{
    for (final hour in [1, 2, 3])
      'sext${hour}Pr': 'collect of the current day at hour $hour',
  };

  OfficeAssembly assemble({
    required String date,
    required String diocese,
    required String celebration,
    required Map<String, dynamic> source,
    required String choice,
  }) {
    final office = OrdoRuntime.engine
        .resolve(date, diocese: diocese)
        .office(celebration);
    expect(office, isNotNull, reason: '$date/$diocese/$celebration');
    return assembleOffice(
      proper: source,
      currentDay: currentDay,
      templates: HiveService.templates(),
      isSunday: computeSeason(date).isSunday,
      choice: choice,
      office: office,
      season: computeSeason(date),
    );
  }

  for (final c in const [
    (
      date: '2026-11-12',
      diocese: 'vitebsk',
      celebration: 'sv-josaphat',
      properId: '12-11-sv-josaphat-vitebsk',
      rank: 'solemnity',
    ),
    (
      date: '2026-11-12',
      diocese: 'pinsk',
      celebration: 'sv-josaphat',
      properId: '12-11-sv-josaphat-minsk-mohilev-pinsk--pinsk',
      rank: 'feast',
    ),
    (
      date: '2026-11-16',
      diocese: 'grodno',
      celebration: 'our-lady-mother-mercy',
      properId: '16-11-our-lady-mother-mercy-grodno',
      rank: 'solemnity',
    ),
  ]) {
    test('${c.date} ${c.diocese}: ${c.rank}, three own daytime collects', () {
      final source = proper(c.properId);
      final office = OrdoRuntime.engine
          .resolve(c.date, diocese: c.diocese)
          .office(c.celebration)!;
      expect(office.officeKind, c.rank);
      expect(source['officeOfReadingsPr'], isNotNull);
      final choices = (source['_templates'] as List).cast<String>();
      expect(choices, isNotEmpty);
      for (final choice in choices) {
        final assembled = assemble(
          date: c.date,
          diocese: c.diocese,
          celebration: c.celebration,
          source: source,
          choice: choice,
        );
        final lauds = assembled.data['laudesPr'];
        expect(lauds, source['officeOfReadingsPr'], reason: choice);
        for (final hour in [1, 2, 3]) {
          final field = 'sext${hour}Pr';
          expect(assembled.data[field], lauds, reason: '$choice $field');
          expect(assembled.provenance[field], 'ref:laudesPr');
        }
      }
    });
  }

  for (final c in const [
    (
      date: '2026-11-12',
      diocese: 'grodno',
      celebration: 'sv-josaphat',
      properId: '12-11-sv-josaphat',
    ),
    (
      date: '2026-11-16',
      diocese: 'vitebsk',
      celebration: 'our-lady-mother-mercy',
      properId: '16-11-our-lady-mother-mercy',
    ),
    (
      date: '2026-11-18',
      diocese: 'vitebsk',
      celebration: 'dedication-basilicas-peter-paul',
      properId: '18-11-dedication-basilicas-peter-paul',
    ),
  ]) {
    test('${c.date} ${c.diocese}: memorial retains the weekday collect', () {
      final source = proper(c.properId);
      final office = OrdoRuntime.engine
          .resolve(c.date, diocese: c.diocese)
          .office(c.celebration)!;
      expect(office.officeKind, anyOf('memorial', 'optional-memorial'));
      // A stale legacy daytime text must not override the memorial rule.
      source['sext1Pr'] = 'stale saint collect';
      for (final choice in [
        kCurrentDayChoice,
        ...(source['_templates'] as List).cast<String>(),
      ]) {
        final assembled = assemble(
          date: c.date,
          diocese: c.diocese,
          celebration: c.celebration,
          source: source,
          choice: choice,
        );
        for (final hour in [1, 2, 3]) {
          final field = 'sext${hour}Pr';
          expect(assembled.data[field], currentDay[field], reason: '$choice $field');
          expect(assembled.provenance[field], kCurrentDayChoice);
        }
      }
    });
  }

  test('an explicitly provided Proper prayer for Sext takes precedence', () {
    const date = '2026-11-12';
    const diocese = 'vitebsk';
    const celebration = 'sv-josaphat';
    final source = proper('12-11-sv-josaphat-vitebsk');
    source['sext2Pr'] = 'special Sext collect';
    final assembled = assemble(
      date: date,
      diocese: diocese,
      celebration: celebration,
      source: source,
      choice: 'pastors',
    );
    expect(assembled.data['sext1Pr'], assembled.data['laudesPr']);
    expect(assembled.data['sext2Pr'], 'special Sext collect');
    expect(assembled.provenance['sext2Pr'], 'proper');
    expect(assembled.data['sext3Pr'], assembled.data['laudesPr']);
  });
}
