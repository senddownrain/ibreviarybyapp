import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';

final liturgicalNavigationControllerProvider = Provider(
  LiturgicalNavigationController.new,
);

/// One navigation command for both daily branches. UI actions use this
/// controller so the Hours and Readings trees move in the same frame.
class LiturgicalNavigationController {
  LiturgicalNavigationController(this.ref);

  final Ref ref;

  void openDate(DateTime value, {String? dayId}) {
    final date = DateUtils.dateOnly(value);
    final current = DateUtils.dateOnly(ref.read(selectedDateProvider));
    if (!DateUtils.isSameDay(date, current)) {
      ref.read(homeNavDirectionProvider.notifier).state = date.isAfter(current)
          ? 1
          : -1;
    }

    if (dayId != null) {
      ref.read(hoursLiturgicalOverridesProvider.notifier).select(date, dayId);
    }
    ref.read(selectedDateProvider.notifier).state = date;

    final readings = ref.read(readingsBranchStateProvider);
    ref.read(readingsBranchStateProvider.notifier).state = readings.copyWith(
      date: date,
      dayId: dayId,
      clearLiturgicalKey: true,
      clearDayId: dayId == null,
    );
  }

  void moveBy(int days) {
    openDate(ref.read(selectedDateProvider).add(Duration(days: days)));
  }

  void selectDay(DateTime value, String dayId) {
    final date = DateUtils.dateOnly(value);
    ref.read(hoursLiturgicalOverridesProvider.notifier).select(date, dayId);
    final readings = ref.read(readingsBranchStateProvider);
    ref.read(readingsBranchStateProvider.notifier).state = readings.copyWith(
      date: date,
      dayId: dayId,
      clearLiturgicalKey: true,
    );
  }
}

/// Keeps the daily context shared by the Hours and Readings branches.
///
/// The guard is needed because every propagated update is observed by the
/// provider on the other side as well.
final liturgicalNavigationSyncProvider = Provider<void>((ref) {
  var propagating = false;

  void propagate(void Function() update) {
    if (propagating) return;
    propagating = true;
    try {
      update();
    } finally {
      propagating = false;
    }
  }

  ref.listen<DateTime>(selectedDateProvider, (previous, next) {
    final date = DateUtils.dateOnly(next);
    final readings = ref.read(readingsBranchStateProvider);
    final dayId = ref.read(hoursLiturgicalSelectionProvider).dayId;
    if (DateUtils.isSameDay(readings.date, date) &&
        readings.liturgicalKey == null &&
        readings.dayId == dayId) {
      return;
    }
    propagate(() {
      ref.read(readingsBranchStateProvider.notifier).state = readings.copyWith(
        date: date,
        dayId: dayId,
        clearLiturgicalKey: true,
        clearDayId: dayId == null,
      );
    });
  });

  ref.listen(hoursLiturgicalSelectionProvider, (previous, next) {
    final dayId = next.dayId;
    final date = DateUtils.dateOnly(ref.read(selectedDateProvider));
    final readings = ref.read(readingsBranchStateProvider);
    if (DateUtils.isSameDay(readings.date, date) &&
        readings.liturgicalKey == null &&
        readings.dayId == dayId) {
      return;
    }
    propagate(() {
      ref.read(readingsBranchStateProvider.notifier).state = readings.copyWith(
        date: date,
        dayId: dayId,
        clearLiturgicalKey: true,
        clearDayId: dayId == null,
      );
    });
  });

  ref.listen<ReadingsBranchState>(readingsBranchStateProvider, (
    previous,
    next,
  ) {
    final date = DateUtils.dateOnly(next.date);
    propagate(() {
      final dayId = next.dayId;
      if (dayId != null) {
        final overrides = ref.read(hoursLiturgicalOverridesProvider);
        final key = liturgicalDateKey(date);
        if (overrides[key] != dayId) {
          ref
              .read(hoursLiturgicalOverridesProvider.notifier)
              .select(date, dayId);
        }
      }
      if (!DateUtils.isSameDay(ref.read(selectedDateProvider), date)) {
        ref.read(selectedDateProvider.notifier).state = date;
      }
    });
  });
});
