import 'package:mybrev_flutter/discovery/discovery.dart';
import 'package:mybrev_flutter/discovery/hints/p0_hints.dart';

final t0 = DateTime.utc(2026, 10, 31, 12);

const variantsAnchor = 'readings.day_variants.button';

/// A ready Readings context with [variants] day variants.
DiscoveryContext readings({
  int visit = 1,
  int? variants = 3,
  Set<String> anchors = const {variantsAnchor},
  DiscoveryUiState ui = DiscoveryUiState.calm,
  DiscoveryDataStatus status = DiscoveryDataStatus.ready,
  Map<String, Object?> extra = const {},
  String screen = 'readings',
}) => DiscoveryContext(
  screenId: screen,
  visitId: visit,
  status: status,
  anchors: anchors,
  ui: ui,
  facts: {kFactDayVariantCount: ?variants, ...extra},
);

HintDefinition testHint(
  String id,
  HintPriority priority, {
  int version = 1,
  int maxShows = 3,
  String screen = 'readings',
}) => HintDefinition(
  id: id,
  version: version,
  priority: priority,
  screenId: screen,
  anchorId: '$id.anchor',
  copyBe: 'copy $id',
  maxShows: maxShows,
);

DiscoveryContext testContext(
  Iterable<HintDefinition> hints, {
  int visit = 1,
  DiscoveryUiState ui = DiscoveryUiState.calm,
}) => DiscoveryContext(
  screenId: 'readings',
  visitId: visit,
  status: DiscoveryDataStatus.ready,
  anchors: {for (final h in hints) h.anchorId},
  ui: ui,
);

class RecordingPresenter implements HintPresenter {
  RecordingPresenter({this.mounts = true});

  bool mounts;
  final shown = <String>[];
  int dismissals = 0;
  Future<bool> Function(HintDefinition hint)? onPresent;

  @override
  Future<bool> present(HintDefinition hint) async {
    if (onPresent != null) return onPresent!(hint);
    if (mounts) shown.add(hint.id);
    return mounts;
  }

  @override
  void dismiss() => dismissals++;
}

Future<DiscoveryRepository> openRepo(
  DiscoveryStorage storage,
  FakeDiscoveryClock clock,
) => DiscoveryRepository.open(storage: storage, clock: clock);

DiscoveryCoordinator coordinatorFor(
  DiscoveryRepository repository,
  FakeDiscoveryClock clock,
  HintPresenter presenter, {
  HintCatalog? catalog,
}) => DiscoveryCoordinator(
  repository: repository,
  catalog: catalog ?? HintCatalog.standard(),
  clock: clock,
  presenter: presenter,
);
