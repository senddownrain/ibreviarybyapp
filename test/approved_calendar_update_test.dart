import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final store = ContentStore.instance;
  Future<void> open() async {
    await HiveService.init(path: directory.path, loadBundle: true);
    await store.ensureLoaded(kContentCollections);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('by-calendar-update-');
    await open();
  });
  tearDown(() async {
    await store.idle();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final revision in [3, 4, 99]) {
    test(
      'old installed overlay revision $revision with a future timestamp cannot replace approved bundle',
      () async {
        final metas = store.collection('liturgicalCalendarMeta');
        final celebrations = store.collection('liturgicalCelebrations');
        // Reproduce a cache written by the previous client after its bundle was
        // built (timestamp alone would incorrectly select it on this release).
        final newman = Map<String, dynamic>.from(
          celebrations.get('sv-john-henry-newman') as Map,
        );
        await celebrations.put('sv-juan-diego', {
          ...newman,
          'id': 'sv-juan-diego',
          'title': 'stale December extra',
          'dateRule': {'type': 'fixed', 'month': 12, 'day': 9},
        }, version: DateTime(2040).millisecondsSinceEpoch);
        await metas.put('current', {
          ...(metas.get('current') as Map),
          'revision': revision,
          'schemaVersion': revision == 99 ? 99 : 1,
        }, version: DateTime(2040).millisecondsSinceEpoch);
        void verify() {
          expect(store.calendarUsesBaseline, isTrue);
          final day = OrdoRuntime.engine.resolve('2026-12-09');
          expect(
            day.options.map((o) => o.id),
            isNot(contains('sv-juan-diego')),
          );
          expect(
            OrdoRuntime.engine
                .resolve('2026-09-08', diocese: 'vitebsk')
                .primary
                .id,
            'our-lady-braslau',
          );
        }

        verify();
        await Hive.close();
        await open();
        verify();
      },
    );
  }

  Future<void> publish(int revision, {int schema = 1}) async {
    final celebrations = store.collection('liturgicalCelebrations');
    final metas = store.collection('liturgicalCalendarMeta');
    final bruno = {
      ...Map<String, dynamic>.from(celebrations.get('sv-bruno') as Map),
      'title': 'New accepted title',
    };
    final meta = {
      ...Map<String, dynamic>.from(metas.get('current') as Map),
      'revision': revision,
      'schemaVersion': schema,
    };
    final version = DateTime(2040).millisecondsSinceEpoch;
    await store.commit({
      'liturgicalCelebrations': celebrations.planUpdate(
        {'sv-bruno': bruno},
        {'sv-bruno': documentHash(bruno)},
        version,
      ),
      'liturgicalCalendarMeta': metas.planUpdate(
        {'current': meta},
        {'current': documentHash(meta)},
        version,
      ),
    }, version);
  }

  test(
    'stale/same-revision and schema99 generations rejected; larger revision refreshes an already opened date and survives restart',
    () async {
      final before = OrdoRuntime.engine.resolve('2026-10-06');
      for (final rev in [3, 4]) {
        await expectLater(publish(rev), throwsStateError);
        expect(
          OrdoRuntime.engine.resolve('2026-10-06').option('sv-bruno')!.title,
          before.option('sv-bruno')!.title,
        );
      }
      await expectLater(publish(99, schema: 99), throwsStateError);
      await publish(5);
      expect(
        OrdoRuntime.engine.resolve('2026-10-06').option('sv-bruno')!.title,
        'New accepted title',
      );
      await expectLater(publish(4), throwsStateError);
      await Hive.close();
      await open();
      expect(
        OrdoRuntime.engine.resolve('2026-10-06').option('sv-bruno')!.title,
        'New accepted title',
      );
    },
  );

  test(
    'removed saved option falls back to current primary; switching dioceses never reuses the other Office',
    () {
      final service = LiturgicalContentService();
      final december = service.contentForDate(DateTime(2026, 12, 9));
      final choice = resolveHoursLiturgicalSelection(
        december.options,
        selectedDayId: '09-12-sv-juan-diego',
      );
      expect(choice.selected!.optionId, december.ordo.primary.id);
      for (final diocese in [
        'vitebsk',
        'minsk-mohilev',
        'grodno',
        'pinsk',
        'vitebsk',
      ]) {
        final content = service.contentForDate(
          DateTime(2026, 9, 8),
          diocese: diocese,
        );
        expect(
          content.options.first.optionId,
          diocese == 'vitebsk'
              ? 'our-lady-braslau'
              : 'nativity-blessed-virgin-mary',
        );
        expect(content.options.first.templates, isNotEmpty);
        for (final oldId in [
          '08-09-nativity-blessed-virgin-mary',
          '08-09-our-lady-braslau-vitebsk',
        ]) {
          expect(
            content.optionOwning(oldId)!.optionId,
            content.ordo.primary.id,
          );
          expect(content.dayById(oldId)!.id, content.options.first.day!.id);
          expect(
            resolveHoursLiturgicalSelection(
              content.options,
              selectedDayId: oldId,
              requireExact: true,
            ).selected!.optionId,
            content.ordo.primary.id,
          );
        }
      }
    },
  );
  test(
    'startup never exposes old overlay before all bundled calendar layers are decoded',
    () async {
      await store.idle();
      final metas = store.collection('liturgicalCalendarMeta');
      await metas.put('current', {
        ...(metas.get('current') as Map),
        'revision': 3,
      }, version: DateTime(2040).millisecondsSinceEpoch);
      await Hive.close();
      Hive.init(directory.path);
      await store.open(loadBundle: true);
      expect(OrdoRuntime.engine.definitions.isEmpty, isTrue);
      await store.ensureLoaded(kOrdoCalendarCollections);
      expect(store.calendarUsesBaseline, isTrue);
      expect(
        OrdoRuntime.engine.resolve('2026-09-08', diocese: 'vitebsk').primary.id,
        'our-lady-braslau',
      );
    },
  );
}
