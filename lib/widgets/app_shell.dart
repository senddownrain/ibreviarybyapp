import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/app_navigation_dock.dart';
import 'package:mybrev_flutter/widgets/navigation_drawer.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/warmup_bootstrap.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.shellState,
    required this.activeBranch,
  });

  final StatefulNavigationShell navigationShell;
  final AppShellState shellState;
  final AppBranch activeBranch;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with RestorationMixin {
  late final RestorableDateTime _hoursDate = RestorableDateTime(
    DateUtils.dateOnly(ref.read(selectedDateProvider)),
  );
  late final RestorableDateTime _readingsDate = RestorableDateTime(
    ref.read(readingsBranchStateProvider).date,
  );
  late final ProviderSubscription<DateTime> _hoursDateSubscription;
  late final ProviderSubscription<ReadingsBranchState>
  _readingsDateSubscription;

  @override
  String? get restorationId => 'production-app-shell';

  @override
  void initState() {
    super.initState();
    widget.shellState.setActiveBranch(widget.activeBranch);
    _hoursDateSubscription = ref.listenManual<DateTime>(selectedDateProvider, (
      previous,
      next,
    ) {
      final date = DateUtils.dateOnly(next);
      if (!DateUtils.isSameDay(_hoursDate.value, date)) {
        _hoursDate.value = date;
      }
    });
    _readingsDateSubscription = ref.listenManual<ReadingsBranchState>(
      readingsBranchStateProvider,
      (previous, next) {
        final date = DateUtils.dateOnly(next.date);
        if (!DateUtils.isSameDay(_readingsDate.value, date)) {
          _readingsDate.value = date;
        }
      },
    );
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_hoursDate, 'hours-date');
    registerForRestoration(_readingsDate, 'readings-date');
    ref.read(selectedDateProvider.notifier).state = DateUtils.dateOnly(
      _hoursDate.value,
    );
    final readings = ref.read(readingsBranchStateProvider);
    ref.read(readingsBranchStateProvider.notifier).state = readings.copyWith(
      date: _readingsDate.value,
    );
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeBranch != widget.activeBranch ||
        oldWidget.shellState != widget.shellState) {
      widget.shellState.setActiveBranch(widget.activeBranch);
    }
  }

  void _requestActiveMode(ReaderChromeMode mode) {
    final controller = widget.shellState.activeController;
    final entryId = controller.activeEntryId;
    if (entryId != null) controller.request(entryId, mode);
  }

  @override
  void dispose() {
    _hoursDateSubscription.close();
    _readingsDateSubscription.close();
    _hoursDate.dispose();
    _readingsDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    return AppNavigationScope(
      shell: widget.navigationShell,
      shellState: widget.shellState,
      child: AnimatedBuilder(
        animation: widget.shellState,
        builder: (context, _) {
          final controller = widget.shellState.activeController;
          final descriptor = controller.activeDescriptor;
          final mode = controller.value;
          final shellOwnsTop =
              descriptor.topChromeOwner == TopChromeOwner.shell;
          final topPadding = MediaQuery.paddingOf(context).top;
          return WarmupBootstrap(
            child: AmbientBackdrop(
              child: Scaffold(
                key: const Key('production-app-shell'),
                backgroundColor: Colors.transparent,
                drawer: const AppNavigationDrawer(),
                body: Stack(
                  children: [
                    Positioned.fill(
                      child: descriptor.reserveShellTopInset
                          ? Column(
                              children: [
                                SizedBox(height: topPadding + 78),
                                Expanded(child: widget.navigationShell),
                              ],
                            )
                          : widget.navigationShell,
                    ),
                    if (shellOwnsTop)
                      Positioned(
                        top: topPadding + 10,
                        left: 14,
                        child: Builder(
                          builder: (scaffoldContext) => _FloatingMenuButton(
                            seasonColor: seasonColor,
                            onTap: () =>
                                Scaffold.of(scaffoldContext).openDrawer(),
                          ),
                        ),
                      ),
                  ],
                ),
                bottomNavigationBar: AppNavigationDock(
                  activeBranch: widget.activeBranch,
                  mode: controller.navigationDockSuppressed
                      ? ReaderChromeMode.hidden
                      : mode,
                  seasonColor: seasonColor,
                  onSelect: AppNavigationScope.of(context).selectBranch,
                  onExpand: () => _requestActiveMode(ReaderChromeMode.full),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FloatingMenuButton extends StatelessWidget {
  const _FloatingMenuButton({required this.seasonColor, required this.onTap});

  final Color seasonColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Меню',
      child: AdaptiveChromeSurface(
        role: ChromeSurfaceRole.control,
        seasonColor: seasonColor,
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: SizedBox.square(
              dimension: 52,
              child: Center(
                child: PhosphorIcon(
                  PhosphorIconsRegular.list,
                  size: 24,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
