import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';

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
  final Map<int, int> _verseColorIndex = <int, int>{};
  static const List<Color> _kHighlightBaseColors = [
    Color(0xFFFFEB3B), // yellow
    Color(0xFF81C784), // green
    Color(0xFF64B5F6), // blue
    Color(0xFFBA68C8), // purple
    Color(0xFFFF8A65), // orange
  ];

  String get _highlightStorageKey =>
      'bibleHighlight:${widget.versionId}:${widget.bookId}:${widget.chapter}';

  @override
  void initState() {
    super.initState();
    _loadHighlights();
  }

  @override
  void didUpdateWidget(covariant BibleChapterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final chapterChanged = oldWidget.chapter != widget.chapter;
    final bookChanged = oldWidget.bookId != widget.bookId;
    final versionChanged = oldWidget.versionId != widget.versionId;
    if (chapterChanged || bookChanged || versionChanged) {
      _loadHighlights();
      setState(() {});
    }
  }

  void _loadHighlights() {
    final raw = HiveService.settingsBox.get(_highlightStorageKey);
    _verseColorIndex.clear();
    if (raw is! Map) return;
    raw.forEach((k, v) {
      final verse = int.tryParse(k.toString());
      final colorIndex = v is num ? v.toInt() : int.tryParse(v.toString());
      if (verse == null || colorIndex == null) return;
      if (colorIndex < 0 || colorIndex >= _kHighlightBaseColors.length) return;
      _verseColorIndex[verse] = colorIndex;
    });
  }

  Future<void> _saveHighlights() async {
    final out = <String, int>{};
    _verseColorIndex.forEach((k, v) => out[k.toString()] = v);
    await HiveService.settingsBox.put(_highlightStorageKey, out);
  }

  @override
  Widget build(BuildContext context) {
    final book = BibleRepository.getBook(widget.versionId, widget.bookId);
    final verses =
        BibleRepository.getChapter(widget.versionId, widget.bookId, widget.chapter);

    if (book == null || verses.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Біблія')),
        body: const Center(child: Text('Раздзел не знойдзены')),
      );
    }

    return ReadingScaffold(
      builder: (context, textStyle) => Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(book.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              Text('Раздзел ${widget.chapter}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.2)),
            ],
          ),
          actions: [
            PopupMenuButton<double>(
              icon: const PhosphorIcon(PhosphorIconsRegular.textAa, size: 22),
              tooltip: 'Памер шрыфту',
              onSelected: (size) =>
                  ref.read(settingsProvider.notifier).setFontSize(size),
              itemBuilder: (_) {
                final current = ref.read(settingsProvider).fontSize;
                return [
                  for (final size in [14.0, 16.0, 18.0, 20.0, 24.0])
                    PopupMenuItem(
                      value: size,
                      child: Text(
                        '${size.toInt()} pt',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: size == current
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                ];
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (book.isVerseTextRussian)
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer
                    .withValues(alpha: 0.6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.translate,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Тэкст гэтае кнігі пададзены па-руску (сінод. пераклад), назва — па-беларуску.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                                height: 1.35,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                itemCount: verses.length,
                itemBuilder: (context, i) {
                  final v = verses[i];
                  return _VerseRow(
                    verseNum: v.verse,
                    text: v.text,
                    textStyle: textStyle,
                    highlightColor: _resolveHighlightColor(
                      context,
                      _verseColorIndex[v.verse],
                    ),
                    onTap: () => _pickVerseColor(v.verse),
                  );
                },
              ),
            ),
            _ChapterNavBar(
              versionId: widget.versionId,
              bookId: widget.bookId,
              chapter: widget.chapter,
              chapterCount: book.chapterCount,
            ),
          ],
        ),
      ),
    );
  }

  Color? _resolveHighlightColor(BuildContext context, int? colorIndex) {
    if (colorIndex == null ||
        colorIndex < 0 ||
        colorIndex >= _kHighlightBaseColors.length) {
      return null;
    }
    final base = _kHighlightBaseColors[colorIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return base.withValues(alpha: isDark ? 0.32 : 0.42);
  }

  Future<void> _pickVerseColor(int verseNum) async {
    final picked = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final current = _verseColorIndex[verseNum];
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Стих $verseNum: цвет выделения',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < _kHighlightBaseColors.length; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: i == _kHighlightBaseColors.length - 1 ? 0 : 8,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(context, i),
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _kHighlightBaseColors[i],
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: current == i
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.black26,
                                    width: current == i ? 3 : 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, -1),
                  icon: const PhosphorIcon(PhosphorIconsRegular.eraser, size: 18),
                  label: const Text('Убрать выделение'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (picked < 0) {
        _verseColorIndex.remove(verseNum);
      } else {
        _verseColorIndex[verseNum] = picked;
      }
    });
    await _saveHighlights();
  }
}

// ── Verse row ─────────────────────────────────────────────────────────────────

class _VerseRow extends StatelessWidget {
  final int verseNum;
  final String text;
  final TextStyle textStyle;
  final Color? highlightColor;
  final VoidCallback onTap;

  const _VerseRow({
    required this.verseNum,
    required this.text,
    required this.textStyle,
    required this.highlightColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final numSize = (textStyle.fontSize ?? 16) * 0.72;
    final colors = Theme.of(context).colorScheme;
    final verseTextStyle = textStyle.copyWith(
      color: colors.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: highlightColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: RichText(
              text: TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Text(
                        '$verseNum',
                        style: TextStyle(
                          fontSize: numSize,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                          fontFamily: textStyle.fontFamily,
                        ),
                      ),
                    ),
                  ),
                  TextSpan(text: text, style: verseTextStyle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Prev / next bar ───────────────────────────────────────────────────────────

class _ChapterNavBar extends StatelessWidget {
  final String versionId;
  final String bookId;
  final int chapter;
  final int chapterCount;

  const _ChapterNavBar({
    required this.versionId,
    required this.bookId,
    required this.chapter,
    required this.chapterCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrev = chapter > 1;
    final hasNext = chapter < chapterCount;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: hasPrev
                  ? TextButton.icon(
                      onPressed: () => _go(context, chapter - 1),
                      icon: const PhosphorIcon(PhosphorIconsRegular.caretLeft, size: 18),
                      label: Text('Раздзел ${chapter - 1}'),
                    )
                  : const SizedBox.shrink(),
            ),
            Text(
              '$chapter / $chapterCount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Expanded(
              child: hasNext
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _go(context, chapter + 1),
                        label: Text('Раздзел ${chapter + 1}'),
                        icon: const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 18),
                        iconAlignment: IconAlignment.end,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, int ch) {
    context.pushReplacement('/bible/$versionId/$bookId/$ch');
  }
}
