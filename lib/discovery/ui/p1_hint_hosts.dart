import 'package:flutter/material.dart';
import 'package:mybrev_flutter/discovery/hint_definition.dart';
import 'package:mybrev_flutter/discovery/hints/p1_hints.dart';
import 'package:mybrev_flutter/discovery/ui/anchor_finder.dart';
import 'package:mybrev_flutter/discovery/ui/discovery_hint_host.dart';
import 'package:mybrev_flutter/discovery/ui/p2_hint_hosts.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';

// Existing keys of the real controls; nothing here adds a widget on top of
// prayer or Scripture text.
const _readerOverflow = Key('reader-chrome-overflow');
const _overflowButton = Key('app-overflow-open');
const _nextHour = Key('ora-next-hour');
const _psalmBreakChip = Key('text-scale-psalm-marker-break');
const _psalmAlignChip = Key('text-scale-psalm-aligned-left');
const _biblePicker = Key('bible-book-chapter-picker');
const _bibleSelection = Key('bible-highlight-palette');
const _prayerSearch = Key('prayerbook-search-action');

bool _mounted(BuildContext context, Key key) =>
    findAnchorElement(context, key) != null;

/// Hour text (`display.font_scale`, `hours.next_hour`).
class HoursHintHost extends StatelessWidget {
  const HoursHintHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DiscoveryHintHost(
    screenId: 'hours',
    child: child,
    probe: (context, ref, metrics) {
      // The font hint belongs to the start of the text; at the end of the
      // document the next-hour hint must be able to win.
      final atStart = (metrics?.pixels ?? 0) < 120;
      return DiscoveryProbe(
        facts: {
          kFactFontControlReady: atStart && _mounted(context, _readerOverflow),
          kFactNextHourReady: _mounted(context, _nextHour),
        },
        anchors: {
          'display.font.button': [_readerOverflow],
          'hours.next_hour.button': [_nextHour],
        },
        invoke: {'display.font_scale': _overflowButton},
      );
    },
  );
}

/// Inside the open «Шрыфт» panel of the hours (`hours.psalm_layout`).
class PsalmLayoutHintHost extends StatefulWidget {
  const PsalmLayoutHintHost({super.key, required this.child});

  final Widget child;

  @override
  State<PsalmLayoutHintHost> createState() => _PsalmLayoutHintHostState();
}

class _PsalmLayoutHintHostState extends State<PsalmLayoutHintHost> {
  final _slot = ValueNotifier<HintDefinition?>(null);

  @override
  Widget build(BuildContext context) => DiscoveryHintHost(
    screenId: 'hours',
    inline: _slot,
    dwell: const Duration(milliseconds: 900),
    child: widget.child,
    probe: (context, ref, metrics) => DiscoveryProbe(
      facts: {
        kFactPsalmChipsReady:
            _mounted(context, _psalmBreakChip) &&
            _mounted(context, _psalmAlignChip),
      },
      anchors: {
        'hours.psalm_chips': [_psalmBreakChip, _psalmAlignChip],
      },
    ),
  );
}

/// Bible chapter screen (`bible.navigation`).
class BibleHintHost extends StatelessWidget {
  const BibleHintHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DiscoveryHintHost(
    screenId: 'bible',
    child: child,
    probe: (context, ref, metrics) => DiscoveryProbe(
      facts: {kFactBibleNavigationReady: _mounted(context, _biblePicker)},
      anchors: {
        'bible.book_picker.button': [_biblePicker],
      },
      invoke: {'bible.navigation': _biblePicker},
      blockedBy: const [_bibleSelection],
    ),
  );
}

/// Prayer book root (`app.search`, prayers only).
class PrayersHintHost extends StatelessWidget {
  const PrayersHintHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DiscoveryHintHost(
    screenId: 'prayers',
    child: child,
    probe: (context, ref, metrics) {
      // P1 (prayer search) and P2 (other sections) share this screen; the
      // engine lets P1 win and shows at most one hint per visit.
      final p2 = p2Probe(context, ref, onLiturgyRoot: false);
      return DiscoveryProbe(
        ready: p2.ready,
        facts: {
          kFactSearchReady: ref.read(prayerCatalogProvider).isNotEmpty,
          ...p2.facts,
        },
        anchors: {
          'app.search.button': [_prayerSearch],
          ...p2.anchors,
        },
        invoke: {'app.search': _prayerSearch},
        actions: p2.actions,
        chromeAnchors: p2.chromeAnchors,
      );
    },
  );
}
