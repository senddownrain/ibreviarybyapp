import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/providers/liturgical_day_presentation_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/widgets/hours_options_sheet.dart';
import 'package:mybrev_flutter/widgets/ordo/liturgical_month_calendar.dart';

Future<void> showLiturgicalCalendarSheet({
  required BuildContext context,
  required String pickerRoute,
  bool focusVariants = false,
}) async {
  final router = GoRouter.of(context);
  final advanced = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => LiturgicalCalendarSheet(focusVariants: focusVariants),
  );
  if (advanced == true) router.push(pickerRoute);
}

/// Date and Office choices apply to the same session selection immediately.
/// Keep the sheet open so the alternatives of the chosen date are visible.
class LiturgicalCalendarSheet extends ConsumerStatefulWidget {
  const LiturgicalCalendarSheet({super.key, this.focusVariants = false});
  final bool focusVariants;
  @override
  ConsumerState<LiturgicalCalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends ConsumerState<LiturgicalCalendarSheet> {
  late bool _calendarExpanded = !widget.focusVariants;

  @override
  Widget build(BuildContext context) {
    final presentation = ref.watch(liturgicalDayPresentationProvider);
    final ready = ref.watch(selectedDateReadyProvider);
    final navigation = ref.read(liturgicalNavigationControllerProvider);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    presentation.dateLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыць',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              key: const Key('liturgical-calendar-scroll'),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_calendarExpanded)
                    LiturgicalMonthCalendar(
                      initialDate: presentation.date,
                      seasonColor: presentation.accent,
                      onSelected: navigation.openDate,
                    )
                  else
                    TextButton.icon(
                      onPressed: () => setState(() => _calendarExpanded = true),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Паказаць каляндар'),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('liturgical-calendar-today'),
                      onPressed: () {
                        navigation.openDate(DateTime.now());
                        setState(() => _calendarExpanded = true);
                      },
                      child: const Text('Сёння'),
                    ),
                  ),
                  if (presentation.variantCount > 1)
                    HoursOptionsSheet(
                      date: presentation.date,
                      color: presentation.accent,
                      embedded: true,
                    )
                  else if (ready.hasError)
                    const Text('Не ўдалося адкрыць тэксты')
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        presentation.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  const Divider(),
                  ListTile(
                    key: const Key('liturgical-calendar-picker'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Знайсці літургічны дзень'),
                    trailing: const Icon(Icons.arrow_forward, size: 20),
                    onTap: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Гатова'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
