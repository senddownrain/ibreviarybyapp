import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
// Admin UIDs matching the web app's ADMIN_UIDS constant
const _kAdminUids = {'glebgenij3@gmail.com'};

class AppNavigationDrawer extends ConsumerWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user != null && _kAdminUids.contains(user.email);
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final isDark = theme.brightness == Brightness.dark;

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
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    seasonColor.withValues(alpha: isDark ? 0.55 : 0.28),
                    seasonColor.withValues(alpha: isDark ? 0.18 : 0.10),
                  ],
                ),
              ),
              child: Center(
                child: Image.asset('assets/mary.png', height: 140),
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
            ListTile(
              leading: PhosphorIcon(PhosphorIconsRegular.heart, size: 22),
              title: const Text('Абраныя малітвы'),
              onTap: () {
                Navigator.pop(context);
                context.push('/prayers/favorites');
              },
            ),
            _CategoryTile(name: 'Марыйныя'),
            _CategoryTile(name: 'Літаніі'),
            _CategoryTile(name: 'Навэнны'),
            const Divider(),
            ListTile(
              leading: PhosphorIcon(PhosphorIconsRegular.gear, size: 22),
              title: const Text('Налады'),
              onTap: () {
                Navigator.pop(context);
                context.go('/settings');
              },
            ),
            if (isAdmin) ...[
              const Divider(),
              ListTile(
                leading: PhosphorIcon(PhosphorIconsRegular.signOut, size: 22),
                title: const Text('Выйсці'),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final String name;
  const _CategoryTile({required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final cat = settings.userCategories.where((c) => c.name == name).firstOrNull;
    return ListTile(
      leading: PhosphorIcon(PhosphorIconsRegular.bookmark, size: 22),
      title: Text(name),
      onTap: () {
        Navigator.pop(context);
        if (cat != null) {
          ref.read(prayersFilterProvider.notifier).selectCategory(cat.id, cat.tags);
        } else {
          ref.read(prayersFilterProvider.notifier).clearFilters();
        }
        context.go('/prayers');
      },
    );
  }
}
