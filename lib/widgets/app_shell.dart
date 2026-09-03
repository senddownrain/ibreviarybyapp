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
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final isOffline = ref.watch(isOfflineProvider);

    // Match the PWA: the top chrome is an isolated floating control, not a
    // full-width toolbar. Content keeps a small breathing space below it.
    final topInset = MediaQuery.viewPaddingOf(context).top + 68;

    return WarmupBootstrap(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: _FloatingMenuBar(seasonColor: seasonColor),
        ),
        drawer: const AppNavigationDrawer(),
        body: AmbientBackdrop(
          child: Column(
            children: [
              SizedBox(height: topInset),
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
              Expanded(child: child),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNav(currentLocation: location),
      ),
    );
  }
}

class _FloatingMenuBar extends StatelessWidget {
  final Color seasonColor;

  const _FloatingMenuBar({required this.seasonColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Builder(
            builder: (ctx) => GlassSurface(
              style: GlassStyle.pill,
              seasonColor: seasonColor,
              borderRadius: BorderRadius.circular(24),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIconsRegular.list,
                        size: 23,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
