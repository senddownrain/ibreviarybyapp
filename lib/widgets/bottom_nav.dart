import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
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
    HapticFeedback.lightImpact();
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
    final arrowWidth = narrow ? 48.0 : 52.0;
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 88 + bottomInset,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: GlassSurface(
            style: GlassStyle.pill,
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showDayArrows) ...[
                    _ArrowBtn(
                      icon: PhosphorIconsRegular.caretLeft,
                      width: arrowWidth,
                      tooltip: 'Папярэдні дзень',
                      onTap: () => _shiftDay(ref, -1),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ],
                  _GlassPill(
                    selectedIndex: selectedIndex,
                    onTap: (i) => _onTap(i, context, ref),
                  ),
                  if (showDayArrows) ...[
                    Container(
                      width: 1,
                      height: 28,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                    _ArrowBtn(
                      icon: PhosphorIconsRegular.caretRight,
                      width: arrowWidth,
                      tooltip: 'Наступны дзень',
                      onTap: () => _shiftDay(ref, 1),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(int i, BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
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
      firstDate: kCalendarFirstDate,
      lastDate: kCalendarLastDate,
    );
    if (picked != null && context.mounted) {
      ref.read(selectedDateProvider.notifier).state = picked;
      context.go('/');
    }
  }
}

class _ArrowBtn extends StatelessWidget {
  final PhosphorIconData icon;
  final double width;
  final String tooltip;
  final VoidCallback onTap;

  const _ArrowBtn({
    required this.icon,
    required this.width,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: SizedBox(
            width: width,
            height: 64,
            child: Center(
              child: PhosphorIcon(icon, size: 20, color: cs.onSurface),
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
      label: 'Службы',
    ),
    (
      icon: PhosphorIconsRegular.sunHorizon,
      fill: PhosphorIconsFill.sunHorizon,
      label: 'Сёння',
    ),
    (
      icon: PhosphorIconsRegular.calendarBlank,
      fill: PhosphorIconsFill.calendarBlank,
      label: 'Выбраць дату',
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 4),
        for (int i = 0; i < _kItems.length; i++)
          _PillItem(
            icon: _kItems[i].icon,
            fillIcon: _kItems[i].fill,
            label: _kItems[i].label,
            isSelected: selectedIndex == i,
            iconOn: iconOn,
            iconOff: iconOff,
            indicatorColor: indicatorColor,
            onTap: () => onTap(i),
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _PillItem extends StatelessWidget {
  final PhosphorIconData icon;
  final PhosphorIconData fillIcon;
  final String label;
  final bool isSelected;
  final Color iconOn;
  final Color iconOff;
  final Color indicatorColor;
  final VoidCallback onTap;

  const _PillItem({
    required this.icon,
    required this.fillIcon,
    required this.label,
    required this.isSelected,
    required this.iconOn,
    required this.iconOff,
    required this.indicatorColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
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
          ),
        ),
      ),
    );
  }
}
