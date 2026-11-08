import 'package:mybrev_flutter/models/reader_preferences.dart';
import 'package:mybrev_flutter/utils/reader_prose.dart';
import 'package:flutter/material.dart';
import 'package:mybrev_flutter/feedback/feedback_models.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:html/dom.dart' as dom;
import 'package:mybrev_flutter/models/mass_ritual.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/mass_ritual_provider.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';
import 'package:mybrev_flutter/utils/prayer_link.dart';
import 'package:mybrev_flutter/utils/prayer_html.dart';
import 'package:mybrev_flutter/widgets/prayer_content.dart';
import 'package:mybrev_flutter/widgets/devotional_office_reader.dart';
import 'package:mybrev_flutter/utils/devotional_office.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/utils/mass_semantics.dart';
import 'package:mybrev_flutter/utils/system_insets.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart'
    show analyticsFeature;

String _stripHtmlText(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _normalizeCmp(String s) {
  final t = s
      .toLowerCase()
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'''[«»"'.,:;!?()\-\n\r]'''), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return t;
}

String _firstVisibleLine(String text) {
  final withBreaks = text
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</h[1-6]\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"');
  for (final line in withBreaks.split(RegExp(r'[\n\r]+'))) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String _removeLeadingDuplicateTitle(String text, String title) {
  if (title.trim().isEmpty) return text;
  var source = text;

  // HTML case: some prayers start with a dedicated heading block
  // (<p>/<div>/<center>/<h*>...), which should be removed if it duplicates
  // the page title.
  if (source.contains('<') && source.contains('>')) {
    for (var i = 0; i < 2; i++) {
      final m = RegExp(
        r'^\s*<(p|div|center|h[1-6])[^>]*>([\s\S]*?)</\1>\s*',
        caseSensitive: false,
      ).firstMatch(source);
      if (m == null) break;
      final blockInner = m.group(2) ?? '';
      final blockText = _stripHtmlText(blockInner);
      if (_normalizeCmp(blockText) == _normalizeCmp(title)) {
        source = source.substring(m.end).trimLeft();
        continue;
      }
      break;
    }
  }

  final first = _firstVisibleLine(source);
  if (first.isEmpty) return text;
  if (_normalizeCmp(first) != _normalizeCmp(title)) return text;

  if (source.contains('<') && source.contains('>')) {
    final cleaned = source
        .replaceFirst(
          RegExp(
            r'^\s*(?:<(?:p|div|h[1-6])[^>]*>\s*)?[^<\n]+(?:\s*</(?:p|div|h[1-6])>)?\s*(?:<br\s*/?>)?',
            caseSensitive: false,
          ),
          '',
        )
        .trimLeft();
    return cleaned.isEmpty ? text : cleaned;
  }

  final lines = source.split(RegExp(r'[\n\r]+'));
  var removed = false;
  final kept = <String>[];
  for (final line in lines) {
    if (!removed && line.trim().isNotEmpty) {
      removed = true;
      continue;
    }
    kept.add(line);
  }
  final out = kept.join('\n').trimLeft();
  return out.isEmpty ? text : out;
}

class PrayerDetailScreen extends ConsumerStatefulWidget {
  final String prayerId;

  /// Holy Mass language requested by a link (`?lang=la`).
  final String? massLanguage;

  const PrayerDetailScreen({
    super.key,
    required this.prayerId,
    this.massLanguage,
  });

  @override
  ConsumerState<PrayerDetailScreen> createState() => _PrayerDetailScreenState();
}

class _PrayerDetailScreenState extends ConsumerState<PrayerDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final MassNavigatorController _massNav = MassNavigatorController();

  /// Latin/English variant ids open the single Holy Mass reader.
  MassVariant? get _linkedVariant =>
      kMassRitual.variantForPrayerId(widget.prayerId);
  bool get _isMass => _linkedVariant != null;
  String get _readerPrayerId =>
      _isMass ? kMassRitual.primaryPrayerId : widget.prayerId;

  late String _massLanguage = _initialMassLanguage();

  String _initialMassLanguage() {
    final linked = _linkedVariant;
    if (linked != null && linked.prayerId != kMassRitual.primaryPrayerId) {
      return linked.language;
    }
    return kMassRitual.resolveLanguage(
      widget.massLanguage,
      ref.read(massLanguageProvider),
    );
  }

  void _selectMassLanguage(String language) {
    if (language == _massLanguage) return;
    analyticsFeature('mass_language_change');
    HapticFeedback.selectionClick();
    _massNav.pendingSection = _massNav.active;
    setState(() => _massLanguage = language);
    ref.read(massLanguageProvider.notifier).select(language);
  }

  Future<void> _openMassSections() async {
    final sections = _massNav.sections;
    if (sections.isEmpty) return;
    final cupertino = usesCupertinoGlass(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: cupertino
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (sheetContext) => _MassSectionsSheet(
        available: {for (final s in sections) s.sectionId},
        activeSectionId: _massNav.active,
      ),
    );
    if (selected != null) {
      analyticsFeature('mass_section_nav');
      _massNav.jumpTo(selected);
    }
  }

  void _onLinkTap(
    String? url,
    Map<String, String> attributes,
    dom.Element? element,
  ) {
    final location = prayerLinkLocation(url);
    if (location != null &&
        location != '/prayers/prayer/${Uri.encodeComponent(widget.prayerId)}') {
      context.push(location);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _massNav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prayers = ref.watch(allPrayersProvider);
    final localPrayers = ref.watch(localPrayersProvider);
    final settings = ref.watch(settingsProvider);

    final Prayer? prayer;
    try {
      prayer = [
        ...prayers,
        ...localPrayers,
      ].firstWhere((p) => p.id == _readerPrayerId);
    } catch (_) {
      return ReaderScaffold(
        semanticLabel: 'Малітва не знойдзена',
        content: const Center(child: Text('Малітва не знойдзена')),
      );
    }

    var p = prayer;
    if (p.priestOnly) {
      final checked = ref.watch(protectedPrayerProvider(p.id));
      if (checked.isLoading) {
        return const ReaderScaffold(
          semanticLabel: 'Праверка доступу',
          content: Center(child: CircularProgressIndicator()),
        );
      }
      final document = checked.value;
      if (document == null) {
        return const ReaderScaffold(
          semanticLabel: 'Малітва недаступная',
          content: Center(
            child: Text('Малітва недаступная. Праверце доступ і злучэнне.'),
          ),
        );
      }
      p = Prayer.fromMap({...document, 'effectivePriestOnly': true}, p.id);
    }
    final isFav = settings.favoriteIds.contains(p.id);
    final variant = _isMass ? kMassRitual.variant(_massLanguage) : null;
    final textPrayer = variant == null
        ? p
        : _massVariantPrayer(variant, p, [...prayers, ...localPrayers]);
    final title = variant == null || variant.prayerId == p.id
        ? p.displayTitle
        : (textPrayer?.displayTitle.isNotEmpty ?? false)
        ? textPrayer!.displayTitle
        : variant.title;

    final office = _isMass ? null : parseDevotionalOffice(p);
    final cs = Theme.of(context).colorScheme;
    return ReadingScaffold(
      builder: (context, textStyle) => ReaderScaffold(
        key: ValueKey('prayer-reader-${p.id}'),
        scrollKey: PageStorageKey('prayer-detail-${p.id}-scroll'),
        semanticLabel: 'Тэкст малітвы ${p.displayTitle}',
        seasonColor: cs.tertiary,
        chromeMode: ReaderChromeMode.compact,
        scrollController: _scrollController,
        showScrollToTop: !_isMass,
        showPsalmody: office != null && office.profile != 'gadzinki',
        overlay: _isMass
            ? _MassNavigatorBar(
                controller: _massNav,
                seasonColor: cs.tertiary,
                onOpenSections: _openMassSections,
              )
            : null,
        // Holy Mass: language instead of the favorite control. The favorite
        // state itself is untouched and stays reachable from the lists.
        actions: [
          if (_isMass)
            _MassLanguageControl(
              language: _massLanguage,
              seasonColor: cs.tertiary,
              onChanged: _selectMassLanguage,
            )
          else
            _PrayerFavoriteControl(prayerId: p.id, favorite: isFav),
        ],
        secondaryActions: [
          if (p.isLocal)
            ReaderSecondaryAction(
              label: 'Рэдагаваць',
              icon: Icons.edit_outlined,
              onSelected: () => context.push('/prayers/prayer/${p.id}/edit'),
            ),
          // Calm, optional entry (overflow menu, never a pop-up while praying).
          ReaderSecondaryAction(
            label: 'Паведаміць пра памылку',
            icon: Icons.flag_outlined,
            onSelected: () => context.push(
              feedbackLocation(kind: 'prayer', id: p.id, title: title),
            ),
          ),
        ],
        contextHeader: ReaderContextHeader(
          eyebrow: _isMass ? 'ЛІТУРГІЯ' : 'МАЛІТВА',
          title: title.isEmpty ? 'Малітва' : title,
          metadata: p.tags.isEmpty ? null : p.tags.join(' · '),
          accentColor: cs.tertiary,
        ),
        content: textPrayer == null
            ? const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            : _buildContent(
                context,
                textPrayer,
                textStyle,
                massVariant: variant,
                office: office,
              ),
      ),
    );
  }

  /// The prayer holding a variant's text: the Mass prayer itself, a synced
  /// variant document, or the bundled fallback asset (null while loading).
  Prayer? _massVariantPrayer(
    MassVariant variant,
    Prayer massPrayer,
    List<Prayer> prayers,
  ) {
    if (variant.prayerId == massPrayer.id) return massPrayer;
    for (final candidate in prayers) {
      if (candidate.id == variant.prayerId) return candidate;
    }
    final asset = variant.bundledAsset;
    if (asset == null) return massPrayer;
    final text = ref.watch(massBundledTextProvider(asset)).value;
    if (text == null) return null;
    return Prayer(
      id: variant.prayerId,
      title: variant.title,
      body: text,
      textFormat: 'mybrev-markdown',
    );
  }

  Widget _buildContent(
    BuildContext context,
    Prayer prayer,
    TextStyle textStyle, {
    MassVariant? massVariant,
    DevotionalOfficeDocument? office,
  }) {
    final isMass = massVariant != null;
    final raw = _removeLeadingDuplicateTitle(
      prayer.displayText,
      prayer.displayTitle,
    ).trim();

    if (raw.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Center(
          child: Column(
            children: [
              PhosphorIcon(
                PhosphorIconsLight.bookOpen,
                size: 48,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'Тэкст малітвы адсутнічае',
                style: TextStyle(color: cs.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Магчыма, малітва была выдалена.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (!isMass) {
      if (office != null) {
        return DevotionalOfficeReader(
          key: ValueKey('devotional-office-${prayer.id}'),
          document: office,
          textStyle: textStyle,
          onLinkTap: _onLinkTap,
        );
      }
      return PrayerContent(
        textAlignment: ref
            .watch(settingsProvider.select((s) => s.textAlignment))
            .textAlign,
        prayer: prayer.copyWith(body: raw),
        textStyle: textStyle,
        onLinkTap: _onLinkTap,
      );
    }

    final html =
        prayer.isMarkdown || (!raw.contains('<') && raw.contains(':::rubric'))
        ? prayerMarkdownToHtml(raw, recognizeSpeakers: false)
        : sanitizePrayerHtml(raw);

    if (html.contains('<') && html.contains('>')) {
      final reader = ReaderTheme.of(context);
      final heading = reader.blockHeading(textStyle.fontSize ?? 16);
      final major = reader.majorHeading(textStyle.fontSize ?? 16);
      final textColor =
          textStyle.color ?? Theme.of(context).colorScheme.onSurface;
      final formattedHtml = sanitizePrayerHtml(formatLiturgicalHtml(html));
      final styles = <String, Style>{
        'a': Style(
          color: Theme.of(context).colorScheme.primary,
          textDecoration: TextDecoration.underline,
        ),
        'body': Style(
          fontSize: FontSize(textStyle.fontSize ?? 16),
          fontFamily: textStyle.fontFamily,
          color: textColor,
          lineHeight: LineHeight(ReaderTheme.bodyHeight),
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
        ),
        'p': Style(
          fontSize: FontSize(textStyle.fontSize ?? 16),
          fontFamily: textStyle.fontFamily,
          color: textColor,
          margin: Margins.only(bottom: LiturgicalSpacing.paragraphAfter),
        ),
        'ul': Style(
          margin: Margins.symmetric(vertical: 10),
          padding: HtmlPaddings.only(left: 24),
          listStylePosition: ListStylePosition.outside,
        ),
        'ol': Style(
          margin: Margins.symmetric(vertical: 10),
          padding: HtmlPaddings.only(left: 24),
          listStylePosition: ListStylePosition.outside,
        ),
        'h2': Style(
          fontFamily: major.fontFamily,
          fontSize: FontSize(major.fontSize!),
          lineHeight: LineHeight(major.height!),
          fontWeight: major.fontWeight,
          color: reader.rubric,
          margin: Margins.only(
            top: LiturgicalSpacing.sectionBefore,
            bottom: LiturgicalSpacing.sectionTitleToBody,
          ),
        ),
        'h3': Style(
          fontFamily: heading.fontFamily,
          fontSize: FontSize(heading.fontSize!),
          lineHeight: LineHeight(heading.height!),
          fontWeight: heading.fontWeight,
          color: reader.rubric,
          margin: Margins.only(
            top: LiturgicalSpacing.sectionBefore,
            bottom: LiturgicalSpacing.sectionTitleToBody,
          ),
        ),
        if (isMass)
          'em': Style(color: reader.rubric, fontStyle: FontStyle.italic),
        '.prayer-rubric': readerRubricHtmlStyle(
          reader: reader,
          body: textStyle,
          margin: Margins.zero,
        )..padding = HtmlPaddings.zero,
        '.prayer-rubric p': readerRubricHtmlStyle(
          reader: reader,
          body: textStyle,
          margin: Margins.only(bottom: LiturgicalSpacing.paragraphAfter),
        ),
        '.prayer-rubric em': Style(
          color: reader.rubric,
          fontStyle: FontStyle.normal,
        ),
        '.psalm-marker': Style(
          color: reader.rubric,
          fontWeight: FontWeight.w600,
        ),
        '.liturgical-rubric-inline': Style(color: reader.rubric),
        if (isMass) ..._massStyles(reader, textStyle),
        '.reader-prose': Style(
          textAlign: ref.watch(settingsProvider).textAlignment.textAlign,
        ),
      };
      if (isMass) {
        return _MassDocument(
          onLinkTap: _onLinkTap,
          html: formattedHtml,
          styles: styles,
          variant: massVariant,
          controller: _massNav,
          scrollController: _scrollController,
          sourceStyle: reader
              .sourceStyle(textStyle.fontSize ?? 16)
              .copyWith(fontFamily: textStyle.fontFamily),
        );
      }
      return Html(
        onLinkTap: _onLinkTap,
        data: prepareReaderProseHtml(formattedHtml),
        style: styles,
      );
    }
    return SelectableText(
      raw,
      style: textStyle,
      textAlign: readerProseAlignment(
        ref.watch(settingsProvider).textAlignment,
        raw,
      ),
    );
  }
}

/// One renderer style per semantic Mass element (see [MassBlockClass]), used
/// for every language variant. Meaning is carried by weight, style, size and
/// layout, not only by colour.
Map<String, Style> _massStyles(ReaderTheme reader, TextStyle body) {
  final size = body.fontSize ?? 16;
  final text = body.color ?? reader.ink;
  final heading = reader.blockHeading(size);
  final major = reader.majorHeading(size);
  return {
    'hr': Style(
      margin: Margins.symmetric(vertical: 12),
      width: Width(42, Unit.percent),
      border: Border(top: BorderSide(color: reader.rubric, width: 0.6)),
    ),
    '.${MassBlockClass.major}': Style(
      fontFamily: major.fontFamily,
      fontSize: FontSize(major.fontSize!),
      fontWeight: major.fontWeight,
      color: reader.rubric,
      lineHeight: LineHeight(major.height!),
      margin: Margins.only(
        top: LiturgicalSpacing.sectionBefore,
        bottom: LiturgicalSpacing.sectionTitleToBody,
      ),
    ),
    '.${MassBlockClass.subsection}': Style(
      fontFamily: heading.fontFamily,
      fontSize: FontSize(heading.fontSize!),
      fontWeight: heading.fontWeight,
      color: reader.rubric,
      lineHeight: LineHeight(heading.height!),
      margin: Margins.only(
        top: LiturgicalSpacing.sectionBefore,
        bottom: LiturgicalSpacing.sectionTitleToBody,
      ),
    ),
    '.${MassBlockClass.minorHeading}': Style(
      fontSize: FontSize(size * 0.98),
      fontWeight: FontWeight.w700,
      color: text,
      margin: Margins.only(top: 14, bottom: 6),
    ),
    '.${MassBlockClass.cited}': Style(
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w600,
    ),
    '.${MassBlockClass.comment}': readerRubricHtmlStyle(
      reader: reader,
      body: body,
      margin: Margins.only(bottom: LiturgicalSpacing.paragraphAfter),
    ),
    '.${MassBlockClass.inlineAlternative}': Style(
      color: reader.rubric,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w700,
      fontSize: FontSize(size * 0.9),
    ),
    '.${MassBlockClass.response}': Style(fontWeight: FontWeight.w700),
    '.${MassBlockClass.roleLabel}': Style(
      color: reader.rubric,
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.normal,
    ),
    '.${MassBlockClass.alternative}': Style(
      color: reader.rubric,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w700,
      fontSize: FontSize(size * 0.9),
      margin: Margins.only(top: 12, bottom: 6),
    ),
    '.${MassBlockClass.posture}': readerRubricHtmlStyle(
      reader: reader,
      body: body,
      textAlign: TextAlign.center,
      margin: Margins.only(bottom: LiturgicalSpacing.paragraphAfter),
    ),
  };
}

/// Shared state between the Mass text, its bottom controls and the sections
/// sheet. Section ids are canonical ritual ids.
class MassNavigatorController extends ChangeNotifier {
  List<LocatedMassSection> _sections = const [];
  String? _active;

  /// Section to restore after the language changes.
  String? pendingSection;
  Future<void> Function(String sectionId)? _jump;

  List<LocatedMassSection> get sections => _sections;
  String? get active => _active;

  /// Laid-out height of the floating section bar, reported by the bar so the
  /// document can reserve exactly that much space at its end.
  double get barHeight => _barHeight;
  double _barHeight = _MassNavigatorBar.minHeight;

  void _reportBarHeight(double height) {
    if ((height - _barHeight).abs() < 0.5) return;
    _barHeight = height;
    notifyListeners();
  }

  /// The canonical major section containing the current position.
  MassSectionDef? get activeMajor => kMassRitual.majorSectionOf(_active);

  /// 1-based position of [activeMajor] among the five major sections.
  int? get activePosition => kMassRitual.majorPositionOf(_active);

  void _update({List<LocatedMassSection>? sections, String? active}) {
    final changed =
        (sections != null && sections != _sections) || active != _active;
    if (sections != null) _sections = sections;
    _active = active;
    if (changed) notifyListeners();
  }

  Future<void> jumpTo(String sectionId) async => _jump?.call(sectionId);
}

class _MassDocument extends StatefulWidget {
  const _MassDocument({
    required this.html,
    required this.styles,
    required this.onLinkTap,
    required this.variant,
    required this.controller,
    required this.scrollController,
    required this.sourceStyle,
  });

  final String html;
  final Map<String, Style> styles;
  final OnTap onLinkTap;
  final MassVariant variant;
  final MassNavigatorController controller;
  final ScrollController scrollController;
  final TextStyle sourceStyle;

  @override
  State<_MassDocument> createState() => _MassDocumentState();
}

class _MassDocumentState extends State<_MassDocument> {
  static const _chromeHeight = 76.0;

  late List<MassDocumentChunk> _chunks;
  final Map<String, GlobalKey> _keys = {};

  @override
  void initState() {
    super.initState();
    _readSections();
    widget.controller._jump = _jumpTo;
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _MassDocument oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
    widget.controller._jump = _jumpTo;
    if (oldWidget.html != widget.html ||
        oldWidget.variant.language != widget.variant.language) {
      _readSections();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    if (widget.controller._jump == _jumpTo) widget.controller._jump = null;
    super.dispose();
  }

  void _readSections() {
    final document = buildMassDocument(widget.html, widget.variant);
    final located = document.sections;
    _chunks = document.chunks;
    _keys
      ..clear()
      ..addEntries(
        located.map(
          (s) => MapEntry(s.sectionId, GlobalKey(debugLabel: s.sectionId)),
        ),
      );
    final pending = widget.controller.pendingSection;
    widget.controller.pendingSection = null;
    // Listeners (the bottom controls) rebuild after this frame, not during it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller._update(
        sections: located,
        active: located.isEmpty ? null : located.first.sectionId,
      );
      final target = kMassRitual.resolveSectionTarget(
        pending,
        located.map((s) => s.sectionId),
      );
      if (target != null) {
        _jumpTo(target, animate: false);
      } else {
        _track();
      }
    });
  }

  // Generous margin below the landing point of a jump, so a heading placed by
  // `_jumpTo` is always counted as the current section.
  double get _readingLine =>
      MediaQuery.paddingOf(context).top + _chromeHeight + 56;

  double? _topOf(String sectionId) {
    final box =
        _keys[sectionId]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  bool _trackScheduled = false;

  /// Scroll notifications arrive before the new layout is painted, so the
  /// positions are measured once after the frame.
  void _onScroll() {
    if (_trackScheduled) return;
    _trackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackScheduled = false;
      _track();
    });
  }

  void _track() {
    if (!mounted || _keys.isEmpty) return;
    final tops = <({String sectionId, double top})>[];
    for (final section in widget.controller.sections) {
      final top = _topOf(section.sectionId);
      if (top != null) tops.add((sectionId: section.sectionId, top: top));
    }
    var readingLine = _readingLine;
    final scroll = widget.scrollController;
    // At the very end short sections can never reach the reading line; then
    // the last section visible on screen is the current one.
    if (scroll.hasClients &&
        scroll.position.pixels >= scroll.position.maxScrollExtent - 1) {
      readingLine = MediaQuery.sizeOf(context).height * 0.75;
    }
    widget.controller._update(active: activeMassSectionAt(tops, readingLine));
  }

  Future<void> _jumpTo(String sectionId, {bool animate = true}) async {
    final top = _topOf(sectionId);
    final scroll = widget.scrollController;
    if (top == null || !scroll.hasClients) return;
    final position = scroll.position;
    final target =
        (position.pixels +
                top -
                MediaQuery.paddingOf(context).top -
                _chromeHeight -
                8)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    widget.controller._update(active: sectionId);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (animate && !reduceMotion) {
      await scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      scroll.jumpTo(target);
    }
    if (mounted) _onScroll();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.variant.source;
    final firstMajorStyle =
        _chunks.isNotEmpty &&
            _chunks.first.html.trimLeft().startsWith(
              '<h2 class="${MassBlockClass.major}"',
            )
        ? {
            ...widget.styles,
            '.${MassBlockClass.major}': widget
                .styles['.${MassBlockClass.major}']!
                .copyWith(
                  margin: Margins.only(
                    top: 0,
                    bottom: LiturgicalSpacing.sectionTitleToBody,
                  ),
                ),
          }
        : widget.styles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, chunk) in _chunks.indexed)
          if (chunk.section case final section?)
            KeyedSubtree(
              key: _keys[section.sectionId],
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                child: Html(
                  onLinkTap: widget.onLinkTap,
                  data: prepareReaderProseHtml(chunk.html),
                  style: index == 0 ? firstMajorStyle : widget.styles,
                ),
              ),
            )
          else
            Html(
              onLinkTap: widget.onLinkTap,
              data: prepareReaderProseHtml(chunk.html),
              style: index == 0 ? firstMajorStyle : widget.styles,
            ),
        if (source != null) ...[
          const SizedBox(height: 18),
          Text(
            'Крыніца: $source',
            key: const Key('mass-variant-source'),
            style: widget.sourceStyle,
          ),
        ],
        // Keeps the last lines clear of the floating section bar. Same
        // window-inset anchor as the bar itself, minus the space the reader
        // surface already adds below its content.
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => SizedBox(
            key: const Key('mass-content-reserve'),
            height: floatingOverlayContentReserve(
              overlayHeight: widget.controller.barHeight,
              overlayBottom: floatingOverlayBottom(
                context,
                gap: _MassNavigatorBar.gap,
              ),
              readerBottomPadding:
                  ReaderContentSurface.bottomSpacing +
                  MediaQuery.paddingOf(context).bottom,
              contentGap: _MassNavigatorBar.contentGap,
            ),
          ),
        ),
      ],
    );
  }
}

