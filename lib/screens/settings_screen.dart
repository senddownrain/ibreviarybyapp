import 'package:mybrev_flutter/widgets/psalmody_settings_section.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/widgets/data_settings_section.dart';
import 'package:mybrev_flutter/widgets/priest_access_settings_section.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_settings_section.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/widgets/adaptive_segmented_control.dart';

// ignore_for_file: use_build_context_synchronously

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.scrollToData = false});

  /// Opened from a «Даныя і афлайн» link: scroll to that section.
  final bool scrollToData;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class SettingsThemeControl extends StatelessWidget {
  const SettingsThemeControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AppThemePreference value;
  final ValueChanged<AppThemePreference> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final widthPerChoice =
          constraints.maxWidth / AppThemePreference.values.length;
      final needsFullWidthLabels =
          constraints.hasBoundedWidth && widthPerChoice < 145 * textScale;
      if (needsFullWidthLabels) {
        return DropdownButtonFormField<AppThemePreference>(
          key: ValueKey(value),
          initialValue: value,
          isExpanded: true,
          items: [
            for (final preference in AppThemePreference.values)
              DropdownMenuItem(
                value: preference,
                child: Text(preference.label),
              ),
          ],
          onChanged: (mode) {
            if (mode != null) onChanged(mode);
          },
        );
      }
      final showIcons = widthPerChoice >= 180 * textScale;
      return AdaptiveSegmentedControl<AppThemePreference>(
        segments: [
          for (final preference in AppThemePreference.values)
            AdaptiveSegment(
              value: preference,
              icon: showIcons
                  ? Icon(switch (preference) {
                      AppThemePreference.system =>
                        PhosphorIconsRegular.circleHalf,
                      AppThemePreference.light => PhosphorIconsRegular.sun,
                      AppThemePreference.dark => PhosphorIconsRegular.moon,
                      AppThemePreference.marian => Icons.star_outline_rounded,
                    }, size: 18)
                  : null,
              label: Text(preference.label),
            ),
        ],
        value: value,
        showSelectedIcon: false,
        onChanged: onChanged,
      );
    },
  );
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _dataKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.scrollToData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _dataKey.currentContext;
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

    return AmbientWash(
      seasonColor: GlassTokens.of(context).ambientBase,
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
                SettingsThemeControl(
                  value: settings.themePreference,
                  onChanged: (mode) => ref
                      .read(settingsProvider.notifier)
                      .setThemePreference(mode),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Same order and live preview as the Web «Тэкст» section.
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const Key('settings-text-section'),
                    title: Text(
                      'Тэкст',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: const Text('Шрыфт, памер і выраўноўванне'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    initiallyExpanded: true,
                    maintainState: true,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Шрыфт чытання',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              key: const Key('settings-reader-font'),
                              initialValue: settings.fontFamily,
                              isExpanded: true,
                              selectedItemBuilder: (context) => [
                                for (final option in kAvailableReaderFonts)
                                  Text(option.label),
                              ],
                              items: [
                                for (final option in kAvailableReaderFonts)
                                  DropdownMenuItem(
                                    value: option.id,
                                    child: Text(
                                      option.label,
                                      style: ReaderTheme.of(
                                        context,
                                      ).body(16, family: option.id),
                                    ),
                                  ),
                              ],
                              onChanged: (family) {
                                if (family != null) {
                                  ref
                                      .read(settingsProvider.notifier)
                                      .setFontFamily(family);
                                }
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              readerFontOption(settings.fontFamily).description,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Памер тэксту',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                ),
                                Text(
                                  '${readerFontScalePercent(settings.fontSize)}%',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ],
                            ),
                            Slider.adaptive(
                              key: const Key('settings-font-size'),
                              value: settings.fontSize,
                              min: kMinReaderFontSize,
                              max: kMaxReaderFontSize,
                              divisions: 11,
                              label:
                                  '${readerFontScalePercent(settings.fontSize)}%',
                              onChanged: (val) => ref
                                  .read(settingsProvider.notifier)
                                  .setFontSize(val),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Выраўноўванне тэксту',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 128,
                                  child: AdaptiveSegmentedControl<TextAlign>(
                                    key: const Key('settings-text-alignment'),
                                    value: settings.textAlignment,
                                    showSelectedIcon: false,
                                    segments: const [
                                      AdaptiveSegment(
                                        value: TextAlign.left,
                                        label: Tooltip(
                                          message: 'Па левым краі',
                                          child: Icon(
                                            Icons.format_align_left,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      AdaptiveSegment(
                                        value: TextAlign.justify,
                                        label: Tooltip(
                                          message: 'Па шырыні',
                                          child: Icon(
                                            Icons.format_align_justify,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (alignment) => ref
                                        .read(settingsProvider.notifier)
                                        .setTextAlignment(alignment),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Божа, прыйдзі мне на дапамогу. Пане, паспяшы да мяне на паратунак.',
                                key: const Key('settings-text-preview'),
                                textAlign: settings.textAlignment,
                                style: ReaderTheme.of(context).body(
                                  settings.fontSize,
                                  family: settings.fontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                const PsalmodySettingsSection(),
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
                    DropdownMenuItem(
                      value: 'hours',
                      child: Text('Літургія гадзінаў'),
                    ),
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

                const LiturgicalCalendarSettingsSection(),
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

                DataSettingsSection(key: _dataKey),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                ListTile(
                  key: const Key('settings-feedback'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.chat_bubble_outline_rounded),
                  title: const Text('Зваротная сувязь'),
                  subtitle: const Text('Пытанні і прапановы'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/feedback'),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const PriestAccessSettingsSection(),
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
                    child: const Text('Інфармацыя'),
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
                'Тэгі не знойдзены',
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
