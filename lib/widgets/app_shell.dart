import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_navigation_sync_provider.dart';
import 'package:mybrev_flutter/providers/readings_navigation_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/app_navigation_dock.dart';
import 'package:mybrev_flutter/widgets/navigation_drawer.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';
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
                    if (shellOwnsTop)
                      Positioned(
                        top: topPadding + 8,
                        left: 12,
                        child: _FloatingMenuButton(
                          onTap: () => showSecondaryMenu(context),
                        ),
                      ),
                    if (shellOwnsTop &&
                        descriptor.isBranchRoot &&
                        widget.activeBranch == AppBranch.hours)
                      Positioned(
                        top: topPadding + 8,
                        right: 12,
                        child: _FloatingDayButton(
                          onTap: () {
                            final date = ref.read(selectedDateProvider);
                            final selection = ref.read(
                              hoursLiturgicalSelectionProvider,
                            );
                            if (selection.dayId case final id?) {
                              context.push(
                                horaRouteForContext(
                                  date: date,
                                  dayId: id,
                                  diocese: selection.diocese,
                                  optionId: selection.selected?.optionId,
                                ),
                              );
                            }
                          },
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
  const _FloatingMenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Меню',
      child: AdaptiveChromeSurface(
        role: ChromeSurfaceRole.control,
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: SizedBox.square(
              dimension: 48,
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
