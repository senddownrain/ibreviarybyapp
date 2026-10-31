import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:mybrev_flutter/discovery/discovery_providers.dart';
import 'package:mybrev_flutter/discovery/discovery_storage.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';

/// Visit counters of the sections P2 introduces («не знаком» = 0).
const kVisitPrayerbook = 'branch.prayerbook';
const kVisitBible = 'branch.bible';
const kVisitSongs = 'section.songs';
const kVisitCompendium = 'section.compendium';

String? branchVisitKey(AppBranch branch) => switch (branch) {
  AppBranch.prayerbook => kVisitPrayerbook,
  AppBranch.bible => kVisitBible,
  _ => null,
};

/// Dock switches in this app session; memory only.
class NavigationSwitchCount extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state = state + 1;
}

final navigationSwitchCountProvider =
    NotifierProvider<NavigationSwitchCount, int>(NavigationSwitchCount.new);

/// Opens an app route for a hint. The engine has no router dependency: the
/// app installs the real one (`lib/router/discovery_navigation.dart`), and
/// without it «Паказаць» only dismisses the hint.
typedef DiscoveryRouteOpener =
    void Function(BuildContext context, String path, {bool switchBranch});

final discoveryRouteOpenerProvider = Provider<DiscoveryRouteOpener>(
  (ref) =>
      (context, path, {switchBranch = false}) =>
          debugPrint('[Discovery] no router installed for $path'),
);

/// Counts a visit. Silent where the hint box is not open (previews, tests of
/// other screens) and when storage fails.
Future<void> recordDiscoveryVisit(WidgetRef ref, String key) async {
  try {
    final storage = ref.read(discoveryStorageProvider);
    if (storage is HiveDiscoveryStorage && !Hive.isBoxOpen(storage.boxName)) {
      return;
    }
    final repository = await ref.read(discoveryRepositoryProvider.future);
    await repository.recordVisit(key);
  } catch (error) {
    debugPrint('[Discovery] visit not counted: $error');
  }
}

/// Wraps a destination screen and counts one visit when it opens.
class DiscoveryVisitMark extends ConsumerStatefulWidget {
  const DiscoveryVisitMark({
    super.key,
    required this.visitKey,
    required this.child,
  });

  final String visitKey;
  final Widget child;

  @override
  ConsumerState<DiscoveryVisitMark> createState() => _DiscoveryVisitMarkState();
}

class _DiscoveryVisitMarkState extends ConsumerState<DiscoveryVisitMark> {
  @override
  void initState() {
    super.initState();
    recordDiscoveryVisit(ref, widget.visitKey);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
