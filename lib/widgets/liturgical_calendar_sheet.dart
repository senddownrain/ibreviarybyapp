import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/providers/liturgical_day_presentation_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/widgets/hours_options_sheet.dart';
import 'package:mybrev_flutter/widgets/ordo/liturgical_month_calendar.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';

/// Date-only entry. Browsing months does not change the underlying reader.
Future<void> showCompactLiturgicalCalendar({
  required BuildContext context,
  required DateTime date,
  String? pickerRoute,
  String? diocese,
  ValueChanged<DateTime>? onSelected,
}) async {
  final router = GoRouter.of(context);
  final result = await showModalBottomSheet<Object>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => ConstrainedBox(
      key: const Key('compact-liturgical-calendar'),
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(sheetContext).height * .85,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiturgicalMonthCalendar(
                initialDate: date,
                diocese: diocese,
                onSelected: (value) => Navigator.pop(sheetContext, value),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('liturgical-calendar-today'),
                  onPressed: () => Navigator.pop(
                    sheetContext,
                    DateUtils.dateOnly(DateTime.now()),
                  ),
                  child: const Text('Сёння'),
                ),
              ),
              if (pickerRoute != null)
                ListTile(
                  key: const Key('liturgical-calendar-picker'),
                  leading: const Icon(Icons.search),
                  title: const Text('Знайсці літургічны дзень'),
                  subtitle: const Text('Пошук паводле перыяду або свята'),
                  onTap: () => Navigator.pop(sheetContext, true),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  if (result is DateTime) {
    if (onSelected != null) {
      onSelected(result);
    } else {
      await router.push(
        Uri(
          path: '/hours/ordo',
          queryParameters: {
            'date': liturgicalDateKey(result),
            'diocese': ?diocese,
          },
        ).toString(),
      );
    }
  } else if (result == true && pickerRoute != null) {
    await router.push(pickerRoute);
  }
}

Future<void> showLiturgicalCalendarSheet({
  required BuildContext context,
  required String pickerRoute,
  bool focusVariants = false,
  String? diocese,
}) async {
  final router = GoRouter.of(context);
  final advanced = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        LiturgicalCalendarSheet(focusVariants: focusVariants, diocese: diocese),
  );
  if (advanced == true) await router.push(pickerRoute);
}

/// Date and Office choices apply to the same session selection immediately.
/// Keep the sheet open so the alternatives of the chosen date are visible.
class LiturgicalCalendarSheet extends ConsumerStatefulWidget {
  const LiturgicalCalendarSheet({
    super.key,
    this.focusVariants = false,
    this.diocese,
  });
  final bool focusVariants;
  final String? diocese;
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
    void selectDate(DateTime date) {
      final saved = ref.read(
        hoursLiturgicalOverridesProvider,
      )[liturgicalDateKey(date)];
      final diocese = saved?.diocese ?? widget.diocese;
      final id =
          saved?.dayId ??
          (diocese == null
              ? null
              : resolveHoursLiturgicalSelection(
                  LiturgicalContentService()
                      .contentForDate(date, diocese: diocese)
                      .options,
                ).dayId);
      navigation.openDate(date, dayId: id, diocese: diocese);
    }

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
                      diocese: widget.diocese,
                      onSelected: selectDate,
                    ),
                  TextButton.icon(
                    key: const Key('liturgical-calendar-toggle'),
                    onPressed: () =>
                        setState(() => _calendarExpanded = !_calendarExpanded),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      _calendarExpanded
                          ? 'Схаваць каляндар'
                          : 'Паказаць каляндар',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('liturgical-calendar-today'),
                      onPressed: () {
                        selectDate(DateTime.now());
                        setState(() => _calendarExpanded = true);
                      },
                      child: const Text('Сёння'),
                    ),
                  ),
                  if (ready.hasValue)
                    HoursOptionsSheet(
                      date: presentation.date,
                      color: presentation.accent,
                      embedded: true,
                    )
                  else if (ready.hasError)
                    const Text('Не ўдалося адкрыць тэксты')
                  else
                    const Center(child: CircularProgressIndicator.adaptive()),
                  const Divider(),
                  ListTile(
                    key: const Key('liturgical-calendar-picker'),
                    leading: const Icon(Icons.search),
                    title: const Text('Знайсці літургічны дзень'),
                    subtitle: const Text('Пошук паводле перыяду або свята'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
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
