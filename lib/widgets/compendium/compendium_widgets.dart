import 'package:mybrev_flutter/utils/reader_prose.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/widgets/source_footer.dart';

import 'package:mybrev_flutter/constants/compendium.dart';
import 'package:mybrev_flutter/models/compendium.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/compendium_data.dart';

/// Opens the source page in the external browser (the same mechanism as the
/// About screen). Overridable in tests.
final compendiumLinkLauncherProvider = sourceLinkLauncherProvider;

/// Visible attribution with a link to the Catholic.by source page, shown on
/// every Compendium screen.
class CompendiumSourceAttribution extends ConsumerWidget {
  const CompendiumSourceAttribution({
    super.key,
    this.onReader = false,
    this.readerTextStyle,
  });

  /// Uses reader surface colours (inside [ReaderContentSurface]).
  final bool onReader;
  final TextStyle? readerTextStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final reader = ReaderTheme.of(context);
    final muted = reader.muted;
    final settings = ref.watch(settingsProvider);
    final link = onReader
        ? reader.rubric
        : GlassTokens.of(context).accentOnSurface(cs.tertiary);
    return SourceFooter(
      sourceId: 'compendium-kkbb-2010',
      sourceName: '$kCompendiumFullTitle, $kCompendiumSourceHost',
      textStyle: onReader && readerTextStyle != null
          ? reader
                .sourceStyle(readerTextStyle!.fontSize ?? 16)
                .copyWith(fontFamily: readerTextStyle!.fontFamily)
          : reader
                .sourceStyle(settings.fontSize, family: settings.fontFamily)
                .copyWith(color: muted),
      linkColor: link,
      topSpacing: onReader ? 28 : 20,
      verticalPadding: 12,
      borderColor: onReader ? reader.border : cs.outlineVariant,
      linkKey: const Key('compendium-source'),
      semanticLabel: 'Крыніца: $kCompendiumFullTitle на $kCompendiumSourceHost',
    );
  }
}

