import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/ordo/liturgical_month_calendar.dart';

/// Shared offline ORDO calendar; returns the chosen date immediately.
Future<DateTime?> showAmbientDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  Color? seasonColor,
}) => showDialog<DateTime>(
  context: context,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SingleChildScrollView(
        child: GlassSurface(
          seasonColor: seasonColor,
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Выбраць дату',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыць',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const PhosphorIcon(PhosphorIconsRegular.x),
                    ),
                  ],
                ),
              ),
              LiturgicalMonthCalendar(
                initialDate: initialDate,
                seasonColor: seasonColor,
                onSelected: (date) => Navigator.of(context).pop(date),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).pop(DateUtils.dateOnly(DateTime.now())),
                icon: const PhosphorIcon(PhosphorIconsRegular.calendarCheck),
                label: const Text('Сёння'),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
