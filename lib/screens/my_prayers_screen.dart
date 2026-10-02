import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';

String _prayerPreview(Prayer prayer) => prayer.displayText
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll(RegExp(r':::[a-z]*'), ' ')
    .replaceAll(RegExp(r'^[#>*+\-]+\s*', multiLine: true), '')
    .replaceAll(RegExp(r'\*\*|__|[*_]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class MyPrayersScreen extends ConsumerWidget {
  const MyPrayersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayers = ref.watch(localPrayersProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AdaptiveAppBar.text('Мае малітвы'),
      // The app dock belongs to the parent Scaffold. With extendBody enabled,
      // its height is exposed here as MediaQuery.padding.bottom, but a nested
      // Scaffold does not apply that padding to its FAB automatically.
      floatingActionButton: Padding(
        key: const Key('my-prayers-add-button-inset'),
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/prayers/prayer/add'),
          tooltip: 'Новая малітва',
          icon: const PhosphorIcon(PhosphorIconsRegular.plus, size: 21),
          label: const Text('Новая малітва'),
        ),
      ),
      body: AmbientWash(
        seasonColor: GlassTokens.of(context).ambientBase,
        height: kToolbarHeight + 100,
        child: prayers.isEmpty
            ? Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top +
                      kFloatingAppBarContentInset,
                  20,
                  MediaQuery.paddingOf(context).bottom + 72,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: GlassSurface(
                      style: GlassStyle.card,
                      borderRadius: BorderRadius.circular(28),
                      padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: PhosphorIcon(
                                PhosphorIconsLight.notepad,
                                size: 38,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Вашы асабістыя малітвы',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Запісвайце тэксты, дадавайце тэгі і афармляйце важныя радкі.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: const Key('my-prayers-empty-create'),
                            onPressed: () =>
                                context.push('/prayers/prayer/add'),
                            icon: const PhosphorIcon(
                              PhosphorIconsRegular.plus,
                              size: 19,
                            ),
                            label: const Text('Стварыць малітву'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.only(
                  top:
                      MediaQuery.paddingOf(context).top +
                      kFloatingAppBarContentInset,
                  bottom: MediaQuery.paddingOf(context).bottom + 88,
                ),
                itemCount: prayers.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Row(
                        children: [
                          Text(
                            'Захаваныя',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text(
                            '${prayers.length}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  }
                  final prayer = prayers[index - 1];
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

    final cs = Theme.of(context).colorScheme;
    final preview = _prayerPreview(prayer);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 9),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/prayers/prayer/${prayer.id}');
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIconsRegular.notepad,
                        size: 23,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prayer.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (preview.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.35,
                                ),
                          ),
                        ],
                        if (prayer.tags.isNotEmpty) ...[
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            children: [
                              for (final tag in prayer.tags.take(3))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    tag,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: isFav
                            ? 'Выдаліць з абраных'
                            : 'Дадаць у абраныя',
                        icon: PhosphorIcon(
                          isFav
                              ? PhosphorIconsFill.heart
                              : PhosphorIconsRegular.heart,
                          size: 21,
                          color: isFav ? cs.error : cs.onSurfaceVariant,
                        ),
                        onPressed: () => ref
                            .read(settingsProvider.notifier)
                            .toggleFavorite(prayer.id),
                      ),
                      IconButton(
                        tooltip: 'Рэдагаваць',
                        icon: PhosphorIcon(
                          PhosphorIconsRegular.pencilSimple,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        onPressed: () =>
                            context.push('/prayers/prayer/${prayer.id}/edit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
