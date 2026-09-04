import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/cache_epoch_provider.dart';
import 'package:mybrev_flutter/providers/data_bootstrap_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/providers/sync_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/utils/cache_stats.dart';

// ignore_for_file: use_build_context_synchronously

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final bootstrap = ref.watch(dataBootstrapProvider);
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    ref.watch(cacheEpochProvider); // refresh Hive stats after warmup
    final stats = CacheStats.collect();
    final topPad = MediaQuery.paddingOf(context).top;

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
        padding: EdgeInsets.fromLTRB(12, topPad + 62, 12, 12),
        children: [
          GlassSurface(
            style: GlassStyle.card,
            seasonColor: seasonColor,
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Theme
                Text('Тэма', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (defaultTargetPlatform == TargetPlatform.iOS)
                  CupertinoSlidingSegmentedControl<ThemeMode>(
                    children: const {
                      ThemeMode.system: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Сістэма'),
                      ),
                      ThemeMode.light: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Светлая'),
                      ),
                      ThemeMode.dark: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Цёмная'),
                      ),
                    },
                    groupValue: settings.themeMode,
                    onValueChanged: (v) {
                      if (v != null) {
                        ref.read(settingsProvider.notifier).setThemeMode(v);
                      }
                    },
                  )
                else
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: PhosphorIcon(
                          PhosphorIconsRegular.circleHalf,
                          size: 18,
                        ),
                        label: Text('Сістэма'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: PhosphorIcon(PhosphorIconsRegular.sun, size: 18),
                        label: Text('Светлая'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: PhosphorIcon(PhosphorIconsRegular.moon, size: 18),
                        label: Text('Цёмная'),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) =>
                        ref.read(settingsProvider.notifier).setThemeMode(s.first),
                  ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Font size
                Text(
                  'Памер шрыфту',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
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
                  style: _textStyle(
                    settings,
                  ).copyWith(fontSize: settings.fontSize),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Font family
                Text('Шрыфт', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: settings.fontFamily,
                  onChanged: (font) {
                    if (font != null) {
                      ref.read(settingsProvider.notifier).setFontFamily(font);
                    }
                  },
                  child: Column(
                    children: kAvailableFonts.map((font) {
                      final selected = settings.fontFamily == font;
                      const previewSize = 15.0;
                      final previewStyle = font == 'Сістэмны'
                          ? const TextStyle(fontSize: previewSize)
                          : GoogleFonts.getFont(font, fontSize: previewSize);
                      return InkWell(
                        onTap: () => ref
                            .read(settingsProvider.notifier)
                            .setFontFamily(font),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Radio<String>(value: font),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(font, style: previewStyle),
                                    Text(
                                      'Аб вечнай радасці спявае душа мая.',
                                      style: previewStyle.copyWith(
                                        fontSize: 13,
                                        color: selected ? null : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Keep screen on
                Text('Экран', style: Theme.of(context).textTheme.titleMedium),
                if (defaultTargetPlatform == TargetPlatform.iOS)
                  ListTile(
                    title: const Text('Не гасіць экран'),
                    subtitle: const Text(
                      'Экран застаецца ўключаным падчас чытання малітваў',
                    ),
                    trailing: CupertinoSwitch(
                      value: settings.keepScreenOn,
                      onChanged: (v) =>
                          ref.read(settingsProvider.notifier).setKeepScreenOn(v),
                    ),
                    contentPadding: EdgeInsets.zero,
                  )
                else
                  SwitchListTile(
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

                // User categories
                _CategoriesSection(),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Sync
                Text(
                  'Сінхранізацыя',
                  style: Theme.of(context).textTheme.titleMedium,
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

                // Stats
                Text(
                  'Статыстыка',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (stats.bootstrapNeeded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'База яшчэ не загружана — адкрыйце галоўны экран',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else if (bootstrap.isRunning)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Загрузка: ${bootstrap.phase == 'static' ? 'база' : 'дні'}...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                if (stats.coverageLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Пакрыццё дат: ${stats.coverageLabel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                _StatRow(label: 'Малітвы', count: stats.prayers),
                _StatRow(label: 'Дні ў кэшы', count: stats.days),
                _StatRow(label: 'Гады', count: stats.years),
                _StatRow(label: 'Чытанні ў кэшы', count: stats.readings),
                _StatRow(label: 'Заклік', count: stats.invitatoriums),
                _StatRow(label: 'Камплета', count: stats.completoriums),
                _StatRow(label: 'Абраныя', count: settings.favoriteIds.length),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // About
                Text(
                  'Пра дадатак',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text('Mybrev — беларускі каталіцкі малітоўнік'),
                const Text('Версія 1.0.0'),
                const SizedBox(height: 14),
              ],
            ),
          ),
          SizedBox(height: 24 + MediaQuery.viewPaddingOf(context).bottom),
        ],
      ),
    );
  }

  TextStyle _textStyle(SettingsState settings) {
    if (settings.resolvedFontFamily == null) return const TextStyle();
    return GoogleFonts.getFont(settings.fontFamily);
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

// ── Categories section ────────────────────────────────────────────────────────

class _CategoriesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(settingsProvider).userCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Мае катэгорыі',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton(
              onPressed: () =>
                  ref.read(settingsProvider.notifier).resetDefaultCategories(),
              child: const Text('Скінуць'),
            ),
            TextButton.icon(
              onPressed: () => _showCategoryDialog(context, ref, null),
              icon: const PhosphorIcon(PhosphorIconsRegular.plus, size: 18),
              label: const Text('Дадаць'),
            ),
          ],
        ),
        if (cats.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Стварыце ўласныя катэгорыі для малітваў',
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
            title: Text(cat.name),
            subtitle: cat.tags.isNotEmpty
                ? Text(
                    cat.tags.join(', '),
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.pencilSimple,
                    size: 20,
                  ),
                  tooltip: 'Рэдагаваць',
                  onPressed: () => _showCategoryDialog(context, ref, cat),
                ),
                IconButton(
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.trash,
                    size: 20,
                  ),
                  tooltip: 'Выдаліць',
                  onPressed: () async {
                    final ok = await (defaultTargetPlatform == TargetPlatform.iOS
                      ? showCupertinoDialog<bool>(
                          context: context,
                          builder: (ctx) => CupertinoAlertDialog(
                            title: const Text('Выдаліць катэгорыю?'),
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
                      : showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Выдаліць катэгорыю?'),
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
                        ));
                    if (ok == true) {
                      ref
                          .read(settingsProvider.notifier)
                          .deleteCategory(cat.id);
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
    void onSave(String name, List<String> tags) {
      if (existing == null) {
        ref.read(settingsProvider.notifier).addCategory(name, tags);
      } else {
        ref.read(settingsProvider.notifier).updateCategory(existing.id, name, tags);
      }
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => _CategoryDialog(existing: existing, onSave: onSave),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => _CategoryDialog(existing: existing, onSave: onSave),
      );
    }
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
