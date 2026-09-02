import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/constants/hora_items.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_day_service.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/ios_app_bar.dart';

/// Screen showing list of available liturgical hours for a day.
class HoraPickerScreen extends ConsumerStatefulWidget {
  final String dayId;

  const HoraPickerScreen({
    super.key,
    required this.dayId,
  });

  @override
  ConsumerState<HoraPickerScreen> createState() => _HoraPickerScreenState();
}

class _HoraPickerScreenState extends ConsumerState<HoraPickerScreen> {
  LiturgicalDay? _day;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  Future<void> _loadDay() async {
    final raw = HiveService.daysBox.get(widget.dayId);
    if (raw != null) {
      setState(() {
        _day = LiturgicalDay.fromMap(Map<String, dynamic>.from(raw));
        _loading = false;
      });
      return;
    }

    final day = await LiturgicalDayService().getDayById(widget.dayId);
    if (!mounted) return;
    setState(() {
      _day = day;
      _loading = false;
    });
  }

  bool _isAvailable(HoraItem hora, LiturgicalDay day) {
    // Completorium lives in its own Hive box, not on the day document.
    if (hora.type == 'completorium') {
      return _completoriumAvailable(day);
    }
    return hora.checkFields.any((k) {
      final v = day.field(k);
      return v != null && v.isNotEmpty;
    });
  }

  bool _completoriumAvailable(LiturgicalDay day) {
    final id = _completoriumId(day);
    if (HiveService.completoriumsBox.containsKey(id)) return true;
    // Essentials sync filled the box — offer Compline even if key shape differs.
    return HiveService.completoriumsBox.isNotEmpty;
  }

  String _completoriumId(LiturgicalDay day) {
    var period = (day.periodType ?? day.field('_periodType') ?? 'ordinary').trim();
    if (period == 'holyweek') period = 'lent';

    final rank =
        (day.rank ?? day.field('_rank') ?? day.field('_feastType') ?? '').trim();
    final isFeast = rank == 'solemnity' ||
        rank == 'feast' ||
        rank == 'solemnitas' ||
        rank == 'festum';
    final dow = isFeast
        ? 1
        : (day.dayOfWeek ?? int.tryParse(day.field('_dayOfWeek') ?? '') ?? 2);

    return '$period-d$dow';
  }

  String? _readingsDateKey() {
    final selected = ref.read(selectedDateProvider);
    return DateFormat('yyyy-MM-dd').format(selected);
  }

  @override
  Widget build(BuildContext context) {
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: IosGlassAppBar.text('Літургія гадзін'),
        body: Stack(
          children: [
            AmbientWash.hero(seasonColor: seasonColor),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    final day = _day;
    if (day == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: IosGlassAppBar.text('Літургія гадзін'),
        body: Stack(
          children: [
            AmbientWash.hero(seasonColor: seasonColor),
            Center(
              child: Text(
                'Дзень не знойдзены',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    final dayTitle = day.feastName ?? day.title ?? '';
    final available = kHoraItems.where((h) => _isAvailable(h, day)).toList();
    final unavailable =
        kHoraItems.where((h) => !_isAvailable(h, day)).toList();
    final dateKey = _readingsDateKey();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: IosGlassAppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Літургія гадзін'),
            if (dayTitle.isNotEmpty)
              Text(
                dayTitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Чытанні',
            icon: const PhosphorIcon(PhosphorIconsRegular.bookOpen, size: 22),
            onPressed: dateKey == null
                ? null
                : () => context.push('/readings/$dateKey'),
          ),
        ],
      ),
      body: Stack(
        children: [
          AmbientWash.hero(seasonColor: seasonColor),
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
              16,
              32,
            ),
            children: [
              if (available.isEmpty)
                GlassSurface(
                  style: GlassStyle.soft,
                  seasonColor: seasonColor,
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Змест гадзін не знойдзены для гэтага дня',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              if (available.isNotEmpty)
                GlassSurface(
                  style: GlassStyle.card,
                  seasonColor: seasonColor,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < available.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 68,
                            color: cs.outlineVariant.withValues(alpha: 0.5),
                          ),
                        _HoraTile(
                          hora: available[i],
                          enabled: true,
                          onTap: () => context.push(
                            '/ora/${widget.dayId}/${available[i].type}',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (unavailable.isNotEmpty && available.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Не запоўнена ў базе',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.outline,
                      ),
                ),
                const SizedBox(height: 8),
                GlassSurface(
                  style: GlassStyle.soft,
                  seasonColor: seasonColor,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < unavailable.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 68,
                            color: cs.outlineVariant.withValues(alpha: 0.35),
                          ),
                        _HoraTile(hora: unavailable[i], enabled: false),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HoraTile extends StatelessWidget {
  final HoraItem hora;
  final bool enabled;
  final VoidCallback? onTap;

  const _HoraTile({
    required this.hora,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = enabled ? cs.primary : cs.outline;
    final textColor = enabled ? cs.onSurface : cs.outline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: enabled ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: PhosphorIcon(hora.icon, size: 20, color: iconColor),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hora.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      hora.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: enabled
                                ? cs.onSurfaceVariant
                                : cs.outline,
                          ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                PhosphorIcon(
                  PhosphorIconsRegular.caretRight,
                  size: 16,
                  color: cs.outline,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
