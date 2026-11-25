import 'package:flutter/foundation.dart';
import 'package:mybrev_flutter/models/priest_access_content.dart';
import 'package:mybrev_flutter/services/access_sets_v2_code.dart';

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
  Future<PrayerAccessContent> load(Set<String> sets, bool Function() isCurrent);
  Future<Map<String, dynamic>?> readPrayer(String id);
}

class IndexedAccessSetsCatalog implements AccessSetsCatalog {
  const IndexedAccessSetsCatalog(this.gateway);
  final AccessSetsV2Gateway gateway;

  Future<Map<String, Map<String, dynamic>>> _loadKind(
    AccessContentKind kind,
    Set<String> sets,
    bool Function() isCurrent,
  ) async {
    final ids = <String>{};
    for (final set in sets) {
      String? cursor;
      do {
        if (!isCurrent()) return {};
        final page = await gateway.listIds(kind, set, after: cursor);
        ids.addAll(page.ids);
        cursor = page.cursor;
      } while (cursor != null);
    }
    final documents = <String, Map<String, dynamic>>{};
    final orderedIds = ids.toList();
    const parallelReads = 4;
    for (var start = 0; start < orderedIds.length; start += parallelReads) {
      if (!isCurrent()) return {};
      final batch = orderedIds.skip(start).take(parallelReads);
      await Future.wait(
        batch.map((id) async {
          final document = await gateway.readContent(kind, id);
          if (document != null) documents[id] = document;
        }),
      );
    }
    return documents;
  }

  @override
  Future<PrayerAccessContent> load(
    Set<String> sets,
    bool Function() isCurrent,
  ) async {
    final categories = await _loadKind(
      AccessContentKind.categories,
      sets,
      isCurrent,
    );
    final prayers = await _loadKind(AccessContentKind.prayers, sets, isCurrent);
    return PrayerAccessContent(prayers, categories);
  }

  @override
  Future<Map<String, dynamic>?> readPrayer(String id) =>
      gateway.readContent(AccessContentKind.prayers, id);
}
