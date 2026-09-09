import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/navigation/bible_navigation.dart';
import 'package:mybrev_flutter/repositories/bible_repository.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';

/// Preserves the production Bible search scope: book names across the current
/// translation and verse text inside the current book only.
class BibleSearchScreen extends StatefulWidget {
  const BibleSearchScreen({
    super.key,
    required this.versionId,
    required this.bookId,
  });

  final String versionId;
  final String bookId;

  @override
  State<BibleSearchScreen> createState() => _BibleSearchScreenState();
}

class _BibleSearchScreenState extends State<BibleSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentBook = BibleRepository.getBook(
      widget.versionId,
      widget.bookId,
    );
    if (currentBook == null) {
      return Scaffold(
        appBar: AdaptiveAppBar.text(
          'Пошук у Бібліі',
          seasonColor: Colors.transparent,
        ),
        body: const Center(child: Text('Кніга для пошуку не знойдзена.')),
      );
    }
    final query = _controller.text.trim().toLowerCase();
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AdaptiveAppBar.text(
        'Пошук у Бібліі',
        seasonColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top +
                    kFloatingAppBarContentInset +
                    8,
                16,
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const Key('bible-search-field'),
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Слова або назва кнігі',
                      prefixIcon: PhosphorIcon(
                        PhosphorIconsRegular.magnifyingGlass,
                        size: 21,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Назвы — ва ўсіх кнігах · тэкст — у «${currentBook.name}»',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
                      key: const PageStorageKey('bible-search-results'),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                      children: [
                        if (books.isNotEmpty) ...[
                          const _SectionTitle('Кнігі'),
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
                              onTap: () => _open(
                                BibleLocation(
                                  versionId: widget.versionId,
                                  bookId: book.id,
                                  chapter: 1,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                        if (verses.isNotEmpty) ...[
                          _SectionTitle('Вершы · ${currentBook.name}'),
                          for (final item in verses)
                            ListTile(
                              key: Key(
                                'bible-search-verse-${item.chapter}-${item.verse.verse}',
                              ),
                              title: Text(
                                '${currentBook.name} ${item.chapter}:${item.verse.verse}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.tertiary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                item.verse.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _open(
                                BibleLocation(
                                  versionId: widget.versionId,
                                  bookId: currentBook.id,
                                  chapter: item.chapter,
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
  }

  void _open(BibleLocation location) =>
      context.push(BibleNavigation.route(location, searchResult: true));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

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
