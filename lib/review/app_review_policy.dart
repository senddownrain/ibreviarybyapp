import 'package:mybrev_flutter/review/app_review_state.dart';

/// Why an automatic request is not allowed right now (for tests and the
/// debug QA panel; never shown to people).
enum ReviewBlock {
  disabledBySetting,
  firstLaunchUnknown,
  clockRolledBack,
  tooEarly,
  tooFewDays,
  cooldown,
  yearlyLimit,
  sameVersion,
}

/// Fixed numbers from the product decision. Injectable only so tests can
/// probe the boundaries.
class AppReviewPolicy {
  const AppReviewPolicy({
    this.minAge = const Duration(days: 7),
    this.minUsageDays = 5,
    this.cooldown = const Duration(days: 120),
    this.window = const Duration(days: 365),
    this.maxPerWindow = 2,
  });

  final Duration minAge;
  final int minUsageDays;
  final Duration cooldown;
  final Duration window;
  final int maxPerWindow;

  /// `null` means eligible. Every condition is on local data only.
  ReviewBlock? evaluate(
    AppReviewState state, {
    required DateTime now,
    required String version,
  }) {
    if (state.autoPromptDisabled) return ReviewBlock.disabledBySetting;
    final first = state.firstLaunchMs;
    if (first == null) return ReviewBlock.firstLaunchUnknown;
    final nowMs = now.millisecondsSinceEpoch;
    final lastAttempt = state.attemptsMs.isEmpty
        ? null
        : state.attemptsMs.reduce((a, b) => a > b ? a : b);
    // A clock set back would make "7 days since install" or "120 days since
    // the last attempt" meaningless, so wait until it catches up.
    if (nowMs < first || (lastAttempt != null && nowMs < lastAttempt)) {
      return ReviewBlock.clockRolledBack;
    }
    if (nowMs - first < minAge.inMilliseconds) return ReviewBlock.tooEarly;
    if (state.usageDays.toSet().length < minUsageDays) {
      return ReviewBlock.tooFewDays;
    }
    if (lastAttempt != null && nowMs - lastAttempt < cooldown.inMilliseconds) {
      return ReviewBlock.cooldown;
    }
    final inWindow = state.attemptsMs
        .where((t) => nowMs - t < window.inMilliseconds)
        .length;
    if (inWindow >= maxPerWindow) return ReviewBlock.yearlyLimit;
    if (state.attemptVersions.contains(version)) return ReviewBlock.sameVersion;
    return null;
  }
}
