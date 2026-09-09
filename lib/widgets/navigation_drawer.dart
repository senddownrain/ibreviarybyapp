import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

const _kMassOrderPrayerId = 'eMmCtxwyJ75ogmL5rwye';

class AppNavigationDrawer extends ConsumerWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final categories = ref.watch(prayerMenuCategoriesProvider);
    final location = GoRouterState.of(context).uri.path;

    void navigate(String path) {
      Navigator.pop(context);
      context.go(path);
    }

    void openDetail(String path) {
      Navigator.pop(context);
      context.push(path);
    }

    return Drawer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.86, -0.94),
            radius: 0.72,
            colors: [
              cs.primary.withValues(alpha: 0.13),
              cs.surface.withValues(alpha: 0),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                _DrawerHeader(onClose: () => Navigator.pop(context)),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewPaddingOf(context).bottom + 8,
                    ),
                    children: [
                      const _SectionLabel('Хуткі доступ'),
                      _DrawerItem(
                        icon: PhosphorIconsRegular.church,
                        title: 'Святая Імша',
                        selected:
                            location == '/prayers/prayer/$_kMassOrderPrayerId',
                        onTap: () =>
                            openDetail('/prayers/prayer/$_kMassOrderPrayerId'),
                      ),
                      const _SectionLabel('Малітоўныя зборнікі', spaced: true),
                      _DrawerItem(
                        icon: PhosphorIconsRegular.heart,
                        title: 'Абраныя малітвы',
                        selected: location == '/prayers/favorites',
                        onTap: () => openDetail('/prayers/favorites'),
                      ),
                      _DrawerItem(
                        icon: PhosphorIconsRegular.notepad,
                        title: 'Мае малітвы',
                        selected: location.startsWith('/prayers/my'),
                        onTap: () => navigate('/prayers/my'),
                      ),
                      for (final category in categories)
                        _DrawerItem(
                          icon: PhosphorIconsRegular.bookmark,
                          title: category.name,
                          onTap: () {
                            ref
                                .read(prayersFilterProvider.notifier)
                                .selectCategory(
                                  category.id,
                                  category.tags,
                                  name: category.name,
                                );
                            navigate('/prayers');
                          },
                        ),
                      if (categories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 5, 14, 8),
                          child: Text(
                            'Стварыце ўласныя зборнікі ў Наладах',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      const _SectionLabel('Праграма', spaced: true),
                      _DrawerItem(
                        icon: PhosphorIconsRegular.gear,
                        title: 'Налады',
                        selected: location == '/settings',
                        onTap: () => openDetail('/settings'),
                      ),
                      _DrawerItem(
                        icon: PhosphorIconsRegular.info,
                        title: 'Інфармацыя',
                        selected: location == '/about',
                        onTap: () => openDetail('/about'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 2, 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withValues(alpha: 0.20)),
            ),
            child: Center(
              child: PhosphorIcon(
                PhosphorIconsLight.cross,
                size: 27,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Малітоўнік',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Літургія і малітвы',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: 'Закрыць меню',
            icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.spaced = false});

  final String text;
  final bool spaced;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(top: spaced ? 8 : 0),
      padding: EdgeInsets.fromLTRB(14, spaced ? 12 : 8, 14, 7),
      decoration: spaced
          ? BoxDecoration(
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            )
          : null,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.selected = false,
  });

  final PhosphorIconData icon;
  final String title;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        minTileHeight: 50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: PhosphorIcon(icon, size: 22),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}
