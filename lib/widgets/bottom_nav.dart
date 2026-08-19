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
    final selected = _getIndex();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFF1A1A1A);
    final iconOff = Colors.white.withOpacity(0.45);
    const iconOn = Colors.black;
    final indicatorColor = isDark ? Colors.white : Colors.white;

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
      height: 80 + bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(31),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 4),
                  _PillItem(
                    icon: PhosphorIcons.listBullets(),
                    isSelected: selected == 0,
                    iconOn: iconOn,
                    iconOff: iconOff,
                    indicatorColor: indicatorColor,
                    onTap: () => context.go('/picker'),
                  ),
                  _PillItem(
                    icon: PhosphorIcons.sunHorizon(),
                    isSelected: selected == 1,
                    iconOn: iconOn,
                    iconOff: iconOff,
                    indicatorColor: indicatorColor,
                    onTap: () {
                      ref.read(selectedDateProvider.notifier).state = DateTime.now();
                      context.go('/');
                    },
                  ),
                  _PillItem(
                    icon: PhosphorIcons.calendarBlank(),
                    isSelected: false,
                    iconOn: iconOn,
                    iconOff: iconOff,
                    indicatorColor: indicatorColor,
                    onTap: () => _showDatePicker(context, ref),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          SizedBox(height: bottomInset + 10),
        ],
      ),
    );
  }

  void _showDatePicker(BuildContext context, WidgetRef ref) async {
    final current = ref.read(selectedDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2019),
      lastDate: DateTime(2030),
      locale: const Locale('be'),
    );
    if (picked != null) {
      ref.read(selectedDateProvider.notifier).state = picked;
      if (context.mounted) context.go('/');
    }
  }
}

class _PillItem extends StatelessWidget {
  final PhosphorIconData icon;
  final bool isSelected;
  final Color iconOn;
  final Color iconOff;
  final Color indicatorColor;
  final VoidCallback onTap;

  const _PillItem({
    required this.icon,
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
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: isSelected ? 48 : 40,
            height: 40,
            decoration: isSelected
                ? BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: Center(
              child: PhosphorIcon(
                icon,
                size: 24,
                color: isSelected ? iconOn : iconOff,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
