import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/connectivity_provider.dart';
import 'package:mybrev_flutter/widgets/navigation_drawer.dart';
import 'package:mybrev_flutter/widgets/bottom_nav.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final location = GoRouterState.of(context).uri.toString();
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final isOffline = ref.watch(isOfflineProvider);

    // iOS: content extends behind the blurred AppBar so it scrolls underneath
    final isIOS = Platform.isIOS;

    return Scaffold(
      extendBodyBehindAppBar: isIOS,
      backgroundColor: cs.surface,
      appBar: isIOS
          ? _iosBlurBar(context, cs, isDark, seasonColor)
          : _androidBar(context, cs),
      drawer: const AppNavigationDrawer(),
      body: Column(
        children: [
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
                      Text('Няма злучэння з інтэрнэтам',
                          style: TextStyle(color: Colors.white, fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: AppBottomNav(currentLocation: location),
    );
  }

  // ── iOS: frosted glass AppBar ─────────────────────────────────────────────

  PreferredSizeWidget _iosBlurBar(
      BuildContext context, ColorScheme cs, bool isDark, Color seasonColor) {
    final blurBg = isDark
        ? Colors.black.withValues(alpha: 0.50)
        : cs.surface.withValues(alpha: 0.65);
    // Tint the blur with the season color
    final seasonTint = seasonColor.withValues(alpha: isDark ? 0.12 : 0.07);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Color.alphaBlend(seasonTint, blurBg),
              border: Border(
                bottom: BorderSide(color: borderColor, width: 0.5),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: _AppBarContent(cs: cs),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Android: solid surface AppBar ────────────────────────────────────────

  PreferredSizeWidget _androidBar(BuildContext context, ColorScheme cs) {
    return AppBar(
      centerTitle: false,
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.list, size: 22),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: _AppBarTitle(cs: cs),
    );
  }
}

// ── Shared title widget ───────────────────────────────────────────────────────

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
        // Mirror leading for centering
        const SizedBox(width: 48),
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
        const Text(
          'Малітоўнік',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
