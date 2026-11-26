import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/models/priest_access_content.dart';
import 'package:mybrev_flutter/services/access_sets_v2_code.dart';
import 'package:mybrev_flutter/services/prayer_category_membership.dart';
import 'package:mybrev_flutter/services/priest_access_policy.dart';
import 'package:mybrev_flutter/services/priest_access_gateway.dart';

enum AccessSetsMode { legacy, canonical, suspended }

enum AccessContentKind {
  prayers('protectedPrayers'),
  categories('protectedCategories');

  const AccessContentKind(this.collection);
  final String collection;
}

typedef AccessV2Grant = ({String codeId, bool active});
typedef AccessIndexPage = ({List<String> ids, String? cursor});

class AccessEntitlements {
  AccessEntitlements(
    this.profileId,
    Iterable<String> allowedSets,
    this.revision,
  ) : allowedSets = Set.unmodifiable(allowedSets);

  final String profileId;
  final Set<String> allowedSets;
  final int revision;

  bool matches(AccessEntitlements? other) =>
      other != null &&
      profileId == other.profileId &&
      revision == other.revision &&
      setEquals(allowedSets, other.allowedSets);
}

abstract interface class AccessSetsV2Gateway {
  /// Null means the server still runs the pre-S1 ruleset.
  Future<AccessSetsMode?> readMode(String uid);
  Future<AccessV2Grant?> readGrant(String uid);
  Future<AccessEntitlements?> readEntitlements(String uid, AccessV2Grant grant);
  Future<void> activate(String uid, AccessSetsV2Code code, String deviceName);
  Future<void> revokeOwn(String uid);

  /// Emits on any difference from the confirmed session, including Auth loss.
  Stream<void> watch(
    String uid, {
    required AccessSetsMode mode,
    required AccessV2Grant? grant,
    required AccessEntitlements? entitlements,
  });

  Future<AccessIndexPage> listIds(
    AccessContentKind kind,
    String setId, {
    int pageSize = 50,
    String? after,
  });
  Future<Map<String, dynamic>?> readContent(AccessContentKind kind, String id);
}

/// The S4 integration boundary. Everything downstream consumes the existing
/// Flutter prayer/category payloads regardless of index layout.

abstract interface class AccessSetsCatalog {
  AccessSetsCatalogSession open(Set<String> sets, bool Function() isCurrent);
}

abstract interface class AccessSetsCatalogSession {
  Future<PrayerAccessContent> load(PrayerAccessContent public);
  Future<Map<String, dynamic>?> readPrayer(
    String id,
    PrayerAccessContent public,
  );
}

class IndexedAccessSetsCatalog implements AccessSetsCatalog {
  const IndexedAccessSetsCatalog(this.gateway);
  final AccessSetsV2Gateway gateway;

  @override
  AccessSetsCatalogSession open(Set<String> sets, bool Function() isCurrent) =>
      _IndexedCatalogSession(gateway, sets, isCurrent);
}

class _IndexedCatalogSession implements AccessSetsCatalogSession {
  _IndexedCatalogSession(this.gateway, this.sets, this.isCurrent);

  static const _pageSize = 25;
  static final _hash = RegExp(r'^[a-f0-9]{64}$');
  static const _expired = PriestAccessException('CATALOG_EXPIRED');
  final AccessSetsV2Gateway gateway;
  final Set<String> sets;
  final bool Function() isCurrent;
  final _rows = <(AccessContentKind, String), Future<Map<String, dynamic>?>>{};
  // All index and payload reads use the same four slots, including deep links.
  final _slots = List.generate(4, (_) => Future<void>.value());
  int _nextSlot = 0;
  Object? _failure;

