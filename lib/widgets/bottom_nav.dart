import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';

class AppBottomNav extends ConsumerWidget {
  final String currentLocation;
  const AppBottomNav({super.key, required this.currentLocation});

  int _getIndex() {
    if (currentLocation.startsWith('/picker')) return 0;
    return 1;
  }

  bool _showDayArrows() {
    return currentLocation == '/' || currentLocation.isEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LiquidGlassNav(
      currentLocation: currentLocation,
      selectedIndex: _getIndex(),
      showDayArrows: _showDayArrows(),
    );
  }
}

/// Floating liquid-glass pill with optional day arrows (web parity).
class _LiquidGlassNav extends ConsumerWidget {
  final String currentLocation;
  final int selectedIndex;
  final bool showDayArrows;

  const _LiquidGlassNav({
    required this.currentLocation,
    required this.selectedIndex,
    required this.showDayArrows,
  });

  void _shiftDay(WidgetRef ref, int days) {
    HapticFeedback.selectionClick();
    final current = ref.read(selectedDateProvider);
    ref.read(homeNavDirectionProvider.notifier).state = days > 0 ? 1 : -1;
    ref.read(selectedDateProvider.notifier).state =
        current.add(Duration(days: days));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final tokens = GlassTokens.of(context);
    final arrowColor = tokens.isDark
        ? Colors.white.withValues(alpha: 0.82)
        : Colors.black.withValues(alpha: 0.72);

    return SizedBox(
      height: 72 + bottomInset,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showDayArrows) ...[
                  _DayArrowButton(
                    icon: PhosphorIconsRegular.caretLeft,
                    color: arrowColor,
                    tooltip: 'Папярэдні дзень',
                    onTap: () => _shiftDay(ref, -1),
                  ),
                  const SizedBox(width: 10),
                ],
                _GlassPill(
                  seasonColor: seasonColor,
                  selectedIndex: selectedIndex,
                  onTap: (i) => _onTap(i, context, ref),
                ),
                if (showDayArrows) ...[
                  const SizedBox(width: 10),
                  _DayArrowButton(
                    icon: PhosphorIconsRegular.caretRight,
                    color: arrowColor,
                    tooltip: 'Наступны дзень',
                    onTap: () => _shiftDay(ref, 1),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onTap(int i, BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
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

class _DayArrowButton extends StatelessWidget {
  final PhosphorIconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _DayArrowButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: PhosphorIcon(icon, size: 22, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final Color seasonColor;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _GlassPill({
    required this.seasonColor,
    required this.selectedIndex,
    required this.onTap,
  });

  static const _kItems = [
    (
      icon: PhosphorIconsRegular.listBullets,
      fill: PhosphorIconsFill.listBullets
    ),
    (
      icon: PhosphorIconsRegular.sunHorizon,
      fill: PhosphorIconsFill.sunHorizon
    ),
    (
      icon: PhosphorIconsRegular.calendarBlank,
      fill: PhosphorIconsFill.calendarBlank
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = GlassTokens.of(context);
    final iconOff = tokens.isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.42);
    final iconOn = Colors.black;
    const indicatorColor = Colors.white;

    return GlassSurface(
      style: GlassStyle.pill,
      seasonColor: seasonColor,
      child: SizedBox(
        height: 62,
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
                onTap: () => onTap(i),
              ),
            const SizedBox(width: 4),
          ],
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
