import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mybrev_flutter/constants/source_bibliography.dart';
import 'package:mybrev_flutter/constants/legal_links.dart';

/// Same external-application launch policy as the privacy document.
final sourceDocumentLauncherProvider =
    Provider<Future<bool> Function(Uri, LaunchMode)>(
      (ref) =>
          (uri, mode) => launchUrl(uri, mode: mode),
    );

Future<void> _openDocument(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  try {
    if (await ref.read(sourceDocumentLauncherProvider)(
      Uri.parse(url),
      LaunchMode.externalApplication,
    )) {
      return;
    }
  } catch (_) {
    // A missing browser and platform errors use the same actionable message.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Не ўдалося адкрыць старонку. Праверце інтэрнэт-злучэнне',
        ),
      ),
    );
  }
}

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _ArticleScroll(
    children: [
      const _Title('Крыніцы і аўтарскія правы'),
      for (final entry in kPublicSourceBibliography.indexed) ...[
        if (entry.$1 > 0) const Divider(height: 24),
        Column(
          key: ValueKey(entry.$2.id),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.$2.title),
            for (final notice in entry.$2.notices) Text(notice),
          ],
        ),
      ],
      const SizedBox(height: 24),
      const Divider(),
      const _SectionTitle('Дакументы'),
      for (final document in kSourceDocumentLinks)
        _DocumentLink(
          label: document.label,
          onPressed: () => _openDocument(context, ref, document.url),
        ),
    ],
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