/// Floating section selector: the full canonical Belarusian name of the
/// current major section (up to two lines), n/5 and a list affordance. Tapping
/// it opens the sections sheet. The language lives in the top reader actions.
class _MassNavigatorBar extends StatelessWidget {
  const _MassNavigatorBar({
    required this.controller,
    required this.onOpenSections,
    this.seasonColor,
  });

  /// Distance between the bar and the system navigation area.
  static const gap = 14.0;

  /// Distance between the end of the document and the bar.
  static const contentGap = 24.0;
  static const minHeight = 56.0;

  final MassNavigatorController controller;
  final VoidCallback onOpenSections;
  final Color? seasonColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.2);
    final majorCount = kMassRitual.majorSections.length;
    // Anchored to the window's system obstruction: the shell hides its dock
    // on the Mass route, so the local MediaQuery padding may already be
    // consumed (Android 3-button navigation).
    return FloatingOverlayPositioned(
      gap: gap,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _MassBarHeightReporter(
            controller: controller,
            child: AdaptiveChromeSurface(
              key: const Key('mass-navigator-bar'),
              role: ChromeSurfaceRole.navigation,
              seasonColor: seasonColor,
              borderRadius: BorderRadius.circular(28),
              padding: const EdgeInsets.all(4),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final major = controller.activeMajor;
                    final position = controller.activePosition;
                    final onTap = controller.sections.isEmpty
                        ? null
                        : onOpenSections;
                    return Semantics(
                      button: true,
                      onTap: onTap,
                      label: major == null
                          ? 'Раздзелы'
                          : 'Раздзелы. Цяпер: ${major.title}, '
                                'раздзел $position з $majorCount',
                      excludeSemantics: true,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          key: const Key('mass-section-selector'),
                          borderRadius: BorderRadius.circular(24),
                          onTap: onTap,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: minHeight - 8,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      major?.title ?? 'Раздзелы',
                                      key: const Key('mass-section-title'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: labelStyle,
                                    ),
                                  ),
                                  if (position != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '$position/$majorCount',
                                      key: const Key('mass-section-position'),
                                      maxLines: 1,
                                      style: labelStyle?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  PhosphorIcon(
                                    PhosphorIconsRegular.listBullets,
                                    size: 18,
                                    color: cs.tertiary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reports the bar's laid-out height (one or two title lines, text scale) to
/// the controller after each layout.
class _MassBarHeightReporter extends SingleChildRenderObjectWidget {
  const _MassBarHeightReporter({required this.controller, super.child});

  final MassNavigatorController controller;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMassBarHeightReporter(controller);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMassBarHeightReporter renderObject,
  ) => renderObject.controller = controller;
}

class _RenderMassBarHeightReporter extends RenderProxyBox {
  _RenderMassBarHeightReporter(this.controller);

  MassNavigatorController controller;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    final target = controller;
    // Listeners rebuild after this frame, not during layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached && identical(target, controller)) {
        target._reportBarHeight(height);
      }
    });
  }
}

