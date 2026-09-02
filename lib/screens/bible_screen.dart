import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/widgets/ios_app_bar.dart';

class BibleScreen extends ConsumerStatefulWidget {
  const BibleScreen({super.key});

  @override
  ConsumerState<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends ConsumerState<BibleScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openChapterPicker(BibleBookInfo book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ChapterPicker(book: book),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final currentVersionId = settings.bibleVersionId;
    final availableVersions = BibleRepository.getAvailableVersions();

    // All possible versions (for the switcher), marking which are available
    final allVersionMeta = kBibleVersionMeta.entries.toList();

    final books = BibleRepository.getBooks(currentVersionId);
    final filtered = _query.isEmpty
        ? books
        : books.where((b) => b.name.toLowerCase().contains(_query)).toList();

    final ot = filtered.where((b) => b.order <= 39).toList();
    final nt = filtered.where((b) => b.order >= 40).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: IosGlassAppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Пошук кнігі...',
                  border: InputBorder.none,
                ),
                style: Theme.of(context).textTheme.titleMedium,
              )
            : const Text('Біблія'),
        actions: [
          if (books.isNotEmpty)
            IconButton(
              icon: PhosphorIcon(_searching ? PhosphorIconsRegular.x : PhosphorIconsRegular.magnifyingGlass, size: 20),
              onPressed: () {
                setState(() {
                  _searching = !_searching;
                  if (!_searching) _searchCtrl.clear();
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Version picker ─────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + kToolbarHeight + 8, 16, 4),
            child: SegmentedButton<String>(
              segments: allVersionMeta.map((e) {
                final isAvailable =
                    availableVersions.any((v) => v.id == e.key);
                return ButtonSegment<String>(
                  value: e.key,
                  label: Text(
                    e.value.langLabel,
                    style: TextStyle(
                      color: isAvailable
                          ? null
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.38),
                    ),
                  ),
                  enabled: isAvailable,
                );
              }).toList(),
              selected: {currentVersionId},
              onSelectionChanged: (s) {
                ref
                    .read(settingsProvider.notifier)
                    .setBibleVersion(s.first);
              },
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          if (availableVersions.length < allVersionMeta.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Беларуская Біблія загружаецца ў фонавым рэжыме',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
          // ── Book list ──────────────────────────────────────────────────────
          Expanded(
            child: books.isEmpty
                ? _EmptyState()
                : CustomScrollView(
                    slivers: [
                      if (ot.isNotEmpty) ...[
                        _SectionHeader('Стары Запавет'),
                        _BookList(books: ot, onTap: _openChapterPicker),
                      ],
                      if (nt.isNotEmpty) ...[
                        _SectionHeader('Новы Запавет'),
                        _BookList(books: nt, onTap: _openChapterPicker),
                      ],
                      if (ot.isEmpty && nt.isEmpty)
                        SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'Нічога не знойдзена',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ),
                      const SliverPadding(
                          padding: EdgeInsets.only(bottom: 24)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Sliver helpers ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  final List<BibleBookInfo> books;
  final void Function(BibleBookInfo) onTap;
  const _BookList({required this.books, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemCount: books.length,
      itemBuilder: (context, i) {
        final book = books[i];
        return ListTile(
          title: Text(book.name),
          subtitle: book.isVerseTextRussian
              ? Text(
                  'тэкст па-руску',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
                        fontStyle: FontStyle.italic,
                      ),
                )
              : null,
          isThreeLine: book.isVerseTextRussian,
          trailing: Text(
            '${book.chapterCount} гл.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          onTap: () => onTap(book),
        );
      },
    );
  }
}

// ── Chapter picker bottom sheet ───────────────────────────────────────────────

class _ChapterPicker extends ConsumerWidget {
  final BibleBookInfo book;
  const _ChapterPicker({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionId = ref.watch(settingsProvider).bibleVersionId;
    final screenH = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenH * 0.6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(book.name,
                    style: Theme.of(context).textTheme.titleMedium),
                if (book.isVerseTextRussian) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Тэкст раздзелаў — па-руску (сінод.)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.tertiary,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 56,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: book.chapterCount,
              itemBuilder: (context, i) {
                final ch = i + 1;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/bible/$versionId/${book.id}/$ch');
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$ch',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(PhosphorIconsLight.bookOpen,
              size: 56, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Біблія загружаецца...',
              style: TextStyle(color: cs.onSurface)),
          const SizedBox(height: 8),
          Text(
            'Перазапусціце дадатак,\nкалі гэтае паведамленне застаецца',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
