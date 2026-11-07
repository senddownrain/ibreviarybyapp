import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/utils/reader_prose.dart';

/// HTML prose opts in at paragraph level; headings and liturgical structures
/// keep their own alignment. Never installed in Hours or devotional offices.
class ReaderProseHtml extends ConsumerWidget {
  const ReaderProseHtml({
    super.key,
    required this.data,
    required this.style,
    this.onLinkTap,
  });
  final String data;
  final Map<String, Style> style;
  final OnTap? onLinkTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Html(
    data: prepareReaderProseHtml(data),
    style: {
      ...style,
      '.$readerProseClass': Style(
        textAlign: ref
            .watch(settingsProvider.select((s) => s.textAlignment))
            .textAlign,
      ),
    },
    onLinkTap: onLinkTap,
  );
}
