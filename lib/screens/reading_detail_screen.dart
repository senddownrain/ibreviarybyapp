import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/models/reading.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/widgets/adaptive_app_bar.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/liturgical_html.dart';

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
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);
    final raw = HiveService.readingsBox.get(widget.readingId);
    if (raw == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AdaptiveAppBar.text('Чытанне'),
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
      builder: (context, textStyle) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AdaptiveAppBar(
          title: Text(
            title.isNotEmpty ? title : 'Чытанне',
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: PhosphorIcon(
                _showRaw ? PhosphorIconsFill.code : PhosphorIconsRegular.code,
                size: 22,
              ),
              tooltip: _showRaw ? 'Аддаць рэндэрынг' : 'Паказаць HTML',
              onPressed: () => setState(() => _showRaw = !_showRaw),
            ),
            IconButton(
              icon: const PhosphorIcon(
                PhosphorIconsRegular.shareNetwork,
                size: 22,
              ),
              tooltip: 'Падзяліцца',
              onPressed: () {
                final text =
                    (title.isNotEmpty ? '$title\n\n' : '') +
                    _stripHtml(reading.text);
                Share.share(text);
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            AmbientWash.hero(seasonColor: seasonColor),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + kFloatingAppBarContentInset,
                16,
                40,
              ),
              child: GlassSurface(
                style: GlassStyle.card,
                seasonColor: seasonColor,
                borderRadius: BorderRadius.circular(28),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
                child: Column(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRendered(String text, TextStyle textStyle) {
    if (text.contains('<') && text.contains('>')) {
      final reader = ReaderTheme.of(context);
      final base = textStyle.fontSize ?? 16;
      final textColor =
          textStyle.color ?? Theme.of(context).colorScheme.onSurface;
      return Html(
        data: formatLiturgicalHtml(text),
        style: {
          'body': Style(
            fontSize: FontSize(base),
            fontFamily: textStyle.fontFamily,
            color: textColor,
            lineHeight: LineHeight(1.78),
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            textAlign: TextAlign.left,
          ),
          'p': Style(color: textColor, margin: Margins.only(bottom: 14)),
          '.liturgical-subheading': Style(
            fontSize: FontSize(base * 0.84),
            lineHeight: LineHeight(1.45),
            color: reader.muted,
          ),
          '.liturgical-heading': Style(
            fontSize: FontSize(base * 0.94),
            lineHeight: LineHeight(1.3),
            color: reader.rubric,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
          '.psalm-marker': Style(
            color: reader.rubric,
            fontWeight: FontWeight.w600,
          ),
          '.liturgical-rubric-inline': Style(color: reader.rubric),
        },
      );
    }
    return SelectableText(text, style: textStyle);
  }
}
