import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/content/content_migration.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/content/content_updater.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/priest_access_gateway.dart';

import 'content_offline_test.dart' show FakeRemote;
import 'prayer_category_contract_test.dart' show fixtureContent;
import 'priest_access_test.dart' show SparkGateway, MemoryStorage, validCode;

class _CategoryGateway extends SparkGateway {
  final fixture = fixtureContent();
  @override
  Future<PrayerAccessContent> publicContent() async {
    check();
    return fixture.publicOnly;
  }

  @override
  Future<PrayerAccessContent> protectedContent(String id) async {
    authorize(id);
    final public = fixture.publicOnly;
    return PrayerAccessContent(
      {
        for (final e in fixture.prayers.entries)
          if (!public.prayers.containsKey(e.key)) e.key: e.value,
      },
      {
        for (final e in fixture.categories.entries)
          if (!public.categories.containsKey(e.key)) e.key: e.value,
      },
    );
  }

  @override
  Future<Map<String, dynamic>?> readProtectedPrayer(
    String id,
    String prayerId,
  ) async {
    authorize(id);
    return fixture.prayers[prayerId];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('categories-security-');
    await HiveService.init(path: directory.path, loadBundle: false);
  });
  tearDown(() async {
    await ContentStore.instance.idle();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'manual-only protection rejects keyed records without embedded id before writing',
    () async {
      final content = fixtureContent();
      await expectLater(
        persistPublicPrayerContent(content),
        throwsFormatException,
      );
      expect(HiveService.prayersBox.keys, isEmpty);
      expect(HiveService.prayerCategoriesBox.keys, isEmpty);
    },
  );

  test(
    'tree iconKey, parent/order/manual links survive public Hive restart together',
    () async {
      final public = fixtureContent().publicOnly;
      for (final pair in [
        ('root', 'virgin-mary'),
        ('middle', 'rosary'),
        ('leaf', 'candle'),
      ]) {
        public.categories[pair.$1]!['iconKey'] = pair.$2;
      }
      await persistPublicPrayerContent(public);
      await Hive.close();
      await HiveService.init(path: directory.path, loadBundle: false);
      for (final pair in [
        ('root', 'virgin-mary'),
        ('middle', 'rosary'),
        ('leaf', 'candle'),
      ]) {
        final data = HiveService.prayerCategoriesBox.get(pair.$1) as Map;
        expect(data, public.categories[pair.$1]);
        final category = PrayerMenuCategory.global(pair.$1, data);
        expect(category.iconKey, pair.$2);
        expect(category.displayIconKey, pair.$2);
        expect(category.parentId, public.categories[pair.$1]!['parentId']);
        expect(category.order, public.categories[pair.$1]!['order']);
        expect(category.prayerIds, public.categories[pair.$1]!['prayerIds']);
      }
    },
  );

  test(
    'grant/merge, background, offline, reopen, revoke: protected data stays off disk',
    () async {
      final gateway = _CategoryGateway();
      const privateComment = 'PRIVATE LEGACY CATEGORY COMMENT';
      gateway.fixture.categories['closed-child']!['comment'] = {
        'content': privateComment,
      };
      final storage = MemoryStorage();
      final controller = PriestAccessController(
        gateway,
        storage,
        persistPublic: persistPublicPrayerContent,
      );
      try {
        await controller.initialize();
        expect(controller.state.content, isNull);
        expect(
          controller.state.publicContent!.prayers,
          isNot(contains('shared-private')),
        );
        expect(
          HiveService.prayerCategoriesBox.get('root')['prayerIds'],
          contains('shared-private'),
        );
        await controller.activate(validCode, 'Synthetic device');
        await controller.loadCatalog();
        expect(controller.state.content!.prayers, contains('shared-private'));
        expect(controller.state.content!.categories['closed']!['prayerIds'], [
          'shared-private',
        ]);
        final child = controller.state.content!.categories['closed-child']!;
        expect(
          PrayerMenuCategory.global('closed-child', child).comment?.content,
          privateComment,
        );
        expect(HiveService.prayerCategoriesBox.get('closed-child'), isNull);
        expect(
          (await controller.readPrayer('shared-private'))!['title'],
          'PRIVATE SHARED FIXTURE',
        );
        expect(HiveService.prayersBox.get('shared-private'), isNull);
        controller.suspend(foreground: false);
        expect(controller.state.content, isNull);
        expect(await controller.readPrayer('shared-private'), isNull);
        await controller.resume(foreground: true);
        await controller.loadCatalog();
        expect(controller.state.content, isNotNull);
        gateway.offline = true;
        await controller.refresh();
        expect(controller.state.content, isNull);
        gateway.offline = false;
        await controller.refresh();
        await controller.loadCatalog();
        expect(controller.state.content, isNotNull);
        gateway.active = false;
        gateway.events.add(PriestDeviceGrant(gateway.uid!, false));
        await Future<void>.delayed(Duration.zero);
        expect(controller.state.content, isNull);
        expect(await controller.readPrayer('shared-private'), isNull);
        await Hive.close();
        for (final file in directory.listSync().whereType<File>()) {
          expect(
            latin1.decode(file.readAsBytesSync()),
            isNot(contains('PRIVATE')),
          );
        }
        await HiveService.init(path: directory.path, loadBundle: false);
        expect(HiveService.prayersBox.get('shared-private'), isNull);
        expect(
          HiveService.prayerCategoriesBox.get('root')['prayerIds'],
          contains('shared-private'),
        );
      } finally {
        controller.dispose();
        await gateway.close();
      }
    },
  );

  test(
    'public update overlay accepts opaque IDs, rejects restricted records atomically, and reloads',
    () async {
      final public = fixtureContent().publicOnly;
      await persistPublicPrayerContent(public);
      final store = ContentStore.instance;
      final updated = <String, dynamic>{
        ...public.categories['root']!,
        'prayerIds': ['manual', 'shared-private', 'unknown-opaque'],
      };
      final remote = FakeRemote({
        'prayers': public.prayers,
        'prayerCategories': {...public.categories, 'root': updated},
      }, contentVersion: DateTime.now().millisecondsSinceEpoch + 1000);
      final updater = ContentUpdater(remote: remote);
      final check = await updater.check();
      await updater.apply(check.plan!);
      expect(
        HiveService.prayerCategoriesBox.get('root')['prayerIds'],
        contains('unknown-opaque'),
      );
      final bad = FakeRemote({
        'prayers': {
          ...public.prayers,
          'shared-private': {'title': 'PRIVATE NEW', 'categoryId': 'closed'},
        },
        'prayerCategories': public.categories,
      }, contentVersion: DateTime.now().millisecondsSinceEpoch + 2000);
      final badUpdater = ContentUpdater(remote: bad);
      final badCheck = await badUpdater.check();
      await expectLater(
        badUpdater.apply(badCheck.plan!),
        throwsA(isA<ContentUpdateRejected>()),
      );
      expect(store.collection('prayers').get('shared-private'), isNull);
      await Hive.close();
      await HiveService.init(path: directory.path, loadBundle: false);
      expect(
        store.collection('prayerCategories').get('root')['prayerIds'],
        contains('unknown-opaque'),
      );
      expect(store.collection('prayers').get('shared-private'), isNull);
    },
  );

  test(
    'legacy migration blocks manual restriction when neither document embeds its ID',
    () async {
      // Exercise the migration's real old-Hive -> ContentStore path.
      final oldCategories = await Hive.openBox('prayerCategories');
      final oldPrayers = await Hive.openBox('prayers');
      await oldCategories.put('closed', {
        'priestOnly': true,
        'prayerIds': ['manual-secret'],
      });
      await oldPrayers.put('manual-secret', {
        'text': 'PRIVATE LEGACY',
        'updatedAt': 5000,
      });
      // A rejected snapshot must not remove protection from canonical metadata.
      await HiveService.prayerCategoriesBox.put('closed', {
        'priestOnly': true,
        'prayerIds': ['manual-secret'],
      });
      await HiveService.metaBox.delete(kContentModelKey);
      await ContentMigration(HiveService.metaBox).run();
      expect(HiveService.prayersBox.get('manual-secret'), isNull);
      expect(await Hive.boxExists('prayers'), isFalse);
    },
  );
}
