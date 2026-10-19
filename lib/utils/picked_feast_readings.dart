import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/ordo/dates.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/readings_loader_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/utils/readings_selection.dart';

/// An explicit search intent prefers this celebration's proper readings.
/// Weekday readings require consent; another celebration is never substituted.
Future<bool> preparePickedFeastReadings(
  BuildContext context,
  WidgetRef ref, {
  required DateTime date,
  required String dayId,
  required String diocese,
  required String optionId,
}) async {
  final loaded = loadReadingsForDate(
    service: ParsedReadingsService(),
    calendar: ref.read(calendarServiceProvider),
    date: date,
    dayId: dayId,
    diocese: diocese,
  );
  if (loaded == null || loaded.optionId != optionId) {
    return _unavailable(context);
  }
  final selection = resolveDefaultReadings(
    readings: loaded.readings,
    sundayCycle: loaded.sundayCycle,
    weekdayCycle: loaded.weekdayCycle,
    optionId: optionId,
  );
  final proper = selection.groups
      .where(
        (g) => g.documents.any(
          (r) => r.ordoOptionRoles[optionId]?.purpose == 'proper',
        ),
      )
      .firstOrNull;
  final weekday = selection.groups
      .where(
        (g) => g.documents.any(
          (r) => r.ordoOptionRoles[optionId]?.purpose == 'weekday',
        ),
      )
      .firstOrNull;
  final group = proper ?? weekday;
  if (group == null) return _unavailable(context);
  if (proper == null && !await confirmDayReadings(context)) return false;
  if (!context.mounted) return false;
  final choices = ref.read(readingsMassSetSelectionProvider.notifier);
  choices.state = {...choices.state, '${isoOf(date)}|$dayId|@group': group.key};
  return true;
}

bool _unavailable(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Чытанні гэтага святкавання недаступныя')),
  );
  return false;
}

Future<bool> confirmDayReadings(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(
          'Для гэтага ўспаміну няма ўласных чытанняў. Адкрыць чытанні дня?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Скасаваць'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Адкрыць чытанні дня'),
          ),
        ],
      ),
    ) ??
    false;