/// Top-right Mass language control: shows the current language code and opens
/// a compact menu with the three variants.
class _MassLanguageControl extends StatelessWidget {
  const _MassLanguageControl({
    required this.language,
    required this.onChanged,
    this.seasonColor,
  });

  final String language;
  final ValueChanged<String> onChanged;
  final Color? seasonColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = kMassRitual.variant(language);
    return Semantics(
      container: true,
      child: AdaptiveChromeSurface(
        role: ChromeSurfaceRole.control,
        seasonColor: seasonColor,
        borderRadius: BorderRadius.circular(24),
        child: Material(
          type: MaterialType.transparency,
          child: PopupMenuButton<String>(
            key: const Key('mass-language-selector'),
            tooltip: 'Мова святой Імшы: ${current?.label ?? language}',
            initialValue: language,
            position: PopupMenuPosition.under,
            offset: const Offset(0, 6),
            borderRadius: BorderRadius.circular(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onSelected: onChanged,
            itemBuilder: (context) => [
              for (final variant in kMassRitual.variants)
                PopupMenuItem<String>(
                  key: Key('mass-language-${variant.language}'),
                  value: variant.language,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: variant.language == language
                            ? Icon(
                                Icons.check_rounded,
                                size: 20,
                                color: cs.tertiary,
                              )
                            : null,
                      ),
                      Expanded(child: Text(variant.label)),
                      const SizedBox(width: 16),
                      Text(
                        variant.shortLabel,
                        style: text.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.only(left: 14, right: 8),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        current?.shortLabel ?? language.toUpperCase(),
                        key: const Key('mass-language-current'),
                        maxLines: 1,
                        style: text.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section navigator: the five canonical major sections by their Belarusian
/// names (whatever the Mass language), with the subsections of the current
/// one nested below it.
class _MassSectionsSheet extends StatelessWidget {
  const _MassSectionsSheet({
    required this.available,
    required this.activeSectionId,
  });

  /// Canonical ids of the sections present in the current language variant.
  final Set<String> available;
  final String? activeSectionId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final activeMajor = kMassRitual.majorSectionOf(activeSectionId);
    final majors = kMassRitual.majorSections;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'СВЯТАЯ ІМША',
                        style: text.labelSmall?.copyWith(
                          color: cs.tertiary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'Раздзелы',
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыць',
                  onPressed: () => Navigator.pop(context),
                  icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 21),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              key: const Key('mass-sections-sheet'),
              shrinkWrap: true,
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                for (var i = 0; i < majors.length; i++) ...[
                  _MassSectionTile(
                    section: majors[i],
                    position: i + 1,
                    enabled: available.contains(majors[i].id),
                    selected: majors[i].id == activeMajor?.id,
                  ),
                  if (majors[i].id == activeMajor?.id)
                    for (final sub in kMassRitual.sections)
                      if (sub.parent == majors[i].id &&
                          available.contains(sub.id))
                        _MassSectionTile(
                          section: sub,
                          enabled: true,
                          selected: sub.id == activeSectionId,
                        ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MassSectionTile extends StatelessWidget {
  const _MassSectionTile({
    required this.section,
    required this.enabled,
    required this.selected,
    this.position,
  });

  final MassSectionDef section;
  final bool enabled;
  final bool selected;

  /// Number shown before a major section (1–5).
  final int? position;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final major = section.isMajor;
    return Semantics(
      selected: selected,
      child: ListTile(
        key: ValueKey('mass-section-${section.id}'),
        enabled: enabled,
        selected: selected,
        selectedColor: cs.tertiary,
        selectedTileColor: major ? cs.tertiary.withValues(alpha: 0.10) : null,
        contentPadding: EdgeInsets.only(left: major ? 20 : 56, right: 16),
        minTileHeight: major ? 56 : 44,
        leading: major
            ? SizedBox(
                width: 24,
                child: Text(
                  '$position',
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? cs.tertiary : cs.onSurfaceVariant,
                  ),
                ),
              )
            : Container(
                width: 2,
                height: 22,
                color: selected ? cs.tertiary : cs.outlineVariant,
              ),
        minLeadingWidth: major ? 24 : 10,
        title: Text(
          section.title,
          style: (major ? text.titleMedium : text.bodyMedium)?.copyWith(
            fontWeight: major || selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        trailing: selected && major
            ? PhosphorIcon(
                PhosphorIconsRegular.bookmarkSimple,
                size: 18,
                color: cs.tertiary,
              )
            : null,
        onTap: () => Navigator.pop(context, section.id),
      ),
    );
  }
}

class _PrayerFavoriteControl extends ConsumerWidget {
  const _PrayerFavoriteControl({
    required this.prayerId,
    required this.favorite,
  });

  final String prayerId;
  final bool favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 48,
      child: IconButton.filledTonal(
        key: const Key('prayer-detail-favorite'),
        tooltip: favorite ? 'Выдаліць з абраных' : 'Дадаць у абраныя',
        onPressed: () {
          HapticFeedback.selectionClick();
          ref.read(settingsProvider.notifier).toggleFavorite(prayerId);
        },
        icon: PhosphorIcon(
          favorite ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
          size: 21,
          color: favorite ? cs.error : null,
        ),
      ),
    );
  }
}
