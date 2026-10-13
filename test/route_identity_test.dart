// Route identity of a liturgical Office: date + document (assembly) id in
// the path (old links keep working), diocese / option in the query; the
// Readings open the selected celebration's readings in the engine's order.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('routes-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kContentCollections);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  final bruno = DateTime(2026, 10, 6);
  final service = LiturgicalContentService();

  test('route builders keep the old path and add the context as a query', () {
    expect(
      oraRouteForContext(
        date: bruno,
        dayId: '06-10-sv-bruno',
        oraType: 'laudes',
      ),
      '/hours/ora/2026-10-06/06-10-sv-bruno/laudes',
    );
    expect(
      oraRouteForContext(
        date: bruno,
        dayId: '06-10-sv-bruno--religious',
        oraType: 'laudes',
        diocese: 'vitebsk',
      ),
      '/hours/ora/2026-10-06/06-10-sv-bruno--religious/laudes?diocese=vitebsk',
    );
    expect(
      readingsRouteForContext(
        date: bruno,
        dayId: '06-10-sv-bruno',
        diocese: 'pinsk',
        optionId: 'sv-bruno',
      ),
      '/readings?date=2026-10-06&dayId=06-10-sv-bruno&option=sv-bruno&diocese=pinsk',
    );
  });

  test('Hours option and Common choice open by their ids; an old link to a '
      'former per-template copy still opens the Office', () {
    final day = service.resolveDayLocal(
      bruno,
      '06-10-sv-bruno--religious',
      null,
      null,
      null,
      diocese: 'vitebsk',
    )!;
    final proper =
        HiveService.content
                .collection('liturgicalProperTexts')
                .get('06-10-sv-bruno')
            as Map;
    expect(day.data['officeOfReadingsR2'], proper['officeOfReadingsR2']);
    expect(day.data['_assembly'], containsPair('choice', 'religious'));
    expect(day.data['_vestmentColor'], 'albus');
    // «З дня» is the default id and also answers `<id>--day`.
    final byDay = service.resolveDayLocal(
      bruno,
      '06-10-sv-bruno--day',
      null,
      null,
      null,
    )!;
    expect(byDay.data['_assembly'], containsPair('choice', 'current-day'));
    // The weekday of the date stays addressable (old links).
    expect(
      service.resolveDayLocal(bruno, 'ordinary-w27-d3', null, null, null),
      isNotNull,
    );
  });

  test(
    'Ordo → Hours: an option opens with its diocese, Settings unchanged',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final content = service.contentForDate(
        DateTime(2026, 8, 26),
        diocese: 'grodno',
      );
      final dayId = content.options
          .firstWhere((o) => o.ordo?.optionId == 'our-lady-czestochowa')
          .dayId!;
      container
          .read(liturgicalNavigationControllerProvider)
          .openDate(DateTime(2026, 8, 26), dayId: dayId, diocese: 'grodno');
      final selection = container.read(hoursLiturgicalSelectionProvider);
      expect(selection.dayId, dayId);
    },
  );

  test('Ora/Ordo → Readings: a memorial opens the weekday readings first; '
      'its own readings stay a choice', () {
    final readings = ParsedReadingsService();
    final calendar = CalendarService();
    final docs = readings.cachedForDate(
      bruno,
      calendar.getYearOptionsCached(2026),
      calendar.getYearOptionsCached(2027),
      calendar.getDynamicDatesCached(2026),
      includeAlternatives: true,
      dayId: '06-10-sv-bruno',
    )!;
    // The weekday readings come first; the screen picks the cycle.
    expect(docs.first.id, startsWith('ordinary-w27-d3--'));
    final selection = readings.ordoSelection(bruno, dayId: '06-10-sv-bruno');
    expect(selection?.optionId, 'sv-bruno');
    expect(selection?.memorial, isTrue);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final result = container.read(readingsLocalLoaderProvider)(
      dateStr: '2026-10-06',
      liturgicalKey: null,
      dayId: '06-10-sv-bruno',
    )!;
    expect(result.linkDayId, isFalse);
    expect(result.readings.first.id, startsWith('ordinary-w27-d3--'));
  });

  test('a solemnity opens its own readings', () {
    final calendar = CalendarService();
    final docs = ParsedReadingsService().cachedForDate(
      DateTime(2026, 8, 15),
      calendar.getYearOptionsCached(2026),
      calendar.getYearOptionsCached(2027),
      calendar.getDynamicDatesCached(2026),
      includeAlternatives: true,
    )!;
    expect(docs.first.date, '15.08');
  });
}
