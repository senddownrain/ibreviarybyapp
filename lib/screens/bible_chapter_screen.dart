import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/navigation/bible_navigation.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/widgets/adaptive_segmented_control.dart';
import 'package:mybrev_flutter/theme/platform_design.dart';
import 'package:mybrev_flutter/widgets/navigation_drawer.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';
import 'package:mybrev_flutter/utils/system_insets.dart';

class BibleChapterScreen extends ConsumerStatefulWidget {
  final String versionId;
  final String bookId;
  final int chapter;

  const BibleChapterScreen({
    super.key,
    required this.versionId,
    required this.bookId,
    required this.chapter,
  });

  @override
  ConsumerState<BibleChapterScreen> createState() => _BibleChapterScreenState();
}

class _BibleChapterScreenState extends ConsumerState<BibleChapterScreen> {
  static const double _compactThreshold = 180;
  bool _didRequestCompact = false;

  static const _colors = <String, Color>{
    'amber': Color(0xFFE2AE34),
    'rose': Color(0xFFD37074),
    'sky': Color(0xFF4F9FC1),
    'leaf': Color(0xFF59A46B),
  };
  static const _colorLabels = <String, String>{
    'amber': 'Бурштынавы колер',
    'rose': 'Ружовы колер',
    'sky': 'Блакітны колер',
    'leaf': 'Зялёны колер',
  };
  final Map<int, String> _highlights = {};
  final Set<int> _selected = {};
  final GlobalKey _paletteMeasureKey = GlobalKey();
  double _paletteHeight = 0;

