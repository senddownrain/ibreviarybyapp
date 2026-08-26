import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/widgets/ios_app_bar.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favIds = settings.favoriteIds;

    final allPrayers = ref.watch(allPrayersProvider);
    final localPrayers = ref.watch(localPrayersProvider);
    final allCombined = [...allPrayers, ...localPrayers];

    final favorites = allCombined
        .where((p) => favIds.contains(p.id))
        .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: IosGlassAppBar.text('Улюбёныя малітвы'),
      body: Stack(
        children: [
          favorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PhosphorIcon(PhosphorIconsLight.heart, size: 56, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'Няма ўлюбёных малітваў',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Дадайце малітву ў улюбёныя\nнацісканнем на іконку сэрца',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                    bottom: 16,
                  ),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final prayer = favorites[index];
                    return _FavoriteTile(prayer: prayer);
                  },
                ),
          IgnorePointer(
            child: Container(
              height: kToolbarHeight + 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    seasonColor.withValues(alpha: isDark ? 0.13 : 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
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
          HapticFeedback.selectionClick();
          ref.read(settingsProvider.notifier).toggleFavorite(prayer.id);
        },
      ),
      onTap: () => context.push('/prayer/${prayer.id}'),
    );
  }
}
