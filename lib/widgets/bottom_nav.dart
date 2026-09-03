import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/widgets/platform_date_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';

class AppBottomNav extends ConsumerWidget {
  final String currentLocation;
  const AppBottomNav({super.key, required this.currentLocation});

  int _getIndex(DateTime selectedDate) {
    if (currentLocation.startsWith('/picker')) return 0;
    final now = DateTime.now();
    final isToday =
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    return isToday ? 1 : 2;
  }

  bool _showDayArrows() {
    return currentLocation == '/' || currentLocation.isEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (currentLocation != '/' &&
        currentLocation.isNotEmpty &&
        !currentLocation.startsWith('/picker')) {
      return const SizedBox.shrink();
    }
    return _LiquidGlassNav(
      currentLocation: currentLocation,
      selectedIndex: _getIndex(ref.watch(selectedDateProvider)),
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
    ref.read(selectedDateProvider.notifier).state = current.add(
      Duration(days: days),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final controlSize = narrow ? 52.0 : 56.0;
    final gap = narrow ? 8.0 : 12.0;

    return SizedBox(
      height: 88 + bottomInset,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showDayArrows) ...[
                  _DayArrowButton(
                    icon: PhosphorIconsRegular.caretLeft,
                    size: controlSize,
                    tooltip: 'Папярэдні дзень',
                    onTap: () => _shiftDay(ref, -1),
                  ),
                  SizedBox(width: gap),
                ],
                _GlassPill(
                  selectedIndex: selectedIndex,
                  onTap: (i) => _onTap(i, context, ref),
                ),
                if (showDayArrows) ...[
                  SizedBox(width: gap),
                  _DayArrowButton(
                    icon: PhosphorIconsRegular.caretRight,
                    size: controlSize,
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
    final picked = await showPlatformDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2019),
      lastDate: DateTime(2030),
    );
    if (picked != null && context.mounted) {
      ref.read(selectedDateProvider.notifier).state = picked;
      context.go('/');
    }
  }
}

class _DayArrowButton extends StatelessWidget {
  final PhosphorIconData icon;
  final double size;
  final String tooltip;
  final VoidCallback onTap;

  const _DayArrowButton({
    required this.icon,
    required this.size,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: GlassSurface(
        style: GlassStyle.pill,
        borderRadius: BorderRadius.circular(size / 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(size / 2),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: PhosphorIcon(icon, size: 20, color: cs.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _GlassPill({required this.selectedIndex, required this.onTap});

  static const _kItems = [
    (
      icon: PhosphorIconsRegular.listBullets,
      fill: PhosphorIconsFill.listBullets,
    ),
    (icon: PhosphorIconsRegular.sunHorizon, fill: PhosphorIconsFill.sunHorizon),
    (
      icon: PhosphorIconsRegular.calendarBlank,
      fill: PhosphorIconsFill.calendarBlank,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = GlassTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final iconOff = tokens.isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.42);
    final iconOn = cs.primary;
    final indicatorColor = cs.primary.withValues(alpha: 0.12);

    return GlassSurface(
      style: GlassStyle.pill,
      child: SizedBox(
        height: 64,
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
        height: 64,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: 48,
            height: 48,
            decoration: isSelected
                ? BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(24),
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
