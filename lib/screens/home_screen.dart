import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';

// Direction of date navigation for slide animation
final _navDirectionProvider = StateProvider<int>((ref) => 0); // -1 back, 0 none, 1 forward

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _navigate(WidgetRef ref, DateTime current, int days) {
    HapticFeedback.selectionClick();
    ref.read(_navDirectionProvider.notifier).state = days > 0 ? 1 : -1;
    ref.read(selectedDateProvider.notifier).state =
        current.add(Duration(days: days));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.isAndroid) {
      return _AndroidHomeScreen(navigate: _navigate);
    }
    return _IOSHomeScreen(navigate: _navigate);
  }
}

// ── Shared content list ───────────────────────────────────────────────────────

typedef _NavigateFn = void Function(WidgetRef ref, DateTime current, int days);

List<Widget> _buildContent(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
  List<DayOption> options,
  bool isToday,
  _NavigateFn navigate,
) {
  if (kDebugMode) debugPrint('[Home] dayOptionsProvider count: ${options.length}');

  return [
    if (options.isEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                PhosphorIcon(PhosphorIconsLight.arrowsClockwise,
                    size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text('Няма дадзеных',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Сінхранізуйце дадзеныя ў Наладах',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    for (final opt in options) ...[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _DayOptionCard(key: ValueKey(opt.key), option: opt, date: date),
      ),
      if (opt.day != null)
        _HoraSection(dayId: opt.day!.id)
      else
        _HoraSyncPrompt(),
    ],
    const SizedBox(height: 24),
  ];
}

// ── iOS layout: classic scrollable with arrow nav header ─────────────────────

class _IOSHomeScreen extends ConsumerWidget {
  final _NavigateFn navigate;
  const _IOSHomeScreen({required this.navigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final options = ref.watch(dayOptionsProvider);
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final navDir = ref.watch(_navDirectionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final dayOfWeekLabel = DateFormat('EEEE', 'be').format(date);
    final dayMonthLabel = DateFormat('d MMMM', 'be').format(date);

    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // ── Ambient gradient background ─────────────────────────────────────
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  seasonColor.withValues(alpha: isDark ? 0.35 : 0.22),
                  seasonColor.withValues(alpha: isDark ? 0.10 : 0.06),
                  seasonColor.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45, 0.85],
              ),
            ),
          ),
        ),

        // ── Content ─────────────────────────────────────────────────────────
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(4, topPad + 4, 4, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const PhosphorIcon(PhosphorIconsRegular.caretLeft, size: 20),
                      tooltip: 'Папярэдні дзень',
                      onPressed: () => navigate(ref, date, -1),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _pickDate(context, ref, date),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          transitionBuilder: (child, anim) {
                            final slide = Tween<Offset>(
                              begin: Offset(navDir * 0.25, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(position: slide, child: child),
                            );
                          },
                          child: Column(
                            key: ValueKey(date.toIso8601String()),
                            children: [
                              Text(
                                dayOfWeekLabel,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: seasonColor,
                                    ),
                              ),
                              const SizedBox(height: 1),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(dayMonthLabel,
                                      style: Theme.of(context).textTheme.bodyMedium),
                                  if (isToday) ...[
                                    const SizedBox(width: 6),
                                    _TodayChip(color: seasonColor),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 20),
                      tooltip: 'Наступны дзень',
                      onPressed: () => navigate(ref, date, 1),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 12)),
            SliverList(
              delegate: SliverChildListDelegate(
                _buildContent(context, ref, date, options, isToday, navigate),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate(
      BuildContext context, WidgetRef ref, DateTime date) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2019),
      lastDate: DateTime(2027, 12, 31),
      locale: const Locale('be'),
    );
    if (picked != null) {
      ref.read(selectedDateProvider.notifier).state = picked;
    }
  }
}

// ── Android layout: SliverAppBar.large with date as large title ───────────────

class _AndroidHomeScreen extends ConsumerWidget {
  final _NavigateFn navigate;
  const _AndroidHomeScreen({required this.navigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final options = ref.watch(dayOptionsProvider);
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final dayOfWeekLabel = DateFormat('EEEE', 'be').format(date);
    final dayMonthLabel = DateFormat('d MMMM', 'be').format(date);

    return CustomScrollView(
      slivers: [
        // Large collapsible AppBar — date is the hero
        SliverAppBar.large(
          automaticallyImplyLeading: false,
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          // Collapsed: short date + arrows
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavArrow(
                icon: PhosphorIconsRegular.caretLeft,
                onTap: () => navigate(ref, date, -1),
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('d MMM', 'be').format(date),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              _NavArrow(
                icon: PhosphorIconsRegular.caretRight,
                onTap: () => navigate(ref, date, 1),
              ),
            ],
          ),
          // Expanded: full day name + month
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            titlePadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            title: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _pickDate(context, ref, date),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dayOfWeekLabel,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        _TodayChip(),
                      ],
                    ],
                  ),
                  Text(
                    dayMonthLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const PhosphorIcon(PhosphorIconsRegular.caretLeft, size: 18),
              tooltip: 'Папярэдні дзень',
              onPressed: () => navigate(ref, date, -1),
            ),
            IconButton(
              icon: const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 18),
              tooltip: 'Наступны дзень',
              onPressed: () => navigate(ref, date, 1),
            ),
          ],
        ),

        // Content
        SliverPadding(
          padding: const EdgeInsets.only(top: 8),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              _buildContent(context, ref, date, options, isToday, navigate),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(
      BuildContext context, WidgetRef ref, DateTime date) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2019),
      lastDate: DateTime(2027, 12, 31),
      locale: const Locale('be'),
    );
    if (picked != null && context.mounted) {
      ref.read(selectedDateProvider.notifier).state = picked;
    }
  }
}

