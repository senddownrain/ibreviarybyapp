import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/app_theme_preference.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/widgets/data_settings_section.dart';
import 'package:mybrev_flutter/widgets/liturgical_calendar_settings_section.dart';
import 'package:mybrev_flutter/widgets/priest_access_settings_section.dart';
import 'package:mybrev_flutter/widgets/reader_icon_segments.dart';
import 'package:mybrev_flutter/widgets/psalmody_settings_section.dart';
import 'package:mybrev_flutter/widgets/settings_reader_controls.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.scrollToData = false});

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelStyle = theme.textTheme.labelMedium!;
        final scaler = MediaQuery.textScalerOf(context);
        final fits = AppThemePreference.values.every((choice) {
          final painter = TextPainter(
            text: TextSpan(text: choice.label, style: labelStyle),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final fits =
              painter.width + 10 <=
              constraints.maxWidth / AppThemePreference.values.length;
          painter.dispose();
          return fits;
        });
        if (!fits) {
          return DropdownButtonFormField<AppThemePreference>(
            key: ValueKey(value),
            initialValue: value,
            isExpanded: true,
            items: [
              for (final choice in AppThemePreference.values)
                DropdownMenuItem(value: choice, child: Text(choice.label)),
            ],
            onChanged: (choice) {
              if (choice != null) onChanged(choice);
            },
          );
        }
        return ReaderIconSegments<AppThemePreference>(
          value: value,
          choices: AppThemePreference.values,
          label: (choice) => choice.label,
          onChanged: onChanged,
          content: (context, choice) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(switch (choice) {
                  AppThemePreference.system => PhosphorIconsRegular.circleHalf,
                  AppThemePreference.light => PhosphorIconsRegular.sun,
                  AppThemePreference.dark => PhosphorIconsRegular.moon,
                  AppThemePreference.marian => Icons.star_outline_rounded,
                }, size: 20),
                const SizedBox(height: 4),
                ExcludeSemantics(child: Text(choice.label, style: labelStyle)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _dataKey = GlobalKey();
  late final _packageInfo = PackageInfo.fromPlatform();

  @override
  void initState() {
    super.initState();
    _scrollToData();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.scrollToData) _scrollToData();
  }

  void _scrollToData() {
    if (!widget.scrollToData) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _dataKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return AmbientWash(
      seasonColor: GlassTokens.of(context).ambientBase,
      child: SingleChildScrollView(
        key: const Key('settings-scroll'),
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _NeutralContentSurface(
              borderRadius: BorderRadius.circular(28),
              padding: const EdgeInsets.all(16),
              child: Column(
                key: const Key('settings-sections'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    key: const Key('settings-start'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Стартовы раздзел',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: const Key('settings-start-section'),
                        initialValue: settings.startSection,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'last',
                            child: Text('Апошні адкрыты'),
                          ),
                          DropdownMenuItem(
                            value: 'hours',
                            child: Text('Літургія гадзінаў'),
                          ),
                          DropdownMenuItem(
                            value: 'readings',
                            child: Text('Чытанні дня'),
                          ),
                          DropdownMenuItem(
                            value: 'prayerbook',
                            child: Text('Малітоўнік'),
                          ),
                          DropdownMenuItem(
                            value: 'bible',
                            child: Text('Біблія'),
                          ),
                        ],
                        onChanged: (section) {
                          if (section != null) {
                            ref
                                .read(settingsProvider.notifier)
                                .setStartSection(section);
                          }
                        },
                      ),
                    ],
                  ),
                  const _SectionDivider(),
                  Column(
                    key: const Key('settings-theme'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Тэма', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SettingsThemeControl(
                        value: settings.themePreference,
                        onChanged: notifier.setThemePreference,
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile.adaptive(
                        key: const Key('settings-keep-screen-on'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Не гасіць экран'),
                        value: settings.keepScreenOn,
                        onChanged: notifier.setKeepScreenOn,
                      ),
                    ],
                  ),
                  const _SectionDivider(),
                  const _TextSection(key: Key('settings-text')),
                  const _SectionDivider(),
                  const LiturgicalCalendarSettingsSection(
                    key: Key('settings-calendar'),
                  ),
                  const _SectionDivider(),
                  KeyedSubtree(
                    key: const Key('settings-data'),
                    child: DataSettingsSection(key: _dataKey),
                  ),
                  const _SectionDivider(),
                  const PriestAccessSettingsSection(
                    key: Key('settings-special-access'),
                  ),
                  const _SectionDivider(),
                  const _SettingsMenuRow(
                    key: Key('settings-feedback'),
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Зваротная сувязь',
                    subtitle: 'Пытанні і прапановы',
                    path: '/settings/feedback',
                  ),
                  const _SettingsMenuRow(
                    key: Key('settings-about'),
                    icon: Icons.info_outline_rounded,
                    title: 'Інфармацыя',
                    subtitle: 'Пра дадатак, крыніцы і правы',
                    path: '/about',
                  ),
                  Padding(
                    key: const Key('settings-version'),
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: FutureBuilder<PackageInfo>(
                      future: _packageInfo,
                      builder: (context, snapshot) => Text(
                        'Версія ${snapshot.data?.version ?? '—'}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
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

class _TextSection extends ConsumerWidget {
  const _TextSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return ExpansionTile(
      key: const Key('settings-text-section'),
      title: Text('Тэкст', style: theme.textTheme.titleMedium),
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      initiallyExpanded: true,
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsReaderRow(
          label: 'Шрыфт',
          controlWidth: 180,
          inlineWidth: 258,
          control: DropdownButtonFormField<String>(
            key: const Key('settings-reader-font'),
            initialValue: settings.fontFamily,
            isExpanded: true,
            selectedItemBuilder: (context) => [
              for (final option in kAvailableReaderFonts) Text(option.label),
            ],
            items: [
              for (final option in kAvailableReaderFonts)
                DropdownMenuItem(
                  value: option.id,
                  child: Text(
                    option.label,
                    style: ReaderTheme.of(context).body(16, family: option.id),
                  ),
                ),
            ],
            onChanged: (family) {
              if (family != null) {
                ref.read(settingsProvider.notifier).setFontFamily(family);
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text('Памер тэксту', style: theme.textTheme.titleSmall),
            ),
            const SizedBox(width: 8),
            Text(
              '${readerFontScalePercent(settings.fontSize)}%',
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        Slider.adaptive(
          key: const Key('settings-font-size'),
          value: settings.fontSize,
          min: kMinReaderFontSize,
          max: kMaxReaderFontSize,
          divisions: 11,
          label: '${readerFontScalePercent(settings.fontSize)}%',
          onChanged: notifier.setFontSize,
        ),
        SettingsReaderRow(
          label: 'Выраўноўванне тэксту',
          controlWidth: 112,
          inlineWidth: 260,
          control: ReaderIconSegments<TextAlign>(
            key: const Key('settings-text-alignment'),
            value: settings.textAlignment,
            choices: const [TextAlign.left, TextAlign.justify],
            label: (choice) =>
                choice == TextAlign.left ? 'Па левым краі' : 'Па шырыні',
            onChanged: notifier.setTextAlignment,
            content: (context, choice) => Icon(
              choice == TextAlign.left
                  ? Icons.format_align_left
                  : Icons.format_align_justify,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SettingsReaderPreview(
          child: Text(
            'Божа, прыйдзі мне на дапамогу. Пане, паспяшы да мяне на паратунак.',
            key: const Key('settings-text-preview'),
            textAlign: settings.textAlignment,
            style: ReaderTheme.of(
              context,
            ).body(settings.fontSize, family: settings.fontFamily),
          ),
        ),
        const SizedBox(height: 16),
        const PsalmodySettingsSection(),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          key: const Key('settings-readings-highlight'),
          title: const Text('Каляровае вылучэнне чытанняў'),
          contentPadding: EdgeInsets.zero,
          value: settings.readingsHighlightEnabled,
          onChanged: notifier.setReadingsHighlightEnabled,
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}

class _SettingsMenuRow extends StatelessWidget {
  const _SettingsMenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 24,
      horizontalTitleGap: 12,
      leading: Icon(icon, size: 24),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(path),
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
