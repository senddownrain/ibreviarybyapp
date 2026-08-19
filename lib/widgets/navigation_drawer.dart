import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';

class AppNavigationDrawer extends ConsumerWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCategories = ref.watch(settingsProvider).userCategories;
    final theme = Theme.of(context);
    final headerBg = theme.colorScheme.surface;

    return Drawer(
      child: SafeArea(
        top: false,
        bottom: true,
        child: ListView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom + 8,
          ),
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: headerBg),
              child: Center(
                child: Image.asset('assets/logo.png', width: 140, height: 140),
              ),
            ),
            ListTile(
              leading: PhosphorIcon(PhosphorIconsLight.cross, size: 22),
              title: const Text('Літургія'),
              onTap: () {
                Navigator.pop(context);
                context.go('/');
              },
            ),
            ListTile(
              leading: PhosphorIcon(PhosphorIconsRegular.bookBookmark, size: 22),
              title: const Text('Малітвы'),
              onTap: () {
                Navigator.pop(context);
                ref.read(prayersFilterProvider.notifier).clearFilters();
                context.go('/prayers');
              },
            ),
            const Divider(),
            for (final cat in userCategories)
              ListTile(
                leading: PhosphorIcon(PhosphorIconsRegular.bookmark, size: 22),
                title: Text(cat.name),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(prayersFilterProvider.notifier)
                      .selectCategory(cat.id, cat.tags);
                  context.go('/prayers');
                },
              ),
            const Divider(),
            ListTile(
              leading: PhosphorIcon(PhosphorIconsRegular.heart, size: 22),
              title: const Text('Улюбёныя малітвы'),
              onTap: () {
                Navigator.pop(context);
                context.push('/prayers/favorites');
              },
            ),
            ListTile(
              leading: PhosphorIcon(PhosphorIconsRegular.pencilSimpleLine, size: 22),
              title: const Text('Мае малітвы'),
              onTap: () {
                Navigator.pop(context);
                context.push('/prayers/my');
              },
            ),
            const Divider(),
            ListTile(
              leading: PhosphorIcon(PhosphorIconsRegular.bookOpen, size: 22),
              title: const Text('Біблія'),
              onTap: () {
                Navigator.pop(context);
                context.push('/bible');
              },
            ),
            const Divider(),
            ListTile(
              leading: PhosphorIcon(PhosphorIconsRegular.gear, size: 22),
              title: const Text('Налады'),
              onTap: () {
                Navigator.pop(context);
                context.go('/settings');
              },
            ),
          ],
        ),
      ),
    );
  }
}