class _NavArrow extends StatelessWidget {
  final PhosphorIconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: PhosphorIcon(icon, size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

// ── Shared small components ───────────────────────────────────────────────────

class _TodayChip extends StatelessWidget {
  final Color? color;
  const _TodayChip({this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'сёння',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final PhosphorIconData icon;
  final String label;
  final bool filled;
  final Color? accentColor;
  final VoidCallback onTap;

  const _CardButton({
    required this.icon,
    required this.label,
    required this.filled,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentColor ?? cs.primary;
    final bg = filled ? accent : accent.withValues(alpha: 0.10);
    final fg = filled ? Colors.white : accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(icon, size: 17, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _stripHtml(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '');

Color _periodColor(String title) {
  if (title.contains('пост') || title.contains('Адвэнт')) {
    return const Color(0xFF7C5CBF);
  }
  if (title.contains('Велікодны')) return const Color(0xFFD4A017);
  if (title.contains('Вялікі тыдзень')) return const Color(0xFF8B0000);
  if (title.contains('Нараджэння')) return const Color(0xFF2E7D32);
  return const Color(0xFF3A7D44);
}

class _DayOptionCard extends StatelessWidget {
  final DayOption option;
  final DateTime date;
  const _DayOptionCard({Key? key, required this.option, required this.date})
      : super(key: key);

  String get _dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint(
          '[Home] DayOptionCard render - key=${option.key}, source=${option.source}');
    }

    Color accentColor;
    String? sourceLabel;
    switch (option.source) {
      case LiturgicalOptionSource.period:
        accentColor = _periodColor(option.title);
        sourceLabel = null;
      case LiturgicalOptionSource.dynamic:
        accentColor = const Color(0xFFE8A030);
        sourceLabel = 'свята';
      case LiturgicalOptionSource.fixed:
        accentColor = const Color(0xFF5B8DD9);
        sourceLabel = 'фіксаванае свята';
    }

    final day = option.day;
    final hasDay = day != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassBg = isDark
        ? Colors.black.withValues(alpha: 0.42)
        : Colors.white.withValues(alpha: 0.78);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.95);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: glassBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 0.7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 16,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Accent left bar
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (sourceLabel != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                sourceLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            _stripHtml(option.title),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (option.source != LiturgicalOptionSource.period &&
                              option.subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(option.subtitle!,
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                          if (day?.feastComment != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              day!.feastComment!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontStyle: FontStyle.italic),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _CardButton(
                                icon: PhosphorIcons.bookOpen(),
                                label: 'Чытанні',
                                filled: false,
                                accentColor: accentColor,
                                onTap: () =>
                                    context.push('/readings/$_dateKey'),
                              ),
                              if (hasDay) ...[
                                const SizedBox(width: 8),
                                _CardButton(
                                  icon: PhosphorIcons.clockCountdown(),
                                  label: 'Літургія',
                                  filled: true,
                                  accentColor: accentColor,
                                  onTap: () =>
                                      context.push('/hora/${day.id}'),
                                ),
                              ],
                            ],
                          ),
                        ],
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

class _HoraSyncPrompt extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.90),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: seasonColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.sync_rounded, color: seasonColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Літургія гадзін недаступная',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Сінхранізуйце дадзеныя ў Наладах',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
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

const _horaItems = [
  (type: 'morning',      label: 'Агульная гадзіна',         icon: PhosphorIconsLight.cloudSun),
  (type: 'invitatorium', label: 'Заклік',                   icon: PhosphorIconsRegular.sunHorizon),
  (type: 'laudes',       label: 'Ютрань',                   icon: PhosphorIconsRegular.sun),
  (type: 'lectionis',   label: 'Гадзіна чытанняў',         icon: PhosphorIconsRegular.bookOpenText),
  (type: 'terz',         label: 'Малітва перад поўднем',    icon: PhosphorIconsRegular.clock),
  (type: 'sext',         label: 'Малітва апоўдні',          icon: PhosphorIconsRegular.sun),
  (type: 'non',          label: 'Малітва пасля поўдня',     icon: PhosphorIconsRegular.cloudSun),
  (type: 'vespers',      label: 'Нешпары',                  icon: PhosphorIconsRegular.moon),
  (type: 'completorium', label: 'Камплета',                 icon: PhosphorIconsRegular.moonStars),
];

class _HoraSection extends StatelessWidget {
  final String dayId;
  const _HoraSection({required this.dayId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6, top: 4),
            child: Text(
              'Літургія гадзін',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.outline,
                    letterSpacing: 0.4,
                  ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Material(
              color: cs.surfaceContainerLow,
              child: Column(
                children: [
                  for (int i = 0; i < _horaItems.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          indent: 52,
                          color: cs.outlineVariant.withValues(alpha: 0.5)),
                    InkWell(
                      onTap: () => GoRouter.of(context)
                          .push('/ora/$dayId/${_horaItems[i].type}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        child: Row(
                          children: [
                            PhosphorIcon(_horaItems[i].icon,
                                size: 20, color: cs.primary),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                _horaItems[i].label,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            PhosphorIcon(PhosphorIconsRegular.caretRight,
                                size: 16, color: cs.outline),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
