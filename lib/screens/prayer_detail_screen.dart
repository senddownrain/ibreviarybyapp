import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mybrev_flutter/models/prayer.dart';
import 'package:mybrev_flutter/providers/prayers_provider.dart';
import 'package:mybrev_flutter/providers/local_prayers_provider.dart';
import 'package:mybrev_flutter/providers/liturgical_provider.dart';
import 'package:mybrev_flutter/providers/settings_provider.dart';
import 'package:mybrev_flutter/utils/prayer_markdown.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mybrev_flutter/widgets/ios_app_bar.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/theme/glass.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mybrev_flutter/theme/reader.dart';

String _stripHtmlForCopy(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _stripHtmlText(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _normalizeCmp(String s) {
  final t = s
      .toLowerCase()
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'''[«»"'.,:;!?()\-\n\r]'''), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return t;
}

String _firstVisibleLine(String text) {
  final withBreaks = text
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</h[1-6]\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"');
  for (final line in withBreaks.split(RegExp(r'[\n\r]+'))) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String _removeLeadingDuplicateTitle(String text, String title) {
  if (title.trim().isEmpty) return text;
  var source = text;

  // HTML case: some prayers start with a dedicated heading block
  // (<p>/<div>/<center>/<h*>...), which should be removed if it duplicates
  // the page title.
  if (source.contains('<') && source.contains('>')) {
    for (var i = 0; i < 2; i++) {
      final m = RegExp(
        r'^\s*<(p|div|center|h[1-6])[^>]*>([\s\S]*?)</\1>\s*',
        caseSensitive: false,
      ).firstMatch(source);
      if (m == null) break;
      final blockInner = m.group(2) ?? '';
      final blockText = _stripHtmlText(blockInner);
      if (_normalizeCmp(blockText) == _normalizeCmp(title)) {
        source = source.substring(m.end).trimLeft();
        continue;
      }
      break;
    }
  }

  final first = _firstVisibleLine(source);
  if (first.isEmpty) return text;
  if (_normalizeCmp(first) != _normalizeCmp(title)) return text;

  if (source.contains('<') && source.contains('>')) {
    final cleaned = source
        .replaceFirst(
          RegExp(
            r'^\s*(?:<(?:p|div|h[1-6])[^>]*>\s*)?[^<\n]+(?:\s*</(?:p|div|h[1-6])>)?\s*(?:<br\s*/?>)?',
            caseSensitive: false,
          ),
          '',
        )
        .trimLeft();
    return cleaned.isEmpty ? text : cleaned;
  }

  final lines = source.split(RegExp(r'[\n\r]+'));
  var removed = false;
  final kept = <String>[];
  for (final line in lines) {
    if (!removed && line.trim().isNotEmpty) {
      removed = true;
      continue;
    }
    kept.add(line);
  }
  final out = kept.join('\n').trimLeft();
  return out.isEmpty ? text : out;
}

class PrayerDetailScreen extends ConsumerWidget {
  final String prayerId;
  const PrayerDetailScreen({super.key, required this.prayerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayers = ref.watch(allPrayersProvider);
    final localPrayers = ref.watch(localPrayersProvider);
    final settings = ref.watch(settingsProvider);
    final seasonColor = ref.watch(liturgicalSeasonColorProvider);

    final Prayer? prayer;
    try {
      prayer = [...prayers, ...localPrayers].firstWhere((p) => p.id == prayerId);
    } catch (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('Малітва')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(PhosphorIconsLight.magnifyingGlass,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('Малітва не знойдзена',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
        ),
      );
    }

    final p = prayer;
    final isFav = settings.favoriteIds.contains(p.id);
    final isLocal = LocalPrayersNotifier.isLocal(p.id);

    return ReadingScaffold(
      builder: (context, textStyle) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: IosGlassAppBar(
          title: Text(p.displayTitle.isNotEmpty ? p.displayTitle : 'Малітва',
              overflow: TextOverflow.ellipsis),
          actions: [
            if (isLocal)
              IconButton(
                icon: const PhosphorIcon(PhosphorIconsRegular.pencilSimple, size: 22),
                tooltip: 'Рэдагаваць',
                onPressed: () => context.push('/prayer/edit/${p.id}'),
              ),
            IconButton(
              icon: PhosphorIcon(
                isFav ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                size: 22,
                color: isFav ? Colors.red : null,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                ref.read(settingsProvider.notifier).toggleFavorite(p.id);
              },
            ),
            IconButton(
              icon: const PhosphorIcon(PhosphorIconsRegular.shareNetwork, size: 22),
              tooltip: 'Падзяліцца',
              onPressed: () {
                final text = '${p.displayTitle.isNotEmpty ? '${p.displayTitle}\n\n' : ''}'
                    '${_stripHtmlForCopy(p.displayText)}';
                Share.share(text);
              },
            ),
            PopupMenuButton<double>(
              icon: const PhosphorIcon(PhosphorIconsRegular.textAa, size: 22),
              onSelected: (size) =>
                  ref.read(settingsProvider.notifier).setFontSize(size),
              itemBuilder: (context) => [
                for (final size in [14.0, 16.0, 18.0, 20.0, 24.0])
                  PopupMenuItem(
                    value: size,
                    child: Text(
                      '${size.toInt()} pt',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: size == settings.fontSize
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            AmbientWash.hero(seasonColor: seasonColor),
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
                  _buildContent(context, p, textStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Prayer prayer, TextStyle textStyle) {
    final raw = _removeLeadingDuplicateTitle(
      prayer.displayText,
      prayer.displayTitle,
    ).trim();

    if (raw.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Center(
          child: Column(
            children: [
              PhosphorIcon(PhosphorIconsLight.bookOpen,
                  size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'Тэкст малітвы адсутнічае',
                style: TextStyle(color: cs.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Паспрабуйце сінхранізаваць дадзеныя ў Наладах.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final html = prayer.isMarkdown ||
            (!raw.contains('<') && raw.contains(':::rubric'))
        ? prayerMarkdownToHtml(raw)
        : raw;

    if (html.contains('<') && html.contains('>')) {
      final reader = ReaderTheme.of(context);
      final textColor = textStyle.color ?? Theme.of(context).colorScheme.onSurface;
      return Html(
        data: html,
        style: {
          'body': Style(
            fontSize: FontSize(textStyle.fontSize ?? 16),
            fontFamily: textStyle.fontFamily,
            color: textColor,
            lineHeight: LineHeight(1.7),
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          'p': Style(
            fontSize: FontSize(textStyle.fontSize ?? 16),
            fontFamily: textStyle.fontFamily,
            color: textColor,
            margin: Margins.only(bottom: 10),
          ),
          'h2': Style(
            fontSize: FontSize((textStyle.fontSize ?? 16) * 1.2),
            fontWeight: FontWeight.w700,
            color: textColor,
            margin: Margins.only(top: 16, bottom: 8),
          ),
          'h3': Style(
            fontSize: FontSize((textStyle.fontSize ?? 16) * 1.1),
            fontWeight: FontWeight.w700,
            color: textColor,
            margin: Margins.only(top: 14, bottom: 6),
          ),
          '.prayer-rubric': Style(
            color: reader.rubric,
            fontStyle: FontStyle.italic,
            margin: Margins.symmetric(vertical: 10),
          ),
        },
      );
    }
    return SelectableText(raw, style: textStyle);
  }
}
