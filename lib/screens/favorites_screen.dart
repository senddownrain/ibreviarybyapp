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
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final cs = Theme.of(context).colorScheme;
    final favIds = settings.favoriteIds;

    final allPrayers = ref.watch(allPrayersProvider);
    final localPrayers = ref.watch(localPrayersProvider);
    final allCombined = [...allPrayers, ...localPrayers];

    final favorites = allCombined.where((p) => favIds.contains(p.id)).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AdaptiveAppBar.text('Абраныя малітвы'),
      body: AmbientWash(
        seasonColor: seasonColor,
        height: kToolbarHeight + 100,
        child: favorites.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      PhosphorIconsLight.heart,
                      size: 56,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Няма абраных малітваў',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Дадайце малітву ў абраныя\nнацісканнем на іконку сэрца',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.only(
                  top:
                      MediaQuery.paddingOf(context).top +
                      kFloatingAppBarContentInset,
                  bottom: 16,
                ),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final prayer = favorites[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 9),
                    child: _FavoriteTile(prayer: prayer),
                  );
                },
              ),
      ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  final Prayer prayer;
  const _FavoriteTile({required this.prayer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return GlassSurface(
      borderRadius: BorderRadius.circular(22),
      child: ListTile(
        minTileHeight: 76,
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: PhosphorIcon(
              PhosphorIconsFill.heart,
              color: cs.error,
              size: 22,
            ),
          ),
        ),
        title: Text(
          prayer.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: prayer.tags.isNotEmpty ? Text(prayer.tags.join(' · ')) : null,
        trailing: IconButton(
          icon: PhosphorIcon(
            PhosphorIconsFill.heart,
            color: cs.error,
            size: 22,
          ),
          tooltip: 'Выдаліць з абраных',
          onPressed: () {
            HapticFeedback.selectionClick();
            ref.read(settingsProvider.notifier).toggleFavorite(prayer.id);
          },
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/prayers/prayer/${prayer.id}');
        },
      ),
    );
  }
}