/// Number (or Roman numeral) badge in the Prayerbook tile style.
class CompendiumBadge extends StatelessWidget {
  const CompendiumBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = GlassTokens.of(context).accentOnSurface(cs.tertiary);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.tertiary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A navigation row on the Compendium list screens (same structure as the
/// songbook and prayer rows: text, then a chevron).
///
/// The hierarchy levels are the wrappers below ([CompendiumSectionRow],
/// [CompendiumSubsectionRow], [CompendiumTopicRow], [CompendiumQuestionRow]);
/// they differ in typography and spacing only, never in colour.
class CompendiumListRow extends StatelessWidget {
  const CompendiumListRow({
    super.key,
    required this.title,
    required this.onTap,
    this.leading,
    this.eyebrow,
    this.subtitle,
    this.titleStyle,
    this.eyebrowStyle,
    this.verticalPadding = 12,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback onTap;

  /// Merged over the default `titleMedium` title style.
  final TextStyle? titleStyle;

  /// Merged over the default accent `labelSmall` eyebrow style.
  final TextStyle? eyebrowStyle;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 62),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: verticalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((eyebrow ?? '').isNotEmpty) ...[
                        Text(
                          eyebrow!,
                          style: textTheme.labelSmall
                              ?.copyWith(
                                color: GlassTokens.of(
                                  context,
                                ).accentOnSurface(cs.tertiary),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              )
                              .merge(eyebrowStyle),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        title,
                        style: textTheme.titleMedium
                            ?.copyWith(height: 1.3)
                            .merge(titleStyle),
                      ),
                      if ((subtitle ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// РАЗДЗЕЛ: the major destination of a part outline. Accent eyebrow, the
/// largest row title and the widest spacing.
class CompendiumSectionRow extends StatelessWidget {
  const CompendiumSectionRow({super.key, required this.node, this.onTap});

  final CompendiumNavNode node;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return CompendiumListRow(
      eyebrow: node.displayLabel,
      title: node.title,
      subtitle: node.rangeLabel,
      verticalPadding: 18,
      eyebrowStyle: TextStyle(
        fontSize: textTheme.labelMedium?.fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
      titleStyle: TextStyle(
        fontSize: textTheme.titleLarge?.fontSize,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      onTap: onTap ?? () => context.push(compendiumNodeLocation(node.id)),
    );
  }
}

/// ПАДРАЗДЗЕЛ: a secondary destination inside a section. Small accent
/// eyebrow and a `titleMedium` title, one step below [CompendiumSectionRow].
class CompendiumSubsectionRow extends StatelessWidget {
  const CompendiumSubsectionRow({super.key, required this.node, this.onTap});

  final CompendiumNavNode node;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => CompendiumListRow(
    eyebrow: node.displayLabel,
    title: node.title,
    subtitle: node.rangeLabel,
    verticalPadding: 14,
    eyebrowStyle: const TextStyle(letterSpacing: 0.9),
    titleStyle: const TextStyle(fontWeight: FontWeight.w700),
    onTap: onTap ?? () => context.push(compendiumNodeLocation(node.id)),
  );
}

/// A named topic: its real title and question range, with no generic level
/// label and a lighter title than [CompendiumSubsectionRow].
class CompendiumTopicRow extends StatelessWidget {
  const CompendiumTopicRow({super.key, required this.node, this.onTap});

  final CompendiumNavNode node;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => CompendiumListRow(
    title: node.title,
    subtitle: node.rangeLabel,
    verticalPadding: 10,
    titleStyle: const TextStyle(fontWeight: FontWeight.w500),
    onTap: onTap ?? () => context.push(compendiumTopicLocation(node.id)),
  );
}

/// The one question row of the Compendium: number badge, question text,
/// chevron. Used unchanged wherever a question is listed (section screen,
/// subsection screen, search results), whoever owns the question.
class CompendiumQuestionRow extends StatelessWidget {
  const CompendiumQuestionRow({
    super.key,
    required this.question,
    this.subtitle,
  });

  final CompendiumQuestion question;

  /// Optional context line (search results).
  final String? subtitle;

  @override
  Widget build(BuildContext context) => CompendiumListRow(
    leading: CompendiumBadge(label: '${question.number}'),
    title: question.question,
    subtitle: subtitle,
    onTap: () => openCompendiumQuestion(context, question.number),
  );
}

/// Answer paragraphs with source emphasis, Catechism references and
/// quotation boxes, in the reader typography.
class CompendiumAnswer extends ConsumerWidget {
  const CompendiumAnswer({
    super.key,
    required this.question,
    required this.textStyle,
  });

  final CompendiumQuestion question;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reader = ReaderTheme.of(context);
    final size = textStyle.fontSize ?? 18;
    final paragraphs = answerParagraphs(question);
    return Column(
      key: ValueKey('compendium-answer-${question.number}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final paragraph in paragraphs)
          Padding(
            padding: const EdgeInsets.only(
              bottom: LiturgicalSpacing.paragraphAfter,
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  for (final run in paragraph)
                    TextSpan(
                      text: run.text,
                      style: switch (run.style) {
                        CompendiumEmphasisStyle.italic => const TextStyle(
                          fontStyle: FontStyle.italic,
                        ),
                        CompendiumEmphasisStyle.bold => const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                        null => null,
                      },
                    ),
                ],
              ),
              style: textStyle,
              textAlign: proseTextAlign(
                ref.watch(settingsProvider).textAlignment,
                paragraph.map((run) => run.text).join(),
              ),
            ),
          ),
        if (question.cccRefs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              bottom: LiturgicalSpacing.metadataToBody,
            ),
            child: Text(
              'ККК ${formatCccRefs(question.cccRefs)}',
              key: ValueKey('compendium-refs-${question.number}'),
              style: reader
                  .referenceStyle(size)
                  .copyWith(fontFamily: textStyle.fontFamily),
            ),
          ),
        for (final citation in question.citations)
          CompendiumCitationBlock(citation: citation, textStyle: textStyle),
      ],
    );
  }
}

/// Quotation box printed before a group or after an answer.
class CompendiumCitationBlock extends StatelessWidget {
  const CompendiumCitationBlock({
    super.key,
    required this.citation,
    required this.textStyle,
  });

  final CompendiumCitation citation;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final reader = ReaderTheme.of(context);
    final size = textStyle.fontSize ?? 18;
    return Padding(
      padding: EdgeInsets.only(bottom: size * 0.8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: reader.rubricSoft,
          border: Border(left: BorderSide(color: reader.rubric, width: 3)),
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(10),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Text(
            citation.text,
            style: textStyle.copyWith(
              fontSize: size * 0.92,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Previous / centre / next controls at the end of a reader.
class CompendiumPager extends StatelessWidget {
  const CompendiumPager({
    super.key,
    this.previousLabel,
    this.onPrevious,
    this.centerLabel,
    this.onCenter,
    this.nextLabel,
    this.onNext,
  });

  final String? previousLabel;
  final VoidCallback? onPrevious;
  final String? centerLabel;
  final VoidCallback? onCenter;
  final String? nextLabel;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final color = ReaderTheme.of(context).rubric;
    final style = TextButton.styleFrom(foregroundColor: color);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          if (onPrevious != null)
            TextButton.icon(
              key: const Key('compendium-previous'),
              style: style,
              onPressed: onPrevious,
              icon: const PhosphorIcon(
                PhosphorIconsRegular.caretLeft,
                size: 18,
              ),
              label: Text(previousLabel ?? ''),
            )
          else
            const SizedBox.shrink(),
          if (onCenter != null)
            TextButton(
              key: const Key('compendium-center'),
              style: style,
              onPressed: onCenter,
              child: Text(centerLabel ?? ''),
            ),
          if (onNext != null)
            TextButton.icon(
              key: const Key('compendium-next'),
              style: style,
              onPressed: onNext,
              iconAlignment: IconAlignment.end,
              icon: const PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                size: 18,
              ),
              label: Text(nextLabel ?? ''),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// Short context line under a question in lists: the part and the nearest
/// real source heading (topic, chapter or section), for example
/// «ЧАСТКА ПЕРШАЯ · «ВЕРУ» — «ВЕРЫМ»» for question 1.
String compendiumQuestionContext(CompendiumQuestion question) {
  final trail = questionContextTrail(question);
  return [trail.first, if (trail.length > 1) trail.last].join(' · ');
}

/// Empty, error and not-found message on the Compendium list screens.
class CompendiumMessage extends StatelessWidget {
  const CompendiumMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          PhosphorIcon(icon, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Opens a question reader.
void openCompendiumQuestion(BuildContext context, int number) =>
    context.push(compendiumQuestionLocation(number));
