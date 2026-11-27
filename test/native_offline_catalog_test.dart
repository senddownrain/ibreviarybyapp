import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/services/access_sets_v2_gateway.dart';
import 'package:mybrev_flutter/services/priest_access_gateway.dart';
import 'package:mybrev_flutter/services/protected_catalog_storage.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';

import 'access_sets_v2_test.dart' show TestAccessSets, syntheticCode;
import 'priest_access_test.dart' show MemoryStorage, SparkGateway;

const _privateComment = 'SYNTHETIC PRIVATE CATEGORY COMMENT';

Map<String, dynamic> _category(
  String id,
  List<String> sets, {
  String? parent,
}) => {
  'id': id,
  'name': id,
  'accessSchemaVersion': 2,
  'accessSets': sets,
  'effectiveAccessSets': sets,
  'contentHash': '0' * 64,
  'parentId': ?parent,
  'comment': {'content': _privateComment},
};

class _UpdatingGateway extends TestAccessSets
    implements AccessCatalogFingerprints {
  final hashes = <String, String>{};
  final checked = <String>[];
  final categories = <String, Map<String, dynamic>>{};
  String? interruptedId;

  Set<String> _sets(String id) => {
    for (final entry in indexes.entries)
      if (entry.value.contains(id)) entry.key,
  };

  @override
  Future<AccessIndexPage> listIds(
    AccessContentKind kind,
    String setId, {
    int pageSize = 50,
    String? after,
  }) async {
    if (kind == AccessContentKind.prayers) {
      return super.listIds(kind, setId, pageSize: pageSize, after: after);
    }
    pages.add((kind, setId, after));
    return (
      ids: categories.values
          .where((row) => (row['effectiveAccessSets'] as List).contains(setId))
          .map((row) => row['id'] as String)
          .toList(),
      cursor: null,
    );
  }

  @override
  Future<AccessContentFingerprint?> readFingerprint(
    AccessContentKind kind,
    String id,
  ) async {
    checked.add(id);
    final row = kind == AccessContentKind.categories ? categories[id] : null;
    if (row != null) {
      return (
        hash: hashes[id] ?? row['contentHash'] as String,
        ownSets: (row['accessSets'] as List).cast<String>().toSet(),
        effectiveSets: (row['effectiveAccessSets'] as List)
            .cast<String>()
            .toSet(),
      );
    }
    final sets = _sets(id);
    return (hash: hashes[id] ?? '0' * 64, ownSets: sets, effectiveSets: sets);
  }

  @override
  Future<Map<String, dynamic>?> readContent(
    AccessContentKind kind,
    String id,
  ) async {
    if (interruptedId == id) throw const PriestAccessException('OFFLINE');
    if (kind == AccessContentKind.categories) {
      reads.add((kind, id));
      await pauseRead?.future;
      if (categories[id] case final row?) {
        return {...row, 'contentHash': ?hashes[id]};
      }
      return null;
    }
    final row = await super.readContent(kind, id);
    if (row == null || !hashes.containsKey(id)) return row;
    return {
      ...row,
      'contentHash': hashes[id],
      'text': 'Updated synthetic text',
    };
  }
}

