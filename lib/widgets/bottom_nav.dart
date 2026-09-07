import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/ambient_date_picker.dart';

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
    return _AdaptiveBottomNav(
      selectedIndex: _getIndex(ref.watch(selectedDateProvider)),
      showDayArrows: _showDayArrows(),
      currentDate: ref.watch(selectedDateProvider),
      mode: _BottomNavMode.hours,
    );
  }
}

/// Reading-specific counterpart of [AppBottomNav]. It intentionally shares
/// the same controls and calendar so both content areas behave identically.
class ReadingsBottomNav extends ConsumerWidget {
  const ReadingsBottomNav({
    super.key,
    required this.currentDate,
    this.showDayArrows = true,
  });

  final DateTime currentDate;
  final bool showDayArrows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateUtils.isSameDay(currentDate, DateTime.now());
    return _AdaptiveBottomNav(
      selectedIndex: today ? 1 : 2,
      showDayArrows: showDayArrows,
      currentDate: currentDate,
      mode: _BottomNavMode.readings,
    );
  }
}

enum _BottomNavMode { hours, readings }

/// Collapses the navigation bar out of the Scaffold layout while preserving a
/// smooth downward exit and upward entrance.
class AutoHidingBottomNavigation extends StatefulWidget {
  const AutoHidingBottomNavigation({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<AutoHidingBottomNavigation> createState() =>
      _AutoHidingBottomNavigationState();
}

class _AutoHidingBottomNavigationState extends State<AutoHidingBottomNavigation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 190),
    value: widget.visible ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(covariant AutoHidingBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    widget.visible ? _controller.forward() : _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _curve,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.34),
            end: Offset.zero,
          ).animate(_curve),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Shared navigation behavior with distinct Material and Cupertino surfaces.
class _AdaptiveBottomNav extends ConsumerWidget {
  final int selectedIndex;
  final bool showDayArrows;
  final DateTime currentDate;
  final _BottomNavMode mode;

  const _AdaptiveBottomNav({
    required this.selectedIndex,
    required this.showDayArrows,
    required this.currentDate,
    required this.mode,
  });

  void _shiftDay(BuildContext context, WidgetRef ref, int days) {
    HapticFeedback.selectionClick();
    final next = DateUtils.dateOnly(currentDate.add(Duration(days: days)));
    if (mode == _BottomNavMode.readings) {
      context.go('/readings/${_dateKey(next)}');
      return;
    }
    ref.read(homeNavDirectionProvider.notifier).state = days > 0 ? 1 : -1;
    ref.read(selectedDateProvider.notifier).state = next;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final cupertino = usesCupertinoGlass(context);
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final controlSize = narrow || !cupertino ? 52.0 : 56.0;
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
                    seasonColor: seasonColor,
                    tooltip: 'Папярэдні дзень',
                    onTap: () => _shiftDay(context, ref, -1),
                  ),
                  SizedBox(width: gap),
                ],
                _PlatformNavPill(
                  selectedIndex: selectedIndex,
                  seasonColor: seasonColor,
                  onTap: (i) => _onTap(i, context, ref),
                ),
                if (showDayArrows) ...[
                  SizedBox(width: gap),
                  _DayArrowButton(
                    icon: PhosphorIconsRegular.caretRight,
                    size: controlSize,
                    seasonColor: seasonColor,
                    tooltip: 'Наступны дзень',
                    onTap: () => _shiftDay(context, ref, 1),
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
        context.go(
          mode == _BottomNavMode.readings ? '/picker?mode=readings' : '/picker',
        );
      case 1:
        final today = DateUtils.dateOnly(DateTime.now());
        if (mode == _BottomNavMode.readings) {
          context.go('/readings/${_dateKey(today)}');
        } else {
          ref.read(selectedDateProvider.notifier).state = today;
          context.go('/');
        }
      case 2:
        _pickDate(context, ref);
    }
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final picked = await showAmbientDatePicker(
      context: context,
      initialDate: currentDate,
      seasonColor: ref.read(liturgicalSeasonColorProvider),
    );
    if (picked != null && context.mounted) {
      if (mode == _BottomNavMode.readings) {
        context.go('/readings/${_dateKey(picked)}');
      } else {
        ref.read(selectedDateProvider.notifier).state = picked;
        context.go('/');
      }
    }
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _DayArrowButton extends StatelessWidget {
  final PhosphorIconData icon;
  final double size;
  final String tooltip;
  final VoidCallback onTap;
  final Color seasonColor;

  const _DayArrowButton({
    required this.icon,
    required this.size,
    required this.tooltip,
    required this.onTap,
    required this.seasonColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: AdaptiveChromeSurface(
        seasonColor: seasonColor,
        role: ChromeSurfaceRole.control,
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

class _PlatformNavPill extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Color seasonColor;

  const _PlatformNavPill({
    required this.selectedIndex,
    required this.onTap,
    required this.seasonColor,
  });

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
    final cupertino = usesCupertinoGlass(context);
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconOff = dark
        ? Colors.white.withValues(alpha: 0.60)
        : Colors.black.withValues(alpha: 0.48);
    final iconOn = cupertino ? cs.primary : cs.onSecondaryContainer;
    final indicatorColor = cupertino
        ? cs.primary.withValues(alpha: 0.13)
        : cs.secondaryContainer;

    return AdaptiveChromeSurface(
      seasonColor: seasonColor,
      role: ChromeSurfaceRole.navigation,
      child: SizedBox(
        height: cupertino ? 64 : 60,
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
                cupertino: cupertino,
                tooltip: const ['Выбраць літургію', 'Сёння', 'Выбраць дату'][i],
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
  final bool cupertino;
  final String tooltip;

  const _PillItem({
    required this.icon,
    required this.fillIcon,
    required this.isSelected,
    required this.iconOn,
    required this.iconOff,
    required this.indicatorColor,
    required this.onTap,
    required this.cupertino,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        radius: 28,
        child: SizedBox(
          width: 56,
          height: cupertino ? 64 : 60,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: cupertino ? 48 : 52,
              height: cupertino ? 48 : 38,
              decoration: isSelected
                  ? BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(99),
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
    );
  }
}
