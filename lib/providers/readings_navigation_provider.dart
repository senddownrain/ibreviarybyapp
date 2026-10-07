import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ReadingsBranchState {
  const ReadingsBranchState({
    required this.date,
    this.liturgicalKey,
    this.dayId,
  });

  final DateTime date;
  final String? liturgicalKey;
  final String? dayId;

  ReadingsBranchState copyWith({
    DateTime? date,
    String? liturgicalKey,
    String? dayId,
    bool clearLiturgicalKey = false,
    bool clearDayId = false,
  }) => ReadingsBranchState(
    date: DateUtils.dateOnly(date ?? this.date),
    liturgicalKey: clearLiturgicalKey
        ? null
        : (liturgicalKey ?? this.liturgicalKey),
    dayId: clearDayId ? null : (dayId ?? this.dayId),
  );
}

final readingsBranchStateProvider = StateProvider<ReadingsBranchState>(
  (ref) => ReadingsBranchState(date: DateUtils.dateOnly(DateTime.now())),
);

/// Mass reading set chosen on the Readings screen, per document of a
/// Readings context (`'<date or liturgical key>|<document id>'` → set id).
/// Kept for the session: returning to a date shows the same set. Not the
/// Office option / Common choice of the Hours.
final readingsMassSetSelectionProvider = StateProvider<Map<String, String>>(
  (ref) => const {},
);