  void _measurePalette() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selected.isEmpty) return;
      final height = _paletteMeasureKey.currentContext?.size?.height;
      if (height != null && height != _paletteHeight) {
        setState(() => _paletteHeight = height);
      }
    });
  }

  final Map<int, GlobalKey> _verseKeys = {};
  int? _requestedVerse;
  bool _bottomSlotInitialized = false;
  late ScrollController _scrollController;
  Timer? _scrollSaveTimer;
  AppRouteEntryScope? _routeScope;

  BibleLocation get _location => BibleLocation(
    versionId: widget.versionId,
    bookId: widget.bookId,
    chapter: widget.chapter,
  );

  String get _highlightKey => BibleNavigation.highlightKey(_location);

  @override
  void initState() {
    super.initState();
    _createScrollController();
    _loadState();
  }

  @override
  void didUpdateWidget(covariant BibleChapterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.versionId != widget.versionId ||
        oldWidget.bookId != widget.bookId ||
        oldWidget.chapter != widget.chapter) {
      _didRequestCompact = false;
      final chrome = ReaderChromeModeScope.maybeControllerOf(context);
      final initialMode =
          AppRouteEntryScope.maybeOf(
            context,
          )?.entry.descriptor.defaultChromeMode ??
          ReaderChromeMode.full;
      final versionId = widget.versionId;
      final bookId = widget.bookId;
      final chapter = widget.chapter;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.versionId == versionId &&
            widget.bookId == bookId &&
            widget.chapter == chapter) {
          chrome?.value = initialMode;
        }
      });
      _selected.clear();
      AppRouteEntryScope.maybeOf(context)?.showContextualBottomBar(false);
      _verseKeys.clear();
      _disposeScrollController();
      _createScrollController();
      _loadState();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeScope = AppRouteEntryScope.maybeOf(context);
    if (!_bottomSlotInitialized) {
      _bottomSlotInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppRouteEntryScope.maybeOf(context)?.showContextualBottomBar(false);
        }
      });
    }
    final verse = int.tryParse(
      GoRouterState.of(context).uri.queryParameters['verse'] ?? '',
    );
    if (verse == null || verse == _requestedVerse) return;
    _requestedVerse = verse;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _verseKeys[verse]?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: const Duration(milliseconds: 320),
        );
      }
    });
  }

  void _loadState() {
    final raw = HiveService.settingsBox.get(_highlightKey);
    _highlights.clear();
    if (raw is Map) {
      const legacy = ['amber', 'leaf', 'sky', 'rose', 'amber'];
      raw.forEach((key, value) {
        final verse = int.tryParse(key.toString());
        if (verse == null) return;
        final color = value is num
            ? legacy[value.toInt().clamp(0, legacy.length - 1)]
            : value.toString();
        if (_colors.containsKey(color)) _highlights[verse] = color;
      });
    }
    unawaited(
      HiveService.settingsBox.put(
        BibleNavigation.lastLocationKey(widget.versionId),
        {'bookId': widget.bookId, 'chapter': widget.chapter},
      ),
    );
  }

  void _createScrollController() {
    final raw = HiveService.settingsBox.get(
      BibleNavigation.scrollKey(_location),
    );
    final initialOffset = raw is num && raw.isFinite
        ? raw.toDouble().clamp(0, double.maxFinite).toDouble()
        : 0.0;
    _scrollController = ScrollController(initialScrollOffset: initialOffset)
      ..addListener(_scheduleScrollSave);
  }

  void _scheduleScrollSave() {
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = Timer(const Duration(milliseconds: 250), _saveScroll);
  }

  void _saveScroll() {
    if (!_scrollController.hasClients) return;
    unawaited(
      HiveService.settingsBox.put(
        BibleNavigation.scrollKey(_location),
        _scrollController.offset,
      ),
    );
  }

  void _disposeScrollController() {
    _scrollSaveTimer?.cancel();
    _saveScroll();
    _scrollController
      ..removeListener(_scheduleScrollSave)
      ..dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (!_didRequestCompact &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.pixels >= _compactThreshold &&
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _didRequestCompact = true;
      ReaderChromeModeScope.maybeControllerOf(context)?.value =
          ReaderChromeMode.compact;
    }
    return false;
  }

  @override
  void dispose() {
    _routeScope?.showContextualBottomBar(false);
    _disposeScrollController();
    super.dispose();
  }

  Future<void> _saveHighlights() => HiveService.settingsBox.put(_highlightKey, {
    for (final item in _highlights.entries) '${item.key}': item.value,
  });

  @override
  Widget build(BuildContext context) {
    if (_selected.isNotEmpty) _measurePalette();
    final book = BibleRepository.getBook(widget.versionId, widget.bookId);
    if (book == null ||
        widget.chapter < 1 ||
        widget.chapter > book.chapterCount) {
      return ReaderScaffold(
        showAmbient: false,
        semanticLabel: 'Памылка адкрыцця Бібліі',
        content: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Кніга або раздзел Бібліі не знойдзены.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/bible'),
                child: const Text('Адкрыць бібліятэку'),
              ),
            ],
          ),
        ),
      );
    }
    final verses = BibleRepository.getChapter(
      widget.versionId,
      widget.bookId,
      widget.chapter,
    );
    final isSearchResult = GoRouterState.of(
      context,
    ).uri.path.startsWith('/bible/search/result');
    return PopScope<void>(
      canPop: _selected.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selected.isNotEmpty) {
          setState(_selected.clear);
          AppRouteEntryScope.maybeOf(context)?.showContextualBottomBar(false);
        }
      },
      child: ReadingScaffold(
        builder: (context, textStyle) => Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: ReaderScaffold(
                onSwipePrevious: _selected.isEmpty && _relative(-1) != null
                    ? () => _goRelative(-1)
                    : null,
                onSwipeNext: _selected.isEmpty && _relative(1) != null
                    ? () => _goRelative(1)
                    : null,
                showAmbient: false,
                enableDoubleTapFullscreen: false,
                scrollController: _scrollController,
                scrollKey: PageStorageKey(
                  'bible-${_location.documentKey}-scroll',
                ),
                semanticLabel: '${book.name}, раздзел ${widget.chapter}',
                chromeMode: ReaderChromeMode.compact,
                leading: isSearchResult ? null : _menuLeading(),
                actions: [
                  _ChromeAction(
                    key: const Key('bible-search-open'),
                    tooltip: 'Пошук у Бібліі',
                    icon: PhosphorIconsRegular.magnifyingGlass,
                    onPressed: () => _openSearch(book),
                  ),
                  const TextScaleControl(),
                ],
                contextHeader: ReaderContextHeader(
                  eyebrow: book.isNewTestament
                      ? 'НОВЫ ЗАПАВЕТ'
                      : 'СТАРЫ ЗАПАВЕТ',
                  title: book.name,
                  titleActionLabel:
                      'Выбраць кнігу або раздзел. Зараз ${book.name} ${widget.chapter}',
                  subtitle: 'Раздзел ${widget.chapter}',
                  metadata: bibleAttribution(
                    versionId: widget.versionId,
                    isNewTestament: book.isNewTestament,
                  ),
                  onTitleTap: () => _openPicker(book),
                  actions: [_translationControl(book)],
                ),
                content: Padding(
                  key: const Key('bible-selection-content-reserve'),
                  padding: EdgeInsets.only(
                    bottom: _selected.isEmpty
                        ? 0
                        : Theme.of(context).platform == TargetPlatform.android
                        ? floatingOverlayContentReserve(
                            overlayHeight: _paletteHeight,
                            overlayBottom: floatingOverlayBottom(
                              context,
                              gap: floatingPaletteGap(context),
                            ),
                            readerBottomPadding:
                                ReaderContentSurface.bottomSpacing +
                                MediaQuery.paddingOf(context).bottom,
                            contentGap: 24,
                          )
                        : 72,
                  ),
                  child: Column(
                    children: [
                      if (verses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('У гэтым раздзеле няма тэксту.'),
                          ),
                        )
                      else
                        for (final verse in verses)
                          _VerseRow(
                            key: _verseKeys.putIfAbsent(
                              verse.verse,
                              GlobalKey.new,
                            ),
                            verseNum: verse.verse,
                            text: verse.text,
                            textStyle: textStyle,
                            highlightColor: _resolvedColor(
                              _highlights[verse.verse],
                            ),
                            selected: _selected.contains(verse.verse),
                            onTap: () => _toggleVerse(verse.verse),
                          ),
                      const SizedBox(height: 24),
                      _ChapterNavBar(
                        book: book,
                        chapter: widget.chapter,
                        hasPrevious: _relative(-1) != null,
                        hasNext: _relative(1) != null,
                        onPrevious: () => _goRelative(-1),
                        onCurrent: () => _openPicker(book),
                        onNext: () => _goRelative(1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_selected.isNotEmpty)
              Positioned(
                left: MediaQuery.sizeOf(context).width <= 340 ? 4 : 12,
                right: MediaQuery.sizeOf(context).width <= 340 ? 4 : 12,
                // The shell hides its navigation dock while the palette is
                // open. In that transition SafeArea can inherit an already
                // consumed inset, so anchor explicitly above system gestures.
                bottom: floatingOverlayBottom(
                  context,
                  gap: floatingPaletteGap(context),
                ),
                child: KeyedSubtree(
                  key: _paletteMeasureKey,
                  child: _colorBar(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _menuLeading() => IconButton(
    tooltip: 'Меню',
    onPressed: () => showSecondaryMenu(context),
    icon: const PhosphorIcon(PhosphorIconsRegular.list, size: 22),
  );

  Widget _translationControl(BibleBookInfo book) => SizedBox(
    width: 136,
    child: AdaptiveSegmentedControl<String>(
      showSelectedIcon: false,
      segments: [
        for (final version in kBibleVersionMeta.values)
          AdaptiveSegment(
            value: version.id,
            label: Text(
              version.shortLabel,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
      ],
      value: widget.versionId,
      onChanged: _changeLanguage,
    ),
  );

  Color? _resolvedColor(String? id) {
    final color = _colors[id];
    if (color == null) return null;
    return color.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.32 : 0.30,
    );
  }

  void _toggleVerse(int verse) {
    setState(() {
      if (!_selected.add(verse)) _selected.remove(verse);
    });
    AppRouteEntryScope.maybeOf(
      context,
    )?.showContextualBottomBar(_selected.isNotEmpty);
    if (_selected.contains(verse)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _verseKeys[verse]?.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: 0.5,
            duration: const Duration(milliseconds: 240),
          );
        }
      });
    }
  }

  Widget _colorBar() => AdaptiveChromeSurface(
    key: const Key('bible-highlight-palette'),
    role: ChromeSurfaceRole.group,
    borderRadius: BorderRadius.circular(22),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            if (constraints.maxWidth >= 390)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '${_selected.length} ${_selected.length == 1 ? 'верш' : 'вершы'}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            const Spacer(),
            for (final color in _colors.entries)
              Semantics(
                button: true,
                label: _colorLabels[color.key],
                selected:
                    _selected.isNotEmpty &&
                    _selected.every((verse) => _highlights[verse] == color.key),
                child: InkWell(
                  key: Key('bible-highlight-${color.key}'),
                  customBorder: const CircleBorder(),
                  onTap: () => _applyColor(color.key),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.value,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              key: const Key('bible-highlight-clear'),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              tooltip: 'Прыбраць вылучэнне',
              onPressed: () => _applyColor(null),
              icon: const PhosphorIcon(PhosphorIconsRegular.eraser, size: 20),
            ),
            IconButton(
              key: const Key('bible-highlight-cancel'),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              tooltip: 'Скасаваць выбар',
              onPressed: () {
                setState(_selected.clear);
                AppRouteEntryScope.maybeOf(
                  context,
                )?.showContextualBottomBar(false);
              },
              icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 19),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _applyColor(String? color) async {
    setState(() {
      for (final verse in _selected) {
        if (color == null) {
          _highlights.remove(verse);
        } else {
          _highlights[verse] = color;
        }
      }
      _selected.clear();
    });
    AppRouteEntryScope.maybeOf(context)?.showContextualBottomBar(false);
    await _saveHighlights();
  }

  _BibleLocation? _relative(int direction) {
    final location = BibleNavigation.relative(_location, direction);
    return location == null
        ? null
        : _BibleLocation(location.bookId, location.chapter);
  }

  void _goRelative(int direction) {
    final location = _relative(direction);
    if (location != null) _navigate(location.bookId, location.chapter);
  }

  void _navigate(String bookId, int chapter, {int? verse}) {
    final searchResult = GoRouterState.of(
      context,
    ).uri.path.startsWith('/bible/search/result');
    context.replace(
      BibleNavigation.route(
        BibleLocation(
          versionId: widget.versionId,
          bookId: bookId,
          chapter: chapter,
          verse: verse,
        ),
        searchResult: searchResult,
      ),
    );
  }

  void _changeLanguage(String versionId) {
    if (versionId == widget.versionId) return;
    final saved = HiveService.settingsBox.get('bibleLastLocation:$versionId');
    final target = BibleNavigation.switchTranslation(
      current: _location,
      targetVersionId: versionId,
      targetSaved: saved is Map ? saved : null,
    );
    if (target == null) return;
    ref.read(settingsProvider.notifier).setBibleVersion(versionId);
    final searchResult = GoRouterState.of(
      context,
    ).uri.path.startsWith('/bible/search/result');
    context.replace(BibleNavigation.route(target, searchResult: searchResult));
  }

  Future<void> _openPicker(BibleBookInfo currentBook) async {
    var newTestament = currentBook.isNewTestament;
    var filter = '';
    String? expandedBookId = currentBook.id;
    final result = await showModalBottomSheet<_BibleLocation>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final books = BibleRepository.getBooks(widget.versionId).where((
            book,
          ) {
            return book.isNewTestament == newTestament &&
                (filter.isEmpty || book.name.toLowerCase().contains(filter));
          }).toList();
          return SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.88,
            child: Column(
              children: [
                _SheetHeader(
                  eyebrow: 'БІБЛІЯТЭКА',
                  title: 'Кнігі і раздзелы',
                  onClose: () => Navigator.pop(sheetContext),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    children: [
                      AdaptiveSegmentedControl<bool>(
                        segments: const [
                          AdaptiveSegment(
                            value: false,
                            label: Text('Стары Запавет'),
                          ),
                          AdaptiveSegment(
                            value: true,
                            label: Text('Новы Запавет'),
                          ),
                        ],
                        value: newTestament,
                        onChanged: (value) => setSheetState(() {
                          newTestament = value;
                          expandedBookId = null;
                        }),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Знайсці кнігу',
                          prefixIcon: PhosphorIcon(
                            PhosphorIconsRegular.magnifyingGlass,
                            size: 19,
                          ),
                        ),
                        onChanged: (value) => setSheetState(
                          () => filter = value.trim().toLowerCase(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      final expanded = expandedBookId == book.id;
                      return Column(
                        children: [
                          ListTile(
                            key: Key('bible-book-${book.id}'),
                            title: Text(book.name),
                            trailing: Badge(
                              label: Text('${book.chapterCount}'),
                            ),
                            selected: expanded,
                            onTap: () => setSheetState(
                              () => expandedBookId = expanded ? null : book.id,
                            ),
                          ),
                          if (expanded) _chapterGrid(sheetContext, book),
                          Divider(
                            height: 1,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (result != null && mounted) _navigate(result.bookId, result.chapter);
  }

  Widget _chapterGrid(BuildContext sheetContext, BibleBookInfo book) =>
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 52,
          mainAxisSpacing: 7,
          crossAxisSpacing: 7,
        ),
        itemCount: book.chapterCount,
        itemBuilder: (context, index) {
          final chapter = index + 1;
          final active = book.id == widget.bookId && chapter == widget.chapter;
          void onPressed() =>
              Navigator.pop(sheetContext, _BibleLocation(book.id, chapter));
          return active
              ? FilledButton(
                  key: Key('bible-chapter-${book.id}-$chapter'),
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                  ),
                  child: Text('$chapter'),
                )
              : OutlinedButton(
                  key: Key('bible-chapter-${book.id}-$chapter'),
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                  ),
                  child: Text('$chapter'),
                );
        },
      );

  Future<void> _openSearch(BibleBookInfo currentBook) => context.push(
    Uri(
      path: '/bible/search',
      queryParameters: {'version': widget.versionId, 'book': currentBook.id},
    ).toString(),
  );
}

class _ChromeAction extends StatelessWidget {
  const _ChromeAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => AdaptiveChromeSurface(
    role: ChromeSurfaceRole.control,
    borderRadius: BorderRadius.circular(24),
    child: SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: PhosphorIcon(icon, size: 22),
      ),
    ),
  );
}

class _VerseRow extends StatelessWidget {
  final int verseNum;
  final String text;
  final TextStyle textStyle;
  final Color? highlightColor;
  final bool selected;
  final VoidCallback onTap;

  const _VerseRow({
    super.key,
    required this.verseNum,
    required this.text,
    required this.textStyle,
    required this.highlightColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chromeController = ReaderChromeModeScope.maybeControllerOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: highlightColor ?? Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: selected
              ? BorderSide(color: cs.primary, width: 2)
              : BorderSide.none,
        ),
        child: Semantics(
          button: true,
          selected: selected,
          label: 'Верш $verseNum. $text',
          onTap: onTap,
          excludeSemantics: true,
          child: InkWell(
            key: Key('bible-verse-$verseNum'),
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            onDoubleTap: chromeController?.toggleFullscreen,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: RichText(
                key: Key('bible-verse-body-$verseNum'),
                textScaler: MediaQuery.textScalerOf(context),
                text: TextSpan(
                  style: textStyle.copyWith(
                    color: ReaderTheme.of(context).ink,
                    height: ReaderTheme.bodyHeight,
                  ),
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.top,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6, top: 1),
                        child: Text(
                          '$verseNum',
                          style: TextStyle(
                            color: cs.tertiary,
                            fontSize: (textStyle.fontSize ?? 16) * 0.64,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    TextSpan(text: text),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterNavBar extends StatelessWidget {
  final BibleBookInfo book;
  final int chapter;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onCurrent;
  final VoidCallback onNext;

  const _ChapterNavBar({
    required this.book,
    required this.chapter,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onCurrent,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    key: const Key('bible-chapter-navigation'),
    top: false,
    bottom: false,
    child: AdaptiveChromeSurface(
      role: ChromeSurfaceRole.group,
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            SizedBox(
              width: 54,
              child: IconButton(
                key: const Key('bible-previous-chapter'),
                tooltip: 'Папярэдні раздзел',
                onPressed: hasPrevious ? onPrevious : null,
                icon: const PhosphorIcon(PhosphorIconsBold.caretLeft, size: 22),
              ),
            ),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(
              child: TextButton.icon(
                key: const Key('bible-book-chapter-picker'),
                onPressed: onCurrent,
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.bookOpenText,
                  size: 20,
                ),
                label: Text(
                  '${book.name} $chapter',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            SizedBox(
              width: 54,
              child: IconButton(
                key: const Key('bible-next-chapter'),
                tooltip: 'Наступны раздзел',
                onPressed: hasNext ? onNext : null,
                icon: const PhosphorIcon(
                  PhosphorIconsBold.caretRight,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final VoidCallback onClose;

  const _SheetHeader({
    required this.eyebrow,
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Закрыць',
          onPressed: onClose,
          icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 21),
        ),
      ],
    ),
  );
}

class _BibleLocation {
  final String bookId;
  final int chapter;
  const _BibleLocation(this.bookId, this.chapter);
}
