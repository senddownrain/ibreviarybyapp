import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _navigate(WidgetRef ref, DateTime current, int days) {
    ref.read(selectedDateProvider.notifier).state =
        current.add(Duration(days: days));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date    = ref.watch(selectedDateProvider);
    final options = ref.watch(dayOptionsProvider);
    if (kDebugMode) debugPrint('[Home] dayOptionsProvider count: ${options.length}');

    final dayOfWeekLabel = DateFormat('EEEE', 'be').format(date);
    final dayMonthLabel  = DateFormat('d MMMM', 'be').format(date);

    final now     = DateTime.now();
    final isToday = date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        // ── Navigation header ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              // ← previous day
              IconButton(
                icon: const PhosphorIcon(PhosphorIconsRegular.caretLeft, size: 20),
                tooltip: 'Папярэдні дзень',
                onPressed: () => _navigate(ref, date, -1),
              ),

              // date label (tap → date picker)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
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
                  },
                  child: Column(
                    children: [
                      Text(
                        dayOfWeekLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayMonthLabel,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'сёння',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // → next day
              IconButton(
                icon: const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 20),
                tooltip: 'Наступны дзень',
                onPressed: () => _navigate(ref, date, 1),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Day option cards ───────────────────────────────────
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    PhosphorIcon(PhosphorIconsLight.arrowsClockwise, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    const Text(
                      'Няма дадзеных',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Сінхранізуйце дадзеныя ў Наладах',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

        for (final opt in options) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DayOptionCard(
              key: ValueKey(opt.key), option: opt, date: date),
          ),
          if (opt.day != null)
            _HoraSection(dayId: opt.day!.id),
        ],
      ],
    );
  }
}

class _CardButton extends StatelessWidget {
  final PhosphorIconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _CardButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = filled ? cs.primary : cs.surfaceContainerHighest;
    final fg = filled ? cs.onPrimary : cs.onSurface;

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
  return const Color(0xFF3A7D44); // ordinary — green
}

class _DayOptionCard extends StatelessWidget {
  final DayOption option;
  final DateTime date;
  const _DayOptionCard({Key? key, required this.option, required this.date}) : super(key: key);

  String get _dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) debugPrint('[Home] DayOptionCard render - key=${option.key}, source=${option.source}');

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

    final day    = option.day;
    final hasDay = day != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored left accent bar
            Container(width: 4, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Source badge for non-period options
                    if (sourceLabel != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (option.source != LiturgicalOptionSource.period && option.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        option.subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (day?.feastComment != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        day!.feastComment!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _CardButton(
                          icon: PhosphorIcons.bookOpen(),
                          label: 'Чытанні',
                          filled: false,
                          onTap: () => context.push('/readings/$_dateKey'),
                        ),
                        if (hasDay) ...[
                          const SizedBox(width: 8),
                          _CardButton(
                            icon: PhosphorIcons.clockCountdown(),
                            label: 'Літургія',
                            filled: true,
                            onTap: () => context.push('/hora/${day.id}'),
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
                      Divider(height: 1, indent: 52, color: cs.outlineVariant.withValues(alpha: 0.5)),
                    InkWell(
                      onTap: () => GoRouter.of(context).push('/ora/$dayId/${_horaItems[i].type}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        child: Row(
                          children: [
                            PhosphorIcon(_horaItems[i].icon, size: 20, color: cs.primary),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                _horaItems[i].label,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            PhosphorIcon(PhosphorIconsRegular.caretRight, size: 16, color: cs.outline),
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
