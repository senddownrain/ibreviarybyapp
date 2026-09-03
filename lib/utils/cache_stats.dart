import 'package:mybrev_flutter/services/hive_service.dart';

/// Cache coverage and counts for settings UI.
class CacheStats {
  final int prayers;
  final int days;
  final int readings;
  final int years;
  final int invitatoriums;
  final int completoriums;
  final String? coverageLabel;
  final bool bootstrapNeeded;

  const CacheStats({
    required this.prayers,
    required this.days,
    required this.readings,
    required this.years,
    required this.invitatoriums,
    required this.completoriums,
    this.coverageLabel,
    required this.bootstrapNeeded,
  });

  factory CacheStats.collect() {
    final coverage = HiveService.getWarmupCoverage();
    String? label;
    if (coverage != null) {
      final (from, to) = coverage;
      label = '${_fmt(from)} – ${_fmt(to)}';
    }

    return CacheStats(
      prayers: HiveService.prayersBox.length,
      days: HiveService.daysBox.length,
      readings: HiveService.readingsBox.length,
      years: HiveService.yearOptionsBox.length,
      invitatoriums: HiveService.invitatoriumsBox.length,
      completoriums: HiveService.completoriumsBox.length,
      coverageLabel: label,
      bootstrapNeeded: HiveService.needsBootstrap(),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}
