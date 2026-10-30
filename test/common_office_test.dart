import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/ordo/season.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/common_seasons.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/utils/liturgical_office.dart';
import 'package:mybrev_flutter/utils/office_assembly.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Map<String, dynamic> fixture;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('common-office-');
    await HiveService.init(path: directory.path, loadBundle: true);
    await ContentStore.instance.ensureLoaded(kLiturgicalCollections);
    fixture =
        jsonDecode(
              File(
                'test/fixtures/common_office_parity.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  Map<String, dynamic> proper(String id) => Map<String, dynamic>.from(
    HiveService.content.collection('liturgicalProperTexts').get(id) as Map,
  );
  OfficeAssembly assemble(
    Map<String, dynamic> subject, {
    String choice = 'religious',
    Map<String, Map<String, dynamic>>? templates,
    String date = '2026-10-19',
  }) => assembleOffice(
    proper: subject,
    currentDay: Map<String, dynamic>.from(fixture['currentDay'] as Map),
    templates: templates ?? HiveService.templates(),
    isSunday: false,
    choice: choice,
    season: computeSeason(date),
  );

  test(
    'real A–F inputs: every text value and source equals production Web',
    () {
      for (final item in (fixture['cases'] as List).cast<Map>()) {
        final doc = proper(item['id'] as String);
        final date = item['date'] as String;
        final office = OrdoRuntime.engine
            .resolve(date)
            .office(doc['_celebrationId'] as String)!;
        final result = assembleOffice(
          proper: doc,
          currentDay: Map<String, dynamic>.from(fixture['currentDay'] as Map),
          templates: HiveService.templates(),
          isSunday: computeSeason(date).isSunday,
          choice: item['choice'] as String,
          office: office,
          season: computeSeason(date),
        );
        final context = '${item['id']} ${item['choice']}';
        for (final entry in (item['fields'] as Map).entries) {
          final hash = sha256
              .convert(utf8.encode(canonicalJson(result.data[entry.key])))
              .toString();
          expect(hash, entry.value, reason: '$context ${entry.key}');
        }
        expect(result.provenance, item['provenance'], reason: context);
        expect(result.missing, item['missing'], reason: context);
        expect(
          result.integrity.map((e) => e.toJson()).toList(),
          item['integrity'],
          reason: context,
        );
        expect(result.data['_assembly'], item['assembly'], reason: context);
        expect(result.data['_rank'], doc['_rank']);
        expect(
          shouldShowTeDeum(LiturgicalDay.fromMap(result.data)),
          item['choice'] != kCurrentDayChoice,
        );
      }
    },
  );

  test(
    'explicit bases win; conflicting, invalid and inferred sources never guess',
    () {
      for (final choice in ['religious', 'educators', 'works-of-mercy']) {
        expect(
          commonBaseRule({
            '_templates': [choice, 'pastors'],
          }, choice)?.template,
          'holy-men',
        );
        expect(
          commonBaseRule({
            '_templates': [choice, 'virgins'],
          }, choice)?.template,
          'holy-women',
        );
        expect(
          commonBaseRule({
            '_templates': [choice, 'pastors', 'virgins'],
            '_commonBase': {choice: 'holy-women'},
          }, choice)?.template,
          'holy-women',
        );
        for (final (metadata, reason) in <(Map<String, dynamic>, String)>[
          (
            {
              '_templates': [choice],
            },
            'base-common-unconfirmed',
          ),
          (
            {
              '_templates': [choice, 'pastors', 'virgins'],
            },
            'base-common-ambiguous',
          ),
          (
            {
              '_templates': [choice, 'pastors'],
              '_templatesInferred': true,
            },
            'base-common-unconfirmed',
          ),
          (
            {
              '_templates': [choice],
              '_commonBase': {choice: 'pastors'},
            },
            'base-common-invalid',
          ),
        ]) {
          final result = assemble({
            '_schema': 2,
            '_rank': 'memoria',
            ...metadata,
          }, choice: choice);
          expect(result.data['vesperPs1'], '');
          expect(
            result.integrity.any(
              (e) => e.field == 'vesperPs1' && e.reason == reason,
            ),
            isTrue,
          );
        }
      }
      expect(
        commonBaseRule({
          '_commonBase': {'pastors': 'holy-men'},
        }, 'pastors'),
        isNull,
      );
    },
  );

  test(
    'Proper precedes Common; absent base, ref and Common stay diagnosed gaps',
    () {
      final doc = proper('19-10-sv-paul-of-cross');
      final templates = HiveService.templates()..remove('holy-men');
      final missing = assemble(doc, templates: templates);
      expect(missing.data['vesperPs1'], '');
      expect(
        missing.integrity.any(
          (e) =>
              e.source == 'common:holy-men' && e.reason == 'template-missing',
        ),
        isTrue,
      );
      final own = assemble({
        ...doc,
        'vesperPs1': 'own psalm',
        'laudesPs1': 'own canticle',
        'invitatoriumAnt': 'own invitatory',
      }, templates: templates);
      expect(own.data['vesperPs1'], 'own psalm');
      expect(own.data['laudesPs1'], 'own canticle');
      expect(own.data['invitatoriumAnt'], 'own invitatory');
      final broken = assemble({
        ...doc,
        '_fieldRules': {
          ...Map<String, dynamic>.from(doc['_fieldRules'] as Map? ?? {}),
          'vesperPs1': {'ref': 'absent'},
        },
      });
      expect(broken.data['vesperPs1'], '');
      expect(broken.integrity.any((e) => e.source == 'ref:absent'), isTrue);
      final withoutCommon = assemble(doc, templates: {});
      expect(withoutCommon.data['laudesPs1'], '');
      expect(
        withoutCommon.integrity.any((e) => e.source == kSundayWeek1Template),
        isTrue,
      );
      expect(
        assemble({...doc, '_omitTeDeum': true}).data['officeOfReadingsTeDeum'],
        false,
      );
    },
  );

  test(
    'seasonal base, omission, rule and Marian section do not mutate cache',
    () {
      final templates = HiveService.templates();
      templates['holy-men'] = {
        ...templates['holy-men']!,
        '_seasonalVariants': {
          'easter': {
            'laudesR': 'seasonal base reading',
            'vesperAnt2': null,
            'vesperHymn': {
              'rule': {'ref': 'laudesHymn'},
            },
          },
        },
      };
      final before = canonicalJson(templates);
      final doc = proper('19-10-sv-paul-of-cross');
      final easter = assemble(doc, templates: templates, date: '2026-04-20');
      expect(easter.data['laudesR'], 'seasonal base reading');
      expect(easter.provenance['laudesR'], 'common:holy-men');
      expect(easter.data['vesperAnt2'], '');
      expect(
        assemble(doc, templates: templates).data['laudesR'],
        isNot('seasonal base reading'),
      );
      expect(canonicalJson(templates), before);
      expect(commonSeasonVariant(computeSeason('2026-03-30')), 'lent');
      expect(commonSeasonVariant(computeSeason('2026-04-03')), isNull);
      final main = materializeCommonForSeason(
        {
          'laudesHymn': 'flat',
          '_fieldRules': {
            'laudesHymn': {'source': 'proper'},
          },
          '_seasonalVariants': {
            'easter': {
              'laudesHymn': 'seasonal',
              'officeOfReadingsTeDeum': true,
            },
          },
        },
        computeSeason('2026-04-20'),
        kOfficeFieldSlots.keys.toSet(),
      )!;
      expect(main['laudesHymn'], 'seasonal');
      expect(main['_fieldRules'], isNull);
      expect(main.containsKey('officeOfReadingsTeDeum'), false);
    },
  );

  test(
    'choice survives hour navigation and date switching; cache rebuild keeps dioceses separate',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final date = DateTime(2026, 10, 19);
      container.read(selectedDateProvider.notifier).state = date;
      const id = '19-10-sv-paul-of-cross--religious';
      container
          .read(hoursLiturgicalOverridesProvider.notifier)
          .select(date, id, diocese: 'minsk-mohilev');
      final first = container.read(hoursLiturgicalSelectionProvider);
      expect(first.dayId, id);
      expect(first.template?.choice, 'religious');
      expect(completoriumRecordIdForDay(first.day), contains('2'));
      expect(nextAvailableHour(first.day!, 'laudes'), isNotNull);
      expect(container.read(hoursLiturgicalSelectionProvider).dayId, id);
      container.read(selectedDateProvider.notifier).state = DateTime(
        2026,
        10,
        20,
      );
      expect(container.read(hoursLiturgicalSelectionProvider).dayId, isNot(id));
      container.read(selectedDateProvider.notifier).state = date;
      expect(container.read(hoursLiturgicalSelectionProvider).dayId, id);
      for (final diocese in ['grodno', 'pinsk', 'vitebsk', 'minsk-mohilev']) {
        final options = LiturgicalContentService()
            .contentForDate(date, diocese: diocese)
            .options;
        final choice = resolveHoursLiturgicalSelection(
          options,
          selectedDayId: id,
          selectedDiocese: diocese,
        );
        expect(choice.dayId, id);
        expect(choice.diocese, diocese);
        expect(choice.day!.data['vesperPs1'], first.day!.data['vesperPs1']);
      }
      expect(isoOf(date), '2026-10-19');
    },
  );

  test(
    'offline bundle contains revision 4, 29 bases, rules and seasonal Commons',
    () {
      final store = ContentStore.instance;
      final meta =
          store.collection('liturgicalCalendarMeta').get('current') as Map;
      expect(meta['properTextsRevision'], 4);
      expect(meta['templatesRevision'], 3);
      final docs = store.collection('liturgicalProperTexts').values.cast<Map>();
      expect(docs.where((d) => d['_commonBase'] != null), hasLength(27));
      expect(
        docs.fold(0, (n, d) => n + ((d['_commonBase'] as Map?)?.length ?? 0)),
        29,
      );
      expect(
        store.collection('liturgicalProperTexts').digest(),
        'e38afe1c97a7ba34',
      );
      expect(HiveService.templatesBox.digest(), '316b5f1487846faf');
      expect(
        HiveService.templates()['holy-women']!['_seasonalVariants'],
        isNotNull,
      );
    },
  );

  test(
    'a new bundle replaces stale Proper and Common overlays without clearing settings',
    () async {
      final store = ContentStore.instance;
      final propers = store.collection('liturgicalProperTexts');
      final templates = store.collection('liturgicalTemplates');
      final oldProper = {...proper('04-10-sv-francis-assisi')}
        ..remove('_commonBase');
      final oldCommon = {...HiveService.templates()['holy-men']!}
        ..remove('_seasonalVariants')
        ..['vesperPs1'] = 'stale cached psalm';
      const oldVersion = 1792323162929;
      await HiveService.settingsBox.put('common-smoke-user-preference', 'kept');
      await store.commit({
        'liturgicalProperTexts': propers.planUpdate(
          {'04-10-sv-francis-assisi': oldProper},
          {'04-10-sv-francis-assisi': documentHash(oldProper)},
          oldVersion,
        ),
        'liturgicalTemplates': templates.planUpdate(
          {'holy-men': oldCommon},
          {'holy-men': documentHash(oldCommon)},
          oldVersion,
        ),
      }, oldVersion);
      await Hive.close();
      await HiveService.init(path: directory.path, loadBundle: true);
      await store.ensureLoaded(kLiturgicalCollections);
      expect(proper('04-10-sv-francis-assisi')['_commonBase'], {
        'religious': 'holy-men',
      });
      expect(
        HiveService.templates()['holy-men']!['vesperPs1'],
        isNot('stale cached psalm'),
      );
      expect(
        HiveService.templates()['holy-men']!['_seasonalVariants'],
        isNotNull,
      );
      expect(
        HiveService.settingsBox.get('common-smoke-user-preference'),
        'kept',
      );
      final offline = assemble(proper('04-10-sv-francis-assisi'));
      expect(offline.provenance['vesperPs1'], 'common:holy-men');
    },
  );
}
