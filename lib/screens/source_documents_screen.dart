import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mybrev_flutter/models/source_documents.dart';
import 'package:mybrev_flutter/theme/reader.dart';

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(sourceRegistryProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            _LoadError(retry: () => ref.invalidate(sourceRegistryProvider)),
        data: (registry) => _ArticleScroll(
          children: [
            const _Title('Крыніцы і аўтарскія правы'),
            for (final group in registry.groups) ...[
              _SectionTitle(group.title),
              for (final entry in group.entries.indexed) ...[
                if (entry.$1 > 0) const Divider(height: 24),
                Column(
                  key: ValueKey(entry.$2.id),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.$2.textLabel.isNotEmpty) Text(entry.$2.textLabel),
                    if (entry.$2.edition.isNotEmpty) Text(entry.$2.edition),
                    for (final notice in entry.$2.notices) Text(notice),
                  ],
                ),
              ],
              const SizedBox(height: 24),
            ],
            const Divider(),
            const _SectionTitle('Дакументы'),
            _DocumentLink(
              label: 'Дэкрэты Літургіі гадзінаў',
              onPressed: () => context.push(hoursDecreesRoute),
            ),
            _DocumentLink(
              label: 'Уласны каляндар дыяцэзій на Беларусі',
              onPressed: () => context.push(properCalendarRoute),
            ),
          ],
        ),
      );
}

class LiturgyHoursDecreesScreen extends StatefulWidget {
  const LiturgyHoursDecreesScreen({super.key});
  @override
  State<LiturgyHoursDecreesScreen> createState() =>
      _LiturgyHoursDecreesScreenState();
}

class _LiturgyHoursDecreesScreenState extends State<LiturgyHoursDecreesScreen> {
  late Future<HoursDecrees> _document = HoursDecrees.load();
  final _anchors = List.generate(4, (_) => GlobalKey());

