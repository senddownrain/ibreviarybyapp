import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

Future<void> showSecondaryMenu(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => const _SecondaryMenuContent(),
    );

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) =>
      const Drawer(child: SafeArea(child: _SecondaryMenuContent()));
}

class _SecondaryMenuContent extends StatelessWidget {
  const _SecondaryMenuContent();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Text('Меню', style: Theme.of(context).textTheme.titleLarge),
        ),
        _item(context, PhosphorIconsRegular.gear, 'Налады', '/settings'),
        _item(
          context,
          PhosphorIconsRegular.arrowsClockwise,
          'Сінхранізацыя',
          '/settings?section=sync',
        ),
        _item(context, PhosphorIconsRegular.info, 'Інфармацыя', '/about'),
      ],
    ),
  );

  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    String route,
  ) => ListTile(
    minTileHeight: 52,
    leading: PhosphorIcon(icon, size: 22),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () {
      Navigator.pop(context);
      context.push(route);
    },
  );
}
