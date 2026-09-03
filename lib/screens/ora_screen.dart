import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/cache_warmup_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/services/liturgical_day_service.dart';
import 'package:mybrev_flutter/services/static_liturgical_service.dart';
import 'package:mybrev_flutter/utils/liturgical_calendar.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';
import 'package:mybrev_flutter/utils/liturgical_office.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';
import 'package:mybrev_flutter/widgets/ios_app_bar.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';
import 'package:mybrev_flutter/theme/glass.dart';

// ─── Static liturgical texts ──────────────────────────────────────────────────

const _kPaterNoster = 'Ойча наш.';

const _kStandardIntro =
    '<p><span style="color:red">К.</span> Божа, прыйдзі мне на дапамогу.</p>'
    '<p><span style="color:red">Н.</span> Пане, паспяшы да мяне на паратунак.</p>'
    '<p>Хвала Айцу і Сыну, * і Духу Святому.<br>'
    'Як была спрадвеку, цяпер і заўсёды, *<br>'
    'і на векі вечныя. Амэн.<br>'
    'Аллелюя.</p>';

const _kInvitIntro =
    '<p><span style="color:red">К.</span> Пане, адкрый мае вусны.</p>'
    '<p><span style="color:red">Н.</span> І вусны мае будуць абвяшчаць Тваю хвалу.</p>';

const _kInvitRubric =
    '<p><span style="color:red"><em>Заклік з’яўляецца пачаткам штодзённай '
    'літургічнай малітвы. Ён папярэднічае Гадзіне чытанняў або Ютрані, '
    'у залежнасці ад таго, якая з гэтых літургічных гадзінаў распачынае '
    'малітву дня.</em></span></p>';

const _kEndOfHour =
    '<p><span style="color:red">К.</span> Няхай Пан благаславіць нас, абароніць ад усялякага зла і давядзе да жыцця вечнага.</p>'
    '<p><span style="color:red">Н.</span> Амэн.</p>';

const _kEndOfComplineBlessing =
    '<p><span style="color:red">К.</span> Ноч спакойную і смерць шчаслівую няхай дасць нам Бог усемагутны, Айцец і Сын, і Дух Святы.</p>'
    '<p><span style="color:red">Н.</span> Амэн.</p>';

const _kBenedictus =
    '<p>Благаслаўлёны Пан, Бог Ізраэля, *<br>бо наведаў і адкупіў народ свой,</p>'
    '<p>і ўзняў моц збаўлення для нас *<br>у доме Давіда, слугі свайго.</p>'
    '<p>Як абвясціў спрадвеку *<br>вуснамі сваіх святых прарокаў,</p>'
    '<p>што збавіць нас ад ворагаў нашых *<br>і ад рук усіх, хто нас ненавідзіць.</p>'
    '<p>Каб праявіць міласэрнасць да айцоў нашых *<br>і нагадаць пра святы запавет свой.</p>'
    '<p>Прысягу, якую даў Абрагаму, айцу нашаму, *<br>дасць нам.</p>'
    '<p>Каб, выбаўленыя з рук ворагаў, *<br>мы без страху служылі Яму</p>'
    '<p>ў святасці і справядлівасці перад Ім *<br>ва ўсе дні нашыя.</p>'
    '<p>А ты, дзіцятка, прарокам Найвышэйшага будзеш названа, *<br>'
    'бо пойдзеш прад абліччам Пана падрыхтаваць шляхі Яму,</p>'
    '<p>каб даць народу Ягонаму пазнаць збаўленне *<br>праз адпушчэнне яго грахоў,</p>'
    '<p>дзякуючы сардэчнай міласэрнасці нашага Бога, *<br>у якой наведаў нас Усход з вышыні;</p>'
    '<p>каб асвятліць тых, *<br>хто сядзіць у цемры і ў цені смяротным;</p>'
    '<p>каб накіраваць ногі нашыя *<br>на шлях спакою.</p>'
    '<p>Хвала Айцу і Сыну, * і Духу Святому.<br>'
    'Як была спрадвеку, цяпер і заўсёды, * і на векі вечныя. Амэн.</p>';

const _kMagnificat =
    '<p>Велічае душа мая Пана, *<br>і ўзрадаваўся дух мой у Богу, маім Збаўцу,</p>'
    '<p>бо глянуў Бог на пакору сваёй слугі. *<br>І цяпер благаслаўляць мяне будуць усе пакаленні.</p>'
    '<p>Бо вялікае ўчыніў мне Усемагутны, *<br>а імя Яго святое.</p>'
    '<p>І міласэрнасць Яго з пакалення ў пакаленне *<br>над тымі, хто Яго баіцца.</p>'
    '<p>Паказаў моц сваёй правіцы, *<br>рассеяў тых, хто пыхлівы сэрцам.</p>'
    '<p>Скінуў магутных з трону *<br>і ўзвысіў пакорных.</p>'
    '<p>Дабром галодных насыціў, *<br>а багатых ні з чым адправіў.</p>'
    '<p>Прыняў свайго слугу Ізраэля, *<br>памятаючы пра сваю міласэрнасць,</p>'
    '<p>як абяцаў бацькам нашым — *<br>Абрагаму і яго патомству навекі.</p>'
    '<p>Хвала Айцу і Сыну, * і Духу Святому.<br>'
    'Як была спрадвеку, цяпер і заўсёды, * і на векі вечныя. Амэн.</p>';

