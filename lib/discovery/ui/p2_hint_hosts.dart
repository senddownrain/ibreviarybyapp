import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/discovery/discovery_providers.dart';
import 'package:mybrev_flutter/discovery/hints/p2_hints.dart';
import 'package:mybrev_flutter/discovery/p2_navigation.dart';
import 'package:mybrev_flutter/discovery/ui/discovery_hint_host.dart';
import 'package:mybrev_flutter/providers/bible_data_provider.dart';
import 'package:mybrev_flutter/providers/compendium_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/songs_provider.dart';

// Keys of the real controls (dock tabs and Prayer book section tiles).
const _prayersTab = Key('app-destination-Малітоўнік');
const _bibleTab = Key('app-destination-Біблія');
const _songbookTile = Key('songbook-destination');
const _compendiumTile = Key('catechism-destination');

/// Routes the hints open; the same ones the real controls use.
const kSongbookRoute = '/prayers/songs';
const kCompendiumRoute = '/prayers/compendium';
const kPrayersRoute = '/prayers';
const kBibleRoute = '/bible';

/// The data of a finished load; null while loading or after an error (an
/// error value must never throw into the hint host).
T? _loaded<T>(AsyncValue<T> value) => value.hasValue ? value.value : null;

/// Everything P2 reports for one screen. A section whose hint is dismissed,
/// completed or already known is not even loaded for the sake of a hint.
DiscoveryProbe p2Probe(
  BuildContext context,
  WidgetRef ref, {
  required bool onLiturgyRoot,
}) {
  final state = _loaded(ref.read(discoveryRepositoryProvider))?.state;
  if (state == null) return const DiscoveryProbe(ready: false);
  final switches = ref.read(navigationSwitchCountProvider);
  final active = switches >= kP2MinNavSwitches;
  bool wanted(String id, String visitKey) =>
      active &&
      state.visitCount(visitKey) == 0 &&
      !state.record(id).dismissed &&
      !state.record(id).completed;

  final facts = <String, Object?>{
    kFactNavSwitches: switches,
    kFactPrayersVisits: state.visitCount(kVisitPrayerbook),
    kFactSongbookVisits: state.visitCount(kVisitSongs),
    kFactCompendiumVisits: state.visitCount(kVisitCompendium),
    kFactBibleVisits: state.visitCount(kVisitBible),
  };
  final opener = ref.read(discoveryRouteOpenerProvider);
  void open(String path, {bool replace = false}) =>
      opener(context, path, switchBranch: replace);

  if (onLiturgyRoot) {
    facts[kFactPrayersAvailable] =
        wanted('discover.prayers', kVisitPrayerbook) &&
        ref.read(prayerCatalogProvider).isNotEmpty;
    return DiscoveryProbe(
      facts: facts,
      anchors: {
        'discover.prayers.tab': [_prayersTab],
      },
      chromeAnchors: const {'discover.prayers.tab'},
      actions: {'discover.prayers': () => open(kPrayersRoute, replace: true)},
    );
  }
  // Data is read only while its hint can still win: songs, Compendium and the
  // Bible are decoded from bundled assets, so everything works offline.
  facts[kFactSongbookLoaded] = wanted('discover.songbook', kVisitSongs)
      ? (_loaded(ref.watch(songsProvider))?.isNotEmpty ?? false)
      : false;
  facts[kFactCompendiumAvailable] =
      wanted('discover.catechism', kVisitCompendium)
      ? (_loaded(ref.watch(compendiumIndexProvider))?.questions.isNotEmpty ??
            false)
      : false;
  facts[kFactBibleAvailable] = wanted('discover.bible', kVisitBible)
      ? ref.watch(bibleDataProvider).hasValue
      : false;
  return DiscoveryProbe(
    facts: facts,
    anchors: {
      'discover.songbook.link': [_songbookTile],
      'discover.compendium.link': [_compendiumTile],
      'discover.bible.tab': [_bibleTab],
    },
    chromeAnchors: const {'discover.bible.tab'},
    actions: {
      'discover.songbook': () => open(kSongbookRoute),
      'discover.catechism': () => open(kCompendiumRoute),
      'discover.bible': () => open(kBibleRoute, replace: true),
    },
  );
}

/// The Liturgy of the Hours list (`/hours`): a menu of hours, not prayer
/// text, with the dock in view, so the Prayer book tab may be introduced.
class LiturgyRootHintHost extends StatelessWidget {
  const LiturgyRootHintHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DiscoveryHintHost(
    screenId: 'hours_root',
    child: child,
    probe: (context, ref, metrics) =>
        p2Probe(context, ref, onLiturgyRoot: true),
  );
}
