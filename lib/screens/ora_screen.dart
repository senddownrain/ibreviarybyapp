import 'package:mybrev_flutter/utils/picked_feast_readings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/constants/hora_items.dart';
import 'package:mybrev_flutter/models/day.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/providers/diocese_provider.dart';
import 'package:mybrev_flutter/utils/reading_choice.dart';
import 'package:mybrev_flutter/providers/calendar_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/data_log.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/services/liturgical_content_service.dart';
import 'package:mybrev_flutter/content/content_bundle.dart';
import 'package:mybrev_flutter/content/content_store.dart';
import 'package:mybrev_flutter/utils/liturgical_day_resolution.dart';
import 'package:mybrev_flutter/utils/liturgical_office.dart';
import 'package:mybrev_flutter/utils/liturgical_vespers.dart';
import 'package:mybrev_flutter/utils/liturgical_theme.dart';
import 'package:mybrev_flutter/utils/liturgical_titles.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';
import 'package:mybrev_flutter/widgets/alternative_text.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';
import 'package:mybrev_flutter/widgets/data_loading_notice.dart';
import 'package:mybrev_flutter/widgets/reader/reader_navigation.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/psalm_choir_html.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/utils/office_collect_conclusion.dart';
import 'package:mybrev_flutter/utils/liturgical_blocks.dart';
import 'package:mybrev_flutter/utils/psalm_opening.dart';
import 'package:mybrev_flutter/utils/liturgical_alternatives.dart';
import 'package:mybrev_flutter/utils/pastors_hymn.dart';
import 'package:mybrev_flutter/utils/hours_liturgical_options.dart';
import 'package:mybrev_flutter/utils/triduum_compline.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart'
    show analyticsFeature;

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
    '<p class="liturgical-rubric"><span style="color:red"><em>Заклік з’яўляецца пачаткам штодзённай '
    'літургічнай малітвы. Ён папярэднічае Гадзіне чытанняў або Ютрані, '
    'у залежнасці ад таго, якая з гэтых літургічных гадзінаў распачынае '
    'малітву дня.</em></span></p>';

const _kEndOfSext =
    '<p><span style="color:red">К.</span> Благаславім Пана.</p>'
    '<p><span style="color:red">Н.</span> Дзякуем Пану Богу.</p>';

const _kEndOfVesper =
    '<p class="liturgical-rubric"><span style="color:red"><em>Потым, калі прысутнічае святар або дыякан, '
    'ён рассылае народ, кажучы:</em></span></p>'
    '<p><span style="color:red">С.</span> Пан з вамі.<br>'
    '<span style="color:red">Н.</span> І з духам тваім.<br>'
    '<span style="color:red">С.</span> Няхай благаславіць вас Бог усемагутны, '
    'Айцец і Сын, і Дух Святы.<br>'
    '<span style="color:red">Н.</span> Амэн.</p>'
    '<p class="liturgical-rubric"><span style="color:red"><em>Калі адбываецца рассыланне народу, '
    'дадаецца заклік:</em></span></p>'
    '<p><span style="color:red">С.</span> Ідзіце ў супакоі Хрыста.<br>'
    '<span style="color:red">Н.</span> Дзякуем Пану Богу.</p>'
    '<p class="liturgical-rubric"><span style="color:red"><em>Калі святар або дыякан адсутнічаюць ці '
    'калі Гадзіна чытаецца індывідуальна, то яна завяршаецца наступным '
    'чынам:</em></span></p>'
    '<p><span style="color:red">К.</span> Няхай Пан благаславіць нас, абароніць '
    'ад усялякага зла і давядзе да жыцця вечнага.<br>'
    '<span style="color:red">Н.</span> Амэн.</p>';

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

  /// Diocese context of the route (null: the primary of Settings).
  final String? diocese;
  const OraScreen({
    super.key,
    required this.dayId,
    required this.oraType,
    required this.date,
    this.diocese,
  });

  @override
  ConsumerState<OraScreen> createState() => _OraScreenState();
}

class _OraScreenState extends ConsumerState<OraScreen> {
  final _psalmodyController = ValueNotifier<int?>(null);
  final _hourTitleAnchor = GlobalKey();
  int? _selectedInvitIndex;
  bool _firstVespersCompline = false;
  String? _vespersTitle;
  late final Future<LiturgicalDay?> _dayFuture;
  late final ScrollController _scrollController;
  ReaderChromeMode _chromeMode = ReaderChromeMode.compact;
  final Map<String, ValueNotifier<int>> _alternativeControllers = {};

