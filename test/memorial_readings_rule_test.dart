// The memorial rule of the web (mybrev memorialReadings.js) in the app:
// weekday readings by default; proper readings only where the Lectionary
// prescribes them (closed registry, Budslav only in Pinsk); own readings stay
// a selectable alternative; the option route opens the option's default.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/ordo/memorial_readings.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/utils/readings_selection.dart';

import 'support/lectionary_run.dart';

const _dioceses = ['minsk-mohilev', 'grodno', 'pinsk', 'vitebsk'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    await initializeDateFormatting('be');
    directory = await Directory.systemTemp.createTemp('memorial-rule-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('the registry is the web one: 12 entries, Budslav only in Pinsk', () {
    expect(kPrescribedProperMemorials, hasLength(12));
    expect(
      memorialReadingsRule('our-lady-budslav', 'memorial', 'pinsk')!.mode,
      'proper-prescribed',
    );
    for (final d in ['minsk-mohilev', 'grodno', 'vitebsk']) {
      expect(
        memorialReadingsRule('our-lady-budslav', 'memorial', d)!.mode,
        'weekday-default',
      );
    }
    expect(memorialReadingsRule('sv-barnabas', 'feast', ''), isNull);
    expect(
      memorialReadingsRule(
        'sv-john-paul-ii',
        'optional-memorial',
      )!.defaultPurpose,
      'weekday',
    );
  });

  test(
    'every memorial option 2025-2035 x 4 dioceses follows the rule',
    () {
      final service = ParsedReadingsService();
      final calendar = CalendarService();
      final ownByOption = <String, int>{};
      final classes = <String, Set<String>>{};
      var memorials = 0;
      var prescribedOpen = 0;
      for (final diocese in _dioceses) {
        var date = DateTime(2025, 1, 1);
        while (date.year <= 2035) {
          final day = OrdoRuntime.engine.resolve(date, diocese: diocese);
          for (final option in day.readingsPlan.where((o) => o.isMemorial)) {
            memorials++;
            final rule = memorialReadingsRule(
              option.optionId,
              option.officeKind,
              diocese,
            )!;
            expect(option.defaultPurpose, rule.defaultPurpose);
            expect(
              option.lookup.first.purpose,
              rule.defaultPurpose,
              reason: '${option.optionId} lookup order',
            );
            final dayId = routeDayIdOf(date, diocese, option.optionId) ?? '';
            final loaded = loadReadingsForDate(
              service: service,
              calendar: calendar,
              date: date,
              dayId: dayId,
              diocese: diocese,
            );
            if (loaded == null) continue;
            final selection = resolveDefaultReadings(
              readings: loaded.readings,
              sundayCycle: loaded.sundayCycle,
              weekdayCycle: loaded.weekdayCycle,
              dayId: loaded.linkDayId ? dayId : null,
              optionId: loaded.optionId,
            );
            final purposesOfActive = {
              for (final doc in selection.documents)
                doc.ordoOptionRoles[option.optionId]?.purpose,
            }..remove(null);
            final own = loaded.readings.where(
              (doc) =>
                  doc.ordoOptionRoles[option.optionId]?.purpose == 'proper',
            );
            final hasOwn = own.isNotEmpty;
            if (hasOwn) {
              // the own readings are always reachable
              expect(
                selection.groups.any(
                  (g) => g.documents.any((d) => own.any((o) => o.id == d.id)),
                ),
                isTrue,
              );
            }
            if (rule.prescribed && hasOwn) {
              prescribedOpen++;
              expect(
                purposesOfActive,
                contains('proper'),
                reason: '$date $diocese ${option.optionId}',
              );
            } else if (dayId.isNotEmpty) {
              expect(
                purposesOfActive.contains('proper') &&
                    hasOwn &&
                    !purposesOfActive.contains('weekday'),
                isFalse,
                reason: 'weekday default: $date $diocese ${option.optionId}',
              );
              if (hasOwn && !rule.prescribed) {
                ownByOption[option.optionId] =
                    (ownByOption[option.optionId] ?? 0) + 1;
              }
            }
            (classes[option.optionId] ??= {}).add(
              '${rule.mode}/${hasOwn ? 'own' : 'none'}',
            );
          }
          date = date.add(const Duration(days: 1));
        }
      }
      // ignore: avoid_print
      print(
        'memorial options $memorials, prescribed opened $prescribedOpen, '
        'weekday-default with own readings $ownByOption',
      );
      expect(memorials, greaterThan(1000));
      for (final id in [
        'sv-john-paul-ii',
        'sv-martin-de-porres',
        'sv-clement-i',
        'holy-name-mary',
        'our-lady-mount-carmel',
      ]) {
        expect(ownByOption[id], isNotNull, reason: id);
      }
      // web `memorials.json`: 56 celebrations are weekday-default with own
      // readings kept as an alternative, plus Our Lady of Trakai (Grodno), which
      // the owner decided is an obligatory memorial on 05.07 (Nov 2026).
      expect(ownByOption, hasLength(57));
      expect(ownByOption['our-lady-trakai'], isNotNull);
      expect(prescribedOpen, greaterThan(0));
      final total = ownByOption.values.fold(0, (a, b) => a + b);
      expect(total, greaterThanOrEqualTo(140));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
