import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/devotional_office.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';
import 'package:mybrev_flutter/widgets/prayer_content.dart';
import 'package:mybrev_flutter/widgets/psalm_choir_html.dart';

/// Semantic presentation only. The containing PrayerDetailScreen still owns
/// access, favorites, navigation, offline data, scrolling and reading settings.
class DevotionalOfficeReader extends ConsumerStatefulWidget {
  const DevotionalOfficeReader({
    super.key,
    required this.document,
    required this.textStyle,
    this.onLinkTap,
  });
  final DevotionalOfficeDocument document;
  final TextStyle textStyle;
  final OnTap? onLinkTap;
  @override
  ConsumerState<DevotionalOfficeReader> createState() =>
      _DevotionalOfficeReaderState();
}

class _DevotionalOfficeReaderState
    extends ConsumerState<DevotionalOfficeReader> {
  final _choir = ValueNotifier<int?>(null);
  int? _intention;
  final _choices = <String, int>{};
  @override
  void didUpdateWidget(DevotionalOfficeReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.prayerId != widget.document.prayerId ||
        oldWidget.document.source != widget.document.source) {
      _intention = null;
      _choices.clear();
      _choir.value = null;
    }
  }

  @override
  void dispose() {
    _choir.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final doc = widget.document;
    return PsalmodyScope(
      controller: _choir,
      mode: settings.psalmodyMode,
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final section in doc.sections)
              if (section.type != 'alternatives' &&
                  section.blocks.any((b) => b.level != 1))
                _section(context, section),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, DevotionalSection section) {
    final doc = widget.document;
    final reader = ReaderTheme.of(context);
    final size = widget.textStyle.fontSize ?? 16;
    final title = doc.profile == 'gadzinki'
        ? section.title
        : switch (section.type) {
            'intro' => doc.profile == 'laudes' ? 'Ютрань' : 'Нешпары',
            'canticle' => 'Песня з Евангелля',
            'reading' => '',
            _ => section.title,
          };
    final choices = doc.choices(section);
    final needsIntention =
        doc.forDead && {'hymn', 'prayer'}.contains(section.type);
    final blocks = doc.selectedBlocks(
      section,
      intention: _intention,
      choice: _choices[section.type] ?? 0,
    );
    return Column(
      key: ValueKey('devotional-section-${section.type}-$title'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty)
          Semantics(
            header: true,
            child: LiturgicalSectionHeading(
              title: title,
              bodySize: size,
              startsSection: true,
            ),
          ),
        if (section.type == 'canticle')
          Padding(
            padding: const EdgeInsets.only(
              bottom: LiturgicalSpacing.metadataToBody,
            ),
            child: Text(section.title, style: reader.psalmSubtitle(size)),
          ),
        if (doc.forDead && section.type == 'hymn')
          _options(
            context,
            'Намер малітвы за памерлых',
            devotionalDeadIntentions,
            _intention,
            (i) => setState(() => _intention = i),
            'intention',
          ),
        if (choices.isNotEmpty)
          _options(
            context,
            '${section.title}: намер',
            choices.map((c) => c.label).toList(),
            _choices[section.type] ?? 0,
            (i) => setState(() => _choices[section.type] = i),
            section.type,
          ),
        if (needsIntention && blocks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _intention == null
                  ? 'Абярыце намерэнне перад гімнам, каб паказаць поўны тэкст.'
                  : 'Тэкст для гэтага намеру недаступны.',
              style: reader.rubricBlock(size),
            ),
          ),
        for (final item in devotionalDisplayItems(section, blocks))
          _item(context, item),
      ],
    );
  }

  Widget _options(
    BuildContext context,
    String label,
    List<String> labels,
    int? selected,
    ValueChanged<int> onChanged,
    String key,
  ) => Semantics(
    container: true,
    label: label,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (var i = 0; i < labels.length; i++)
            ChoiceChip(
              key: ValueKey('devotional-$key-$i'),
              label: Text(labels[i], softWrap: true),
              selected: selected == i,
              onSelected: (_) => onChanged(i),
              labelStyle: TextStyle(
                fontFamily: widget.textStyle.fontFamily,
                fontSize: widget.textStyle.fontSize,
                color: selected == i
                    ? ReaderTheme.of(context).rubric
                    : ReaderTheme.of(context).ink,
              ),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
        ],
      ),
    ),
  );
  Widget _item(BuildContext context, DevotionalItem item) {
    final body = widget.textStyle;
    final size = body.fontSize ?? 16;
    final reader = ReaderTheme.of(context);
    final styles = {
      ...prayerDocumentStyles(context, body),
      ...liturgicalDocumentStyles(reader: reader, body: body),
    };
    switch (item.kind) {
      case 'heading':
      case 'readingTitle':
      case 'responseTitle':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: LiturgicalSectionHeading(
                title: item.kind == 'readingTitle'
                    ? 'Кароткае чытанне'
                    : item.text,
                bodySize: size,
                startsSection: true,
              ),
            ),
            if (item.reference.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: LiturgicalSpacing.metadataToBody,
                ),
                child: Text(
                  item.reference,
                  style: reader.rubricReference(size),
                ),
              ),
          ],
        );
      case 'psalmTitle':
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(
              item.text,
              textAlign: TextAlign.center,
              style: body.copyWith(
                color: reader.rubric,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      case 'psalmMeta':
        return Html(
          data: prayerMarkdownToHtml(item.source),
          style: {
            ...styles,
            'p': Style(
              textAlign: TextAlign.center,
              fontSize: FontSize(reader.metadata(size).fontSize!),
              color: reader.muted,
              margin: Margins.only(bottom: 7),
            ),
          },
        );
      case 'psalmBody':
        return PsalmChoirHtml(
          html: formatPsalmHtml(
            prayerMarkdownToHtml(item.source, recognizeSpeakers: false),
          ),
          style: {
            ...styles,
            '.psalm-strophe': Style(
              margin: Margins.only(bottom: LiturgicalSpacing.paragraphAfter),
            ),
            '.psalm-strophe-even': Style(
              margin: Margins.only(
                left: 16,
                bottom: LiturgicalSpacing.paragraphAfter,
              ),
            ),
          },
          textColor: body.color ?? reader.ink,
          rubricColor: reader.rubric,
        );
      case 'antiphon':
        return Html(
          data: markLiturgicalCadenceSigns(
            devotionalSpeakerHtml(item.source).replaceFirstMapped(
              RegExp(
                r'(<p>)([1-3]?\s*[Аа]нт\.(?:\s+да\s+песні\s+(?:Захарыі|Марыі))?:?)',
              ),
              (m) =>
                  '${m[1]}<span class="liturgical-rubric-inline">${m[2]}</span>',
            ),
          ),
          style: styles,
        );
      case 'responsoryBody':
        return LiturgicalResponsoryBlock(
          html: devotionalSpeakerHtml(item.source, responsory: true),
          style: {
            ...styles,
            'p': Style(
              margin: Margins.only(bottom: 8),
              lineHeight: LineHeight(ReaderTheme.responsoryHeight),
            ),
          },
        );
      case 'separator':
        return const LiturgicalSectionDivider();
      default:
        // Reuse the ordinary safe reader for prose, verse and explicit rubrics.
        // Only office-specific speaker forms need the semantic projection.
        if (!RegExp(
          r'(?:\*\*|^|\n)(?:Кантар:|Мол[іi]мся:|[КНС][.:])',
        ).hasMatch(item.source)) {
          return PrayerContent(
            prayer: Prayer(
              id: '',
              title: '',
              body: item.source,
              textFormat: 'mybrev-markdown',
            ),
            textStyle: body,
            onLinkTap: widget.onLinkTap,
            wrapInSelectionArea: false,
          );
        }
        return Html(
          data: devotionalSpeakerHtml(item.source),
          style: styles,
          onLinkTap: widget.onLinkTap,
        );
    }
  }
}
