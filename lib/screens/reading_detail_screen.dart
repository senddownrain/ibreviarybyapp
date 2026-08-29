import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/models/reading.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/widgets/ios_app_bar.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:share_plus/share_plus.dart';

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
      final cs = Theme.of(context).colorScheme;
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: IosGlassAppBar.text('Чытанне'),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(PhosphorIconsLight.bookOpen,
                  size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('Чытанне не знойдзена',
                  style: TextStyle(color: cs.onSurface)),
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
        appBar: IosGlassAppBar(
          title: Text(title.isNotEmpty ? title : 'Чытанне',
              overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              icon: PhosphorIcon(_showRaw ? PhosphorIconsFill.code : PhosphorIconsRegular.code, size: 22),
              tooltip: _showRaw ? 'Аддаць рэндэрынг' : 'Паказаць HTML',
              onPressed: () => setState(() => _showRaw = !_showRaw),
            ),
            IconButton(
              icon: const PhosphorIcon(PhosphorIconsRegular.shareNetwork, size: 22),
              tooltip: 'Падзяліцца',
              onPressed: () {
                final text = (title.isNotEmpty ? '$title\n\n' : '') +
                    _stripHtml(reading.text);
                Share.share(text);
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                16,
                40,
              ),
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
            AmbientWash(
              seasonColor: seasonColor,
              height: kToolbarHeight + 120,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRendered(String text, TextStyle textStyle) {
    if (text.contains('<') && text.contains('>')) {
      return Html(
        data: text,
        style: {
          'body': Style(
            fontSize: FontSize(textStyle.fontSize ?? 16),
            fontFamily: textStyle.fontFamily,
          ),
        },
      );
    }
    return SelectableText(text, style: textStyle);
  }
}
