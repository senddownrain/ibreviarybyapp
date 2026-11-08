import 'package:mybrev_flutter/models/reader_preferences.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/utils/reader_prose.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/models/reading.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/theme/liturgical_document.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart'
    show analyticsFeature;

String _stripHtml(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class ReadingDetailScreen extends ConsumerStatefulWidget {
  final String readingId;
  const ReadingDetailScreen({super.key, required this.readingId});

  @override
  ConsumerState<ReadingDetailScreen> createState() =>
      _ReadingDetailScreenState();
}

class _ReadingDetailScreenState extends ConsumerState<ReadingDetailScreen> {
  bool _showRaw = false;

  @override
  Widget build(BuildContext context) {
    final raw = HiveService.readingsBox.get(widget.readingId);
    if (raw == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AdaptiveAppBar.text(
          'Чытанне',
          showOverflow: true,
          showTextScale: true,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                PhosphorIconsLight.bookOpen,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              const Text('Чытанне не знойдзена'),
            ],
          ),
        ),
      );
    }
    final reading = Reading.fromMap(Map<String, dynamic>.from(raw));
    final title = reading.title != null ? _stripHtml(reading.title!) : '';

    return ReadingScaffold(
      builder: (context, textStyle) => ReaderScaffold(
        semanticLabel: 'Тэкст чытання',
        contextHeader: ReaderContextHeader(
          title: title.isNotEmpty ? title : 'Чытанне',
        ),
        secondaryActions: [
          ReaderSecondaryAction(
            label: _showRaw ? 'Аддаць рэндэрынг' : 'Паказаць HTML',
            icon: PhosphorIconsRegular.code,
            onSelected: () => setState(() => _showRaw = !_showRaw),
          ),
          ReaderSecondaryAction(
            label: 'Падзяліцца',
            icon: PhosphorIconsRegular.shareNetwork,
            onSelected: () {
              final text =
                  (title.isNotEmpty ? '$title\n\n' : '') +
                  _stripHtml(reading.text);
              analyticsFeature('share_use');
              Share.share(text);
            },
          ),
        ],
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reading.cycle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Chip(label: Text('Цыкл ${reading.cycle}')),
              ),
            if (_showRaw)
              SelectableText(
                reading.text,
                style: textStyle.copyWith(
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              _buildRendered(reading.text, textStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildRendered(String text, TextStyle textStyle) {
    if (text.contains('<') && text.contains('>')) {
      final reader = ReaderTheme.of(context);
      return Html(
        data: prepareReaderProseHtml(formatLiturgicalHtml(text)),
        style: {
          ...liturgicalDocumentStyles(reader: reader, body: textStyle),
          '.reader-prose': Style(
            textAlign: ref.watch(settingsProvider).textAlignment.textAlign,
          ),
        },
      );
    }
    final rubric = ReaderTheme.of(context).rubric;
    return SelectableText.rich(
      textAlign: readerProseAlignment(
        ref.watch(settingsProvider).textAlignment,
        text,
      ),
      TextSpan(
        children: [
          for (final piece in text.split(RegExp(r'(?=[*†])|(?<=[*†])')))
            TextSpan(
              text: piece,
              style: piece == '*' || piece == '†'
                  ? textStyle.copyWith(
                      color: rubric,
                      fontWeight: FontWeight.w600,
                    )
                  : textStyle,
            ),
        ],
      ),
    );
  }
}
