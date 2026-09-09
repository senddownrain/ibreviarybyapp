import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';
import 'package:mybrev_flutter/widgets/adaptive_segmented_control.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';
import 'package:mybrev_flutter/navigation/app_navigation.dart';

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
  static const _colors = <String, Color>{
    'amber': Color(0xFFE2AE34),
    'rose': Color(0xFFD37074),
    'sky': Color(0xFF4F9FC1),
    'leaf': Color(0xFF59A46B),
  };
  final Map<int, String> _highlights = {};
  final Set<int> _selected = {};
  final Map<int, GlobalKey> _verseKeys = {};
  int? _requestedVerse;
  bool _bottomSlotInitialized = false;

  String get _highlightKey =>
      'bibleHighlight:${widget.versionId}:${widget.bookId}:${widget.chapter}';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void didUpdateWidget(covariant BibleChapterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.versionId != widget.versionId ||
        oldWidget.bookId != widget.bookId ||
        oldWidget.chapter != widget.chapter) {
      _selected.clear();
      AppRouteEntryScope.maybeOf(context)?.showContextualBottomBar(false);
      _verseKeys.clear();
      _loadState();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    HiveService.settingsBox.put('bibleLastLocation:${widget.versionId}', {
      'bookId': widget.bookId,
      'chapter': widget.chapter,
    });
  }

  Future<void> _saveHighlights() => HiveService.settingsBox.put(_highlightKey, {
    for (final item in _highlights.entries) '${item.key}': item.value,
  });

  @override
  Widget build(BuildContext context) {
    final book = BibleRepository.getBook(widget.versionId, widget.bookId);
    if (book == null ||
        widget.chapter < 1 ||
        widget.chapter > book.chapterCount) {
      return Scaffold(
        appBar: AdaptiveAppBar.text('Біблія'),
        body: Center(
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
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    return PopScope<void>(
      canPop: _selected.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selected.isNotEmpty) {
          setState(_selected.clear);
          AppRouteEntryScope.maybeOf(context)?.showContextualBottomBar(false);
        }
      },
      child: ReadingScaffold(
        builder: (context, textStyle) => Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AdaptiveAppBar.text(
            'Біблія',
            actions: const [TextScaleControl()],
          ),
          body: Stack(
            children: [
              AmbientWash.hero(seasonColor: seasonColor),
              Positioned.fill(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    MediaQuery.paddingOf(context).top +
                        kFloatingReaderAppBarContentInset +
                        12,
                    12,
                    _selected.isEmpty ? 92 : 164,
                  ),
                  children: [
                    _toolbar(book),
                    const SizedBox(height: 14),
                    _heading(book, seasonColor),
                    const SizedBox(height: 14),
                    GlassSurface(
                      style: GlassStyle.card,
                      seasonColor: seasonColor,
                      borderRadius: BorderRadius.circular(26),
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                      child: verses.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: Text('У гэтым раздзеле няма тэксту.'),
                              ),
                            )
                          : Column(
                              children: [
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
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              if (_selected.isNotEmpty)
                Positioned(left: 12, right: 12, bottom: 80, child: _colorBar()),
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: _ChapterNavBar(
                  book: book,
                  chapter: widget.chapter,
                  hasPrevious: _relative(-1) != null,
                  hasNext: _relative(1) != null,
                  onPrevious: () => _goRelative(-1),
                  onCurrent: () => _openPicker(book),
                  onNext: () => _goRelative(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar(BibleBookInfo book) => Row(
    children: [
      GlassSurface(
        style: GlassStyle.soft,
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final version in kBibleVersionMeta.values)
              _LanguageButton(
                label: version.shortLabel,
                selected: widget.versionId == version.id,
                onTap: () => _changeLanguage(version.id, book),
              ),
          ],
        ),
      ),
      const Spacer(),
      GlassSurface(
        style: GlassStyle.pill,
        borderRadius: BorderRadius.circular(24),
        child: IconButton(
          tooltip: 'Пошук у Бібліі',
          onPressed: () => _openSearch(book),
          icon: const PhosphorIcon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 22,
          ),
        ),
      ),
    ],
  );

  Widget _heading(BibleBookInfo book, Color seasonColor) {
    final meta = kBibleVersionMeta[widget.versionId]!;
    return GlassSurface(
      style: GlassStyle.card,
      seasonColor: seasonColor,
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openPicker(book),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${book.isNewTestament ? 'НОВЫ ЗАПАВЕТ' : 'СТАРЫ ЗАПАВЕТ'} · ${meta.langLabel.toUpperCase()}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.tertiary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.12,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Раздзел ${widget.chapter}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const PhosphorIcon(PhosphorIconsBold.caretDown, size: 20),
              ],
            ),
            const SizedBox(height: 15),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 10),
            Text(
              meta.attribution,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _colorBar() => GlassSurface(
    style: GlassStyle.pill,
    borderRadius: BorderRadius.circular(22),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Row(
      children: [
        if (MediaQuery.sizeOf(context).width >= 390)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '${_selected.length} ${_selected.length == 1 ? 'верш' : 'вершы'}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        const Spacer(),
        for (final color in _colors.entries)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _applyColor(color.key),
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
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Прыбраць вылучэнне',
          onPressed: () => _applyColor(null),
          icon: const PhosphorIcon(PhosphorIconsRegular.eraser, size: 20),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Скасаваць выбар',
          onPressed: () {
            setState(_selected.clear);
            AppRouteEntryScope.maybeOf(context)?.showContextualBottomBar(false);
          },
          icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 19),
        ),
      ],
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
    final books = BibleRepository.getBooks(widget.versionId);
    final index = books.indexWhere((item) => item.id == widget.bookId);
    if (index < 0) return null;
    final current = books[index];
    if (direction < 0 && widget.chapter > 1) {
      return _BibleLocation(current.id, widget.chapter - 1);
    }
    if (direction > 0 && widget.chapter < current.chapterCount) {
      return _BibleLocation(current.id, widget.chapter + 1);
    }
    final adjacentIndex = index + direction;
    if (adjacentIndex < 0 || adjacentIndex >= books.length) return null;
    final adjacent = books[adjacentIndex];
    return _BibleLocation(
      adjacent.id,
      direction < 0 ? adjacent.chapterCount : 1,
    );
  }

  void _goRelative(int direction) {
    final location = _relative(direction);
    if (location != null) _navigate(location.bookId, location.chapter);
  }

  void _navigate(String bookId, int chapter, {int? verse}) {
    context.replace(
      Uri(
        path: '/bible',
        queryParameters: {
          'version': widget.versionId,
          'book': bookId,
          'chapter': '$chapter',
          if (verse != null) 'verse': '$verse',
        },
      ).toString(),
    );
  }

  void _changeLanguage(String versionId, BibleBookInfo currentBook) {
    if (versionId == widget.versionId) return;
    final parallel = BibleRepository.getParallelBook(
      widget.versionId,
      currentBook.id,
      versionId,
    );
    final saved = HiveService.settingsBox.get('bibleLastLocation:$versionId');
    final savedBook = saved is Map
        ? BibleRepository.getBook(versionId, saved['bookId']?.toString() ?? '')
        : null;
    final target =
        parallel ??
        savedBook ??
        BibleRepository.getBooks(versionId).firstOrNull;
    if (target == null) return;
    final savedChapter = saved is Map
        ? int.tryParse(saved['chapter']?.toString() ?? '') ?? 1
        : 1;
    final chapter = (parallel == null ? savedChapter : widget.chapter).clamp(
      1,
      target.chapterCount,
    );
    ref.read(settingsProvider.notifier).setBibleVersion(versionId);
    context.replace(
      Uri(
        path: '/bible',
        queryParameters: {
          'version': versionId,
          'book': target.id,
          'chapter': '$chapter',
        },
      ).toString(),
    );
  }

  Future<void> _openPicker(BibleBookInfo currentBook) async {
    var newTestament = currentBook.isNewTestament;
    var filter = '';
    String? expandedBookId = currentBook.id;
    final result = await showModalBottomSheet<_BibleLocation>(
      context: context,
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
          return FractionallySizedBox(
            heightFactor: 0.88,
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
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                  ),
                  child: Text('$chapter'),
                )
              : OutlinedButton(
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                  ),
                  child: Text('$chapter'),
                );
        },
      );

  Future<void> _openSearch(BibleBookInfo currentBook) async {
    final controller = TextEditingController();
    final result = await showDialog<_SearchTarget>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = controller.text.trim().toLowerCase();
          final books = query.length < 2
              ? const <BibleBookInfo>[]
              : BibleRepository.getBooks(widget.versionId)
                    .where((book) => book.name.toLowerCase().contains(query))
                    .take(8)
                    .toList();
          final verses = BibleRepository.searchBook(
            widget.versionId,
            currentBook.id,
            query,
          );
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
              child: Column(
                children: [
                  _SheetHeader(
                    eyebrow: 'ПОШУК',
                    title: 'Знайсці ў Бібліі',
                    onClose: () => Navigator.pop(dialogContext),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Слова або назва кнігі',
                        prefixIcon: PhosphorIcon(
                          PhosphorIconsRegular.magnifyingGlass,
                          size: 21,
                        ),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 19),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Назвы — ва ўсіх кнігах · тэкст — у «${currentBook.name}»',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: query.length < 2
                        ? const Center(
                            child: Text('Увядзіце не менш за дзве літары.'),
                          )
                        : books.isEmpty && verses.isEmpty
                        ? const Center(child: Text('Нічога не знойдзена.'))
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                            children: [
                              if (books.isNotEmpty) ...[
                                const _SearchSectionTitle('Кнігі'),
                                for (final book in books)
                                  ListTile(
                                    leading: const PhosphorIcon(
                                      PhosphorIconsRegular.bookOpenText,
                                      size: 19,
                                    ),
                                    title: Text(book.name),
                                    trailing: const PhosphorIcon(
                                      PhosphorIconsRegular.caretRight,
                                      size: 17,
                                    ),
                                    onTap: () => Navigator.pop(
                                      dialogContext,
                                      _SearchTarget(book.id, 1),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                              ],
                              if (verses.isNotEmpty) ...[
                                _SearchSectionTitle(
                                  'Вершы · ${currentBook.name}',
                                ),
                                for (final item in verses)
                                  ListTile(
                                    title: Text(
                                      '${currentBook.name} ${item.chapter}:${item.verse.verse}',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.tertiary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      item.verse.text,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => Navigator.pop(
                                      dialogContext,
                                      _SearchTarget(
                                        currentBook.id,
                                        item.chapter,
                                        verse: item.verse.verse,
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
    if (result != null && mounted) {
      _navigate(result.bookId, result.chapter, verse: result.verse);
    }
  }
}

class _LanguageButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: selected
        ? FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size(58, 38),
              padding: const EdgeInsets.symmetric(horizontal: 13),
            ),
            child: Text(label),
          )
        : TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              minimumSize: const Size(58, 38),
              padding: const EdgeInsets.symmetric(horizontal: 13),
            ),
            child: Text(label),
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
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: RichText(
              text: TextSpan(
                style: textStyle.copyWith(color: cs.onSurface, height: 1.72),
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
    top: false,
    child: GlassSurface(
      style: GlassStyle.pill,
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            SizedBox(
              width: 54,
              child: IconButton(
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

class _SearchSectionTitle extends StatelessWidget {
  final String text;
  const _SearchSectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 7),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.tertiary,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}

class _BibleLocation {
  final String bookId;
  final int chapter;
  const _BibleLocation(this.bookId, this.chapter);
}

class _SearchTarget extends _BibleLocation {
  final int? verse;
  const _SearchTarget(super.bookId, super.chapter, {this.verse});
}
