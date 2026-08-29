import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/ios_app_bar.dart';

class MyPrayersScreen extends ConsumerWidget {
  const MyPrayersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayers = ref.watch(localPrayersProvider);
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: IosGlassAppBar.text('Мае малітвы'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/prayer/add'),
        tooltip: 'Новая малітва',
        child: const PhosphorIcon(PhosphorIconsRegular.plus, size: 24),
      ),
      body: AmbientWash(
        seasonColor: seasonColor,
        height: kToolbarHeight + 100,
        child: prayers.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(PhosphorIconsLight.notepad,
                        size: 56, color: cs.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      'Тут будуць вашы малітвы',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Націсніце + каб дадаць першую',
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                  bottom: 80,
                ),
                itemCount: prayers.length,
                itemBuilder: (context, index) {
                  final prayer = prayers[index];
                  return _MyPrayerTile(prayer: prayer);
                },
              ),
      ),
    );
  }
}

class _MyPrayerTile extends ConsumerWidget {
  final Prayer prayer;
  const _MyPrayerTile({required this.prayer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(settingsProvider).favoriteIds.contains(prayer.id);

    return ListTile(
      title: Text(prayer.displayTitle),
      subtitle: prayer.tags.isNotEmpty ? Text(prayer.tags.join(', ')) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: PhosphorIcon(
              isFav ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
              size: 22,
              color: isFav ? Colors.red : null,
            ),
            onPressed: () =>
                ref.read(settingsProvider.notifier).toggleFavorite(prayer.id),
          ),
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.pencilSimple, size: 20),
            onPressed: () => context.push('/prayer/edit/${prayer.id}'),
          ),
        ],
      ),
      onTap: () => context.push('/prayer/${prayer.id}'),
    );
  }
}
