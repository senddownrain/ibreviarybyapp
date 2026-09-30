import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/constants/hora_items.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/liturgical_day_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/services/parsed_readings_service.dart';
import 'package:mybrev_flutter/services/static_liturgical_service.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';
import 'package:mybrev_flutter/widgets/shimmer_placeholder.dart';
import 'package:mybrev_flutter/widgets/data_loading_notice.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';
import 'package:mybrev_flutter/models/year_options.dart';

/// Compatibility/fallback screen showing liturgical hours for a day.
///
/// Stage 3 keeps this route for old links and transitional navigation. The
/// normal daily flow now opens an hour directly from the Hours root.
/// Status: KEEP / DEPRECATE / REMOVE LATER.
class HoraPickerScreen extends ConsumerStatefulWidget {
  final String dayId;
  final DateTime date;

  const HoraPickerScreen({super.key, required this.dayId, required this.date});

  @override
  ConsumerState<HoraPickerScreen> createState() => _HoraPickerScreenState();
}

class _HoraPickerScreenState extends ConsumerState<HoraPickerScreen> {
  LiturgicalDay? _day;
  List<DayTemplate> _templates = const [];
  bool _loading = true;
  String _readingSubtitle = 'Чытанні і Евангелле';

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  @override
  void didUpdateWidget(covariant HoraPickerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dayId != widget.dayId || oldWidget.date != widget.date) {
      setState(() {
        _loading = true;
        _day = null;
        _templates = const [];
      });
      _loadDay();
    }
  }

  /// Cache first: a day that is on the device is shown in the first frame.
  bool _applyLocal() {
    if (!HiveService.isCacheReady || HiveService.completoriumsBox.isEmpty) {
      return false;
    }
    final calendar = ref.read(calendarServiceProvider);
    final opts = calendar.getYearOptionsCached(widget.date.year);
    final nextOpts = calendar.getYearOptionsCached(widget.date.year + 1);
    final dynamicDates = calendar.getDynamicDatesCached(widget.date.year);
    final content = LiturgicalContentService();
    final day = content.resolveDayLocal(
      widget.date,
      widget.dayId,
      opts,
      nextOpts,
      dynamicDates,
    );
    if (day == null) return false;
    _day = day;
    _templates =
        content
            .getContentForDate(widget.date, opts, nextOpts, dynamicDates)
            .where(
              (item) => item.templates.any(
                (template) => template.id == widget.dayId,
              ),
            )
            .firstOrNull
            ?.templates ??
        const [];
    _loading = false;
    unawaited(_loadReadingSubtitle(calendar, dynamicDates));
    return true;
  }

  Future<void> _loadDay() async {
    if (_applyLocal()) {
      if (mounted) setState(() {});
      return;
    }
    try {
      await _loadDayContent();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDayContent() async {
    final calendar = CalendarService();
    await Future.wait([
      calendar.ensureYearOptions(widget.date.year),
      calendar.ensureYearOptions(widget.date.year + 1),
      calendar.ensureDynamicDates(widget.date.year),
      StaticLiturgicalService().getCompletoriums(),
    ]);
    final dynamicDates = calendar.getDynamicDatesCached(widget.date.year);
    final context = computeLiturgicalContext(
      widget.date,
      calendar.getYearOptionsCached(widget.date.year),
      calendar.getYearOptionsCached(widget.date.year + 1),
      dynamicDates,
    );
    final day = await LiturgicalDayService().resolveDayForDate(
      widget.date,
      widget.dayId,
      context,
      getDynamicFeastCodesForDate(widget.date, dynamicDates),
    );
    final option = LiturgicalContentService()
        .getContentForDate(
          widget.date,
          calendar.getYearOptionsCached(widget.date.year),
          calendar.getYearOptionsCached(widget.date.year + 1),
          dynamicDates,
        )
        .where(
          (item) =>
              item.templates.any((template) => template.id == widget.dayId),
        )
        .firstOrNull;
    if (!mounted) return;
    setState(() {
      _day = day;
      _templates = option?.templates ?? const [];
      _loading = false;
    });
    unawaited(_loadReadingSubtitle(calendar, dynamicDates));
  }

  Future<void> _loadReadingSubtitle(
    CalendarService calendar,
    DynamicDates? dynamicDates,
  ) async {
    try {
      final readings = await ParsedReadingsService().fetchForDate(
        widget.date,
        calendar.getYearOptionsCached(widget.date.year),
        calendar.getYearOptionsCached(widget.date.year + 1),
        dynamicDates,
        includeAlternatives: true,
        dayId: widget.dayId,
      );
      final references = <String>{};
      for (final reading in readings) {
        for (final reference in [
          reading.firstReading?.bible,
          reading.reading2?.bible,
          reading.gospel?.bible,
        ]) {
          if ((reference ?? '').trim().isNotEmpty) {
            references.add(reference!.trim());
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _readingSubtitle = references.isNotEmpty
            ? references.join(' · ')
            : readings.isEmpty
            ? 'Чытанні для гэтай даты не знойдзены'
            : 'Чытанні і Евангелле';
      });
    } catch (_) {
      // The readings route remains available; offline cache may be populated
      // later by warmup or manual synchronisation.
    }
  }

  String _readingsDateKey() {
    return DateFormat('yyyy-MM-dd').format(widget.date);
  }

  bool _isHoraAvailable(HoraItem hora) {
    return isHourAvailable(_day, hora);
  }

  @override
  Widget build(BuildContext context) {
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AdaptiveAppBar.text('Літургія гадзін'),
        body: Stack(
          children: [
            AmbientWash.hero(seasonColor: seasonColor),
            ListView(
              padding: EdgeInsets.fromLTRB(
                0,
                MediaQuery.paddingOf(context).top + kFloatingAppBarContentInset,
                0,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: const [
                DataLoadingNotice(label: 'Загружаем літургічныя тэксты дня'),
                TileShimmer(),
                TileShimmer(),
                TileShimmer(),
              ],
            ),
          ],
        ),
      );
    }

    final day = _day;
    if (day == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AdaptiveAppBar.text('Літургія гадзін'),
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

    final dayTitle = liturgicalDayDisplayTitle(day, widget.date)
        .replaceAll(RegExp(r'\\?<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
    final periodLabel = liturgicalDayPeriodLabel(day);
    final psalterLabel = liturgicalDayPsalterLabel(day, widget.date);
    final rankLabel = liturgicalDayRankLabel(day);
    final placeLabel = liturgicalDayPlaceLabel(day);
    final dayColor = liturgicalColorForDay(day);
    final dateKey = _readingsDateKey();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AdaptiveAppBar(
        title: const Text('Літургія гадзін'),
        actions: [
          IconButton(
            tooltip: 'Чытанні',
            icon: const PhosphorIcon(PhosphorIconsRegular.bookOpen, size: 22),
            onPressed: () => context.go(
              Uri(
                path: '/readings',
                queryParameters: {'date': dateKey, 'dayId': widget.dayId},
              ).toString(),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          AmbientWash.hero(seasonColor: dayColor),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  12,
                  MediaQuery.paddingOf(context).top +
                      kFloatingAppBarContentInset,
                  12,
                  // Keep the final hour clear of the floating app dock.
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                children: [
                  GlassSurface(
                    style: GlassStyle.card,
                    seasonColor: dayColor,
                    borderRadius: BorderRadius.circular(28),
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 142),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PhosphorIcon(
                                PhosphorIconsFill.circle,
                                size: 9,
                                color: dayColor,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  [
                                    periodLabel,
                                    if (psalterLabel.isNotEmpty) psalterLabel,
                                  ].join(' · '),
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: dayColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          if (dayTitle.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              dayTitle,
                              style: ReaderTheme.of(
                                context,
                              ).displayTitle(34).copyWith(color: cs.onSurface),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${DateFormat('d MMMM y', 'be').format(widget.date)} г.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              if (rankLabel.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: dayColor.withValues(alpha: 0.11),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    rankLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: dayColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              if (placeLabel.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        placeLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (_templates.length > 1) ...[
                            const SizedBox(height: 14),
                            Text(
                              'ШАБЛОН ЛІТУРГІІ ДНЯ',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final template in _templates)
                                  ChoiceChip(
                                    label: Text(template.label),
                                    selected: template.id == widget.dayId,
                                    onSelected: (_) => context.replace(
                                      horaRouteForContext(
                                        date: widget.date,
                                        dayId: template.id,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassSurface(
                    style: GlassStyle.card,
                    seasonColor: dayColor,
                    borderRadius: BorderRadius.circular(22),
                    padding: EdgeInsets.zero,
                    child: _ReadingTile(
                      color: dayColor,
                      subtitle: _readingSubtitle,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.go(
                          Uri(
                            path: '/readings',
                            queryParameters: {
                              'date': dateKey,
                              'dayId': widget.dayId,
                            },
                          ).toString(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final hora in kHoraItems) ...[
                    GlassSurface(
                      style: GlassStyle.card,
                      seasonColor: dayColor,
                      borderRadius: BorderRadius.circular(22),
                      padding: EdgeInsets.zero,
                      child: _HoraTile(
                        hora: hora,
                        enabled: _isHoraAvailable(hora),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push(
                            oraRouteForContext(
                              date: widget.date,
                              dayId: widget.dayId,
                              oraType: hora.type,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
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

class _ReadingTile extends StatelessWidget {
  final Color color;
  final String subtitle;
  final VoidCallback onTap;

  const _ReadingTile({
    required this.color,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      minTileHeight: 78,
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: PhosphorIcon(PhosphorIconsRegular.bookOpenText, color: color),
      ),
      title: Text(
        'Чытанні',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle),
      trailing: PhosphorIcon(
        PhosphorIconsRegular.caretRight,
        size: 18,
        color: cs.outline,
      ),
    );
  }
}

class _HoraTile extends StatelessWidget {
  final HoraItem hora;
  final bool enabled;
  final VoidCallback? onTap;

  const _HoraTile({required this.hora, required this.enabled, this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: enabled ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: PhosphorIcon(hora.icon, size: 23, color: iconColor),
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
                        color: enabled ? cs.onSurfaceVariant : cs.outline,
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
