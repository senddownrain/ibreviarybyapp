import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';

/// Shared calendar used by both the Hours and Readings navigation bars.
Future<DateTime?> showAmbientDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  Color? seasonColor,
}) {
  final today = DateUtils.dateOnly(DateTime.now());
  final safeInitial = DateUtils.dateOnly(initialDate);
  final firstDate = kCalendarFirstDate;
  final lastDate = kCalendarLastDate;
  if (usesCupertinoGlass(context)) {
    return showCupertinoModalPopup<DateTime>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (_) => _CupertinoDatePickerSheet(
        initialDate: safeInitial,
        firstDate: firstDate,
        lastDate: lastDate,
        today: today,
        seasonColor: seasonColor,
      ),
    );
  }
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.46),
    builder: (context) => _MaterialAmbientDatePickerDialog(
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      today: today,
      seasonColor: seasonColor,
    ),
  );
}

class _MaterialAmbientDatePickerDialog extends StatefulWidget {
  const _MaterialAmbientDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.today,
    this.seasonColor,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime today;
  final Color? seasonColor;

  @override
  State<_MaterialAmbientDatePickerDialog> createState() =>
      _MaterialAmbientDatePickerDialogState();
}

class _MaterialAmbientDatePickerDialogState
    extends State<_MaterialAmbientDatePickerDialog> {
  late DateTime _selectedDate = widget.initialDate;

  void _selectToday() {
    setState(() => _selectedDate = widget.today);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = GlassTokens.of(
      context,
    ).accentOnSurface(widget.seasonColor ?? cs.primary);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                AmbientWash(
                  seasonColor: widget.seasonColor ?? cs.primary,
                  height: 190,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'КАЛЯНДАР',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.3,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Выбраць дату',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Закрыць',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const PhosphorIcon(
                              PhosphorIconsRegular.x,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: cs.copyWith(primary: accent),
                        datePickerTheme: DatePickerThemeData(
                          backgroundColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                          todayBorder: BorderSide(color: accent, width: 1.5),
                        ),
                      ),
                      child: CalendarDatePicker(
                        key: ValueKey(_selectedDate),
                        initialDate: _selectedDate,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        currentDate: widget.today,
                        onDateChanged: (date) =>
                            setState(() => _selectedDate = date),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 16, 14),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: _selectToday,
                            icon: const PhosphorIcon(
                              PhosphorIconsRegular.calendarCheck,
                              size: 18,
                            ),
                            label: const Text('Сёння'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(_selectedDate),
                            child: const Text('Выбраць'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CupertinoDatePickerSheet extends StatefulWidget {
  const _CupertinoDatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.today,
    this.seasonColor,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime today;
  final Color? seasonColor;

  @override
  State<_CupertinoDatePickerSheet> createState() =>
      _CupertinoDatePickerSheetState();
}

class _CupertinoDatePickerSheetState extends State<_CupertinoDatePickerSheet> {
  late DateTime _selectedDate = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = GlassTokens.of(
      context,
    ).accentOnSurface(widget.seasonColor ?? cs.primary);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AdaptiveChromeSurface(
                role: ChromeSurfaceRole.group,
                seasonColor: widget.seasonColor,
                borderRadius: BorderRadius.circular(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          CupertinoButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Скасаваць'),
                          ),
                          const Spacer(),
                          Text(
                            'Выбраць дату',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          CupertinoButton(
                            onPressed: () =>
                                Navigator.of(context).pop(_selectedDate),
                            child: const Text('Гатова'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 216,
                      child: CupertinoTheme(
                        data: CupertinoTheme.of(context).copyWith(
                          primaryColor: accent,
                          brightness: Theme.of(context).brightness,
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          initialDateTime: _selectedDate,
                          minimumDate: widget.firstDate,
                          maximumDate: widget.lastDate,
                          onDateTimeChanged: (date) =>
                              _selectedDate = DateUtils.dateOnly(date),
                        ),
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(widget.today),
                      child: const Text('Сёння'),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
