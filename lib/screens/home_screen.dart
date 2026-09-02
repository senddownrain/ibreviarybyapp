import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/constants/liturgical.dart';
import 'package:mybrev_flutter/providers/data_bootstrap_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/utils/day_prefetch_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final options = ref.watch(dayOptionsProvider);
    final isLoading = ref.watch(homeDataLoadingProvider);
    final bootstrap = ref.watch(dataBootstrapProvider);
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final navDir = ref.watch(homeNavDirectionProvider);
    final tokens = GlassTokens.of(context);
    final titleColor = tokens.accentOnSurface(seasonColor);
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final dayOfWeekLabel = DateFormat('EEEE', 'be').format(date);
    final dayMonthLabel = DateFormat('d MMMM', 'be').format(date);

    return Stack(
      children: [
        AmbientWash.hero(seasonColor: seasonColor),
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _pickDate(context, ref, date),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, anim) {
                      final slide = Tween<Offset>(
                        begin: Offset(navDir * 0.25, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(parent: anim, curve: Curves.easeOut),
                      );
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: Column(
                      key: ValueKey(date.toIso8601String()),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PhosphorIcon(
                              PhosphorIconsRegular.calendarBlank,
                              size: 14,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isToday ? 'Сёння' : 'Выбраная дата',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dayOfWeekLabel,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                                letterSpacing: -0.4,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dayMonthLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(width: 4),
                            PhosphorIcon(
                              PhosphorIconsRegular.caretDown,
                              size: 14,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (options.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    'Літургія гадзін',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                  ),
                ),
              ),
            if (options.isEmpty && isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                  child: GlassSurface(
                    style: GlassStyle.card,
                    seasonColor: seasonColor,
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          bootstrap.phase == 'static'
                              ? 'Загрузка базы дадзеных...'
                              : 'Загрузка літургічных дзён...',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Гэта можа заняць некалькі секунд',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (options.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassSurface(
                    style: GlassStyle.card,
                    seasonColor: seasonColor,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        PhosphorIcon(
                          PhosphorIconsLight.arrowsClockwise,
                          size: 48,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Няма дадзеных',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Сінхранізуйце дадзеныя ў Наладах',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final opt = options[i];
                    if (kDebugMode) {
                      debugPrint(
                        '[Home] DayOptionCard render - key=${opt.key}, source=${opt.source}',
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _DayOptionCard(option: opt, date: date),
                    );
                  },
                  childCount: options.length,
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 88 + MediaQuery.viewPaddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) async {
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

class _DayOptionCard extends ConsumerWidget {
  final DayOption option;
  final DateTime date;
  const _DayOptionCard({required this.option, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GlassTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);

    final accentColor = _accentForOption(option);
    final accentFg = tokens.accentOnSurface(accentColor);
    final day = option.day;
    final hasDay = day != null;

    final icon = switch (option.source) {
      LiturgicalOptionSource.period => PhosphorIconsRegular.calendar,
      LiturgicalOptionSource.dynamic => PhosphorIconsRegular.star,
      LiturgicalOptionSource.fixed => PhosphorIconsRegular.cross,
    };

    final sourceLabel = switch (option.source) {
      LiturgicalOptionSource.period => null,
      LiturgicalOptionSource.dynamic => 'свята',
      LiturgicalOptionSource.fixed => 'фіксаванае свята',
    };

    final child = GlassSurface(
      style: GlassStyle.card,
      seasonColor: seasonColor,
      accentBar: accentColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentFg.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: PhosphorIcon(icon, size: 22, color: accentFg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sourceLabel != null) ...[
                  Text(
                    sourceLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accentFg,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  _stripHtml(option.title),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                ),
                if (option.source != LiturgicalOptionSource.period &&
                    option.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (day?.feastComment != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    day!.feastComment!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
                if (!hasDay) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Сінхранізуйце дадзеныя ў Наладах',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (hasDay)
            PhosphorIcon(
              PhosphorIconsRegular.caretRight,
              size: 18,
              color: cs.outline,
            ),
        ],
      ),
    );

    if (!hasDay) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final dayId = day.id;
          unawaited(DayPrefetchService().prefetch(date, option));
          context.push('/hora/$dayId');
        },
        child: child,
      ),
    );
  }
}

String _stripHtml(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '');

Color _accentForOption(DayOption option) {
  if (option.source == LiturgicalOptionSource.period) {
    return _periodColor(option.title);
  }
  if (option.source == LiturgicalOptionSource.dynamic) {
    return const Color(0xFFE8A030);
  }
  return const Color(0xFF5B8DD9);
}

Color _periodColor(String title) {
  if (title.contains('пост') || title.contains('Адвэнт')) {
    return const Color(0xFF7C5CBF);
  }
  if (title.contains('Велікодны')) return const Color(0xFFD4A017);
  if (title.contains('Вялікі тыдзень')) return const Color(0xFF8B0000);
  if (title.contains('Нараджэння')) return const Color(0xFF2E7D32);
  return const Color(0xFF3A7D44);
}
