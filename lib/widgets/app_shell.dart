import 'package:mybrev_flutter/utils/picked_feast_readings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/discovery/tour/tour_host.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/app_navigation_dock.dart';
import 'package:mybrev_flutter/widgets/app_overflow_menu.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/content_update_scheduler.dart';

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
  late final RestorableDateTime _liturgicalDate = RestorableDateTime(
    DateUtils.dateOnly(ref.read(selectedDateProvider)),
  );
  late final ProviderSubscription<DateTime> _liturgicalDateSubscription;

  late _ShellTourBridge _tourShell = _ShellTourBridge(
    widget.shellState,
    widget.navigationShell,
  );

  @override
  String? get restorationId => 'production-app-shell';

  @override
  void initState() {
    super.initState();
    ref.read(liturgicalNavigationSyncProvider);
    widget.shellState.setActiveBranch(widget.activeBranch);
    _rememberActiveBranch();
    _liturgicalDateSubscription = ref.listenManual<DateTime>(
      selectedDateProvider,
      (previous, next) {
        final date = DateUtils.dateOnly(next);
        if (!DateUtils.isSameDay(_liturgicalDate.value, date)) {
          _liturgicalDate.value = date;
        }
      },
    );
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_liturgicalDate, 'hours-date');
    final restoredDate = DateUtils.dateOnly(_liturgicalDate.value);
    // Restoration runs during didChangeDependencies, when provider writes
    // would notify widgets that are still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectedDateProvider.notifier).state = restoredDate;
      final readings = ref.read(readingsBranchStateProvider);
      ref.read(readingsBranchStateProvider.notifier).state = readings.copyWith(
        date: restoredDate,
        clearLiturgicalKey: true,
      );
    });
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeBranch != widget.activeBranch ||
        oldWidget.shellState != widget.shellState) {
      _tourShell = _ShellTourBridge(widget.shellState, widget.navigationShell);
      widget.shellState.setActiveBranch(widget.activeBranch);
      _rememberActiveBranch();
    }
  }

  void _rememberActiveBranch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(settingsProvider.notifier)
          .rememberLastSection(widget.activeBranch.name);
    });
  }

  void _requestActiveMode(ReaderChromeMode mode) {
    final controller = widget.shellState.activeController;
    final entryId = controller.activeEntryId;
    if (entryId != null) controller.request(entryId, mode);
  }

  Future<void> _selectBranch(BuildContext context, AppBranch branch) async {
    if (branch == AppBranch.readings &&
        widget.activeBranch == AppBranch.hours) {
      final date = ref.read(selectedDateProvider);
      final choice = ref.read(
        hoursLiturgicalOverridesProvider,
      )[liturgicalDateKey(date)];
      final selection = ref.read(hoursLiturgicalSelectionProvider);
      if (choice?.fromSearch == true &&
          selection.dayId != null &&
          selection.diocese != null &&
          selection.selected?.optionId != null) {
        if (!await preparePickedFeastReadings(
          context,
          ref,
          date: date,
          dayId: selection.dayId!,
          diocese: selection.diocese!,
          optionId: selection.selected!.optionId,
        )) {
          return;
        }
        if (!context.mounted) return;
      }
    }
    AppNavigationScope.of(context).selectBranch(branch);
  }

  @override
  void dispose() {
    _liturgicalDateSubscription.close();
    _liturgicalDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppNavigationScope(
      shell: widget.navigationShell,
      shellState: widget.shellState,
      child: TourHost(
        shell: _tourShell,
        child: AnimatedBuilder(
          animation: widget.shellState,
          builder: (context, _) {
            final controller = widget.shellState.activeController;
            final descriptor = controller.activeDescriptor;
            final mode = controller.value;
            final shellOwnsTop =
                descriptor.topChromeOwner == TopChromeOwner.shell;
            final topPadding = MediaQuery.paddingOf(context).top;
            return ContentUpdateScheduler(
              child: AmbientBackdrop(
                child: Scaffold(
                  key: const Key('production-app-shell'),
                  backgroundColor: Colors.transparent,
                  extendBody: true,
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
                      if (shellOwnsTop && mode != ReaderChromeMode.hidden)
                        Positioned(
                          top: topPadding + 8,
                          right: 12,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (descriptor.isBranchRoot &&
                                  widget.activeBranch == AppBranch.hours) ...[
                                _FloatingDayButton(
                                  onTap: () {
                                    final selection = ref.read(
                                      hoursLiturgicalSelectionProvider,
                                    );
                                    context.push(
                                      Uri(
                                        path: '/hours/ordo',
                                        queryParameters: {
                                          'date': liturgicalDateKey(
                                            ref.read(selectedDateProvider),
                                          ),
                                          'dayId': ?selection.dayId,
                                          'diocese': ?selection.diocese,
                                        },
                                      ).toString(),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],
                              const AppOverflowMenu(),
                            ],
                          ),
                        ),
                    ],
                  ),
                  bottomNavigationBar: AppNavigationDock(
                    activeBranch: widget.activeBranch,
                    mode: controller.navigationDockSuppressed
                        ? ReaderChromeMode.hidden
                        : mode,
                    seasonColor: Theme.of(context).colorScheme.primary,
                    onSelect: (branch) => _selectBranch(context, branch),
                    onExpand: () => _requestActiveMode(ReaderChromeMode.full),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Lets the tour read and switch the section without knowing the shell.
class _ShellTourBridge implements TourShell {
  _ShellTourBridge(this._state, this._shell);

  final AppShellState _state;
  final StatefulNavigationShell _shell;

  @override
  Listenable get changes => _state;

  @override
  AppBranch get branch => _state.activeBranch;

  @override
  bool get atBranchRoot =>
      _state.activeController.activeDescriptor.isBranchRoot;

  @override
  bool get dockVisible {
    final controller = _state.activeController;
    return controller.activeDescriptor.showsNavigationDock &&
        !controller.navigationDockSuppressed &&
        controller.value != ReaderChromeMode.hidden;
  }

  @override
  void selectBranch(AppBranch branch) {
    if (branch == _state.activeBranch) return;
    _state.clearOraReturn();
    _shell.goBranch(branch.index);
  }
}

class _FloatingDayButton extends StatelessWidget {
  const _FloatingDayButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AdaptiveChromeSurface(
    role: ChromeSurfaceRole.control,
    borderRadius: BorderRadius.circular(24),
    child: SizedBox.square(
      dimension: 48,
      child: IconButton(
        key: const Key('hours-calendar-action'),
        tooltip: 'Літургічны дзень',
        onPressed: onTap,
        icon: const PhosphorIcon(PhosphorIconsRegular.calendarDots, size: 24),
      ),
    ),
  );
}
