import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/discovery/discovery_context.dart';
import 'package:mybrev_flutter/discovery/hints/p0_hints.dart';
import 'package:mybrev_flutter/discovery/p0_facts.dart';
import 'package:mybrev_flutter/discovery/ui/discovery_hint_slot.dart';
import 'package:mybrev_flutter/discovery/ui/discovery_visit.dart';

/// `calendar.more_periods`: put right above the «Знайсці літургічны дзень»
/// tile of a calendar sheet the person opened. The sheet is the screen of
/// this visit, so the hint never sits on top of a prayer.
class CalendarSearchHint extends ConsumerStatefulWidget {
  const CalendarSearchHint({super.key});

  @override
  ConsumerState<CalendarSearchHint> createState() => _CalendarSearchHintState();
}

class _CalendarSearchHintState extends ConsumerState<CalendarSearchHint> {
  static const _anchor = 'calendar.search.button';
  late final DiscoveryVisit _visit = DiscoveryVisit(ref, 'calendar_sheet');
  int _opens = 0;

  @override
  void initState() {
    super.initState();
    _opens = ++ref.read(discoverySessionSignalsProvider).calendarOpens;
    _begin();
  }

  Future<void> _begin() async {
    await _visit.begin();
    if (!mounted) return;
    _visit.schedule(_snapshot);
  }

  DiscoveryContext? _snapshot(int visitId) {
    if (!mounted) return null;
    return DiscoveryContext(
      screenId: 'calendar_sheet',
      visitId: visitId,
      status: DiscoveryDataStatus.ready,
      anchors: _visit.mounted(const {_anchor}),
      facts: {
        // The feast search reads the bundled celebrations; without them the
        // tile would lead to an empty list.
        kFactHolidaySearchWorks:
            ContentStore.instance.areLoaded(const ['liturgicalCelebrations']) &&
            _opens > kMorePeriodsCalendarOpens,
      },
    );
  }

  @override
  void dispose() {
    _visit.end();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const DiscoveryHintSlot(anchorIds: [_anchor]);
}