  ValueNotifier<int> _alternativeController(String key) =>
      _alternativeControllers.putIfAbsent(key, () => ValueNotifier<int>(0));

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _dayFuture = _loadDay();
  }

  @override
  void dispose() {
    _psalmodyController.dispose();
    _scrollController.dispose();
    for (final controller in _alternativeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The hour is resolved from the content on the device in the first
  /// frame. Only at launch, while the content is still being decoded, the
  /// screen waits for it (a fraction of a second).
  Future<LiturgicalDay?> _loadDay() {
    final local = _resolveLocal();
    if (local != null || HiveService.isCacheReady) {
      DataLog.cacheHit(() => 'hour ${widget.oraType} ${widget.dayId}');
      return SynchronousFuture(local);
    }
    return ContentStore.instance
        .ensureLoaded(kLiturgicalCollections)
        .then((_) => _resolveLocal());
  }

  LiturgicalDay? _resolveLocal() {
    if (!HiveService.isCacheReady) return null;
    final calendar = ref.read(calendarServiceProvider);
    final content = LiturgicalContentService();
    final diocese =
        widget.diocese ?? ref.read(dioceseSelectionProvider).primary;
    final selected = content.resolveDayLocal(
      widget.date,
      widget.dayId,
      calendar.getYearOptionsCached(widget.date.year),
      calendar.getYearOptionsCached(widget.date.year + 1),
      calendar.getDynamicDatesCached(widget.date.year),
      diocese: diocese,
      forCompline: widget.oraType == 'completorium',
    );
    if (selected == null || widget.oraType != 'vespers') return selected;
    if (usesOwnVespers(selected)) return selected;
    // The Ordo, not non-empty `vesper1*`, decides which Office owns tonight.
    final today = content.contentForDate(widget.date, diocese: diocese);
    final tomorrow = DateUtils.addDaysToDate(widget.date, 1);
    return _vespersFrom(
      selected,
      today,
      content.contentForDate(tomorrow, diocese: diocese),
    );
  }

  /// Resolves tonight's Office from the Ordo precedence and the on-device
  /// text sources. I Vespers of an ordinary Sunday borrow Saturday's psalter,
  /// never the Sunday document's II Vespers.
  LiturgicalDay _vespersFrom(
    LiturgicalDay selected,
    LiturgicalDayContent today,
    LiturgicalDayContent tomorrow,
  ) {
    final evening = resolveEveningOffice(
      date: widget.date,
      selected: selected,
      today: today,
      tomorrow: tomorrow,
    );
    _vespersTitle = evening.isFirst
        ? vespersHourTitle('first')
        : evening.isSecond
        ? vespersHourTitle('second')
        : null;
    return evening.day;
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
    appBar: AdaptiveAppBar.text(
      _oraTitle(widget.oraType),
      showOverflow: true,
      showTextScale: true,
      showPsalmody: true,
    ),
    body: Stack(
      children: [
        AmbientWash(seasonColor: ref.watch(liturgicalSeasonColorProvider)),
        ListView(
          padding: EdgeInsets.fromLTRB(
            0,
            MediaQuery.paddingOf(context).top + kFloatingAppBarContentInset,
            0,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          // A still outline of a text page: nothing moves next to the
          // place where the prayer is about to appear.
          children: const [
            DataLoadingNotice(
              label: 'Адкрываем тэкст гадзіны',
              shape: LoadingShape.text,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildForDay(BuildContext context, LiturgicalDay day) {
    final seasonColor = liturgicalColorForDay(day);

    // Invitatoriums — all variants for selection
    final allInvit = HiveService.invitatoriumsBox.values
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();

    // Completorium — keyed by {periodType}-d{dayOfWeek}
    final compId = completoriumRecordIdForDay(
      day,
      firstVespers: _firstVespersCompline,
    );
    final compRaw = HiveService.completoriumsBox.get(compId);
    final comp = compRaw != null
        ? Map<String, dynamic>.from(compRaw as Map)
        : null;

    final settings = ref.watch(settingsProvider);
    return PsalmodyScope(
      controller: _psalmodyController,
      mode: settings.psalmodyMode,
      child: ReadingScaffold(
        builder: (context, textStyle) => ReaderScaffold(
          seasonColor: seasonColor,
          chromeMode: _chromeMode,
          onChromeModeChanged: (mode) => setState(() => _chromeMode = mode),
          scrollController: _scrollController,
          scrollKey: PageStorageKey(
            'ora-${widget.date.toIso8601String()}-${widget.dayId}-${widget.oraType}',
          ),
          semanticLabel: 'Тэкст Ora',
          showScrollToTop: true,
          hourTitle: _oraTitle(widget.oraType),
          hourTitleAnchor: _hourTitleAnchor,
          onChangeHour: () => _changeHour(day),
          showPsalmody: true,
          contextHeader: _buildReaderContext(context, day),
          content: _buildContent(context, day, allInvit, comp, textStyle),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AdaptiveAppBar.text(
        _oraTitle(widget.oraType),
        showOverflow: true,
        showTextScale: true,
        showPsalmody: true,
      ),
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
              'Для гэтай даты тэксты адсутнічаюць',
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
      appBar: AdaptiveAppBar.text(
        _oraTitle(widget.oraType),
        showOverflow: true,
        showTextScale: true,
        showPsalmody: true,
      ),
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

  Widget _buildContent(
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
      'completorium' => _buildCompline(comp, day),
      _ => <_OraItem>[],
    };
    if (hourSections.isEmpty) {
      return const Center(child: Text('Няма зместу'));
    }

    final next = nextAvailableHour(day, widget.oraType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in hourSections) item.build(context, textStyle),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '· · ·',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ReaderTheme.of(context).muted,
              letterSpacing: 6,
            ),
          ),
        ),
        if (next != null) ...[
          const SizedBox(height: 28),
          Center(
            child: Padding(
              // Keep the document action clear of the small side arrow even
              // when a long hour name wraps on a narrow screen.
              padding: const EdgeInsets.symmetric(horizontal: 44),
              child: OutlinedButton.icon(
                key: const Key('ora-next-hour'),
                onPressed: () => _openHour(next.type),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  'Далей: ${next.label}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReaderContext(BuildContext context, LiturgicalDay day) {
    final theme = Theme.of(context);
    final accent = liturgicalColorForDay(day);
    final dayTitle = liturgicalDayDisplayTitle(day, widget.date)
        .replaceAll(RegExp(r'\\?<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
    final weekday = DateFormat('EEEE', 'be').format(widget.date);
    final celebration = dayTitle.replaceFirst(
      RegExp(',\\s*${RegExp.escape(weekday)}\$', caseSensitive: false),
      '',
    );
    final periodLabel = liturgicalDayPeriodLabel(day);
    final psalterLabel = liturgicalDayPsalterLabel(day, widget.date);
    final placeLabel = liturgicalDayPlaceLabel(day);
    final feastComment = (day.feastComment ?? '').trim();
    final contextSummary = [
      if ((day.feastName ?? '').isNotEmpty && periodLabel.isNotEmpty)
        periodLabel,
      if (psalterLabel.isNotEmpty) psalterLabel,
    ].join(' · ');
    final header = ReaderContextHeader(
      titleAnchorKey: _hourTitleAnchor,
      accentColor: accent,
      eyebrow:
          '${weekday[0].toUpperCase()}${weekday.substring(1)}, ${DateFormat('d MMMM y', 'be').format(widget.date)}',
      subtitle: celebration,
      eyebrowStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      subtitleStyle: ReaderTheme.of(context).displayTitle(24),
      title: _oraTitle(widget.oraType),
      metadata: contextSummary,
      details: placeLabel.isEmpty
          ? null
          : Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    placeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
      onTitleTap: () => _changeHour(day),
      actions: [
        TextButton.icon(
          key: const Key('ora-readings-action'),
          onPressed: () async {
            final choice = ref.read(
              hoursLiturgicalOverridesProvider,
            )[liturgicalDateKey(widget.date)];
            final selection = ref.read(hoursLiturgicalSelectionProvider);
            if (choice?.fromSearch == true &&
                selection.diocese != null &&
                selection.selected?.optionId != null) {
              if (!await preparePickedFeastReadings(
                context,
                ref,
                date: widget.date,
                dayId: widget.dayId,
                diocese: selection.diocese!,
                optionId: selection.selected!.optionId,
              )) {
                return;
              }
              if (!context.mounted) return;
            }
            AppNavigationScope.of(context).openReadingsFromOra(
              context,
              date: widget.date,
              dayId: widget.dayId,
            );
          },
          icon: const PhosphorIcon(PhosphorIconsRegular.bookOpenText, size: 19),
          label: const Text('Чытанні'),
        ),
      ],
    );
    if (feastComment.isEmpty) return header;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          child: _ExpandableFeastComment(feastComment),
        ),
      ],
    );
  }

  Future<void> _changeHour(LiturgicalDay day) async {
    final selected = await showReaderChoiceSheet<String>(
      context: context,
      title: 'Літургія гадзінаў',
      selectedValue: widget.oraType,
      choices: [
        for (final hora in kHoraItems)
          ReaderChoice(
            value: hora.type,
            label: hora.label,
            subtitle: hora.subtitle,
            icon: hora.icon,
            enabled: isHourAvailable(day, hora),
          ),
      ],
    );
    if (!mounted || selected == null || selected == widget.oraType) return;
    _openHour(selected);
  }

  void _openHour(String type) {
    analyticsFeature('hour_switch');
    final currentQuery = GoRouterState.of(context).uri.queryParameters;
    final route = Uri.parse(
      oraRouteForContext(
        date: widget.date,
        dayId: widget.dayId,
        oraType: type,
        diocese: widget.diocese,
      ),
    );
    // A different hour is a new reader page, replacing the current one. Reusing
    // its page key with replace leaves the branch Navigator unchanged after
    // the root choice sheet closes: Android can retain its canHandlePop=false
    // notification even though the branch still has the day list underneath.
    context.pushReplacement(
      route
          .replace(queryParameters: {...currentQuery, ...route.queryParameters})
          .toString(),
    );
  }

  bool _containsLiturgicalText(String? html, String text) =>
      (parseFragment(html ?? '').text ?? '')
          .replaceAll(RegExp(r'[\s\u00a0]+'), ' ')
          .contains(text);

  static const _complineFormulas = {
    false: 'Пасля II Нешпараў нядзелі',
    true: 'Пасля I Нешпараў нядзелі',
  };

  Widget _complineFormulaButton(BuildContext context) => TextButton.icon(
    key: const Key('compline-formula-picker'),
    icon: const PhosphorIcon(PhosphorIconsRegular.listChecks, size: 19),
    label: Text(_complineFormulas[_firstVespersCompline]!),
    onPressed: () async {
      final selected = await showReaderChoiceSheet<bool>(
        context: context,
        title: 'Фармуляр Камплеты',
        selectedValue: _firstVespersCompline,
        choices: [
          for (final formula in _complineFormulas.entries)
            ReaderChoice(
              value: formula.key,
              label: formula.value,
              icon: Icons.menu_book_rounded,
            ),
        ],
      );
      if (mounted && selected != null) {
        setState(() => _firstVespersCompline = selected);
      }
    },
  );

  // ─── Completorium ID ─────────────────────────────────────────────────────────
  // Format: {periodType}-d{dayOfWeek}, Sunday = d1, Saturday = d7
  // Solemnities/feasts → d1; holyweek → lent

  // ─── Invitatorium ─────────────────────────────────────────────────────────────
  // Ant from days; Ps1–6 from invitatoriums collection.
  // Pattern: Ant → Ps1 → Ant → Ps2 → Ant … → Ant

  List<_OraItem> _buildInvitatorium(
    LiturgicalDay day,
    List<Map<String, dynamic>> allInvit,
  ) {
    final ant = (day.field('invitatoriumAnt') ?? '').trim();
    final items = <_OraItem>[];

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
        _OraItem.html('<p><em>Псалом запрашэння не знойдзены.</em></p>'),
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
    final antController = _alternativeController('invitatorium-antiphon');
    for (var i = 1; i <= 6; i++) {
      final ps = (invit['invitatoriumPs$i']?.toString() ?? '').trim();
      if (ps.isEmpty) break;
      items.add(
        _OraItem.antiphon(ant, controller: antController, showPicker: i == 1),
      );
      items.add(_OraItem.psalm(ps));
    }
    items.add(
      _OraItem.antiphon(ant, controller: antController, showPicker: false),
    );
  }

  String _invitName(Map<String, dynamic> m) {
    final explicit = (m['title'] as String? ?? m['name'] as String? ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (explicit.isNotEmpty && explicit.toLowerCase() != 'псальм запрашэння') {
      return explicit;
    }

    final source = [
      for (var i = 1; i <= 6; i++) m['invitatoriumPs$i'],
    ].whereType<Object>().join(' ');
    final plain = (parseFragment(source).text ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final psalm = RegExp(
      r'Псал(?:ьм|ом)\s+\d+(?:\s*\(\d+\))?',
      caseSensitive: false,
    ).firstMatch(plain);
    if (psalm == null) {
      return explicit.isNotEmpty ? explicit : 'Псальм запрашэння';
    }

    final number = psalm.group(0)!;
    var subtitle = plain.substring(psalm.end).trim();
    subtitle = subtitle.replaceFirst(RegExp(r'^[—–:.,\s]+'), '');
    if (subtitle.isEmpty) return number;
    final sentenceEnd = subtitle.indexOf(RegExp(r'[.!?]'));
    if (sentenceEnd > 12) subtitle = subtitle.substring(0, sentenceEnd + 1);
    if (subtitle.length > 64) subtitle = '${subtitle.substring(0, 61).trim()}…';
    return '$number — $subtitle';
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
    _addIntro(items);
    _addHymn(items, day, 'officeOfReadingsHymn');
    _addPsalmBlock(items, day, 'officeOfReadingsAnt', 'officeOfReadingsPs', 3);
    _addField(items, day, 'officeOfReadingsVers', '');
    _addOfficeReadings(items, day);
    if (shouldShowTeDeum(day)) {
      _addMajorBoundary(items);
      items.add(_OraItem.blockHeader('ГІМН', startsSection: false));
      items.add(_OraItem.html(_kTeDeum, kind: 'hymn'));
    }
    _addDividerBeforeField(items, day, 'officeOfReadingsPr');
    _addField(items, day, 'officeOfReadingsPr', 'Малітва');
    if (!skipEnding) items.add(_OraItem.html(_kEndOfSext));
    return items;
  }

  // ─── Laudes (Ютрань) ─────────────────────────────────────────────────────────

  List<_OraItem> _buildLaudes(LiturgicalDay day) {
    final items = <_OraItem>[];
    _addIntro(items);
    _addHymn(items, day, 'laudesHymn');
    _addPsalmBlock(items, day, 'laudesAnt', 'laudesPs', 3);
    _addDividerBeforeField(items, day, 'laudesR');
    _addField(items, day, 'laudesR', '');

    final antBen = (day.field('laudesAntBen') ?? '').trim();
    if (antBen.isNotEmpty) {
      _addGospelCanticle(
        items,
        antiphon: antBen,
        controllerScope: 'laudes-ant-ben',
        caption:
            '<p><em>Песня Захарыі (Лк 1, 68–79) — Месія і Яго папярэднік</em></p>',
        psalm: _kBenedictus,
      );
    }

    _addDividerBeforeField(items, day, 'laudesInter');
    _addField(items, day, 'laudesInter', 'Просьбы');
    _addPaterAndPrayer(items, (day.field('laudesPr') ?? '').trim());
    items.add(_OraItem.html(_kEndOfVesper));
    return items;
  }

  // ─── Sext hours (Terz / Sext / Non) ─────────────────────────────────────────
  // Per-field fallback: sext2/* and sext3/* fall back to sext1/* when empty

  String _sextF(LiturgicalDay day, String suffix, int num) {
    return daytimeHourField(day, num, suffix);
  }

  List<_OraItem> _buildSextHour(LiturgicalDay day, {required int num}) {
    final items = <_OraItem>[];
    _addIntro(items);

    final hymn = _sextF(day, 'Hymn', num);
    if (hymn.isNotEmpty) {
      items.add(_OraItem.blockHeader('ГІМН'));
      items.add(_OraItem.html(hymn, kind: 'hymn'));
    }

    _addPsalmBlockResolved(items, [
      (_sextF(day, 'Ant1', num), _sextF(day, 'Ps1', num)),
      (_sextF(day, 'Ant2', num), _sextF(day, 'Ps2', num)),
      (_sextF(day, 'Ant3', num), _sextF(day, 'Ps3', num)),
    ], controllerScope: 'sext$num');

    final r = daytimeHourField(day, num, 'R');
    if (r.isNotEmpty) {
      _addMajorBoundary(items);
      items.add(_OraItem.html(r, kind: 'reading'));
    }

    final pr = daytimeHourField(day, num, 'Pr');
    if (pr.isNotEmpty) {
      _addMajorBoundary(items);
      items.add(_OraItem.labeled('Малітва', pr, kind: 'prayer'));
    }

    items.add(_OraItem.html(_kEndOfSext));
    return items;
  }

  // ─── Vespers (Нешпары) ────────────────────────────────────────────────────────

  List<_OraItem> _buildVespers(LiturgicalDay day) {
    final items = <_OraItem>[];
    final triduumNotice = triduumVespersNotice(day);
    if (triduumNotice.isNotEmpty &&
        !_containsLiturgicalText(day.field('vesperR'), triduumNotice)) {
      items.add(
        _OraItem.html('<p><span style="color:red">$triduumNotice</span></p>'),
      );
    }
    _addIntro(items);
    final missingFirst = day.data['_missingFirstVespersFields'];
    if (missingFirst is List && missingFirst.isNotEmpty) {
      items.add(
        _OraItem.custom(
          (context, _) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Не ўсе тэксты I Нешпараў знойдзены ў псалтыры. '
              'Тэксты II Нешпараў не падстаўляюцца.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ),
      );
    }
    _addHymn(items, day, 'vesperHymn');
    _addPsalmBlock(items, day, 'vesperAnt', 'vesperPs', 3);
    _addDividerBeforeField(items, day, 'vesperR');
    _addField(items, day, 'vesperR', '');
    final specialAntiphon = triduumAntiphon(day);
    if (specialAntiphon.isNotEmpty &&
        !_containsLiturgicalText(
          day.field('vesperR'),
          'Хрыстус стаў дзеля нас паслухмяным',
        )) {
      items.add(_OraItem.html(specialAntiphon, kind: 'responsory'));
    }

    final antMag = (day.field('vesperAntMag') ?? '').trim();
    if (antMag.isNotEmpty) {
      _addGospelCanticle(
        items,
        antiphon: antMag,
        controllerScope: 'vespers-ant-mag',
        caption:
            '<p><em>Песня Марыі (Лк 1, 46–55) — Радасць душы ў Пану</em></p>',
        psalm: _kMagnificat,
      );
    }

    _addDividerBeforeField(items, day, 'vesperInter');
    final intercessionsNotice = goodFridayIntercessionsRubric(day);
    final intercessions = (day.field('vesperInter') ?? '').trim();
    if (intercessionsNotice.isNotEmpty &&
        !_containsLiturgicalText(intercessions, intercessionsNotice)) {
      items.add(_OraItem.blockHeader('ПРОСЬБЫ', startsSection: false));
      items.add(
        _OraItem.html(
          '<p><span style="color:red">$intercessionsNotice</span></p>',
        ),
      );
      if (intercessions.isNotEmpty) {
        items.add(_OraItem.html(intercessions, kind: 'intercession'));
      }
    } else {
      _addField(items, day, 'vesperInter', 'Просьбы');
    }
    // vesperPr fallback to laudesPr
    final pr = (day.field('vesperPr') ?? '').trim();
    final effectivePr = pr.isNotEmpty
        ? pr
        : (day.field('laudesPr') ?? '').trim();
    _addPaterAndPrayer(items, effectivePr);

    items.add(_OraItem.html(_kEndOfVesper));
    return items;
  }

  // ─── Completorium (Камплета) ──────────────────────────────────────────────────
  // Uses completoriums collection.

  List<_OraItem> _buildCompline(Map<String, dynamic>? comp, LiturgicalDay day) {
    final items = <_OraItem>[];
    final notice = triduumComplineNotice(day);
    if (notice.isNotEmpty) {
      items.add(_OraItem.html('<p><span style="color:red">$notice</span></p>'));
    }
    _addIntro(items);

    if (comp == null) {
      items.add(
        _OraItem.html('<p><em>Камплета для гэтага дня не знойдзена.</em></p>'),
      );
      return items;
    }

    if (day.field('_ordoComplineChoice') == 'true') {
      items.add(
        _OraItem.custom((context, _) => _complineFormulaButton(context)),
      );
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
      items.add(_OraItem.html(hymn, kind: 'hymn'));
    }

    final ant1 = cf('compAnt1');
    final ps1 = cf('compPs1');
    final ant2 = cf('compAnt2');
    final ps2 = cf('compPs2');
    _addPsalmBlockResolved(items, [
      (ant1, ps1),
      (ant2, ps2),
    ], controllerScope: 'completorium');

    final r = cf('compR');
    if (r.isNotEmpty) {
      _addMajorBoundary(items);
      items.add(_OraItem.html(r, kind: 'reading'));
    }

    final specialResp = specialComplineResponsory(day);
    final resp = specialResp.isNotEmpty ? specialResp : cf('compResp');
    if (resp.isNotEmpty) items.add(_OraItem.html(resp, kind: 'responsory'));

    final antS = cf('compAntS');
    if (antS.isNotEmpty) {
      final antController = _alternativeController('compline-ant-s');
      _addMajorBoundary(items);
      items.add(
        _OraItem.psalmBlock(
          _kNunc,
          openingAntiphon: antS,
          repeatedAntiphon: antS,
          antiphonController: antController,
          canticleCaption:
              'Песня Сімяона (Лк 2, 29–32) — Хрыстус — святло народаў і хвала Ізраэля',
        ),
      );
    }

    final specialPrayer = specialComplinePrayer(day);
    final pr = specialPrayer.isNotEmpty ? specialPrayer : cf('compPr');
    if (pr.isNotEmpty) {
      _addMajorBoundary(items);
      items.add(_OraItem.labeled('Малітва', pr, kind: 'prayer'));
    }

    _addMajorBoundary(items);
    items.add(
      _OraItem.html(
        '<p><span style="color:red">Потым, нават тады, калі Камплета чытаецца індывідуальна, прамаўляецца благаслаўленне:</span></p>',
      ),
    );
    items.add(_OraItem.html(_kEndOfComplineBlessing));

    final antM = cf('compAntM');
    if (antM.isNotEmpty) {
      _addMajorBoundary(items);
      items.add(
        _OraItem.blockHeader(
          'АНТЫФОНЫ НА ЗАКАНЧЭННЕ ДА НАЙСВЯЦЕЙШАЙ ПАННЫ МАРЫІ',
          startsSection: false,
        ),
      );
      items.add(_OraItem.html(antM, kind: 'marian-antiphon'));
    }

    return items;
  }

  // ─── Morning / Агульная гадзіна ────────────────────────────────────────────────
  // Invitatorium + Lectionis (no ending) + Laudes — no standard intro at top

  List<_OraItem> _buildMorning(
    LiturgicalDay day,
    List<Map<String, dynamic>> allInvit,
  ) {
    final items = <_OraItem>[];

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
    _addOfficeReadings(items, day);
    if (shouldShowTeDeum(day)) {
      _addMajorBoundary(items);
      items.add(_OraItem.blockHeader('ГІМН', startsSection: false));
      items.add(_OraItem.html(_kTeDeum, kind: 'hymn'));
    }

    _addMajorBoundary(items);
    _addPsalmBlock(items, day, 'laudesAnt', 'laudesPs', 3);
    _addDividerBeforeField(items, day, 'laudesR');
    _addField(items, day, 'laudesR', '');
    final antBen = (day.field('laudesAntBen') ?? '').trim();
    if (antBen.isNotEmpty) {
      _addGospelCanticle(
        items,
        antiphon: antBen,
        controllerScope: 'morning-ant-ben',
        caption:
            '<p><em>Песня Захарыі (Лк 1, 68–79)<br>Месія і Яго папярэднік</em></p>',
        psalm: _kBenedictus,
      );
    }
    _addDividerBeforeField(items, day, 'laudesInter');
    _addField(items, day, 'laudesInter', 'Просьбы');
    _addPaterAndPrayer(items, (day.field('laudesPr') ?? '').trim());
    items.add(_OraItem.html(_kEndOfVesper));
    return items;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  void _addIntro(List<_OraItem> items) {
    items.add(_OraItem.html(_kStandardIntro));
  }

  void _addGospelCanticle(
    List<_OraItem> items, {
    required String antiphon,
    required String controllerScope,
    required String caption,
    required String psalm,
  }) {
    final antController = _alternativeController(controllerScope);
    _addMajorBoundary(items);
    items.add(
      _OraItem.psalmBlock(
        psalm,
        openingAntiphon: antiphon,
        repeatedAntiphon: antiphon,
        antiphonController: antController,
        canticleCaption: parseFragment(caption).text?.trim(),
      ),
    );
  }

  void _addHymn(List<_OraItem> items, LiturgicalDay day, String fieldName) {
    final v = (day.field(fieldName) ?? '').trim();
    if (v.isEmpty) return;
    items.add(_OraItem.blockHeader('ГІМН'));
    items.add(
      _OraItem.html(preparePastorsHymn(v, day.feastName), kind: 'hymn'),
    );
  }

  void _addPaterAndPrayer(List<_OraItem> items, String prayer) {
    // The prayer heading owns this transition. Keep the ordinary trailing
    // space on Pater Noster only when the prayer is absent.
    items.add(
      _OraItem.plain(
        _kPaterNoster,
        trailingSpacing: prayer.isEmpty ? LiturgicalSpacing.plainTextAfter : 0,
      ),
    );
    if (prayer.isNotEmpty) {
      _addMajorBoundary(items);
      items.add(
        _OraItem.labeled(
          'Малітва',
          expandOfficeCollectConclusion(prayer),
          kind: 'prayer',
          startsSection: false,
        ),
      );
    }
  }

  void _addOfficeReadings(List<_OraItem> items, LiturgicalDay day) {
    final hasFirst = (day.field('officeOfReadingsR1') ?? '').trim().isNotEmpty;
    final hasSecond = (day.field('officeOfReadingsR2') ?? '').trim().isNotEmpty;
    if (hasFirst || hasSecond) _addMajorBoundary(items);
    _addField(items, day, 'officeOfReadingsR1', 'Першае чытанне');
    _addField(
      items,
      day,
      'officeOfReadingsR2',
      'Другое чытанне',
      startsSection: hasFirst,
    );
  }

  void _addField(
    List<_OraItem> items,
    LiturgicalDay day,
    String fieldName,
    String label, {
    bool startsSection = false,
  }) {
    final v = (day.field(fieldName) ?? '').trim();
    if (v.isEmpty) return;
    if (label.isNotEmpty) {
      final content =
          fieldName == 'officeOfReadingsR1' || fieldName == 'officeOfReadingsR2'
          ? stripLeadingReadingHeading(v, label)
          : v;
      items.add(
        _OraItem.labeled(
          label,
          content,
          kind: _alternativeKind(fieldName),
          startsSection: startsSection,
          choice: _readingChoiceSlot(fieldName),
        ),
      );
    } else {
      items.add(_OraItem.html(v, kind: _alternativeKind(fieldName)));
    }
  }

  /// D-1: the picked reading is remembered per field, day, Office option and diocese.
  ReadingChoiceSlot? _readingChoiceSlot(String fieldName) {
    if (_alternativeKind(fieldName) != 'office-reading') return null;
    return ReadingChoiceSlot(
      field: fieldName,
      context: readingChoiceContext(
        widget.date.toIso8601String().substring(0, 10),
        widget.dayId,
        widget.diocese,
      ),
    );
  }

  String _alternativeKind(String fieldName) {
    if (fieldName.endsWith('Inter')) return 'intercession';
    if (fieldName.endsWith('Pr')) return 'prayer';
    if (fieldName == 'officeOfReadingsR1' ||
        fieldName == 'officeOfReadingsR2') {
      return 'office-reading';
    }
    if (fieldName.contains('R')) return 'reading';
    return 'generic';
  }

  void _addDividerBeforeField(
    List<_OraItem> items,
    LiturgicalDay day,
    String fieldName,
  ) {
    if ((day.field(fieldName) ?? '').trim().isNotEmpty) {
      _addMajorBoundary(items);
    }
  }

  void _addMajorBoundary(List<_OraItem> items) {
    if (items.isNotEmpty && items.last.type != _OraItemType.divider) {
      items.add(_OraItem.divider());
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
    ], controllerScope: antPrefix);
  }

  // Universal psalmody algorithm (spec §4):
  // Normal: ant1→ps1→ant1, ant2→ps2→ant2, ant3→ps3→ant3
  // Single-ant mode (ant1 + all 3 psalms, ant2/3 empty): ant1→ps1→ps2→ps3→ant1
  void _addPsalmBlockResolved(
    List<_OraItem> items,
    List<(String ant, String ps)> pairs, {
    String controllerScope = 'psalmody',
  }) {
    final hasSomething = pairs.any((p) => p.$1.isNotEmpty || p.$2.isNotEmpty);
    if (!hasSomething) return;

    items.add(
      _OraItem.blockHeader(
        'ПСАЛМОДЫЯ',
        startsSection: items.isEmpty || items.last.type != _OraItemType.divider,
      ),
    );

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
      final controller = _alternativeController(
        '${widget.oraType}-$controllerScope-ant-0',
      );
      final structured = pairs.any(
        (pair) => ownsStructuredPsalmPackage(pair.$2),
      );
      final lastPsalmIndex =
          pairs.where((pair) => pair.$2.isNotEmpty).length - 1;
      var psalmIndex = 0;
      for (final (_, ps) in pairs) {
        if (ps.isNotEmpty) {
          if (psalmIndex > 0) items.add(_OraItem.psalmGap());
          items.add(
            _OraItem.psalmBlock(
              ps,
              openingAntiphon: !structured && psalmIndex == 0
                  ? pairs[0].$1
                  : null,
              repeatedAntiphon: !structured && psalmIndex == lastPsalmIndex
                  ? pairs[0].$1
                  : null,
              sourceAntiphon: structured ? null : pairs[0].$1,
              antiphonController: controller,
            ),
          );
          psalmIndex++;
        }
      }
    } else {
      var hasBlock = false;
      for (var index = 0; index < pairs.length; index++) {
        final (ant, ps) = pairs[index];
        if (ant.isEmpty && ps.isEmpty) continue;
        if (hasBlock) items.add(_OraItem.psalmGap());
        hasBlock = true;
        final controller = _alternativeController(
          '${widget.oraType}-$controllerScope-ant-$index',
        );
        final structured = ownsStructuredPsalmPackage(ps);
        if (ps.isNotEmpty) {
          items.add(
            _OraItem.psalmBlock(
              ps,
              openingAntiphon: structured ? null : ant,
              repeatedAntiphon: structured ? null : ant,
              sourceAntiphon: structured ? null : ant,
              antiphonController: controller,
            ),
          );
        } else if (ant.isNotEmpty) {
          items.add(_OraItem.antiphon(ant, controller: controller));
        }
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
    'vespers' => _vespersTitle ?? 'Нешпары',
    'completorium' => 'Камплета',
    _ => type,
  };
}

// ─── _OraItem ─────────────────────────────────────────────────────────────────

enum _OraItemType {
  blockHeader,
  divider,
  psalmGap,
  psalmBlock,
  antiphon,
  labeled,
  html,
  psalm,
  plain,
  custom,
}

class _ExpandableFeastComment extends ConsumerStatefulWidget {
  const _ExpandableFeastComment(this.text);

  final String text;

  @override
  ConsumerState<_ExpandableFeastComment> createState() =>
      _ExpandableFeastCommentState();
}

class _ExpandableFeastCommentState
    extends ConsumerState<_ExpandableFeastComment> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      expanded: _expanded,
      label: _expanded
          ? 'Згарнуць апісанне святкавання'
          : 'Паказаць поўнае апісанне святкавання',
      child: Material(
        key: const Key('ora-feast-comment-toggle'),
        color: cs.surface.withValues(alpha: 0.72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Уступ да літургіі дня',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.topCenter,
                  child: Text(
                    widget.text,
                    key: const Key('ora-feast-comment-text'),
                    textAlign: ref.watch(
                      settingsProvider.select((s) => s.textAlignment),
                    ),
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 16,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _expanded ? 'Згарнуць' : 'Чытаць цалкам',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
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

class _OraItem {
  final _OraItemType type;
  final String? label;
  final String content;
  final String alternativeKind;
  final ValueNotifier<int>? alternativeController;
  final bool showPicker;
  final String? externalAntiphon;
  final String? repeatedAntiphon;
  final String? sourceAntiphon;
  final ValueNotifier<int>? antiphonController;
  final String? canticleCaption;
  final bool startsSection;
  final ReadingChoiceSlot? choice;
  final double trailingSpacing;
  final double? gapHeight;
  final Widget Function(BuildContext, TextStyle)? _customWidget;

  const _OraItem._(
    this.type,
    this.content, {
    this.label,
    this.alternativeKind = 'generic',
    this.alternativeController,
    this.showPicker = true,
    this.externalAntiphon,
    this.repeatedAntiphon,
    this.sourceAntiphon,
    this.antiphonController,
    this.canticleCaption,
    this.startsSection = false,
    this.choice,
    this.trailingSpacing = LiturgicalSpacing.plainTextAfter,
    this.gapHeight,
    Widget Function(BuildContext, TextStyle)? customWidget,
  }) : _customWidget = customWidget;

  factory _OraItem.blockHeader(String title, {bool startsSection = true}) =>
      _OraItem._(_OraItemType.blockHeader, title, startsSection: startsSection);

  factory _OraItem.divider() => const _OraItem._(_OraItemType.divider, '');
  factory _OraItem.psalmGap() => _OraItem._(
    _OraItemType.psalmGap,
    '',
    gapHeight: LiturgicalSpacing.psalmBlockToNext,
  );

  factory _OraItem.psalmBlock(
    String html, {
    String? openingAntiphon,
    String? repeatedAntiphon,
    String? sourceAntiphon,
    ValueNotifier<int>? antiphonController,
    String? canticleCaption,
  }) => _OraItem._(
    _OraItemType.psalmBlock,
    html,
    alternativeKind: 'psalm',
    externalAntiphon: openingAntiphon,
    repeatedAntiphon: repeatedAntiphon,
    sourceAntiphon: sourceAntiphon,
    antiphonController: antiphonController,
    canticleCaption: canticleCaption,
  );

  factory _OraItem.antiphon(
    String text, {
    String kind = 'generic',
    ValueNotifier<int>? controller,
    bool showPicker = true,
  }) => _OraItem._(
    _OraItemType.antiphon,
    text,
    alternativeKind: kind,
    alternativeController: controller,
    showPicker: showPicker,
  );

  factory _OraItem.labeled(
    String label,
    String content, {
    String kind = 'generic',
    bool startsSection = false,
    ReadingChoiceSlot? choice,
  }) => _OraItem._(
    _OraItemType.labeled,
    content,
    label: label,
    alternativeKind: kind,
    startsSection: startsSection,
    choice: choice,
  );

  factory _OraItem.html(String html, {String kind = 'generic'}) =>
      _OraItem._(_OraItemType.html, html, alternativeKind: kind);

  factory _OraItem.psalm(String html, {String? externalAntiphon}) => _OraItem._(
    _OraItemType.psalm,
    html,
    alternativeKind: 'psalm',
    externalAntiphon: externalAntiphon,
  );

  factory _OraItem.plain(
    String text, {
    String? label,
    double trailingSpacing = LiturgicalSpacing.plainTextAfter,
  }) => _OraItem._(
    _OraItemType.plain,
    text,
    label: label,
    trailingSpacing: trailingSpacing,
  );

  factory _OraItem.custom(Widget Function(BuildContext, TextStyle) builder) =>
      _OraItem._(_OraItemType.custom, '', customWidget: builder);

  Widget build(BuildContext context, TextStyle textStyle) {
    final cs = Theme.of(context).colorScheme;

    switch (type) {
      case _OraItemType.divider:
        return const LiturgicalSectionDivider();
      case _OraItemType.psalmGap:
        return SizedBox(height: gapHeight);
      case _OraItemType.psalmBlock:
        return _LiturgicalPsalmBlock(
          source: content,
          textStyle: textStyle,
          openingAntiphon: externalAntiphon,
          repeatedAntiphon: repeatedAntiphon,
          sourceAntiphon: sourceAntiphon,
          antiphonController: antiphonController,
          canticleCaption: canticleCaption,
        );
      case _OraItemType.blockHeader:
        return LiturgicalSectionHeading(
          title: _managedHeading(content),
          bodySize: textStyle.fontSize ?? 16,
          startsSection: startsSection,
        );

      case _OraItemType.antiphon:
        return Padding(
          padding: EdgeInsets.zero,
          child: _HtmlOrText(
            content: content,
            textStyle: textStyle.copyWith(fontWeight: FontWeight.w600),
            alternativeKind: alternativeKind == 'generic'
                ? 'psalm-antiphon'
                : alternativeKind,
            alternativeController: alternativeController,
            showPicker: showPicker,
            pickerLabel: 'Выбар антыфоны',
          ),
        );

      case _OraItemType.labeled:
        return _LabeledSection(
          label: label!,
          content: content,
          textStyle: textStyle,
          alternativeKind: alternativeKind,
          startsSection: startsSection,
          choice: choice,
        );

      case _OraItemType.html:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _HtmlOrText(
            content: content,
            textStyle: textStyle,
            alternativeKind: alternativeKind,
            pickerLabel: _pickerLabel(alternativeKind),
          ),
        );

      case _OraItemType.psalm:
        return Padding(
          padding: EdgeInsets.zero,
          child: _HtmlOrText(
            content: content,
            textStyle: textStyle,
            isPsalm: true,
            externalAntiphon: externalAntiphon,
          ),
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
            _LiturgicalSelectableText(content: content, textStyle: textStyle),
            SizedBox(height: trailingSpacing),
          ],
        );

      case _OraItemType.custom:
        return _customWidget!(context, textStyle);
    }
  }

  static String _pickerLabel(String kind) => switch (kind) {
    'hymn' => 'Выбар варыянта гімна',
    'reading' => 'Выбар чытання',
    'responsory' => 'Выбар рэспансорыя',
    'office-reading' => 'Выбар чытання',
    'prayer' => 'Выбар малітвы',
    'intercession' => 'Выбар просьбаў',
    'psalm' => 'Выбар псальма',
    'marian-antiphon' => 'Выбар антыфоны да Найсвяцейшай Панны Марыі',
    _ => 'Выбар варыянта',
  };
}

String _managedHeading(String value) => switch (value.toUpperCase()) {
  'ГІМН' => 'Гімн',
  'ПСАЛМОДЫЯ' => 'Псалмодыя',
  'ПЕСНЯ З ЕВАНГЕЛЛЯ' => 'Песня з Евангелля',
  'АНТЫФОНЫ НА ЗАКАНЧЭННЕ ДА НАЙСВЯЦЕЙШАЙ ПАННЫ МАРЫІ' =>
    'Антыфоны на заканчэнне да Найсвяцейшай Панны Марыі',
  _ => value,
};

// ─── Section widgets ──────────────────────────────────────────────────────────

class _LabeledSection extends StatelessWidget {
  final String label;
  final String content;
  final TextStyle textStyle;
  final String alternativeKind;
  final bool startsSection;
  final ReadingChoiceSlot? choice;

  const _LabeledSection({
    required this.label,
    required this.content,
    required this.textStyle,
    this.alternativeKind = 'generic',
    this.startsSection = false,
    this.choice,
  });

  @override
  Widget build(BuildContext context) {
    final base = textStyle.fontSize ?? 16;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LiturgicalSectionHeading(
          key: Key('liturgical-$alternativeKind-title'),
          title: label,
          bodySize: base,
          startsSection: startsSection,
        ),
        KeyedSubtree(
          key: Key('liturgical-$alternativeKind-body'),
          child: _HtmlOrText(
            content: content,
            textStyle: textStyle,
            alternativeKind: alternativeKind,
            pickerLabel: _OraItem._pickerLabel(alternativeKind),
            choice: choice,
          ),
        ),
        const SizedBox(height: LiturgicalSpacing.paragraphAfter),
      ],
    );
  }
}

/// The same semantic shell renders external psalms, structured packages and
/// Gospel canticles. Only this widget owns their outer gaps.
class _LiturgicalPsalmBlock extends StatelessWidget {
  const _LiturgicalPsalmBlock({
    required this.source,
    required this.textStyle,
    this.openingAntiphon,
    this.repeatedAntiphon,
    this.sourceAntiphon,
    this.antiphonController,
    this.canticleCaption,
  });

  final String source;
  final TextStyle textStyle;
  final String? openingAntiphon;
  final String? repeatedAntiphon;
  final String? sourceAntiphon;
  final ValueNotifier<int>? antiphonController;
  final String? canticleCaption;

  @override
  Widget build(BuildContext context) => AlternativeText(
    text: source,
    kind: 'psalm',
    label: 'Выбар псальма',
    contentBuilder: (context, selected) {
      final models = parseLiturgicalPsalms(
        selected,
        openingAntiphon: openingAntiphon,
        repeatedAntiphon: repeatedAntiphon,
        sourceAntiphon: sourceAntiphon,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < models.length; i++) ...[
            if (i > 0)
              const SizedBox(height: LiturgicalSpacing.psalmBlockToNext),
            _renderModel(context, models[i]),
          ],
        ],
      );
    },
  );

  Widget _renderModel(BuildContext context, LiturgicalPsalmModel model) {
    final reader = ReaderTheme.of(context);
    final size = textStyle.fontSize ?? 16;
    final styles = {
      ...liturgicalDocumentStyles(reader: reader, body: textStyle),
      '.psalm-strophe': Style(
        margin: Margins.only(bottom: LiturgicalSpacing.paragraphAfter),
      ),
      '.psalm-strophe-even': Style(
        margin: Margins.only(
          left: 16,
          bottom: LiturgicalSpacing.paragraphAfter,
        ),
      ),
      '.semantic-last': Style(margin: Margins.zero),
      '.psalm-strophe-even.semantic-last': Style(
        margin: Margins.only(left: 16),
      ),
    };
    final metadata = <PsalmMetadataLine>[
      if (canticleCaption != null) ...[
        const PsalmMetadataLine('ПЕСНЯ З ЕВАНГЕЛЛЯ', PsalmMetadataRole.service),
        PsalmMetadataLine(canticleCaption!, PsalmMetadataRole.subtitle),
      ],
      ...model.metadata,
    ];
    Widget antiphon(String html, {required bool showPicker}) => _HtmlOrText(
      content: html,
      textStyle: textStyle.copyWith(fontWeight: FontWeight.w600),
      alternativeKind: canticleCaption == null
          ? 'psalm-antiphon'
          : 'gospel-antiphon',
      alternativeController: antiphonController,
      showPicker: showPicker,
      pickerLabel: 'Выбар антыфоны',
    );
    return Column(
      key: const Key('liturgical-psalm-block'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model.leadingHtml.isNotEmpty)
          _HtmlOrText(content: model.leadingHtml, textStyle: textStyle),
        if (model.openingAntiphon case final opening?) ...[
          KeyedSubtree(
            key: const Key('liturgical-psalm-opening'),
            child: antiphon(opening, showPicker: true),
          ),
          const SizedBox(height: LiturgicalSpacing.antiphonToPsalm),
        ],
        for (var i = 0; i < metadata.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          KeyedSubtree(
            key: Key('liturgical-psalm-metadata-$i'),
            child: _metadata(context, metadata[i], size),
          ),
        ],
        if (metadata.isNotEmpty)
          const SizedBox(height: LiturgicalSpacing.metadataToBody),
        if (model.bodyHtml.trim().isNotEmpty)
          KeyedSubtree(
            key: const Key('liturgical-psalm-body'),
            child: _psalmBody(model, styles, reader),
          ),
        if (model.repeatedAntiphon case final repeated?) ...[
          const SizedBox(height: LiturgicalSpacing.antiphonToPsalm),
          KeyedSubtree(
            key: const Key('liturgical-psalm-repeat'),
            child: antiphon(repeated, showPicker: false),
          ),
        ],
        if (model.trailingHtml.isNotEmpty)
          _HtmlOrText(content: model.trailingHtml, textStyle: textStyle),
      ],
    );
  }

  Widget _psalmBody(
    LiturgicalPsalmModel model,
    Map<String, Style> styles,
    ReaderTheme reader,
  ) {
    Widget render(int selectedAntiphon) {
      var html = model.bodyHtml;
      if (model.openingAntiphon case final opening?) {
        final choices = getLiturgicalAlternatives(
          opening,
          kind: canticleCaption == null ? 'psalm-antiphon' : 'gospel-antiphon',
        );
        if (selectedAntiphon >= 0 && selectedAntiphon < choices.length) {
          html = omitEchoedPsalmOpening(html, choices[selectedAntiphon].html);
        }
      }
      return PsalmChoirHtml(
        html: html,
        style: styles,
        textColor: textStyle.color ?? reader.ink,
        rubricColor: reader.rubric,
      );
    }

    final controller = antiphonController;
    return controller == null
        ? render(0)
        : ValueListenableBuilder<int>(
            valueListenable: controller,
            builder: (context, selected, child) => render(selected),
          );
  }

  Widget _metadata(BuildContext context, PsalmMetadataLine line, double size) {
    final reader = ReaderTheme.of(context);
    final style = switch (line.role) {
      PsalmMetadataRole.service => reader.serviceHeading(size),
      PsalmMetadataRole.muted => reader.metadata(size),
      PsalmMetadataRole.subtitle => reader.psalmSubtitle(size),
    };
    return Html(
      data: '<p>${line.html}</p>',
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          textAlign: TextAlign.center,
        ),
        'p': Style(
          margin: Margins.zero,
          textAlign: TextAlign.center,
          fontSize: FontSize(style.fontSize!),
          lineHeight: LineHeight(style.height!),
          fontFamily: style.fontFamily,
          color: style.color,
          fontStyle: style.fontStyle,
          fontWeight: style.fontWeight,
        ),
        '.liturgical-rubric-inline': Style(color: reader.rubric),
      },
    );
  }
}

class _HtmlOrText extends ConsumerWidget {
  final String content;
  final TextStyle textStyle;
  final bool isPsalm;
  final String alternativeKind;
  final ValueNotifier<int>? alternativeController;
  final bool showPicker;
  final String pickerLabel;
  final String? externalAntiphon;
  final ReadingChoiceSlot? choice;

  const _HtmlOrText({
    required this.content,
    required this.textStyle,
    this.isPsalm = false,
    this.alternativeKind = 'generic',
    this.alternativeController,
    this.showPicker = true,
    this.pickerLabel = 'Выбар варыянта',
    this.externalAntiphon,
    this.choice,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textAlignment = ref.watch(
      settingsProvider.select((s) => s.textAlignment),
    );
    final alignable = const {
      'reading',
      'office-reading',
      'prayer',
    }.contains(alternativeKind);
    if (content.contains('<') && content.contains('>')) {
      return AlternativeText(
        text: content,
        label: pickerLabel,
        kind: alternativeKind,
        controller: alternativeController,
        showPicker: showPicker,
        choice: choice,
        contentBuilder: (context, selectedHtml) {
          final displayedHtml = alternativeKind == 'intercession'
              ? formatIntercessions(selectedHtml)
              : selectedHtml;
          return _renderHtml(context, displayedHtml, textAlignment);
        },
      );
    }
    if (alternativeKind == 'reading' || alternativeKind == 'office-reading') {
      return _renderHtml(context, content, textAlignment);
    }
    final plain = _LiturgicalSelectableText(
      content: content,
      textStyle: textStyle,
      textAlign: alignable ? textAlignment : TextAlign.left,
    );
    return plain;
  }

  Widget _renderHtml(
    BuildContext context,
    String html,
    TextAlign textAlignment,
  ) {
    final textColor =
        textStyle.color ?? Theme.of(context).colorScheme.onSurface;
    final reader = ReaderTheme.of(context);
    final paragraphSpacing = alternativeKind == 'hymn'
        ? LiturgicalSpacing.hymnStropheAfter
        : alternativeKind == 'psalm-antiphon' ||
              alternativeKind == 'gospel-antiphon'
        ? 0.0
        : LiturgicalSpacing.paragraphAfter;
    final styles = <String, Style>{
      ...liturgicalDocumentStyles(
        reader: reader,
        body: alternativeKind == 'hymn'
            ? textStyle.copyWith(height: ReaderTheme.hymnHeight)
            : textStyle,
        paragraphAfter: paragraphSpacing,
      ),
      '.psalm-strophe': Style(margin: Margins.only(bottom: 8)),
      '.psalm-strophe-even': Style(margin: Margins.only(left: 16, bottom: 8)),
      '.ora-ant': Style(
        color: reader.ink,
        fontWeight: FontWeight.w600,
        margin: Margins.zero,
      ),
    };
    // Only Scripture/Office readings and the final prayer are prose.
    // In particular, responsory turns, headings and rubrics stay left aligned.
    if (const {
      'reading',
      'office-reading',
      'prayer',
    }.contains(alternativeKind)) {
      styles['body']!.textAlign = textAlignment;
      styles['p']!.textAlign = textAlignment;
      for (final selector in [
        '.liturgical-heading',
        '.liturgical-service-heading',
        '.liturgical-reference',
        '.liturgical-subheading',
        '.liturgical-reading-reference',
        '.office-reading-pericope-title',
        '.liturgical-rubric',
        '.responsory-turn',
      ]) {
        styles[selector] = (styles[selector] ?? Style())
          ..textAlign = TextAlign.left;
      }
    }
    if (isPsalm) {
      return PsalmChoirHtml(
        html: formatPsalmHtml(
          stripEmbeddedAntiphon(html, externalAntiphon: externalAntiphon),
        ),
        style: styles,
        textColor: textColor,
        rubricColor: reader.rubric,
      );
    }
    final officeHtml =
        alternativeKind == 'reading' ||
            alternativeKind == 'office-reading' ||
            alternativeKind == 'responsory'
        ? normalizeOfficeHtml(
            html,
            officeReading: alternativeKind == 'office-reading',
          )
        : html;

    final isAntiphon =
        alternativeKind == 'psalm-antiphon' ||
        alternativeKind == 'gospel-antiphon';
    final semanticBody = isAntiphon
        ? normalizeAntiphonBody(officeHtml)
        : const {'hymn', 'prayer', 'intercession'}.contains(alternativeKind)
        ? normalizeSemanticBody(officeHtml)
        : officeHtml;
    if (alternativeKind == 'reading' ||
        alternativeKind == 'office-reading' ||
        alternativeKind == 'responsory') {
      return _renderOfficeHtml(semanticBody, styles);
    }
    return Html(data: formatLiturgicalHtml(semanticBody), style: styles);
  }

  Widget _renderOfficeHtml(String html, Map<String, Style> styles) {
    final formatted = formatLiturgicalHtml(html);
    final root = parseFragment(formatted);
    final parts =
        <({bool turns, String html, String? title, String? reference})>[];
    var buffer = StringBuffer();
    bool? turnGroup;
    void flush() {
      if (turnGroup != null && buffer.toString().trim().isNotEmpty) {
        parts.add((
          turns: turnGroup,
          html: buffer.toString(),
          title: null,
          reference: null,
        ));
      }
      buffer = StringBuffer();
    }

    final nodes = root.nodes;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is dom.Element &&
          node.classes.contains('liturgical-heading') &&
          const {
            'КАРОТКАЕ ЧЫТАННЕ',
            'КАРОТКІ РЭСПАНСОРЫЙ',
            'РЭСПАНСОРЫЙ',
          }.contains(node.text.trim().toUpperCase())) {
        flush();
        turnGroup = null;
        final next = node.nextElementSibling;
        final reference =
            next != null &&
                next.classes.contains('liturgical-reference') &&
                nodes
                    .sublist(i + 1, nodes.indexOf(next))
                    .every(
                      (node) => node is dom.Text && node.text.trim().isEmpty,
                    )
            ? next
            : null;
        parts.add((
          turns: false,
          html: '',
          title: node.text,
          reference: reference?.text,
        ));
        if (reference != null) i = nodes.indexOf(reference);
        continue;
      }
      final isTurn =
          node is dom.Element && node.classes.contains('responsory-turn');
      if (node is dom.Text && node.text.trim().isEmpty) {
        buffer.write(node.text);
        continue;
      }
      if (turnGroup != null && turnGroup != isTurn) flush();
      turnGroup = isTurn;
      buffer.write(node is dom.Element ? node.outerHtml : node.text);
    }
    flush();
    if (!parts.any((part) => part.turns || part.title != null)) {
      return Html(data: formatted, style: styles);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final part in parts)
          if (part.title != null && part.reference == null)
            LiturgicalSectionHeading(
              title: part.title!,
              bodySize: styles['body']?.fontSize?.value ?? 16,
            )
          else if (part.title != null)
            LiturgicalHeadingReferenceRow(
              title: part.title!,
              reference: part.reference,
              bodySize: styles['body']?.fontSize?.value ?? 16,
            )
          else
            part.turns
                ? LiturgicalResponsoryBlock(html: part.html, style: styles)
                : Html(data: part.html, style: styles),
      ],
    );
  }
}

class _LiturgicalSelectableText extends StatelessWidget {
  final String content;
  final TextStyle textStyle;
  final TextAlign textAlign;

  const _LiturgicalSelectableText({
    required this.content,
    required this.textStyle,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    final rubric = ReaderTheme.of(context).rubric;
    final pieces = content.split(RegExp(r'(?=[*†])|(?<=[*†])'));
    return SelectableText.rich(
      TextSpan(
        children: [
          for (final piece in pieces)
            TextSpan(
              text: piece,
              style: piece == '*' || piece == '†'
                  ? textStyle.copyWith(
                      color: rubric,
                      fontWeight: FontWeight.w600,
                    )
                  : textStyle,
            ),
        ],
      ),
      textAlign: textAlign,
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
    final reader = ReaderTheme.of(context);
    final activeIndex = selectedIndex.clamp(0, names.length - 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('invitatorium-psalm-picker'),
          onPressed: () async {
            final selected = await showReaderChoiceSheet<int>(
              context: context,
              title: 'Псальм закліку',
              selectedValue: activeIndex,
              choices: [
                for (var i = 0; i < names.length; i++)
                  ReaderChoice(
                    value: i,
                    label: names[i],
                    subtitle: 'Варыянт ${i + 1} з ${names.length}',
                    icon: Icons.menu_book_rounded,
                  ),
              ],
            );
            if (selected != null) onSelect(selected);
          },
          icon: const PhosphorIcon(PhosphorIconsRegular.listChecks, size: 19),
          label: Text(names[activeIndex]),
          style: TextButton.styleFrom(
            foregroundColor: reader.rubric,
            minimumSize: const Size(48, 48),
            textStyle: reader
                .body(16)
                .copyWith(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
