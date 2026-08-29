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
    final cs = Theme.of(context).colorScheme;
    final location = GoRouterState.of(context).uri.toString();
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final isOffline = ref.watch(isOfflineProvider);

    // Content scrolls under frosted glass bars on both platforms.
    // Content scrolls under frosted glass app bar; spacer keeps it below the bar.
    final topInset = MediaQuery.viewPaddingOf(context).top + kToolbarHeight;

    return WarmupBootstrap(
      child: Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: cs.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: GlassBar(
          seasonColor: seasonColor,
          child: _AppBarContent(cs: cs),
        ),
      ),
      drawer: const AppNavigationDrawer(),
      body: Column(
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
                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
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
      bottomNavigationBar: AppBottomNav(currentLocation: location),
      ),
    );
  }
}

class _AppBarContent extends StatelessWidget {
  final ColorScheme cs;
  const _AppBarContent({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Builder(
          builder: (ctx) => IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.list, size: 22),
            color: cs.onSurface,
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        const Spacer(),
        _AppBarTitle(cs: cs),
        const Spacer(),
        // Mirror leading for centering (iOS-style); keep balance on Android too.
        SizedBox(width: 48),
      ],
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  final ColorScheme cs;
  const _AppBarTitle({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhosphorIcon(
          PhosphorIconsLight.cross,
          size: 15,
          color: cs.primary.withValues(alpha: 0.75),
        ),
        const SizedBox(width: 7),
        Text(
          'Малітоўнік',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}
