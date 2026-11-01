import 'package:flutter/foundation.dart' show immutable;

/// Lower index = higher priority (P0 > P1 > P2).
enum HintPriority { p0, p1, p2 }

/// `deferred` keeps an ID in the catalog (stable, versioned) while the
/// audited feature is not confirmed; a deferred hint is never eligible.
enum HintStatus { active, deferred }

/// One condition on a fact the screen reports. A missing fact means the
/// source is unknown, so the hint stays silent.
@immutable
class FactRequirement {
  const FactRequirement(this.key, this.test);

  /// The fact is a number of at least [min].
  factory FactRequirement.atLeast(String key, int min) =>
      FactRequirement(key, (value) => value is num && value >= min);

  /// The fact is exactly `true`.
  factory FactRequirement.isTrue(String key) =>
      FactRequirement(key, (value) => value == true);

  final String key;
  final bool Function(Object? value) test;
}

/// A catalog entry. Adding a hint = adding one of these to a file under
/// `lib/discovery/hints/`; no shared file changes.
@immutable
class HintDefinition {
  const HintDefinition({
    required this.id,
    required this.version,
    required this.priority,
    required this.screenId,
    required this.anchorId,
    required this.copyBe,
    this.actionLabelBe,
    this.requirements = const [],
    this.status = HintStatus.active,
    this.maxShows = 3,
    this.allowSnooze = true,
  });

  /// Stable public identifier, never renamed or reused.
  final String id;

  /// Bumped when the copy or meaning changes materially. A new version never
  /// revives a dismissed or completed hint.
  final int version;
  final HintPriority priority;

  /// Screen on which the hint may appear.
  final String screenId;

  /// Stable identifier of the real widget the hint points at.
  final String anchorId;

  /// Belarusian text shown to the person.
  final String copyBe;

  /// Label of the primary action (`Паказаць`); null for a pure note.
  final String? actionLabelBe;
  final List<FactRequirement> requirements;
  final HintStatus status;

  /// Hard cap on automatic displays (first display plus snoozed repeats).
  final int maxShows;
  final bool allowSnooze;
}
