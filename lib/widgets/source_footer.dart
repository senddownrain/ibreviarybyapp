import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mybrev_flutter/models/source_documents.dart';

import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';

final sourceLinkLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Attribution inside scrolling content. The reader owns bottom/inset padding.
class SourceFooter extends ConsumerWidget {
  const SourceFooter({
    super.key,
    this.sourceName = 'Catholic.by',
    this.sourceUrl = 'https://catholic.by/',
    this.copyright = '',
    this.sourceId,
    this.textStyle,
    this.linkColor,
    this.topSpacing = 32,
    this.verticalPadding = 0,
    this.borderColor,
    this.linkKey,
    this.semanticLabel,
  });

  final String sourceName;
  final String sourceUrl;
  final String copyright;
  final String? sourceId;
  final TextStyle? textStyle;
  final Color? linkColor;
  final double topSpacing;
  final double verticalPadding;
  final Color? borderColor;
  final Key? linkKey;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = sourceId == null
        ? null
        : ref.watch(sourceRegistryProvider).valueOrNull?.entry(sourceId!);
    if (sourceId != null && entry == null) {
      return const SizedBox.shrink();
    }
    final sourceName = this.sourceName == 'Catholic.by'
        ? entry?.digitalLabel ?? this.sourceName
        : this.sourceName;
    final sourceUrl = entry?.digitalUrl ?? this.sourceUrl;
    final copyright = sourceId == null
        ? this.copyright
        : entry?.notices.join('. ') ?? '';
    final reader = ReaderTheme.of(context);
    final settings = ref.watch(settingsProvider);
    final style =
        textStyle ??
        reader
            .sourceStyle(settings.fontSize, family: settings.fontFamily)
            .copyWith(fontSize: settings.fontSize * .75);
    final link = linkColor ?? reader.muted;
    final text = Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'Крыніца: ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: sourceName,
            style: TextStyle(
              color: link,
              decoration: TextDecoration.underline,
              decorationColor: link,
            ),
          ),
          if (copyright.isNotEmpty) TextSpan(text: '. $copyright'),
        ],
      ),
      style: style,
    );
    Widget result = Semantics(
      link: true,
      label:
          semanticLabel ??
          'Крыніца: $sourceName${copyright.isEmpty ? '' : '. $copyright'}',
      excludeSemantics: true,
      child: InkWell(
        key: linkKey,
        borderRadius: BorderRadius.circular(8),
        onTap: () => _open(context, ref, sourceUrl),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: text,
        ),
      ),
    );
    if (borderColor case final color?) {
      result = DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: color)),
        ),
        child: result,
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: topSpacing),
      child: result,
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    String sourceUrl,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      opened = await ref.read(sourceLinkLauncherProvider)(Uri.parse(sourceUrl));
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Не ўдалося адкрыць сайт')),
      );
    }
  }
}