  Future<T> _request<T>(Future<T> Function() run) {
    final slot = _nextSlot;
    _nextSlot = (_nextSlot + 1) % _slots.length;
    final result = _slots[slot].then((_) async {
      if (!isCurrent()) throw _expired;
      if (_failure case final error?) throw error;
      try {
        final value = await run();
        if (!isCurrent()) throw _expired;
        if (_failure case final error?) throw error;
        return value;
      } catch (error) {
        _failure ??= error;
        rethrow;
      }
    });
    _slots[slot] = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  static bool _validId(String value) =>
      value.isNotEmpty && !value.contains('/');

  static List<String>? _setList(Object? value) {
    if (value is! List ||
        !value.every((id) => id is String && accessSetId.hasMatch(id)) ||
        value.toSet().length != value.length) {
      return null;
    }
    return value.cast<String>();
  }

  static List<String> _effective(Map<String, dynamic>? row) =>
      _setList(row?['effectiveAccessSets']) ?? const [];

  bool _permitted(Map<String, dynamic> row, String id) {
    final effective = _effective(row);
    final ownSets = _setList(row['accessSets']);
    final hash = row['contentHash'];
    return row['id'] == id &&
        row['accessSchemaVersion'] == 2 &&
        ownSets != null &&
        hash is String &&
        _hash.hasMatch(hash) &&
        effective.any(sets.contains) &&
        (ownSets.isEmpty || effective.every(ownSets.contains)) &&
        (row['priestOnly'] != true || listEquals(effective, ['priest'])) &&
        ['tags', 'prayerIds', 'categoryIds'].every(
          (field) =>
              !row.containsKey(field) ||
              (row[field] is List &&
                  (row[field] as List).every((id) => id is String)),
        );
  }

  Future<Map<String, dynamic>?> _row(AccessContentKind kind, String id) {
    if (!_validId(id)) return Future.value(null);
    return _rows.putIfAbsent((kind, id), () async {
      final row = await _request(() => gateway.readContent(kind, id));
      return row != null && _permitted(row, id) ? row : null;
    });
  }

  Future<Map<String, Map<String, dynamic>>> _loadKind(
    AccessContentKind kind,
  ) async {
    final accepted = <String, Map<String, dynamic>>{};
    final orderedSets = sets.toList()..sort();
    for (final set in orderedSets) {
      String? cursor;
      do {
        final page = await _request(
          () => gateway.listIds(kind, set, pageSize: _pageSize, after: cursor),
        );
        if (page.ids.length > _pageSize ||
            !page.ids.every(_validId) ||
            (page.cursor != null &&
                (page.cursor != page.ids.lastOrNull ||
                    page.cursor == cursor))) {
          throw const PriestAccessException('SERVICE_UNAVAILABLE');
        }
        final rows = await Future.wait(
          page.ids
              .where((id) => !accepted.containsKey(id))
              .map((id) => _row(kind, id)),
          eagerError: true,
        );
        for (final row in rows.whereType<Map<String, dynamic>>()) {
          if (_effective(row).contains(set)) {
            accepted[row['id'] as String] = row;
          }
        }
        cursor = page.cursor;
      } while (cursor != null);
    }
    return accepted;
  }

  bool _validCategory(String id, Map<String, Map<String, dynamic>> categories) {
    final seen = <String>{};
    var current = id;
    while (seen.add(current) && seen.length <= kMaxPrayerCategoryDepth) {
      final row = categories[current];
      if (row == null) return false;
      final parent = row['parentId'];
      if (parent == null || parent == '') return true;
      if (parent is! String || !_validId(parent)) return false;
      final parentSets = _effective(categories[parent]);
      final childSets = _effective(row);
      if (parentSets.isNotEmpty &&
          (childSets.isEmpty || !childSets.every(parentSets.contains))) {
        return false;
      }
      current = parent;
    }
    return false;
  }

  Iterable<String> _categoryIds(Map<String, dynamic> row) => [
    row['categoryId'],
    ...?row['categoryIds'] as List?,
  ].whereType<String>().where((id) => id.isNotEmpty).toSet();

  bool _prayerFits(
    Map<String, dynamic> row,
    Map<String, Map<String, dynamic>> categories,
  ) {
    if (row['categoryId'] != null && row['categoryId'] is! String) return false;
    final effective = _effective(row);
    for (final id in _categoryIds(row)) {
      if (!_validCategory(id, categories)) return false;
    }
    for (final entry in categories.entries) {
      final category = entry.value;
      final ownerSets = _effective(category);
      if (ownerSets.isEmpty || effective.every(ownerSets.contains)) continue;
      if (matchesPrayerCategory(
        prayerId: row['id'] as String,
        prayerTags: (row['tags'] as List?) ?? const [],
        prayerCategoryId: row['categoryId'] as String?,
        prayerCategoryIds: (row['categoryIds'] as List?) ?? const [],
        categoryId: entry.key,
        categoryTags: (category['tags'] as List?) ?? const [],
        categoryPrayerIds: (category['prayerIds'] as List?) ?? const [],
      )) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<PrayerAccessContent> load(PrayerAccessContent public) async {
    final categories = await _loadKind(AccessContentKind.categories);
    final combined = {...public.categories, ...categories};
    final prayers = await _loadKind(AccessContentKind.prayers);
    return PrayerAccessContent(
      {
        for (final entry in prayers.entries)
          if (_prayerFits(entry.value, combined)) entry.key: entry.value,
      },
      {
        for (final entry in categories.entries)
          if (_validCategory(entry.key, combined)) entry.key: entry.value,
      },
    );
  }

  @override
  Future<Map<String, dynamic>?> readPrayer(
    String id,
    PrayerAccessContent public,
  ) async {
    final prayer = await _row(AccessContentKind.prayers, id);
    if (prayer == null) return null;
    final categories = {...public.categories};
    for (final start in _categoryIds(prayer)) {
      String? current = start;
      var depth = 0;
      while (current != null && !categories.containsKey(current)) {
        if (++depth > kMaxPrayerCategoryDepth) return null;
        final row = await _row(AccessContentKind.categories, current);
        if (row == null) return null;
        categories[current] = row;
        final parent = row['parentId'];
        current = parent is String && parent.isNotEmpty ? parent : null;
      }
    }
    return _prayerFits(prayer, categories) ? prayer : null;
  }
}
