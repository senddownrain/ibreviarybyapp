import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/discovery/discovery_clock.dart';
import 'package:mybrev_flutter/discovery/discovery_coordinator.dart';
import 'package:mybrev_flutter/discovery/discovery_repository.dart';
import 'package:mybrev_flutter/discovery/discovery_state.dart';
import 'package:mybrev_flutter/discovery/discovery_storage.dart';
import 'package:mybrev_flutter/discovery/hint_catalog.dart';
import 'package:mybrev_flutter/discovery/hint_eligibility.dart';

/// Every dependency is a provider so tests and the QA harness override the
/// same seams the app uses.
final discoveryClockProvider = Provider<DiscoveryClock>(
  (ref) => const SystemDiscoveryClock(),
);

final discoveryStorageProvider = Provider<DiscoveryStorage>(
  (ref) => HiveDiscoveryStorage(),
);

final hintCatalogProvider = Provider<HintCatalog>(
  (ref) => HintCatalog.standard(),
);

final discoveryPolicyConfigProvider = Provider<DiscoveryPolicyConfig>(
  (ref) => const DiscoveryPolicyConfig(),
);

/// The single presenter of the app; Stage 3 overrides it.
final hintPresenterProvider = Provider<HintPresenter>(
  (ref) => const NullHintPresenter(),
);

final discoveryRepositoryProvider = FutureProvider<DiscoveryRepository>((
  ref,
) async {
  final repository = await DiscoveryRepository.open(
    storage: ref.watch(discoveryStorageProvider),
    clock: ref.watch(discoveryClockProvider),
    policy: ref.watch(discoveryPolicyConfigProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// Live state for settings and QA screens.
final discoveryStateProvider = StreamProvider<DiscoveryState>((ref) async* {
  final repository = await ref.watch(discoveryRepositoryProvider.future);
  yield repository.state;
  yield* repository.changes;
});

final discoveryCoordinatorProvider = FutureProvider<DiscoveryCoordinator>((
  ref,
) async {
  final repository = await ref.watch(discoveryRepositoryProvider.future);
  return DiscoveryCoordinator(
    repository: repository,
    catalog: ref.watch(hintCatalogProvider),
    clock: ref.watch(discoveryClockProvider),
    presenter: ref.watch(hintPresenterProvider),
    policy: HintPolicy(ref.watch(discoveryPolicyConfigProvider)),
  );
});