  @override
  Widget build(BuildContext context) => FutureBuilder<HoursDecrees>(
    future: _document,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(
          retry: () => setState(() => _document = HoursDecrees.load()),
        );
      }
      final data = snapshot.data;
      if (data == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final style = ReaderTheme.of(context).body(18).copyWith(height: 1.6);
      return _ArticleScroll(
        children: [
          _Title(data.title),
          Wrap(
            spacing: 8,
            children: [
              for (final decree in data.documents.indexed)
                TextButton(
                  onPressed: () => _jumpTo(_anchors[decree.$1]),
                  child: Text('Том ${decree.$2.roman}'),
                ),
            ],
          ),
          for (final decree in data.documents.indexed)
            Padding(
              key: _anchors[decree.$1],
              padding: const EdgeInsets.only(top: 24),
              child: DefaultTextStyle(
                style: style,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 1),
                    _SectionTitle('Том ${decree.$2.roman}'),
                    Text(
                      decree.$2.lines('issuer').join('\n'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Text('№ ${decree.$2.number}'),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        decree.$2.heading,
                        textAlign: TextAlign.center,
                        style: style.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    for (final paragraph in decree.$2.lines('paragraphs'))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(paragraph),
                      ),
                    const SizedBox(height: 6),
                    Text(decree.$2.lines('dateLines').join('\n')),
                    const SizedBox(height: 22),
                    Text(decree.$2.lines('signature').join('\n')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 26),
          _DocumentLink(
            label: 'Крыніца дэкрэтаў I–III тамоў',
            onPressed: () => _openDecreeSource(context),
          ),
        ],
      );
    },
  );

  Future<void> _openDecreeSource(BuildContext context) async {
    try {
      if (await launchUrl(
        Uri.parse('https://lh.catholic.by/dekrety.php'),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // The complete local documents above remain available offline.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не ўдалося адкрыць сайт')));
    }
  }
}

class ProperCalendarScreen extends StatefulWidget {
  const ProperCalendarScreen({super.key});
  @override
  State<ProperCalendarScreen> createState() => _ProperCalendarScreenState();
}

class _ProperCalendarScreenState extends State<ProperCalendarScreen> {
  late Future<ProperCalendarDocument> _document = ProperCalendarDocument.load();
  final _anchors = List.generate(12, (_) => GlobalKey());

  @override
  Widget build(BuildContext context) => FutureBuilder<ProperCalendarDocument>(
    future: _document,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(
          retry: () =>
              setState(() => _document = ProperCalendarDocument.load()),
        );
      }
      final data = snapshot.data;
      if (data == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return _ArticleScroll(
        children: [
          _Title(data.title),
          Wrap(
            spacing: 4,
            children: [
              for (final month in data.months)
                TextButton(
                  key: ValueKey('calendar-jump-${month.number}'),
                  onPressed: () => _jumpTo(_anchors[month.number - 1]),
                  child: Text(month.title),
                ),
            ],
          ),
          const SizedBox(height: 20),
          for (final page in data.pages)
            Column(
              key: ValueKey('calendar-page-${page.number}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in page.rows.indexed)
                  if (row.$2.kind == 'month')
                    Padding(
                      key: _anchors[row.$2.month! - 1],
                      padding: const EdgeInsets.only(top: 30, bottom: 16),
                      child: Semantics(
                        header: true,
                        child: Text(
                          row.$2.text!,
                          textAlign: TextAlign.center,
                          style: ReaderTheme.of(context)
                              .body(20)
                              .copyWith(
                                color: documentTone(context, 'red'),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    )
                  else if (row.$2.kind == 'intro') ...[
                    if (page.number == 1 && row.$1 == 0)
                      DocumentRuns(
                        key: const Key('calendar-intro'),
                        runs: data.introRuns,
                      ),
                  ] else if (row.$2.kind == 'note')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: DocumentRuns(runs: row.$2.runs),
                    )
                  else
                    CalendarDocumentLine(
                      key: ValueKey('calendar-line-${page.number}-${row.$1}'),
                      row: row.$2,
                    ),
              ],
            ),
          const SizedBox(height: 26),
          Builder(
            builder: (buttonContext) => _DocumentLink(
              label: 'Арыгінал PDF',
              onPressed: () => shareProperCalendarPdf(buttonContext),
            ),
          ),
        ],
      );
    },
  );
}

/// Rank stays with its own original line on phones and at larger text scales.
/// Continuations retain their source order and their date-column indentation.
class CalendarDocumentLine extends StatelessWidget {
  const CalendarDocumentLine({super.key, required this.row});
  final CalendarRow row;

  @override
  Widget build(BuildContext context) {
    final dateWidth = MediaQuery.textScalerOf(context).scale(18) * 1.9;
    final full = row.date == null && !row.indent;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (row.runs.isNotEmpty) DocumentRuns(runs: row.runs),
        if (row.rank.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: DocumentRuns(runs: row.rank, fontSize: 16),
          ),
      ],
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.textScalerOf(context).scale(18) * 1.5,
      ),
      child: full
          ? content
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: dateWidth,
                  child: row.date == null
                      ? null
                      : DocumentRuns(
                          runs: [
                            DocumentRun(
                              text: '${row.date}.',
                              tone: row.dateTone ?? 'black',
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 4),
                Expanded(child: content),
              ],
            ),
    );
  }
}

Color documentTone(BuildContext context, String tone) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (tone) {
    'red' => dark ? const Color(0xffff9292) : const Color(0xffb42121),
    'magenta' => dark ? const Color(0xffef9cdb) : const Color(0xffa02b81),
    _ => ReaderTheme.of(context).ink,
  };
}

class DocumentRuns extends StatelessWidget {
  const DocumentRuns({super.key, required this.runs, this.fontSize = 18});
  final List<DocumentRun> runs;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        for (final run in runs)
          TextSpan(
            text: run.text,
            style: TextStyle(
              color: documentTone(context, run.tone),
              fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
              fontWeight: run.bold ? FontWeight.w700 : FontWeight.w400,
              fontSize: run.small ? fontSize * .79 : fontSize,
            ),
          ),
      ],
    ),
    style: ReaderTheme.of(context).body(fontSize).copyWith(height: 1.45),
  );
}

/// Native share sheet / web download, from bundled bytes (no remote URL).
/// The origin rectangle is required for the iPad share popover.
Future<void> shareProperCalendarPdf(BuildContext context) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  try {
    final data = await rootBundle.load(properCalendarPdfAsset);
    await Share.shareXFiles(
      [
        XFile.fromData(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          mimeType: 'application/pdf',
          name: 'proper-calendar.pdf',
        ),
      ],
      fileNameOverrides: ['proper-calendar.pdf'],
      sharePositionOrigin: origin,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не ўдалося адкрыць PDF')));
    }
  }
}

void _jumpTo(GlobalKey key) {
  final context = key.currentContext;
  if (context == null) return;
  Scrollable.ensureVisible(
    context,
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250),
  );
}

class _ArticleScroll extends StatelessWidget {
  const _ArticleScroll({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 16, height: 1.55),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class _DocumentLink extends StatelessWidget {
  const _DocumentLink({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(vertical: 10),
        minimumSize: const Size(48, 48),
      ),
      child: Text(label),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.retry});
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: retry,
      child: const Text('Не ўдалося адкрыць дакумент. Паўтарыць'),
    ),
  );
}
