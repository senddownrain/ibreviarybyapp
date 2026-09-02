import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/ios_app_bar.dart';

class LiturgicalDayOptionsScreen extends ConsumerWidget {
  final String period;
  final int week;
  final int day;

  const LiturgicalDayOptionsScreen({
    super.key,
    required this.period,
    required this.week,
    required this.day,
  });

  static const _dayLabels = {
    1: 'Нядзеля',
    2: 'Панядзелак',
    3: 'Аўторак',
    4: 'Серада',
    5: 'Чацвер',
    6: 'Пятніца',
    7: 'Субота',
  };

  static const _periodLabels = {
    'ordinary': 'Звычайны перыяд',
    'advent': 'Адвэнт',
    'lent': 'Вялікі пост',
    'easter': 'Велікодны перыяд',
    'christmas': 'Перыяд Нараджэння',
    'holyweek': 'Вялікі тыдзень',
  };

  String? _findDayId() {
    final box = HiveService.daysBox;
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      final data = Map<String, dynamic>.from(raw);
      final pt = data['_periodType'];
      final wn = data['_periodWeekNumber']?.toString();
      final dw = data['_dayOfWeek']?.toString();
      final feast = data['_feast'];
      final noFeast = feast == null || feast == '';
      if (pt == period &&
          wn == week.toString() &&
          dw == day.toString() &&
          noFeast) {
        return LiturgicalDay.fromMap(data).id;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodLabel = _periodLabels[period] ?? period;
    final dayLabel = _dayLabels[day] ?? '$day';
    final dayId = _findDayId();
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: IosGlassAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(periodLabel),
            Text(
              'Тыдзень $week · $dayLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).appBarTheme.foregroundColor?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      body: AmbientWash(
        seasonColor: seasonColor,
        height: 260,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + kToolbarHeight + 18,
            16,
            24,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: GlassSurface(
              style: GlassStyle.card,
              seasonColor: seasonColor,
              borderRadius: BorderRadius.circular(28),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.bookOpen,
                      size: 20,
                    ),
                    label: const Text('Чытанні'),
                    onPressed: () =>
                        context.push('/readings/liturgical/$period/$week/$day'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.clockCountdown,
                      size: 20,
                    ),
                    label: const Text('Літургія гадзін'),
                    onPressed: dayId != null
                        ? () => context.push('/hora/$dayId')
                        : null,
                  ),
                  if (dayId == null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Гадзіны малітвы для гэтага дня не знойдзены ў базе',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
