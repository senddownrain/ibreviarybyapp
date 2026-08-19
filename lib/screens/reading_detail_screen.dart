import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/models/reading.dart';
import 'package:mybrev_flutter/services/hive_service.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';

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
        appBar: AppBar(title: const Text('Чытанне')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(PhosphorIconsLight.bookOpen, size: 48, color: Colors.grey[400]),
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
        appBar: AppBar(
          title: Text(title.isNotEmpty ? title : 'Чытанне'),
          actions: [
            IconButton(
              icon: PhosphorIcon(_showRaw ? PhosphorIconsFill.code : PhosphorIconsRegular.code, size: 22),
              tooltip: _showRaw ? 'Аддаць рэндэрынг' : 'Паказаць HTML',
              onPressed: () => setState(() => _showRaw = !_showRaw),
            ),
            IconButton(
              icon: const PhosphorIcon(PhosphorIconsRegular.copy, size: 22),
              tooltip: 'Скапіяваць',
              onPressed: () {
                final text = _showRaw ? reading.text : _stripHtml(reading.text);
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Скапіявана'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
