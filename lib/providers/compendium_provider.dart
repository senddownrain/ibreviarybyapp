import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:mybrev_flutter/models/compendium.dart';
import 'package:mybrev_flutter/models/sync_plan.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/providers/sync_provider.dart';
import 'package:mybrev_flutter/services/compendium_repository.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';
import 'package:mybrev_flutter/utils/compendium_search.dart';

// ── Data ─────────────────────────────────────────────────────────────────────

/// Bundled canonical dataset, decoded on first use (never at startup).
final compendiumBundledProvider = FutureProvider<CompendiumDataset>(
  (ref) => CompendiumRepository.loadBundled(),
);

/// Hidden search aliases. Search still works without them.
final compendiumAliasesProvider = FutureProvider<CompendiumSearchAliases>((
  ref,
) async {
  try {
    return CompendiumSearchAliases.compile(
      await CompendiumRepository.loadAliases(),
    );
  } catch (_) {
    return CompendiumSearchAliases.empty;
  }
});

/// Synced copy from the `compendium` SyncTarget, if complete and valid.
final compendiumStoredProvider = Provider<CompendiumDataset?>((ref) {
  ref.watch(cacheEpochProvider);
  return CompendiumRepository.readStored();
});

/// The synced copy wins only when it is strictly newer than the bundle
/// (MyBrev `createCompendiumLoader`).
CompendiumDataset selectCompendium(
  CompendiumDataset bundled,
  CompendiumDataset? stored,
) =>
    stored != null &&
        stored.meta.schemaVersion == bundled.meta.schemaVersion &&
        stored.meta.contentVersion > bundled.meta.contentVersion
    ? stored
    : bundled;

/// Offline-first dataset: bundled seed, replaced by a newer synced copy. If
/// the seed cannot be read, a valid synced copy is still shown.
final compendiumDatasetProvider = Provider<AsyncValue<CompendiumDataset>>((
  ref,
) {
  final bundled = ref.watch(compendiumBundledProvider);
  final stored = ref.watch(compendiumStoredProvider);
  return switch (bundled) {
    AsyncData(:final value) => AsyncData(selectCompendium(value, stored)),
    AsyncError(:final error, :final stackTrace) =>
      stored == null ? AsyncError(error, stackTrace) : AsyncData(stored),
    _ => const AsyncLoading(),
  };
});

final _indexes = Expando<CompendiumIndex>('compendiumIndex');

/// Lookup structures, built once per dataset instance.
final compendiumIndexProvider = Provider<AsyncValue<CompendiumIndex>>(
  (ref) => ref
      .watch(compendiumDatasetProvider)
      .whenData((dataset) => _indexes[dataset] ??= CompendiumIndex(dataset)),
);

final compendiumQuestionProvider =
    Provider.family<AsyncValue<CompendiumQuestion?>, String>(
      (ref, number) => ref
          .watch(compendiumIndexProvider)
          .whenData(
            (index) => RegExp(r'^\d{1,3}$').hasMatch(number)
                ? index.getQuestion(number)
                : null,
          ),
    );

final compendiumGroupProvider =
    Provider.family<AsyncValue<CompendiumGroup?>, String>(
      (ref, id) => ref
          .watch(compendiumIndexProvider)
          .whenData((index) => index.getGroup(id)),
    );

/// Visible source outline of a part (only real headings are nodes).
final compendiumPartOutlineProvider =
    Provider.family<AsyncValue<CompendiumNavNode?>, String>(
      (ref, partId) => ref
          .watch(compendiumIndexProvider)
          .whenData((index) => index.partOutline(partId)),
    );

// ── Search ───────────────────────────────────────────────────────────────────

/// Search index, built lazily the first time a query is entered and only
/// once per dataset and alias file.
final compendiumSearchIndexProvider = Provider<CompendiumSearchIndex?>((ref) {
  final index = ref.watch(compendiumIndexProvider).valueOrNull;
  final aliases = ref.watch(compendiumAliasesProvider);
  if (index == null || aliases.isLoading) return null;
  return CompendiumSearchIndex(
    index.questions,
    aliases.valueOrNull ?? CompendiumSearchAliases.empty,
  );
});

/// Session search query, shared by the search dock of every Compendium
/// screen; kept when the user opens a result and comes back.
class CompendiumSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final compendiumSearchQueryProvider =
    NotifierProvider<CompendiumSearchQueryNotifier, String>(
      CompendiumSearchQueryNotifier.new,
    );

final compendiumSearchResultsProvider = Provider<List<CompendiumSearchResult>>((
  ref,
) {
  final query = ref.watch(compendiumSearchQueryProvider);
  if (query.trim().isEmpty) return const [];
  final index = ref.watch(compendiumSearchIndexProvider);
  return index == null ? const [] : searchCompendium(index, query);
});

// ── Session view state ───────────────────────────────────────────────────────

/// Expanded question rows per reading group, kept for the session.
class CompendiumExpandedNotifier extends Notifier<Map<String, Set<int>>> {
  @override
  Map<String, Set<int>> build() => const {};

  bool isExpanded(String groupId, int number) =>
      state[groupId]?.contains(number) ?? false;

  void toggle(String groupId, int number) {
    final current = {...?state[groupId]};
    if (!current.remove(number)) current.add(number);
    state = {...state, groupId: current};
  }
}

final compendiumExpandedProvider =
    NotifierProvider<CompendiumExpandedNotifier, Map<String, Set<int>>>(
      CompendiumExpandedNotifier.new,
    );

// ── Opportunistic refresh ────────────────────────────────────────────────────

/// Called when the Compendium is opened. If the device is online and the
/// Compendium was not checked during the last day, queue a background,
/// cancellable `compendium`-only sync (one meta read; units only when newer).
/// The bundled text stays visible meanwhile.
final compendiumRefreshProvider = Provider<void Function()>((ref) {
  return () {
    if (ref.read(isOfflineProvider)) return;
    if (!Hive.isBoxOpen('meta')) return;
    final last = HiveService.getLastSync(SyncTarget.compendium.collection);
    if (last != null &&
        DateTime.now().difference(last) < const Duration(days: 1)) {
      return;
    }
    ref
        .read(syncStatusProvider.notifier)
        .synchronize(
          const SyncPlan(
            targets: {SyncTarget.compendium},
            forceRefresh: false,
            background: true,
          ),
        );
  };
});
