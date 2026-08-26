import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';

class AppBottomNav extends ConsumerWidget {
  final String currentLocation;
  const AppBottomNav({super.key, required this.currentLocation});

  int _getIndex() {
    if (currentLocation.startsWith('/picker')) return 0;
    return 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.isAndroid) {
      return _AndroidNav(currentLocation: currentLocation);
    }
    return _IOSLiquidGlassNav(
      currentLocation: currentLocation,
      selectedIndex: _getIndex(),
    );
  }
}

// ── Android: Material 3 NavigationBar ────────────────────────────────────────

class _AndroidNav extends ConsumerWidget {
  final String currentLocation;
  const _AndroidNav({required this.currentLocation});

  int get _index {
    if (currentLocation.startsWith('/picker')) return 0;
    return 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (i) => _onTap(i, context, ref),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: const [
        NavigationDestination(
          icon: PhosphorIcon(PhosphorIconsRegular.listBullets, size: 22),
          selectedIcon: PhosphorIcon(PhosphorIconsFill.listBullets, size: 22),
          label: 'Малітвы',
        ),
        NavigationDestination(
          icon: PhosphorIcon(PhosphorIconsRegular.sunHorizon, size: 22),
          selectedIcon: PhosphorIcon(PhosphorIconsFill.sunHorizon, size: 22),
          label: 'Сёння',
        ),
        NavigationDestination(
          icon: PhosphorIcon(PhosphorIconsRegular.calendarBlank, size: 22),
          selectedIcon: PhosphorIcon(PhosphorIconsFill.calendarBlank, size: 22),
          label: 'Дата',
        ),
      ],
    );
  }

  void _onTap(int i, BuildContext context, WidgetRef ref) {
    switch (i) {
      case 0:
        context.go('/picker');
      case 1:
        ref.read(selectedDateProvider.notifier).state = DateTime.now();
        context.go('/');
      case 2:
        _pickDate(context, ref);
    }
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final current = ref.read(selectedDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2019),
      lastDate: DateTime(2030),
      locale: const Locale('be'),
    );
    if (picked != null && context.mounted) {
      ref.read(selectedDateProvider.notifier).state = picked;
      context.go('/');
    }
  }
}

// ── iOS: Liquid Glass floating pill ──────────────────────────────────────────

class _IOSLiquidGlassNav extends ConsumerStatefulWidget {
  final String currentLocation;
  final int selectedIndex;
  const _IOSLiquidGlassNav({
    required this.currentLocation,
    required this.selectedIndex,
  });

  @override
  ConsumerState<_IOSLiquidGlassNav> createState() => _IOSLiquidGlassNavState();
}

class _IOSLiquidGlassNavState extends ConsumerState<_IOSLiquidGlassNav> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);

    return SizedBox(
      height: 72 + bottomInset,
      child: Stack(
        children: [
          // Pill
          Positioned(
            left: 0, right: 0, top: 4,
            child: Center(
              child: _GlassPill(
                isDark: isDark,
                seasonColor: seasonColor,
                selectedIndex: widget.selectedIndex,
                onTap: _onTap,
              ),
            ),
          ),
          SizedBox(height: bottomInset),
        ],
      ),
    );
  }

  void _onTap(int i, BuildContext context) {
    switch (i) {
      case 0:
        context.go('/picker');
      case 1:
        ref.read(selectedDateProvider.notifier).state = DateTime.now();
        context.go('/');
      case 2:
        _pickDate(context);
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final current = ref.read(selectedDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2019),
      lastDate: DateTime(2030),
      locale: const Locale('be'),
    );
    if (picked != null && context.mounted) {
      ref.read(selectedDateProvider.notifier).state = picked;
      context.go('/');
    }
  }
}

class _GlassPill extends StatelessWidget {
  final bool isDark;
  final Color seasonColor;
  final int selectedIndex;
  final void Function(int, BuildContext) onTap;

  const _GlassPill({
    required this.isDark,
    required this.seasonColor,
    required this.selectedIndex,
    required this.onTap,
  });

  static const _kItems = [
    (icon: PhosphorIconsRegular.listBullets,  fill: PhosphorIconsFill.listBullets),
    (icon: PhosphorIconsRegular.sunHorizon,   fill: PhosphorIconsFill.sunHorizon),
    (icon: PhosphorIconsRegular.calendarBlank, fill: PhosphorIconsFill.calendarBlank),
  ];

  @override
  Widget build(BuildContext context) {
    final baseGlass = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.82);
    final seasonTint = seasonColor.withValues(alpha: isDark ? 0.10 : 0.07);
    final glassBg = Color.alphaBlend(seasonTint, baseGlass);
    final specular = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.90);
    const indicatorColor = Colors.white;
    final iconOff = isDark
        ? Colors.white.withValues(alpha: 0.50)
        : Colors.black.withValues(alpha: 0.40);
    final iconOn = isDark ? Colors.black : Colors.black;

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            // Main glass fill
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [specular, glassBg],
              stops: const [0.0, 0.35],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                blurRadius: 32,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 8,
                spreadRadius: -1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 4),
              for (int i = 0; i < _kItems.length; i++)
                _PillItem(
                  icon: _kItems[i].icon,
                  fillIcon: _kItems[i].fill,
                  isSelected: selectedIndex == i,
                  iconOn: iconOn,
                  iconOff: iconOff,
                  indicatorColor: indicatorColor,
                  onTap: () => onTap(i, context),
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  final PhosphorIconData icon;
  final PhosphorIconData fillIcon;
  final bool isSelected;
  final Color iconOn;
  final Color iconOff;
  final Color indicatorColor;
  final VoidCallback onTap;

  const _PillItem({
    required this.icon,
    required this.fillIcon,
    required this.isSelected,
    required this.iconOn,
    required this.iconOff,
    required this.indicatorColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 62,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: isSelected ? 48 : 40,
            height: 40,
            decoration: isSelected
                ? BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  )
                : null,
            child: Center(
              child: PhosphorIcon(
                isSelected ? fillIcon : icon,
                size: 23,
                color: isSelected ? iconOn : iconOff,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
