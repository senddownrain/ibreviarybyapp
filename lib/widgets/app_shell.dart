import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/navigation_drawer.dart';
import 'package:mybrev_flutter/widgets/bottom_nav.dart';
import 'package:mybrev_flutter/widgets/warmup_bootstrap.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final isOffline = ref.watch(isOfflineProvider);

    final topPadding = MediaQuery.paddingOf(context).top;

    return WarmupBootstrap(
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,

        drawer: const AppNavigationDrawer(),

        body: AmbientBackdrop(
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
                      child: child,
                    ),
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
                    return _FloatingGlassButton(
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

        bottomNavigationBar: AppBottomNav(
          currentLocation: location,
        ),
      ),
    );
  }
}

class _FloatingGlassButton extends StatelessWidget {
  final Color seasonColor;
  final PhosphorIconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _FloatingGlassButton({
    required this.seasonColor,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final button = GlassSurface(
      style: GlassStyle.pill,
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
              child: PhosphorIcon(
                icon,
                size: 24,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(
      message: tooltip!,
      child: button,
    );
  }
}