class _Disk {
  _Disk(this.folder);
  final Directory folder;
  String? key;
  ProtectedCatalogStorage reopen() => SealedProtectedCatalogStorage(
    directory: () async => folder,
    readKey: () async => key,
    writeKey: (value) async => key = value,
    deleteKey: () async => key = null,
  );
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 300 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

void main() {
  late Directory directory;
  late _Disk disk;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mybrev-protected-test-');
    disk = _Disk(directory);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'active install downloads, restores offline, refreshes by hash, and removes revoked rows',
    () async {
      final legacy = SparkGateway()..uid = 'existing-device';
      final access = _UpdatingGateway()
        ..grant = (codeId: 'ABCDEFGHJKLMNPQR', active: true)
        ..profile = AccessEntitlements('combined', ['marian', 'priest'], 1);
      access.categories.addAll({
        'comment-marian': _category('comment-marian', ['marian']),
        'old-priest': _category('old-priest', ['priest'])..remove('comment'),
      });
      final record = MemoryStorage();
      final initial = PriestAccessController(
        legacy,
        record,
        offlineStorage: disk.reopen(),
        accessSets: access,
      );
      await initial.initialize();
      await _until(() => initial.state.offlineReady);
      expect(
        initial.state.content?.prayers.keys,
        containsAll(['marian-one', 'priest-one', 'shared']),
      );
      expect(access.reads.where((item) => item.$2 == 'shared'), hasLength(1));
      expect(initial.state.content?.categories['comment-marian']?['comment'], {
        'content': _privateComment,
      });
      expect(
        initial.state.publicContent?.categories,
        isNot(contains('comment-marian')),
      );
      expect(legacy.signups, 0);
      final cipher = File.fromUri(directory.uri.resolve('catalog.bin'));
      expect(
        latin1.decode(await cipher.readAsBytes()),
        isNot(contains('synthetic private')),
      );
      expect(record.record.toString(), isNot(contains('synthetic private')));
      expect(record.record.toString(), isNot(contains(_privateComment)));
      expect(
        latin1.decode(await cipher.readAsBytes()),
        isNot(contains(_privateComment)),
      );
      final readsBeforeRestore = access.reads.length;
      initial.dispose();

      final restored = PriestAccessController(
        legacy,
        record,
        offlineStorage: disk.reopen(),
        accessSets: access,
      );
      restored.suspend(online: false);
      await restored.initialize();
      expect(restored.state.offlineReady, isTrue);
      expect(restored.state.allowedSets, {'marian', 'priest'});
      final restoredCategories = projectPrayerCategories(
        restored.state.content!.categories,
        allowRestricted: true,
      );
      expect(
        restoredCategories
            .singleWhere((row) => row.id == 'comment-marian')
            .comment
            ?.content,
        _privateComment,
      );
      expect(
        restoredCategories.singleWhere((row) => row.id == 'old-priest').comment,
        isNull,
      );
      expect(access.reads, hasLength(readsBeforeRestore));
      expect(await restored.readPrayer('marian-one'), isNotNull);
      final offline = restored.state.content!.prayers.entries
          .map((e) => Prayer.fromMap(e.value, e.key))
          .toList();
      expect(
        filterAndSortPrayers(
          offline,
          const PrayersFilter(searchQuery: 'synthetic private'),
          ['marian-one'],
        ).first.id,
        'marian-one',
      );
      restored.suspend(foreground: false);
      await restored.resume(foreground: true);
      expect(await restored.readPrayer('priest-one'), isNotNull);
      access.reads.clear();
      access.hashes['marian-one'] = '1' * 64;
      access.hashes['comment-marian'] = '2' * 64;
      access.categories['comment-marian']!['comment'] = {
        'content': 'UPDATED $_privateComment',
      };
      await restored.resume(online: true);
      await _until(
        () =>
            restored.state.content?.prayers['marian-one']?['text'] ==
            'Updated synthetic text',
      );
      expect(
        access.reads,
        unorderedEquals([
          (AccessContentKind.prayers, 'marian-one'),
          (AccessContentKind.categories, 'comment-marian'),
        ]),
      );
      expect(restored.state.error, isNull);
      expect(
        (await disk.reopen().read())
            ?.content
            .categories['comment-marian']?['comment'],
        {'content': 'UPDATED $_privateComment'},
      );
      expect(
        access.checked,
        containsAll(['marian-one', 'priest-one', 'shared']),
      );

      restored.suspend(online: false);
      access.profile = AccessEntitlements('combined', ['priest'], 2);
      expect(restored.state.content?.categories, contains('comment-marian'));
      await restored.resume(online: true);
      await _until(
        () =>
            restored.state.allowedSets.length == 1 &&
            restored.state.offlineReady,
      );
      expect(
        restored.state.content?.prayers.containsKey('marian-one'),
        isFalse,
      );
      expect(
        (await disk.reopen().read())?.content.prayers.containsKey('marian-one'),
        isFalse,
      );
      expect(
        restored.state.content?.categories,
        isNot(contains('comment-marian')),
      );
      expect(
        (await disk.reopen().read())?.content.categories,
        isNot(contains('comment-marian')),
      );
      restored.suspend(online: false);
      legacy.offline = true;
      await restored.disable();
      expect(restored.state.content, isNull);
      expect(restored.state.pendingDisable, isTrue);
      expect(await disk.reopen().read(), isNull);
      expect(disk.key, isNull);
      restored.dispose();
      await access.events.close();
      await legacy.close();
    },
  );

  test(
    'canonical categories respect each confirmed set and suspend on the memory path',
    () async {
      for (final (mode, sets, expected) in [
        (AccessSetsMode.canonical, ['priest'], ['priest-only', 'combined']),
        (AccessSetsMode.canonical, ['marian'], ['marian-only', 'combined']),
        (
          AccessSetsMode.canonical,
          ['marian', 'priest'],
          ['priest-only', 'marian-only', 'combined'],
        ),
        (AccessSetsMode.canonical, ['future-catalog'], ['future-only']),
        (AccessSetsMode.suspended, ['marian', 'priest'], <String>[]),
      ]) {
        final legacy = SparkGateway()..uid = 'fixture-device';
        final access = _UpdatingGateway()
          ..mode = mode
          ..grant = (codeId: 'ABCDEFGHJKLMNPQR', active: true)
          ..profile = AccessEntitlements('fixture-profile', sets, 1)
          ..indexes['future-catalog'] = ['future-prayer'];
        access.categories.addAll({
          'priest-only': _category('priest-only', ['priest']),
          'marian-only': _category('marian-only', ['marian']),
          'combined': _category('combined', ['marian', 'priest']),
          'future-only': _category('future-only', ['future-catalog']),
          'invalid-child': _category('invalid-child', [
            'marian',
          ], parent: 'priest-only'),
        });
        final controller = PriestAccessController(
          legacy,
          MemoryStorage(),
          accessSets: access,
        );
        try {
          await controller.initialize();
          await controller.loadCatalog();
          final content = controller.state.content;
          final rows = projectPrayerCategories(
            content?.categories ?? {},
            allowRestricted: content != null,
          ).where((row) => row.isProtected);
          expect(rows.map((row) => row.id), unorderedEquals(expected));
          for (final row in rows) {
            expect(row.comment?.content, _privateComment);
          }
          controller.suspend(online: false);
          expect(controller.state.content, isNull);
        } finally {
          controller.dispose();
          await access.events.close();
          await legacy.close();
        }
      }
    },
  );

