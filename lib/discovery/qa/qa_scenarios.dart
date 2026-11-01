import 'package:mybrev_flutter/discovery/discovery_context.dart';
import 'package:mybrev_flutter/discovery/hints/p0_hints.dart';

/// Synthetic inputs for the QA harness. They exercise the engine's own
/// eligibility logic; they do NOT prove that an alternative is liturgically
/// allowed on any real date.
enum QaScenario {
  withVariants('Ёсць варыянты', 'readings.day_variants'),
  noVariants('Няма варыянтаў', 'none'),
  otherYear('Іншы год', 'readings.other_year'),
  loading('Loading', 'none'),
  error('Памылка', 'none'),
  disabled('Выключана', 'none');

  const QaScenario(this.label, this.expected);

  final String label;

  /// The `hint_id` (or `none`) the engine must answer for a fresh profile.
  final String expected;

  /// Hints are globally off only in the `disabled` scenario.
  bool get hintsEnabled => this != QaScenario.disabled;

  DiscoveryContext context(int visitId) {
    const screen = 'readings';
    const variantsAnchor = 'readings.day_variants.button';
    const cycleAnchor = 'readings.cycle.button';
    switch (this) {
      case QaScenario.loading:
        return DiscoveryContext.loading(
          screenId: screen,
          visitId: visitId,
          anchors: const {variantsAnchor},
        );
      case QaScenario.error:
        return DiscoveryContext.error(
          screenId: screen,
          visitId: visitId,
          anchors: const {variantsAnchor},
        );
      case QaScenario.noVariants:
        return DiscoveryContext(
          screenId: screen,
          visitId: visitId,
          status: DiscoveryDataStatus.ready,
          anchors: const {variantsAnchor},
          facts: const {kFactDayVariantCount: 1},
        );
      case QaScenario.otherYear:
        return DiscoveryContext(
          screenId: screen,
          visitId: visitId,
          status: DiscoveryDataStatus.ready,
          anchors: const {cycleAnchor},
          facts: const {kFactDayVariantCount: 1, kFactOtherCycleLoaded: true},
        );
      case QaScenario.withVariants:
      case QaScenario.disabled:
        return DiscoveryContext(
          screenId: screen,
          visitId: visitId,
          status: DiscoveryDataStatus.ready,
          anchors: const {variantsAnchor},
          facts: const {kFactDayVariantCount: 3},
        );
    }
  }
}
