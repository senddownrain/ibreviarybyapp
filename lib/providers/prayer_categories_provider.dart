import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/firestore_cache.dart';

const kPrayerCategoriesCollection = 'prayerCategories';

class PrayerMenuCategory {
  final String id;
  final String name;
  final List<String> tags;
  final bool isGlobal;

  const PrayerMenuCategory({
    required this.id,
    required this.name,
    required this.tags,
    required this.isGlobal,
  });

  factory PrayerMenuCategory.global(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return PrayerMenuCategory(
      id: document.id,
      name: data['name']?.toString().trim() ?? '',
      tags: _cleanTags(data['tags']),
      isGlobal: true,
    );
  }

  factory PrayerMenuCategory.personal(UserCategory category) =>
      PrayerMenuCategory(
        id: category.id,
        name: category.name,
        tags: category.tags,
        isGlobal: false,
      );
}

List<String> _cleanTags(dynamic value) {
  if (value is! Iterable) return const [];
  return value
      .map((tag) => tag.toString().trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();
}

final globalPrayerCategoriesProvider = StreamProvider<List<PrayerMenuCategory>>(
  (ref) async* {
    if (Hive.isBoxOpen(kPrayerCategoriesCollection)) {
      final cached = HiveService.boxFor(kPrayerCategoriesCollection).values
          .whereType<Map>()
          .map(
            (data) => PrayerMenuCategory(
              id: data['id'].toString(),
              name: data['name']?.toString().trim() ?? '',
              tags: _cleanTags(data['tags']),
              isGlobal: true,
            ),
          )
          .where((c) => c.name.isNotEmpty)
          .toList();
      if (cached.isNotEmpty) yield cached;
    }
    yield* FirebaseFirestore.instance
        .collection(kPrayerCategoriesCollection)
        .snapshots()
        .asyncMap((snapshot) async {
          if (Hive.isBoxOpen(kPrayerCategoriesCollection)) {
            for (final doc in snapshot.docs) {
              await HiveService.putCached(
                kPrayerCategoriesCollection,
                doc.id,
                firestoreToStorable({...doc.data(), 'id': doc.id}),
              );
            }
          }
          final documents = snapshot.docs.toList()
            ..sort((left, right) {
              final leftRawOrder = left.data()['order'];
              final rightRawOrder = right.data()['order'];
              final leftOrder = leftRawOrder is num
                  ? leftRawOrder.toDouble()
                  : null;
              final rightOrder = rightRawOrder is num
                  ? rightRawOrder.toDouble()
                  : null;
              final orderComparison = (leftOrder ?? double.maxFinite).compareTo(
                rightOrder ?? double.maxFinite,
              );
              if (orderComparison != 0) return orderComparison;
              return (left.data()['name']?.toString() ?? '')
                  .toLowerCase()
                  .compareTo(
                    (right.data()['name']?.toString() ?? '').toLowerCase(),
                  );
            });

          return documents
              .map(PrayerMenuCategory.global)
              .where((category) => category.name.isNotEmpty)
              .toList(growable: false);
        });
  },
);

/// Combines database-managed defaults with local user customizations.
/// Global categories win on duplicate names, matching the web application.
final prayerMenuCategoriesProvider = Provider<List<PrayerMenuCategory>>((ref) {
  final settings = ref.watch(settingsProvider);
  final globalCategories =
      ref.watch(globalPrayerCategoriesProvider).value ?? [];
  return buildPrayerCategoryMenu(
    globalCategories,
    settings.userCategories,
    settings.hiddenGlobalPrayerCategoryIds,
  );
});

List<PrayerMenuCategory> buildPrayerCategoryMenu(
  List<PrayerMenuCategory> globalCategories,
  List<UserCategory> personalCategories,
  List<String> hiddenGlobalCategoryIds,
) {
  final hiddenIds = hiddenGlobalCategoryIds.toSet();
  final names = <String>{};
  final result = <PrayerMenuCategory>[];

  for (final category in globalCategories) {
    if (hiddenIds.contains(category.id)) continue;
    final nameKey = category.name.toLowerCase();
    names.add(nameKey);
    result.add(category);
  }

  for (final category in personalCategories) {
    final nameKey = category.name.toLowerCase();
    if (!names.add(nameKey)) continue;
    result.add(PrayerMenuCategory.personal(category));
  }

  return result;
}
