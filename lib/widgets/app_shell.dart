import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/app_shell_scope.dart';
import 'package:mybrev_flutter/widgets/navigation_drawer.dart';
import 'package:mybrev_flutter/widgets/bottom_nav.dart';
import 'package:mybrev_flutter/widgets/warmup_bootstrap.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final isOffline = ref.watch(isOfflineProvider);

    return WarmupBootstrap(
      child: Scaffold(
        key: _scaffoldKey,
        extendBody: true,
        backgroundColor: Colors.transparent,

        drawer: const AppNavigationDrawer(),

        body: AppShellScope(
          openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          child: AmbientBackdrop(
            child: Stack(
              children: [
                //
                // Основной контент.
                //
                Positioned.fill(
                  child: Column(
                    children: [
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
                      Expanded(
                        child: widget.child,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        bottomNavigationBar: AppBottomNav(
          currentLocation: location,
        ),
      ),
    );
  }
}