const _kNunc =
    '<p>Цяпер адпускаеш слугу Твайго, Валадару, *<br>паводле слова Твайго, у спакоі;</p>'
    '<p>бо вочы мае ўбачылі збаўленне Тваё, *<br>якое падрыхтаваў Ты перад абліччам усіх народаў,</p>'
    '<p>святло для асвятлення язычнікаў *<br>і хвалу народу Твайго Ізраэля.</p>'
    '<p>Хвала Айцу і Сыну, * і Духу Святому.<br>'
    'Як была спрадвеку, цяпер і заўсёды, * і на векі вечныя. Амэн.</p>';

const _kTeDeum =
    '<p>Цябе, Бога, праслаўляем,<br>Табе, Пане, хвала вечна.</p>'
    '<p>Неба і зямля спявае<br>Табе, Ойча векавечны.</p>'
    '<p>Табе, Божа, ўсе анёлы,<br>З імі Моцы і Нябёсы,</p>'
    '<p>Херубімы, серафімы<br>Гімн хвалы адвечны ўзносяць.</p>'
    '<p>Святы, Святы над святымі<br>Бог магутны і ласкавы,</p>'
    '<p>Над зямлёй і небам слыне<br>Неабсяжнасць Тваёй славы.</p>'
    '<p>І Апосталы, і вучні,<br>Хор прарокаў, поўны хвалы,</p>'
    '<p>З імі мучанікаў лучнасць<br>Аддаюць Табе пашану.</p>'
    '<p>У сугучным хоры льецца<br>Па ўсёй зямлі наўкола</p>'
    '<p>Табе хвала з нашых сэрцаў,<br>Спеў святы Твайго Касцёла.</p>'
    '<p>Сына з Духам суцяшэння,<br>Велічы Айца прамністай</p>'
    '<p>Праслаўляе ўсё стварэнне, –<br>Валадар хвалы Ты, Хрыстэ.</p>'
    '<p>Каб жа выбавіць свет цэлы<br>Праз свае святыя раны,</p>'
    '<p>Сын Айца спрадвечны, цела<br>Ты прыняў ва ўлонні Панны.</p>'
    '<p>Зруйнаваў Ты брамы смерці,<br>На крыжы ёй вырваў джала,</p>'
    '<p>Каб для ўсіх, хто ў Цябе верыць,<br>Радасць вечная заззяла.</p>'
    '<p>Праваруч Айца, у славе<br>Трон Твой, Збаўца наш адзіны,</p>'
    '<p>Прыйдзеш зноў адтуль у яве,<br>Каб судзіць людскія чыны.</p>'
    '<p>Грэшным Ты не дай загінуць, –<br>Будзь нам Збаўцам, не Суддзёю</p>'
    '<p>І абмый нас ад правінаў<br>Дарагой сваёй крывёю.</p>'
    '<p>Са святымі, ў бляску моцы<br>Захавай Тваіх абраных.</p>'
    '<p><em>Апошнюю частку гімна можна па жаданні прапусціць.</em></p>'
    '<p>Пане, збаў народ Твой, просім,<br>Благаслаў Тваіх падданых.</p>'
    '<p>Шляхам нас вядзі бяспечным<br>У нябесны Ерузалем.</p>'
    '<p>Цябе, Валадар адвечны,<br>Мы штодзённа праслаўляем.</p>'
    '<p>Праз вякі гучыць няспынна<br>Спеў, што славіць Твае справы.</p>'
    '<p>Пане, ад усіх правінаў<br>Захаваць нас будзь ласкавы.</p>'
    '<p>Не пакінь жа свайго люду,<br>Божа, без Тваёй апекі.</p>'
    '<p>Пану веру, дык не буду<br>Асаромлены навекі.</p>';

// ─── Screen ───────────────────────────────────────────────────────────────────

class OraScreen extends ConsumerStatefulWidget {
  final String dayId;
  final String oraType;
  final DateTime date;
  const OraScreen({
    super.key,
    required this.dayId,
    required this.oraType,
    required this.date,
  });

  @override
  ConsumerState<OraScreen> createState() => _OraScreenState();
}

class _OraScreenState extends ConsumerState<OraScreen> {
  int? _selectedInvitIndex;
  String? _vespersRubric;
  late final Future<LiturgicalDay?> _dayFuture;

  @override
  void initState() {
    super.initState();
    _dayFuture = _loadDay();
  }

