import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/ordo/liturgical_catalog.dart';
import 'package:mybrev_flutter/ordo/runtime.dart';
import 'package:mybrev_flutter/screens/catalog_entry_screen.dart';
import 'package:mybrev_flutter/screens/liturgical_picker_screen.dart';
import 'package:mybrev_flutter/ordo/dates.dart';

/// Compatibility for old period deep links. Use the same independent catalog
/// and calendar gate as the picker, never synthesize a date from legacy days.
class LiturgicalDayOptionsScreen extends ConsumerWidget {
  const LiturgicalDayOptionsScreen({
    super.key,
    required this.period,
    required this.week,
    required this.day,
    this.mode = 'hours',
  });
  final String period, mode;
  final int week, day;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = periodCatalog(OrdoRuntime.engine.definitions)
        .where(
          (e) =>
              e.period == period &&
              e.data['week'] == week &&
              e.data['weekday'] == day,
        )
        .firstOrNull;
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Літургічныя тэксты')),
        body: const Center(child: Text('Літургічная пазіцыя не знойдзена')),
      );
    }
    return CatalogEntryScreen(
      entry: entry,
      mode: mode,
      onOpen: (o) => openPickedDate(
        context,
        ref,
        dateOfIso(o.effectiveDate!),
        readingsMode: mode == 'readings',
        optionId: o.optionId,
        diocese: o.diocese,
      ),
    );
  }
}
