import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/constants/source_bibliography.dart';
import 'package:mybrev_flutter/providers/prayer_categories_provider.dart';
import 'package:mybrev_flutter/providers/priest_access_provider.dart';
import 'package:mybrev_flutter/utils/prayer_link.dart';
import 'package:mybrev_flutter/widgets/prayer_content.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';

const _fallbackTitle = 'Пра гэты раздзел';

int _commentRevision(PrayerCategoryComment comment) =>
    Object.hash(comment.content, comment.title, comment.sourceId);

class PrayerCategoryCommentButton extends StatelessWidget {
  const PrayerCategoryCommentButton({
    super.key,
    required this.category,
    required this.onOpenPrayer,
    this.accessGeneration,
  });

  final PrayerMenuCategory category;
  final int? accessGeneration;
  final ValueChanged<String> onOpenPrayer;

  Future<void> _open(BuildContext context) async {
    final categoryId = category.id;
    final generation = accessGeneration;
    final revision = generation == null
        ? null
        : _commentRevision(category.comment!);
    final location = await showDialog<String>(
      context: context,
      fullscreenDialog: true,
      useSafeArea: false,
      barrierDismissible: false,
      builder: (_) => _PrayerCategoryCommentReader(
        categoryId: categoryId,
        accessGeneration: generation,
        commentRevision: revision,
      ),
    );
    if (context.mounted && location != null) onOpenPrayer(location);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: () => _open(context),
        style: TextButton.styleFrom(
          foregroundColor: colors.onSurface,
          backgroundColor: colors.surfaceContainerLow,
          minimumSize: const Size(48, 48),
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Flexible(child: Text(category.comment?.title ?? _fallbackTitle)),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new, size: 16, color: colors.primary),
          ],
        ),
      ),
    );
  }
}

class _PrayerCategoryCommentReader extends ConsumerWidget {
  const _PrayerCategoryCommentReader({
    required this.categoryId,
    required this.accessGeneration,
    required this.commentRevision,
  });

  final String categoryId;
  final int? accessGeneration;
  final int? commentRevision;

  PrayerMenuCategory? _currentCategory(WidgetRef ref) {
    final generation = accessGeneration;
    if (generation != null &&
        !ref.watch(
          priestAccessProvider.select(
            (access) =>
                access.generation == generation && access.content != null,
          ),
        )) {
      return null;
    }
    final categories = ref.watch(prayerMenuCategoriesProvider);
    for (final category in categories) {
      final comment = category.comment;
      if (category.id == categoryId &&
          category.isGlobal &&
          category.isProtected == (generation != null) &&
          comment != null &&
          (commentRevision == null ||
              _commentRevision(comment) == commentRevision)) {
        return category;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = _currentCategory(ref);
    if (category == null) {
      // Render no private text while removing just this dialog, even if
      // another route was pushed in the same frame.
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route != null && route.isActive) {
          route.navigator?.removeRoute(route);
        }
      });
      return const SizedBox.shrink();
    }

    final comment = category.comment!;
    final title = comment.title ?? _fallbackTitle;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category.readerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыць',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('category-comment-reader-scroll'),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ReadingScaffold(
                      builder: (context, textStyle) => SelectionArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: textStyle.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: (textStyle.fontSize ?? 16) * 1.4,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            PrayerDocumentBody(
                              markdown: comment.content,
                              textStyle: textStyle,
                              onLinkTap: (url, _, _) {
                                final location = prayerLinkLocation(url);
                                if (location != null) {
                                  Navigator.of(context).pop(location);
                                }
                              },
                            ),
                            PrayerSourceNote(
                              source: kPublicSourceBibliography
                                  .where((item) => item.id == comment.sourceId)
                                  .firstOrNull
                                  ?.title,
                              textStyle: textStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
