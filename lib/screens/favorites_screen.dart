import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/models/prayer.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final favIds = settings.favoriteIds;

    final allPrayers = ref.watch(allPrayersProvider);
    final localPrayers = ref.watch(localPrayersProvider);
    final allCombined = [...allPrayers, ...localPrayers];

    final favorites = allCombined
        .where((p) => favIds.contains(p.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Улюбёныя малітвы')),
      body: favorites.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(PhosphorIconsLight.heart, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Няма ўлюбёных малітваў',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Дадайце малітву ў улюбёныя\nнацісканнем на іконку сэрца',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final prayer = favorites[index];
                return _FavoriteTile(prayer: prayer);
              },
            ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  final Prayer prayer;
  const _FavoriteTile({required this.prayer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(prayer.displayTitle),
      subtitle: prayer.tags.isNotEmpty ? Text(prayer.tags.join(', ')) : null,
      trailing: IconButton(
        icon: const PhosphorIcon(PhosphorIconsFill.heart, color: Colors.red, size: 22),
        tooltip: 'Выдаліць з улюбёных',
        onPressed: () {
          ref.read(settingsProvider.notifier).toggleFavorite(prayer.id);
        },
      ),
      onTap: () => context.push('/prayer/${prayer.id}'),
    );
  }
}
