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
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/day_prefetch_service.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';

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

    final dayOfWeekLabel = _sentenceCase(DateFormat('EEEE', 'be').format(date));
    final dayMonthLabel = DateFormat('d MMMM y', 'be').format(date);

    return Stack(
      children: [
        AmbientWash.hero(seasonColor: seasonColor),
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
                    child: GlassSurface(
                      style: GlassStyle.card,
                      seasonColor: seasonColor,
                      borderRadius: BorderRadius.circular(28),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _pickDate(context, ref, date),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          transitionBuilder: (child, anim) {
                            final slide =
                                Tween<Offset>(
                                  begin: Offset(navDir * 0.25, 0),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: anim,
                                    curve: Curves.easeOut,
                                  ),
                                );
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            );
                          },
                          child: SizedBox(
                            key: ValueKey(date.toIso8601String()),
                            height: 190,
                            child: Stack(
                              children: [
                                Positioned(
                                  top: -30,
                                  right: -24,
                                  child: Container(
                                    width: 116,
                                    height: 116,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: seasonColor.withValues(
                                        alpha: tokens.isDark ? 0.20 : 0.13,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Row(
                                        children: [
                                          PhosphorIcon(
                                            PhosphorIconsRegular.circleHalf,
                                            size: 14,
                                            color: titleColor,
                                          ),
                                          const SizedBox(width: 7),
                                          Expanded(
                                            child: Text(
                                              isToday
                                                  ? 'ЛІТУРГІЧНЫ КАЛЯНДАР · СЁННЯ'
                                                  : 'ЛІТУРГІЧНЫ КАЛЯНДАР · ВЫБРАНАЯ ДАТА',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: titleColor,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.0,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        dayOfWeekLabel,
                                        style: ReaderTheme.of(context)
                                            .displayTitle(38)
                                            .copyWith(color: cs.onSurface),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          PhosphorIcon(
                                            PhosphorIconsRegular.calendarBlank,
                                            size: 17,
                                            color: cs.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            dayMonthLabel,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: seasonColor.withValues(
                                                alpha: tokens.isDark
                                                    ? 0.18
                                                    : 0.10,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: seasonColor.withValues(
                                                  alpha: 0.20,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Змяніць',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: titleColor,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(width: 3),
                                                PhosphorIcon(
                                                  PhosphorIconsRegular
                                                      .caretDown,
                                                  size: 12,
                                                  color: titleColor,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (options.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Text(
                        'ВЫБЕРЫЦЕ ЛІТУРГІЧНЫ ДЗЕНЬ',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                if (options.isEmpty && isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 32,
                      ),
                      child: GlassSurface(
                        style: GlassStyle.card,
                        seasonColor: seasonColor,
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
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
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final opt = options[i];
                      if (kDebugMode) {
                        debugPrint(
                          '[Home] DayOptionCard render - key=${opt.key}, source=${opt.source}',
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: _DayOptionCard(option: opt, date: date),
                      );
                    }, childCount: options.length),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 88 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
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
    final accentColor = _accentForOption(option);
    final accentFg = tokens.accentOnSurface(accentColor);
    final day = option.day;
    final hasDay = day != null;

    final icon = switch (option.source) {
      LiturgicalOptionSource.period => PhosphorIconsRegular.calendar,
      LiturgicalOptionSource.dynamic => PhosphorIconsRegular.star,
      LiturgicalOptionSource.fixed => PhosphorIconsRegular.cross,
      LiturgicalOptionSource.officeForDead => PhosphorIconsRegular.flowerLotus,
    };

    final sourceLabel = switch (option.source) {
      LiturgicalOptionSource.period => null,
      LiturgicalOptionSource.dynamic => 'свята',
      LiturgicalOptionSource.fixed => 'фіксаванае свята',
      LiturgicalOptionSource.officeForDead => 'памінальны афіцый',
    };

    final child = GlassSurface(
      style: GlassStyle.card,
      seasonColor: accentColor,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentFg.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withValues(alpha: 0.18)),
            ),
            child: Center(child: PhosphorIcon(icon, size: 24, color: accentFg)),
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
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    height: 1.32,
                    color: cs.onSurface,
                  ),
                ),
                if (option.source != LiturgicalOptionSource.period &&
                    option.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (!hasDay) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Сінхранізуйце дадзеныя ў Наладах',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          final dayId = day.id;
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          unawaited(DayPrefetchService().prefetch(date, option));
          context.push('/hora/$dateKey/$dayId');
        },
        child: child,
      ),
    );
  }
}

String _stripHtml(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '');

String _sentenceCase(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

Color _accentForOption(DayOption option) {
  return liturgicalColorForDay(
    option.day,
    fallbackPeriodType: option.contextPeriodType,
  );
}
