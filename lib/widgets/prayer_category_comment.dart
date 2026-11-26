import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mybrev_flutter/constants/source_bibliography.dart';
import 'package:mybrev_flutter/models/prayer_menu_category.dart';
import 'package:mybrev_flutter/widgets/prayer_content.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';

class PrayerCategoryCommentSection extends StatefulWidget {
  const PrayerCategoryCommentSection({
    super.key,
    required this.comment,
    this.onLinkTap,
  });

  final PrayerCategoryComment comment;
  final OnTap? onLinkTap;

  @override
  State<PrayerCategoryCommentSection> createState() =>
      _PrayerCategoryCommentSectionState();
}

class _PrayerCategoryCommentSectionState
    extends State<PrayerCategoryCommentSection>
    with AutomaticKeepAliveClientMixin<PrayerCategoryCommentSection> {
  bool _expanded = false;

  @override
  bool get wantKeepAlive => _expanded;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;
    final comment = widget.comment;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Semantics(
              expanded: _expanded,
              child: ListTile(
                title: Text(comment.title ?? 'Пра гэты раздзел'),
                trailing: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                ),
                onTap: () {
                  setState(() => _expanded = !_expanded);
                  updateKeepAlive();
                },
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ReadingScaffold(
                builder: (context, textStyle) => SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PrayerDocumentBody(
                        markdown: comment.content,
                        textStyle: textStyle,
                        onLinkTap: widget.onLinkTap,
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
        ],
      ),
    );
  }
}