  Future<LiturgicalDay?> _loadDay() async {
    final calendar = CalendarService();
    final staticContent = StaticLiturgicalService();
    await Future.wait([
      calendar.ensureYearOptions(widget.date.year),
      calendar.ensureYearOptions(widget.date.year + 1),
      calendar.ensureDynamicDates(widget.date.year),
      staticContent.getInvitatoriums(),
      staticContent.getCompletoriums(),
    ]);
    final dynamicDates = calendar.getDynamicDatesCached(widget.date.year);
    final context = computeLiturgicalContext(
      widget.date,
      calendar.getYearOptionsCached(widget.date.year),
      calendar.getYearOptionsCached(widget.date.year + 1),
      dynamicDates,
    );
    final selected = await LiturgicalDayService().resolveDayForDate(
      widget.date,
      widget.dayId,
      context,
      getDynamicFeastCodesForDate(widget.date, dynamicDates),
    );
    if (selected == null || widget.oraType != 'vespers') return selected;
    return _resolveVespers(selected, calendar);
  }

  Future<LiturgicalDay> _resolveVespers(
    LiturgicalDay selected,
    CalendarService calendar,
  ) async {
    if (usesOwnVespers(selected)) return selected;
    try {
      final tomorrow = widget.date.add(const Duration(days: 1));
      await CacheWarmupService().warmupDate(tomorrow);
      await Future.wait([
        calendar.ensureYearOptions(tomorrow.year),
        calendar.ensureYearOptions(tomorrow.year + 1),
        calendar.ensureDynamicDates(tomorrow.year),
      ]);
      final options = LiturgicalContentService().getContentForDate(
        tomorrow,
        calendar.getYearOptionsCached(tomorrow.year),
        calendar.getYearOptionsCached(tomorrow.year + 1),
        calendar.getDynamicDatesCached(tomorrow.year),
      );
      final candidates = options
          .map((option) => option.day)
          .whereType<LiturgicalDay>();

      bool isUniversal(LiturgicalDay day) {
        final place = day.data['_place'];
        return place == null ||
            (place is String && place.trim().isEmpty) ||
            (place is List && place.isEmpty);
      }

      final first = candidates
          .where(
            (day) =>
                isUniversal(day) &&
                hasFirstVespersRank(day) &&
                hasFirstVespers(day),
          )
          .firstOrNull;
      if (first != null) {
        final title = liturgicalDayDisplayTitle(first, tomorrow);
        _vespersRubric =
            'I Нешпары · ${title.isEmpty ? 'заўтрашняга дня' : title}';
        return normalizeFirstVespers(first)!;
      }
      if (widget.date.weekday == DateTime.saturday) {
        final tomorrowDay = candidates.where(isUniversal).firstOrNull;
        if (tomorrowDay != null) {
          final title = liturgicalDayDisplayTitle(tomorrowDay, tomorrow);
          _vespersRubric =
              'I Нешпары · ${title.isEmpty ? 'нядзелі' : title}';
          return tomorrowDay;
        }
      }
    } catch (error) {
      debugPrint('[OraScreen] tomorrow Vespers lookup failed: $error');
    }
    if (widget.date.weekday == DateTime.sunday || isSolemnity(selected)) {
      _vespersRubric = 'II Нешпары';
    }
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LiturgicalDay?>(
      future: _dayFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _loadingState(context);
        }
        if (snap.hasError) {
          return _errorState(context, snap.error.toString());
        }
        final day = snap.data;
        if (day == null) return _emptyState(context);
        try {
          return _buildForDay(context, day);
        } catch (e, st) {
          debugPrint('[OraScreen] build failed: $e\n$st');
          return _errorState(context, e.toString());
        }
      },
    );
  }

  Widget _loadingState(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: IosGlassAppBar.text(_oraTitle(widget.oraType)),
    body: const Center(child: CircularProgressIndicator()),
  );

  Widget _buildForDay(BuildContext context, LiturgicalDay day) {
    final seasonColor = liturgicalColorForDay(day);
    final baseTheme = Theme.of(context);
    final themedScheme = baseTheme.colorScheme.copyWith(
      primary: seasonColor,
      primaryContainer: Color.alphaBlend(
        seasonColor.withValues(alpha: 0.18),
        baseTheme.colorScheme.surface,
      ),
    );

    // Invitatoriums — all variants for selection
    final allInvit = HiveService.invitatoriumsBox.values
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();

    // Completorium — keyed by {periodType}-d{dayOfWeek}
    final compId = _completoriumId(day);
    final compRaw = HiveService.completoriumsBox.get(compId);
    final comp = compRaw != null
        ? Map<String, dynamic>.from(compRaw as Map)
        : null;

    return Theme(
      data: baseTheme.copyWith(colorScheme: themedScheme),
      child: ReadingScaffold(
        builder: (context, textStyle) => Scaffold(
          extendBodyBehindAppBar: true,
          appBar: IosGlassAppBar.text(
            _oraTitle(widget.oraType),
            actions: const [TextScaleControl()],
          ),
          body: Stack(
            children: [
              AmbientWash.hero(seasonColor: seasonColor),
              _buildBody(context, day, allInvit, comp, textStyle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: IosGlassAppBar.text(_oraTitle(widget.oraType)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIconsLight.bookOpen,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('Дзень не знойдзены', style: TextStyle(color: cs.onSurface)),
            const SizedBox(height: 4),
            Text(
              'Магчыма, трэба сінхранізаваць дадзеныя ў Наладах',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: IosGlassAppBar.text(_oraTitle(widget.oraType)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                PhosphorIconsLight.warning,
                size: 48,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'Не атрымалася адкрыць гадзіну',
                style: TextStyle(color: cs.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    LiturgicalDay day,
    List<Map<String, dynamic>> allInvit,
    Map<String, dynamic>? comp,
    TextStyle textStyle,
  ) {
    final hourSections = switch (widget.oraType) {
      'morning' => _buildMorning(day, allInvit),
      'invitatorium' => _buildInvitatorium(day, allInvit),
      'lectionis' => _buildLectionis(day),
      'laudes' => _buildLaudes(day),
      'terz' => _buildSextHour(day, num: 1),
      'sext' => _buildSextHour(day, num: 2),
      'non' => _buildSextHour(day, num: 3),
      'vespers' => _buildVespers(day),
      'completorium' => _buildCompline(comp),
      _ => <_OraItem>[],
    };
    final sections = <_OraItem>[
      _OraItem.custom(
        (context, textStyle) =>
            _DayHeading(day: day, date: widget.date, textStyle: textStyle),
      ),
      ...hourSections,
    ];

    if (sections.isEmpty) {
      return const Center(child: Text('Няма зместу'));
    }

    final topPad = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, topPad, 16, 40),
      itemCount: sections.length,
      itemBuilder: (_, i) => sections[i].build(context, textStyle),
    );
  }

  // ─── Completorium ID ─────────────────────────────────────────────────────────
  // Format: {periodType}-d{dayOfWeek}, Sunday = d1, Saturday = d7
  // Solemnities/feasts → d1; holyweek → lent

  String _completoriumId(LiturgicalDay day) {
    final period = (day.periodType ?? day.field('_periodType') ?? 'ordinary')
        .trim();
    final dow =
        day.dayOfWeek ?? int.tryParse(day.field('_dayOfWeek') ?? '') ?? 2;
    return completoriumId(period, dow, day);
  }

  // ─── Invitatorium ─────────────────────────────────────────────────────────────
  // Ant from days; Ps1–6 from invitatoriums collection.
  // Pattern: Ant → Ps1 → Ant → Ps2 → Ant … → Ant

  List<_OraItem> _buildInvitatorium(
    LiturgicalDay day,
    List<Map<String, dynamic>> allInvit,
  ) {
    final ant = (day.field('invitatoriumAnt') ?? '').trim();
    final items = <_OraItem>[];

    items.add(_OraItem.sectionTitle('ЗАКЛІК'));
    _addInvitatoriumContent(items, day, allInvit, ant);

    return items;
  }

  void _addInvitatoriumContent(
    List<_OraItem> items,
    LiturgicalDay day,
    List<Map<String, dynamic>> allInvit,
    String ant,
  ) {
    items.add(_OraItem.html('$_kInvitRubric$_kInvitIntro'));

    if (ant.isEmpty) return;

    if (allInvit.isEmpty) {
      items.add(
        _OraItem.html(
          '<p><em>Псалом запрашэння не знойдзены. Выканайце сінхранізацыю ў Наладах.</em></p>',
        ),
      );
      return;
    }

    // Variant selector when multiple invitatoriums exist
    if (allInvit.length > 1) {
      final names = allInvit.map((m) => _invitName(m)).toList();
      items.add(
        _OraItem.custom(
          (ctx, _) => _InvitSelector(
            names: names,
            selectedIndex:
                _selectedInvitIndex ??
                _defaultInvitatoriumIndex(allInvit, day.periodType),
            onSelect: (i) => setState(() => _selectedInvitIndex = i),
          ),
        ),
      );
    }

    final defaultIndex = _defaultInvitatoriumIndex(allInvit, day.periodType);
    final selectedIndex = (_selectedInvitIndex ?? defaultIndex).clamp(
      0,
      allInvit.length - 1,
    );
    final invit = allInvit[selectedIndex];

    // Collect psalm parts, stop on first empty
    for (var i = 1; i <= 6; i++) {
      final ps = (invit['invitatoriumPs$i']?.toString() ?? '').trim();
      if (ps.isEmpty) break;
      items.add(_OraItem.antiphon(ant));
      items.add(_OraItem.html(ps));
    }
    items.add(_OraItem.antiphon(ant));
  }

  String _invitName(Map<String, dynamic> m) {
    final t = (m['title'] as String? ?? m['name'] as String? ?? '').trim();
    return t.isNotEmpty ? t : 'Псальм запрашэння';
  }

  int _defaultInvitatoriumIndex(
    List<Map<String, dynamic>> items,
    String? periodType,
  ) {
    if (periodType != 'christmas') return 0;
    final pattern = RegExp(r'Псальм\s+95\s*\(94\)', caseSensitive: false);
    final index = items.indexWhere((item) {
      final text = [
        item['title'],
        item['name'],
        item['invitatoriumPs1'],
      ].whereType<Object>().join(' ').replaceAll(RegExp(r'<[^>]*>'), ' ');
      return pattern.hasMatch(text);
    });
    return index < 0 ? 0 : index;
  }

  // ─── Lectionis (Гадзіна чытанняў) ───────────────────────────────────────────

  List<_OraItem> _buildLectionis(LiturgicalDay day, {bool skipEnding = false}) {
    final items = <_OraItem>[];
    items.add(_OraItem.sectionTitle('ГАДЗІНА ЧЫТАННЯЎ'));
    _addIntro(items);
    _addHymn(items, day, 'officeOfReadingsHymn');
    _addPsalmBlock(items, day, 'officeOfReadingsAnt', 'officeOfReadingsPs', 3);
    _addField(items, day, 'officeOfReadingsVers', '');
    _addField(items, day, 'officeOfReadingsR1', 'Першае чытанне');
    _addField(items, day, 'officeOfReadingsR2', 'Другое чытанне');
    if (shouldShowTeDeum(day)) {
      items.add(_OraItem.blockHeader('ГІМН'));
      items.add(_OraItem.html(_kTeDeum));
    }
    _addField(items, day, 'officeOfReadingsPr', 'Малітва');
    if (!skipEnding) items.add(_OraItem.html(_kEndOfHour));
    return items;
  }

  // ─── Laudes (Ютрань) ─────────────────────────────────────────────────────────

  List<_OraItem> _buildLaudes(LiturgicalDay day) {
    final items = <_OraItem>[];
    items.add(_OraItem.sectionTitle('ЮТРАНЬ'));
    _addIntro(items);
    _addHymn(items, day, 'laudesHymn');
    _addPsalmBlock(items, day, 'laudesAnt', 'laudesPs', 3);
    _addField(items, day, 'laudesR', '');

    final antBen = (day.field('laudesAntBen') ?? '').trim();
    if (antBen.isNotEmpty) {
      items.add(_OraItem.blockHeader('ПЕСНЯ З ЕВАНГЕЛЛЯ'));
      items.add(
        _OraItem.html(
          '<p><em>Песня Захарыі (Лк 1, 68–79) — Месія і Яго папярэднік</em></p>',
        ),
      );
      items.add(_OraItem.antiphon(antBen));
      items.add(_OraItem.html(_kBenedictus));
      items.add(_OraItem.antiphon(antBen));
    }

    _addField(items, day, 'laudesInter', 'Просьбы');
    items.add(_OraItem.plain(_kPaterNoster));
    _addField(items, day, 'laudesPr', 'Малітва');
    items.add(_OraItem.html(_kEndOfHour));
    return items;
  }

  // ─── Sext hours (Terz / Sext / Non) ─────────────────────────────────────────
  // Per-field fallback: sext2/* and sext3/* fall back to sext1/* when empty

  String _sextF(LiturgicalDay day, String suffix, int num) {
    return daytimeHourField(day, num, suffix);
  }

  List<_OraItem> _buildSextHour(LiturgicalDay day, {required int num}) {
    final title = switch (num) {
      1 => 'МАЛІТВА ПЕРАД ПОЎДНЕМ',
      2 => 'МАЛІТВА АПОЎДНІ',
      _ => 'МАЛІТВА ПАСЛЯ ПОЎДНЯ',
    };

    final items = <_OraItem>[];
    items.add(_OraItem.sectionTitle(title));
    _addIntro(items);

    final hymn = _sextF(day, 'Hymn', num);
    if (hymn.isNotEmpty) {
      items.add(_OraItem.blockHeader('ГІМН'));
      items.add(_OraItem.html(hymn));
    }

    _addPsalmBlockResolved(items, [
      (_sextF(day, 'Ant1', num), _sextF(day, 'Ps1', num)),
      (_sextF(day, 'Ant2', num), _sextF(day, 'Ps2', num)),
      (_sextF(day, 'Ant3', num), _sextF(day, 'Ps3', num)),
    ]);

    final r = daytimeHourField(day, num, 'R');
    if (r.isNotEmpty) items.add(_OraItem.html(r));

    final pr = daytimeHourField(day, num, 'Pr');
    if (pr.isNotEmpty) items.add(_OraItem.labeled('Малітва', pr));

    items.add(_OraItem.html(_kEndOfHour));
    return items;
  }

  // ─── Vespers (Нешпары) ────────────────────────────────────────────────────────

  List<_OraItem> _buildVespers(LiturgicalDay day) {
    final items = <_OraItem>[];
    items.add(_OraItem.sectionTitle('НЕШПАРЫ'));
    _addIntro(items);
    if (_vespersRubric case final rubric?) {
      items.add(
        _OraItem.custom(
          (context, _) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              rubric,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: liturgicalColorForDay(day),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
    _addHymn(items, day, 'vesperHymn');
    _addPsalmBlock(items, day, 'vesperAnt', 'vesperPs', 3);
    _addField(items, day, 'vesperR', '');

    final antMag = (day.field('vesperAntMag') ?? '').trim();
    if (antMag.isNotEmpty) {
      items.add(_OraItem.blockHeader('ПЕСНЯ З ЕВАНГЕЛЛЯ'));
      items.add(
        _OraItem.html(
          '<p><em>Песня Марыі (Лк 1, 46–55) — Радасць душы ў Пану</em></p>',
        ),
      );
      items.add(_OraItem.antiphon(antMag));
      items.add(_OraItem.html(_kMagnificat));
      items.add(_OraItem.antiphon(antMag));
    }

    _addField(items, day, 'vesperInter', 'Просьбы');
    items.add(_OraItem.plain(_kPaterNoster));

    // vesperPr fallback to laudesPr
    final pr = (day.field('vesperPr') ?? '').trim();
    final effectivePr = pr.isNotEmpty
        ? pr
        : (day.field('laudesPr') ?? '').trim();
    if (effectivePr.isNotEmpty) {
      items.add(_OraItem.labeled('Малітва', effectivePr));
    }

    items.add(_OraItem.html(_kEndOfHour));
    return items;
  }

  // ─── Completorium (Камплета) ──────────────────────────────────────────────────
  // Uses completoriums collection.

  List<_OraItem> _buildCompline(Map<String, dynamic>? comp) {
    final items = <_OraItem>[];
    items.add(_OraItem.sectionTitle('КАМПЛЕТА'));
    _addIntro(items);

    if (comp == null) {
      items.add(
        _OraItem.html(
          '<p><em>Камплета для гэтага дня не знойдзена. Выканайце сінхранізацыю ў Наладах.</em></p>',
        ),
      );
      return items;
    }

    String cf(String name) {
      final v = comp[name];
      if (v == null) return '';
      return v.toString().trim();
    }

    items.add(
      _OraItem.html(
        '<p><span style="color:red">Пасля гэтага пажадана зрабіць рахунак сумлення.</span></p>',
      ),
    );

    final hymn = cf('compHymn');
    if (hymn.isNotEmpty) {
      items.add(_OraItem.blockHeader('ГІМН'));
      items.add(_OraItem.html(hymn));
    }

    final ant1 = cf('compAnt1');
    final ps1 = cf('compPs1');
    final ant2 = cf('compAnt2');
    final ps2 = cf('compPs2');
    _addPsalmBlockResolved(items, [(ant1, ps1), (ant2, ps2)]);

    final r = cf('compR');
    if (r.isNotEmpty) items.add(_OraItem.html(r));

    final resp = cf('compResp');
    if (resp.isNotEmpty) items.add(_OraItem.html(resp));

    final antS = cf('compAntS');
    if (antS.isNotEmpty) {
      items.add(_OraItem.blockHeader('ПЕСНЯ З ЕВАНГЕЛЛЯ'));
      items.add(
        _OraItem.html(
          '<p><em>Песня Сімяона (Лк 2, 29–32) — Хрыстус — святло народаў і хвала Ізраэля</em></p>',
        ),
      );
      items.add(_OraItem.antiphon(antS));
      items.add(_OraItem.html(_kNunc));
      items.add(_OraItem.antiphon(antS));
    }

    final pr = cf('compPr');
    if (pr.isNotEmpty) items.add(_OraItem.labeled('Малітва', pr));

    items.add(
      _OraItem.html(
        '<p><span style="color:red">Потым, нават тады, калі Камплета чытаецца індывідуальна, прамаўляецца благаслаўленне:</span></p>',
      ),
    );
    items.add(_OraItem.html(_kEndOfComplineBlessing));

    final antM = cf('compAntM');
    if (antM.isNotEmpty) {
      items.add(
        _OraItem.blockHeader(
          'АНТЫФОНЫ НА ЗАКАНЧЭННЕ ДА НАЙСВЯЦЕЙШАЙ ПАННЫ МАРЫІ',
        ),
      );
      items.add(_OraItem.html(antM));
    }

    return items;
  }

  // ─── Morning / Агульная гадзіна ────────────────────────────────────────────────
  // Invitatorium + Lectionis (no ending) + Laudes — no standard intro at top

  List<_OraItem> _buildMorning(
    LiturgicalDay day,
    List<Map<String, dynamic>> allInvit,
  ) {
    final items = <_OraItem>[_OraItem.sectionTitle('АГУЛЬНАЯ ГАДЗІНА')];

    _addInvitatoriumContent(
      items,
      day,
      allInvit,
      (day.field('invitatoriumAnt') ?? '').trim(),
    );

    // The combined morning office follows mybrev/Morning.vue: the hymn is
    // taken from Lauds, then the Office of Readings and Lauds continue without
    // repeating their hour headings or introductory dialogue.
    _addHymn(items, day, 'laudesHymn');
    _addPsalmBlock(items, day, 'officeOfReadingsAnt', 'officeOfReadingsPs', 3);
    _addField(items, day, 'officeOfReadingsVers', '');
    _addField(items, day, 'officeOfReadingsR1', 'Першае чытанне');
    _addField(items, day, 'officeOfReadingsR2', 'Другое чытанне');
    if (shouldShowTeDeum(day)) {
      items.add(_OraItem.blockHeader('ГІМН'));
      items.add(_OraItem.html(_kTeDeum));
    }

    _addPsalmBlock(items, day, 'laudesAnt', 'laudesPs', 3);
    _addField(items, day, 'laudesR', '');
    final antBen = (day.field('laudesAntBen') ?? '').trim();
    if (antBen.isNotEmpty) {
      items.add(_OraItem.blockHeader('ПЕСНЯ З ЕВАНГЕЛЛЯ'));
      items.add(
        _OraItem.html(
          '<p><em>Песня Захарыі (Лк 1, 68–79)<br>Месія і Яго папярэднік</em></p>',
        ),
      );
      items.add(_OraItem.antiphon(antBen));
      items.add(_OraItem.html(_kBenedictus));
      items.add(_OraItem.antiphon(antBen));
    }
    _addField(items, day, 'laudesInter', 'Просьбы');
    items.add(_OraItem.plain(_kPaterNoster));
    _addField(items, day, 'laudesPr', 'Малітва');
    items.add(_OraItem.html(_kEndOfHour));
    return items;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  void _addIntro(List<_OraItem> items) {
    items.add(_OraItem.html(_kStandardIntro));
  }

  void _addHymn(List<_OraItem> items, LiturgicalDay day, String fieldName) {
    final v = (day.field(fieldName) ?? '').trim();
    if (v.isEmpty) return;
    items.add(_OraItem.blockHeader('ГІМН'));
    items.add(_OraItem.html(v));
  }

  void _addField(
    List<_OraItem> items,
    LiturgicalDay day,
    String fieldName,
    String label,
  ) {
    final v = (day.field(fieldName) ?? '').trim();
    if (v.isEmpty) return;
    if (label.isNotEmpty) {
      items.add(_OraItem.labeled(label, v));
    } else {
      items.add(_OraItem.html(v));
    }
  }

  // Reads ant/ps pairs from day and calls _addPsalmBlockResolved
  void _addPsalmBlock(
    List<_OraItem> items,
    LiturgicalDay day,
    String antPrefix,
    String psPrefix,
    int count,
  ) {
    _addPsalmBlockResolved(items, [
      for (var i = 1; i <= count; i++)
        (
          (day.field('$antPrefix$i') ?? '').trim(),
          (day.field('$psPrefix$i') ?? '').trim(),
        ),
    ]);
  }

  // Universal psalmody algorithm (spec §4):
  // Normal: ant1→ps1→ant1, ant2→ps2→ant2, ant3→ps3→ant3
  // Single-ant mode (ant1 + all 3 psalms, ant2/3 empty): ant1→ps1→ps2→ps3→ant1
  void _addPsalmBlockResolved(
    List<_OraItem> items,
    List<(String ant, String ps)> pairs,
  ) {
    final hasSomething = pairs.any((p) => p.$1.isNotEmpty || p.$2.isNotEmpty);
    if (!hasSomething) return;

    items.add(_OraItem.blockHeader('ПСАЛМОДЫЯ'));

    // Single-ant mode: ant1 & all psalms present, ant2/ant3 absent
    final isSingleAnt =
        pairs.length >= 3 &&
        pairs[0].$1.isNotEmpty &&
        pairs[0].$2.isNotEmpty &&
        pairs[1].$2.isNotEmpty &&
        pairs[2].$2.isNotEmpty &&
        pairs[1].$1.isEmpty &&
        pairs[2].$1.isEmpty;

    if (isSingleAnt) {
      items.add(_OraItem.antiphon(pairs[0].$1));
      for (final (_, ps) in pairs) {
        if (ps.isNotEmpty) items.add(_OraItem.html(ps));
      }
      items.add(_OraItem.antiphon(pairs[0].$1));
    } else {
      for (final (ant, ps) in pairs) {
        if (ant.isNotEmpty) items.add(_OraItem.antiphon(ant));
        if (ps.isNotEmpty) items.add(_OraItem.html(ps));
        if (ant.isNotEmpty && ps.isNotEmpty) items.add(_OraItem.antiphon(ant));
      }
    }
  }

  String _oraTitle(String type) => switch (type) {
    'morning' => 'Агульная гадзіна',
    'invitatorium' => 'Заклік',
    'lectionis' => 'Гадзіна чытанняў',
    'laudes' => 'Ютрань',
    'terz' => 'Малітва перад поўднем',
    'sext' => 'Малітва апоўдні',
    'non' => 'Малітва пасля поўдня',
    'vespers' => 'Нешпары',
    'completorium' => 'Камплета',
    _ => type,
  };
}

// ─── _OraItem ─────────────────────────────────────────────────────────────────

enum _OraItemType {
  sectionTitle,
  blockHeader,
  antiphon,
  labeled,
  html,
  plain,
  custom,
}

class _OraItem {
  final _OraItemType type;
  final String? label;
  final String content;
  final Widget Function(BuildContext, TextStyle)? _customWidget;

  const _OraItem._(
    this.type,
    this.content, {
    this.label,
    Widget Function(BuildContext, TextStyle)? customWidget,
  }) : _customWidget = customWidget;

  factory _OraItem.sectionTitle(String title) =>
      _OraItem._(_OraItemType.sectionTitle, title);

  factory _OraItem.blockHeader(String title) =>
      _OraItem._(_OraItemType.blockHeader, title);

  factory _OraItem.antiphon(String text) =>
      _OraItem._(_OraItemType.antiphon, text);

  factory _OraItem.labeled(String label, String content) =>
      _OraItem._(_OraItemType.labeled, content, label: label);

  factory _OraItem.html(String html) => _OraItem._(_OraItemType.html, html);

  factory _OraItem.plain(String text, {String? label}) =>
      _OraItem._(_OraItemType.plain, text, label: label);

  factory _OraItem.custom(Widget Function(BuildContext, TextStyle) builder) =>
      _OraItem._(_OraItemType.custom, '', customWidget: builder);

  Widget build(BuildContext context, TextStyle textStyle) {
    final cs = Theme.of(context).colorScheme;

    switch (type) {
      case _OraItemType.sectionTitle:
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: Text(
            content,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.primary,
              letterSpacing: 0.5,
            ),
          ),
        );

      case _OraItemType.blockHeader:
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            content.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
        );

      case _OraItemType.antiphon:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.22),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            border: Border(
              left: BorderSide(
                color: cs.primary.withValues(alpha: 0.5),
                width: 3,
              ),
            ),
          ),
          child: _HtmlOrText(
            content: content,
            textStyle: textStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        );

      case _OraItemType.labeled:
        return _LabeledSection(
          label: label!,
          content: content,
          textStyle: textStyle,
        );

      case _OraItemType.html:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _HtmlOrText(content: content, textStyle: textStyle),
        );

      case _OraItemType.plain:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  label!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(content, style: textStyle),
            const SizedBox(height: 12),
          ],
        );

      case _OraItemType.custom:
        return _customWidget!(context, textStyle);
    }
  }
}

// ─── Section widgets ──────────────────────────────────────────────────────────

class _LabeledSection extends StatelessWidget {
  final String label;
  final String content;
  final TextStyle textStyle;

  const _LabeledSection({
    required this.label,
    required this.content,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: cs.onSurface.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 6),
        _HtmlOrText(content: content, textStyle: textStyle),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _HtmlOrText extends StatelessWidget {
  final String content;
  final TextStyle textStyle;

  const _HtmlOrText({required this.content, required this.textStyle});

  @override
  Widget build(BuildContext context) {
    if (content.contains('<') && content.contains('>')) {
      try {
        final textColor =
            textStyle.color ?? Theme.of(context).colorScheme.onSurface;
        return Html(
          data: content,
          style: {
            'body': Style(
              fontSize: FontSize(textStyle.fontSize ?? 16),
              fontFamily: textStyle.fontFamily,
              fontWeight: textStyle.fontWeight,
              color: textColor,
              lineHeight: LineHeight(1.75),
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              textAlign: TextAlign.left,
            ),
            'p': Style(color: textColor, margin: Margins.only(bottom: 8)),
          },
        );
      } catch (e) {
        debugPrint('[OraScreen] Html parse failed: $e');
        return SelectableText(
          content.replaceAll(RegExp(r'<[^>]+>'), ' ').trim(),
          style: textStyle,
        );
      }
    }
    return SelectableText(content, style: textStyle);
  }
}

// ─── Invitatorium variant selector ────────────────────────────────────────────

class _DayHeading extends StatelessWidget {
  final LiturgicalDay day;
  final DateTime date;
  final TextStyle textStyle;

  const _DayHeading({
    required this.day,
    required this.date,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final color = liturgicalColorForDay(day);
    final cs = Theme.of(context).colorScheme;
    final title = liturgicalDayDisplayTitle(day, date)
        .replaceAll(RegExp(r'\\?<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
    final periodLabel = liturgicalDayPeriodLabel(day);
    final psalterLabel = liturgicalDayPsalterLabel(day, date);
    final rankLabel = liturgicalDayRankLabel(day);
    final dateText = '${DateFormat('d MMMM y', 'be').format(date)} г.';
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GlassSurface(
        style: GlassStyle.card,
        seasonColor: color,
        accentBar: color,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                periodLabel,
                if (psalterLabel.isNotEmpty) psalterLabel,
              ].join(' · '),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (title.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                title.replaceAll(RegExp(r'<[^>]+>'), ' ').trim(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: cs.onSurface,
                  fontFamily: textStyle.fontFamily,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (rankLabel.isNotEmpty)
                  Text(
                    rankLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if ((day.feastComment ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                day.feastComment!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InvitSelector extends StatelessWidget {
  final List<String> names;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _InvitSelector({
    required this.names,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ВАРЫЯНТ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < names.length; i++)
                ChoiceChip(
                  label: Text(names[i]),
                  selected: selectedIndex == i,
                  onSelected: (_) => onSelect(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
