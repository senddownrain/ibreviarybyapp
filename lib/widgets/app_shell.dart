import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/navigation_drawer.dart';
import 'package:mybrev_flutter/widgets/bottom_nav.dart';
import 'package:mybrev_flutter/widgets/warmup_bootstrap.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _bottomNavVisible = true;
  double _scrollDelta = 0;

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.runtimeType != widget.child.runtimeType) {
      _scrollDelta = 0;
      _bottomNavVisible = true;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.pixels <= 8) {
      _scrollDelta = 0;
      if (!_bottomNavVisible) setState(() => _bottomNavVisible = true);
      return false;
    }
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta;
      if (delta == null) return false;
      if (_scrollDelta != 0 && delta.sign != _scrollDelta.sign) {
        _scrollDelta = 0;
      }
      _scrollDelta += delta;
      if (_scrollDelta > 12 && _bottomNavVisible) {
        setState(() => _bottomNavVisible = false);
        _scrollDelta = 0;
      } else if (_scrollDelta < -12 && !_bottomNavVisible) {
        setState(() => _bottomNavVisible = true);
        _scrollDelta = 0;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final routeUri = GoRouterState.of(context).uri;
    final location = routeUri.toString();
    final contentBehindMenu = routeUri.path == '/prayers';
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final isOffline = ref.watch(isOfflineProvider);

    final topPadding = MediaQuery.paddingOf(context).top;

    return WarmupBootstrap(
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,

        drawer: const AppNavigationDrawer(),

        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: AmbientBackdrop(
            child: Stack(
              children: [
                //
                // Основной контент.
                //
                Positioned.fill(
                  child: Column(
                    children: [
                      // Most shell pages start below the floating menu.
                      // Prayers paints its ambient background behind it and
                      // supplies its own title spacing.
                      SizedBox(height: contentBehindMenu ? 0 : topPadding + 78),

                      //
                      // Offline banner
                      //
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: isOffline ? 32 : 0,
                        color: const Color(0xFFB71C1C),
                        child: isOffline
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.wifi_off_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Няма злучэння з інтэрнэтам',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      //
                      // Сам экран.
                      //
                      Expanded(child: widget.child),
                    ],
                  ),
                ),

                //
                // Плавающая кнопка меню.
                //
                Positioned(
                  top: topPadding + 10,
                  left: 14,
                  child: Builder(
                    builder: (scaffoldContext) {
                      return _FloatingMenuButton(
                        seasonColor: seasonColor,
                        icon: PhosphorIconsRegular.list,
                        tooltip: 'Меню',
                        onTap: () {
                          Scaffold.of(scaffoldContext).openDrawer();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        bottomNavigationBar: AutoHidingBottomNavigation(
          visible: _bottomNavVisible,
          child: AppBottomNav(currentLocation: location),
        ),
      ),
    );
  }
}

class _FloatingMenuButton extends StatelessWidget {
  final Color seasonColor;
  final PhosphorIconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _FloatingMenuButton({
    required this.seasonColor,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final button = AdaptiveChromeSurface(
      role: ChromeSurfaceRole.control,
      seasonColor: seasonColor,
      borderRadius: BorderRadius.circular(28),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: PhosphorIcon(icon, size: 24, color: colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(message: tooltip!, child: button);
  }
}
