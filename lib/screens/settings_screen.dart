import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/data_bootstrap_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/providers/sync_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/utils/cache_stats.dart';
import 'package:mybrev_flutter/widgets/adaptive_segmented_control.dart';

// ignore_for_file: use_build_context_synchronously

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.scrollToSync = false});

  final bool scrollToSync;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _syncKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.scrollToSync) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _syncKey.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final bootstrap = ref.watch(dataBootstrapProvider);
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    ref.watch(cacheEpochProvider); // refresh Hive stats after warmup
    final stats = CacheStats.collect();

    final lastSync = _latestSync([
      HiveService.getLastSync('prayers'),
      HiveService.getLastSync('days'),
      HiveService.getLastSync('yearOptions'),
      HiveService.getLastSync('invitatoriums'),
      HiveService.getLastSync('completoriums'),
    ]);

    return AmbientWash(
      seasonColor: seasonColor,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _NeutralContentSurface(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Theme
                Text('Тэма', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                AdaptiveSegmentedControl<ThemeMode>(
                  segments: const [
                    AdaptiveSegment(
                      value: ThemeMode.system,
                      icon: PhosphorIcon(
                        PhosphorIconsRegular.circleHalf,
                        size: 18,
                      ),
                      label: Text('Сістэма'),
                    ),
                    AdaptiveSegment(
                      value: ThemeMode.light,
                      icon: PhosphorIcon(PhosphorIconsRegular.sun, size: 18),
                      label: Text('Светлая'),
                    ),
                    AdaptiveSegment(
                      value: ThemeMode.dark,
                      icon: PhosphorIcon(PhosphorIconsRegular.moon, size: 18),
                      label: Text('Цёмная'),
                    ),
                  ],
                  value: settings.themeMode,
                  // The selected fill already communicates the active theme.
                  // Omitting a second icon leaves room for translated labels.
                  showSelectedIcon: false,
                  onChanged: (mode) =>
                      ref.read(settingsProvider.notifier).setThemeMode(mode),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Font size
                Text(
                  'Памер шрыфту',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider.adaptive(
                  value: settings.fontSize,
                  min: kMinReaderFontSize,
                  max: kMaxReaderFontSize,
                  divisions: 11,
                  label: '${readerFontScalePercent(settings.fontSize)}%',
                  onChanged: (val) =>
                      ref.read(settingsProvider.notifier).setFontSize(val),
                ),
                Text(
                  'Прыклад: Госпадзе, памілуй нас.',
                  style: TextStyle(fontSize: settings.fontSize),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                Text(
                  'Стартовы раздзел',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('settings-start-section'),
                  initialValue: settings.startSection,
                  items: const [
                    DropdownMenuItem(
                      value: 'last',
                      child: Text('Апошні адкрыты'),
                    ),
                    DropdownMenuItem(value: 'hours', child: Text('Літургія')),
                    DropdownMenuItem(value: 'readings', child: Text('Чытанні')),
                    DropdownMenuItem(
                      value: 'prayerbook',
                      child: Text('Малітоўнік'),
                    ),
                    DropdownMenuItem(value: 'bible', child: Text('Біблія')),
                  ],
                  onChanged: (section) {
                    if (section != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .setStartSection(section);
                    }
                  },
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Keep screen on
                Text('Экран', style: Theme.of(context).textTheme.titleMedium),
                SwitchListTile.adaptive(
                  title: const Text('Не гасіць экран'),
                  subtitle: const Text(
                    'Экран застаецца ўключаным падчас чытання малітваў',
                  ),
                  value: settings.keepScreenOn,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setKeepScreenOn(v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Sync
                SizedBox(
                  key: _syncKey,
                  child: Text(
                    'Сінхранізацыя',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                if (lastSync != null)
                  Text(
                    'Апошняя сінхранізацыя: ${_formatDate(lastSync)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Text(
                  'Малітвы і статычныя зборнікі загружаюцца цалкам. '
                  'Дні і чытанні — толькі на бліжэйшыя даты (каля 2 месяцаў), '
                  'каб не цягнуць усю базу.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (syncStatus.isSyncing) ...[
                  LinearProgressIndicator(value: syncStatus.progress),
                  const SizedBox(height: 8),
                  Text(
                    '${syncStatus.currentLabel ?? syncStatus.currentCollection ?? "..."}  '
                    '(${syncStatus.completedCollections + 1} з ${syncStatus.totalCollections})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (syncStatus.currentDocCount != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${syncStatus.currentDocCount} дакументаў',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
                if (syncStatus.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            PhosphorIcon(
                              PhosphorIconsRegular.warning,
                              size: 20,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                syncStatus.error!,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: syncStatus.isSyncing
                      ? null
                      : () => ref
                            .read(syncStatusProvider.notifier)
                            .forceSyncAll(),
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.arrowsClockwise,
                    size: 18,
                  ),
                  label: const Text('Сінхранізаваць'),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                ExpansionTile(
                  key: const Key('settings-diagnostics'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text('Дыягностыка'),
                  subtitle: const Text('Кэш і пакрыццё даных'),
                  children: [
                    if (stats.bootstrapNeeded)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'База яшчэ не загружана — адкрыйце галоўны экран',
                        ),
                      )
                    else if (bootstrap.isRunning)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Загрузка: ${bootstrap.phase == 'static' ? 'база' : 'дні'}...',
                        ),
                      ),
                    if (stats.coverageLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Пакрыццё дат: ${stats.coverageLabel}'),
                      ),
                    _StatRow(label: 'Малітвы', count: stats.prayers),
                    _StatRow(label: 'Дні ў кэшы', count: stats.days),
                    _StatRow(label: 'Гады', count: stats.years),
                    _StatRow(label: 'Чытанні ў кэшы', count: stats.readings),
                    _StatRow(label: 'Заклік', count: stats.invitatoriums),
                    _StatRow(label: 'Камплета', count: stats.completoriums),
                    _StatRow(
                      label: 'Абраныя',
                      count: settings.favoriteIds.length,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) =>
                      Text('Версія ${snapshot.data?.version ?? '—'}'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.push('/about'),
                    child: const Text('Інфармацыя пра дадатак'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24 + MediaQuery.viewPaddingOf(context).bottom),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year} '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  DateTime? _latestSync(List<DateTime?> times) {
    DateTime? best;
    for (final t in times) {
      if (t == null) continue;
      if (best == null || t.isAfter(best)) best = t;
    }
    return best;
  }
}

class _NeutralContentSurface extends StatelessWidget {
  const _NeutralContentSurface({
    required this.child,
    required this.padding,
    required this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

// ── Categories section ────────────────────────────────────────────────────────

// Kept temporarily for storage-compatible migration; the only visible editor
// is now the canonical Prayerbook categories route.
// ignore: unused_element
class _CategoriesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final cats = ref.watch(prayerMenuCategoriesProvider);
    final globalCategories = ref.watch(globalPrayerCategoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Катэгорыі ў меню',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            if (settings.hiddenGlobalPrayerCategoryIds.isNotEmpty)
              TextButton(
                onPressed: () => ref
                    .read(settingsProvider.notifier)
                    .resetDefaultCategories(),
                child: const Text('Аднавіць'),
              ),
            TextButton.icon(
              onPressed: () => _showCategoryDialog(context, ref, null),
              icon: const PhosphorIcon(PhosphorIconsRegular.plus, size: 18),
              label: const Text('Дадаць'),
            ),
          ],
        ),
        if (globalCategories.isLoading && cats.isEmpty)
          const LinearProgressIndicator(),
        if (globalCategories.hasError && cats.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Не атрымалася загрузіць катэгорыі. Праверце падключэнне.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (!globalCategories.isLoading &&
            !globalCategories.hasError &&
            cats.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'У меню няма катэгорый',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final cat in cats)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const PhosphorIcon(
              PhosphorIconsRegular.bookmark,
              size: 22,
            ),
            title: Row(
              children: [
                Flexible(child: Text(cat.name)),
                if (cat.isGlobal) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: const Text('Па змаўчанні'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
            subtitle: cat.tags.isNotEmpty
                ? Text(
                    cat.tags.join(', '),
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!cat.isGlobal)
                  IconButton(
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.pencilSimple,
                      size: 20,
                    ),
                    tooltip: 'Рэдагаваць',
                    onPressed: () => _showCategoryDialog(
                      context,
                      ref,
                      UserCategory(id: cat.id, name: cat.name, tags: cat.tags),
                    ),
                  ),
                IconButton(
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.trash,
                    size: 20,
                  ),
                  tooltip: 'Выдаліць',
                  onPressed: () async {
                    final ok = usesCupertinoGlass(context)
                        ? await showCupertinoDialog<bool>(
                            context: context,
                            builder: (ctx) => CupertinoAlertDialog(
                              title: Text(
                                cat.isGlobal
                                    ? 'Прыбраць катэгорыю з меню?'
                                    : 'Выдаліць катэгорыю?',
                              ),
                              actions: [
                                CupertinoDialogAction(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Адмена'),
                                ),
                                CupertinoDialogAction(
                                  isDestructiveAction: true,
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Выдаліць'),
                                ),
                              ],
                            ),
                          )
                        : await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(
                                cat.isGlobal
                                    ? 'Прыбраць катэгорыю з меню?'
                                    : 'Выдаліць катэгорыю?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Адмена'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Выдаліць'),
                                ),
                              ],
                            ),
                          );
                    if (ok == true) {
                      final notifier = ref.read(settingsProvider.notifier);
                      if (cat.isGlobal) {
                        notifier.hideGlobalPrayerCategory(cat.id);
                      } else {
                        notifier.deleteCategory(cat.id);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    UserCategory? existing,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryDialog(
        existing: existing,
        onSave: (name, tags) {
          if (existing == null) {
            ref.read(settingsProvider.notifier).addCategory(name, tags);
          } else {
            ref
                .read(settingsProvider.notifier)
                .updateCategory(existing.id, name, tags);
          }
        },
      ),
    );
  }
}

class _CategoryDialog extends ConsumerStatefulWidget {
  final UserCategory? existing;
  final void Function(String name, List<String> tags) onSave;

  const _CategoryDialog({this.existing, required this.onSave});

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  late final TextEditingController _nameCtrl;
  late Set<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _selectedTags = Set<String>.from(widget.existing?.tags ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allTags = ref.watch(allTagsProvider);

    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Новая катэгорыя' : 'Рэдагаваць катэгорыю',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Назва катэгорыі',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text('Тэгі:', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            if (allTags.isEmpty)
              Text(
                'Тэгі не знойдзены (патрэбна сінхранізацыя)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: allTags.map((tag) {
                final sel = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                  selected: sel,
                  onSelected: (_) {
                    setState(() {
                      if (sel) {
                        _selectedTags.remove(tag);
                      } else {
                        _selectedTags.add(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Адмена'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            widget.onSave(name, _selectedTags.toList());
            Navigator.pop(context);
          },
          child: const Text('Захаваць'),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final String label;
  final int count;
  const _StatRow({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
