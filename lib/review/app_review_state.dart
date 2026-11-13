import 'dart:convert';

/// What the app remembers locally about the store-review prompt. Nothing here
/// leaves the device and nothing records whether a person actually rated: the
/// system API never says, so only the time of *our call* is stored.
class AppReviewState {
  const AppReviewState({
    this.firstLaunchMs,
    this.usageDays = const [],
    this.attemptsMs = const [],
    this.attemptVersions = const [],
    this.autoPromptDisabled = false,
  });

  /// Milliseconds since epoch of the first run that was recorded.
  final int? firstLaunchMs;

  /// Distinct local calendar days of use as `yyyy-MM-dd`, oldest first.
  final List<String> usageDays;

  /// Times (ms since epoch) at which we called the native review API.
  final List<int> attemptsMs;

  /// App version (`1.0.0+6`) of each attempt, parallel to [attemptsMs].
  final List<String> attemptVersions;

  /// The settings switch «Не прапаноўваць ацэнку». Blocks automatic requests
  /// only; the manual store link never looks at it.
  final bool autoPromptDisabled;

  static const _maxDays = 30;
  static const _maxAttempts = 10;

  AppReviewState copyWith({
    int? firstLaunchMs,
    List<String>? usageDays,
    List<int>? attemptsMs,
    List<String>? attemptVersions,
    bool? autoPromptDisabled,
  }) => AppReviewState(
    firstLaunchMs: firstLaunchMs ?? this.firstLaunchMs,
    usageDays: usageDays ?? this.usageDays,
    attemptsMs: attemptsMs ?? this.attemptsMs,
    attemptVersions: attemptVersions ?? this.attemptVersions,
    autoPromptDisabled: autoPromptDisabled ?? this.autoPromptDisabled,
  );

  /// Adds today's key once; keeps the list short.
  AppReviewState withUsageDay(String day) {
    if (usageDays.contains(day)) return this;
    final days = [...usageDays, day];
    return copyWith(
      usageDays: days.length > _maxDays
          ? days.sublist(days.length - _maxDays)
          : days,
    );
  }

  AppReviewState withAttempt(int ms, String version) {
    final times = [...attemptsMs, ms];
    final versions = [...attemptVersions, version];
    final cut = times.length > _maxAttempts ? times.length - _maxAttempts : 0;
    return copyWith(
      attemptsMs: times.sublist(cut),
      attemptVersions: versions.sublist(cut),
    );
  }

  String encode() => jsonEncode({
    'v': 1,
    'firstLaunchMs': firstLaunchMs,
    'usageDays': usageDays,
    'attemptsMs': attemptsMs,
    'attemptVersions': attemptVersions,
    'autoPromptDisabled': autoPromptDisabled,
  });

  /// Tolerant: a damaged or foreign payload yields the empty state instead
  /// of an exception on startup.
  static AppReviewState decode(String? raw) {
    if (raw == null || raw.isEmpty) return const AppReviewState();
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const AppReviewState();
      List<T> list<T>(Object? value) =>
          value is List ? value.whereType<T>().toList() : <T>[];
      final times = list<int>(json['attemptsMs']);
      final versions = list<String>(json['attemptVersions']);
      return AppReviewState(
        firstLaunchMs: json['firstLaunchMs'] is int
            ? json['firstLaunchMs'] as int
            : null,
        usageDays: list<String>(json['usageDays']),
        attemptsMs: times,
        attemptVersions: versions.length == times.length
            ? versions
            : List<String>.filled(times.length, ''),
        autoPromptDisabled: json['autoPromptDisabled'] == true,
      );
    } catch (_) {
      return const AppReviewState();
    }
  }
}
