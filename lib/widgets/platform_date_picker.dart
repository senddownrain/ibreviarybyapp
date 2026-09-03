import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shows a platform-appropriate date picker, returns the chosen [DateTime] or
/// null when the user dismissed without confirming.
///
/// Android — Material [showDatePicker] calendar grid.
/// iOS     — [CupertinoDatePicker] drum-roll in a modal bottom sheet.
Future<DateTime?> showPlatformDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return _showCupertinoPicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    locale: const Locale('be'),
  );
}

Future<DateTime?> _showCupertinoPicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (ctx) => _CupertinoDateSheet(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _CupertinoDateSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _CupertinoDateSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_CupertinoDateSheet> createState() => _CupertinoDateSheetState();
}

class _CupertinoDateSheetState extends State<_CupertinoDateSheet> {
  late DateTime _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1B22) : const Color(0xFFF2F1EC);

    return Container(
      height: 300 + MediaQuery.viewPaddingOf(context).bottom,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              CupertinoButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Адмена',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                ),
              ),
              const Spacer(),
              CupertinoButton(
                onPressed: () => Navigator.pop(context, _current),
                child: Text(
                  'Гатова',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: widget.initialDate,
              minimumDate: widget.firstDate,
              maximumDate: widget.lastDate,
              onDateTimeChanged: (d) => _current = d,
              itemExtent: 38,
              dateOrder: DatePickerDateOrder.dmy,
              backgroundColor: Colors.transparent,
            ),
          ),
          SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
        ],
      ),
    );
  }
}