  test(
    'offline restore discards a category comment after UID change or signout',
    () async {
      for (final uid in ['different-uid', null]) {
        final store = disk.reopen();
        await store.write(
          ProtectedCatalogSnapshot(
            'original-uid',
            ['marian'],
            'fixture-v2-scope',
            PrayerAccessContent({}, {
              'private': _category('private', ['marian']),
            }),
          ),
        );
        final gateway = SparkGateway()..uid = uid;
        final controller = PriestAccessController(
          gateway,
          MemoryStorage(),
          offlineStorage: store,
        );
        try {
          controller.suspend(online: false);
          await controller.initialize();
          expect(controller.state.content, isNull);
          expect(await store.read(), isNull);
          expect(disk.key, isNull);
          expect(gateway.reads, 0);
        } finally {
          controller.dispose();
          await gateway.close();
        }
      }
    },
  );

  test(
    'an in-flight protected category cannot publish after suspension',
    () async {
      final legacy = SparkGateway()..uid = 'fixture-device';
      final gate = Completer<void>();
      final access = _UpdatingGateway()
        ..grant = (codeId: 'ABCDEFGHJKLMNPQR', active: true)
        ..pauseRead = gate
        ..categories['private'] = _category('private', ['marian']);
      final controller = PriestAccessController(
        legacy,
        MemoryStorage(),
        accessSets: access,
      );
      try {
        await controller.initialize();
        final loading = controller.loadCatalog();
        await _until(
          () =>
              access.reads.contains((AccessContentKind.categories, 'private')),
        );
        controller.suspend(online: false);
        gate.complete();
        await loading;
        expect(controller.state.content, isNull);
      } finally {
        if (!gate.isCompleted) gate.complete();
        controller.dispose();
        await access.events.close();
        await legacy.close();
      }
    },
  );

  test(
    'new activation checkpoints interrupted download and resumes securely',
    () async {
      final legacy = SparkGateway();
      final access = _UpdatingGateway()..interruptedId = 'shared';
      final record = MemoryStorage();
      final initial = PriestAccessController(
        legacy,
        record,
        offlineStorage: disk.reopen(),
        accessSets: access,
      );
      await initial.activate(syntheticCode, 'Synthetic device');
      await _until(
        () => initial.state.error != null && !initial.state.catalogLoading,
      );
      expect(await disk.reopen().read(), isNull);
      expect((await disk.reopen().read(staging: true))?.content.prayers.keys, [
        'marian-one',
      ]);
      initial.dispose();

      access.interruptedId = null;
      access.reads.clear();
      final resumed = PriestAccessController(
        legacy,
        record,
        offlineStorage: disk.reopen(),
        accessSets: access,
      );
      await resumed.initialize();
      await _until(() => resumed.state.offlineReady);
      expect(access.reads, [(AccessContentKind.prayers, 'shared')]);
      expect(await disk.reopen().read(staging: true), isNull);
      resumed.dispose();

      final other = PriestAccessController(
        SparkGateway()..uid = 'other',
        record,
        offlineStorage: disk.reopen(),
        accessSets: access,
      );
      other.suspend(online: false);
      await other.initialize();
      expect(other.state.content, isNull);
      expect(await disk.reopen().read(), isNull);
      other.dispose();
      await access.events.close();
      await legacy.close();
    },
  );

  test(
    'tampered ciphertext and staging substitution fail integrity checks',
    () async {
      final store = disk.reopen();
      final snapshot = ProtectedCatalogSnapshot(
        'device',
        ['test'],
        'v2-1',
        const PrayerAccessContent({
          'id': {'text': 'hidden'},
        }, {}),
      );
      await store.write(snapshot);
      expect((await store.read())?.uid, 'device');
      final complete = File.fromUri(directory.uri.resolve('catalog.bin'));
      final stage = File.fromUri(directory.uri.resolve('staging.bin'));
      await complete.copy(stage.path);
      expect(await store.read(staging: true), isNull);
      final bytes = await complete.readAsBytes();
      bytes[bytes.length - 1] ^= 1;
      await complete.writeAsBytes(bytes, flush: true);
      expect(await store.read(), isNull);
    },
  );

  test('speaker styling matches Web', () {
    final html = prayerMarkdownToHtml(
      'Л. За нашую краіну\nУ. Пане, пачуй нас.\n\n_(аўтар)_',
    );
    expect(html, contains('data-role="reader">Л.</span>'));
    expect(html, contains('data-role="all">У.</span>'));
    expect(html, contains('<em>(аўтар)</em>'));
    expect(
      prayerMarkdownToHtml('Л. Імя Прозвішча'),
      isNot(contains('prayer-speaker')),
    );
  });
}
