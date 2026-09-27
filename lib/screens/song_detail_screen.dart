import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:mybrev_flutter/models/song.dart';
import 'package:mybrev_flutter/providers/songs_provider.dart';
import 'package:mybrev_flutter/theme/reader.dart';
import 'package:mybrev_flutter/utils/song_chords.dart';
import 'package:mybrev_flutter/widgets/reader/reader_scaffold.dart';
import 'package:mybrev_flutter/widgets/reading_scaffold.dart';
import 'package:mybrev_flutter/widgets/songs/song_settings_sheet.dart';
import 'package:mybrev_flutter/widgets/songs/song_text.dart';
import 'package:mybrev_flutter/widgets/text_scale_control.dart';

/// `/prayers/songs/:id`: one song on the shared Reader foundation.
class SongDetailScreen extends ConsumerStatefulWidget {
  const SongDetailScreen({super.key, required this.songId});

  final String songId;

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Display-only transposition in semitones; never persisted.
  int _transpose = 0;

  @override
  void didUpdateWidget(covariant SongDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) _transpose = 0;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setTranspose(int value) {
    HapticFeedback.selectionClick();
    setState(() => _transpose = value.clamp(kMinTranspose, kMaxTranspose));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(songByIdProvider(widget.songId));
    final song = state.valueOrNull;
    if (song == null) {
      final message = state.isLoading
          ? null
          : state.hasError
          ? 'Не атрымалася загрузіць спеў'
          : 'Спеў не знойдзены';
      return ReaderScaffold(
        semanticLabel: message ?? 'Загрузка спеву',
        content: Center(
          child: message == null
              ? const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: LinearProgressIndicator(key: Key('song-loading')),
                )
              : Text(message, key: const Key('song-not-found')),
        ),
      );
    }

    final prefs = ref.watch(songPreferencesProvider);
    final favorite = prefs.favoriteSongIds.contains(song.id);
    final chordsVisible = prefs.showChords && song.hasChords;
    final cs = Theme.of(context).colorScheme;
    final tags = song.displayTags;

    return ReadingScaffold(
      builder: (context, textStyle) => ReaderScaffold(
        key: ValueKey('song-reader-${song.id}'),
        scrollKey: PageStorageKey('song-detail-${song.id}-scroll'),
        semanticLabel: 'Тэкст спеву ${song.title}',
        seasonColor: cs.tertiary,
        chromeMode: ReaderChromeMode.compact,
        scrollController: _scrollController,
        showScrollToTop: true,
        actions: [
          _SongFavoriteControl(songId: song.id, favorite: favorite),
          const TextScaleControl(),
        ],
        secondaryActions: [
          ReaderSecondaryAction(
            label: 'Налады спеўніка',
            icon: Icons.tune_rounded,
            onSelected: () => showSongSettingsSheet(context),
          ),
        ],
        contextHeader: ReaderContextHeader(
          eyebrow: 'СПЕЎНІК',
          title: song.title,
          metadata: tags.isEmpty ? null : tags.join(' · '),
          accentColor: cs.tertiary,
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (chordsVisible) ...[
              _TransposeControl(value: _transpose, onChanged: _setTranspose),
              const SizedBox(height: 20),
            ],
            SongText(
              song: song,
              textStyle: textStyle,
              showChords: prefs.showChords,
              layout: prefs.chordLayout,
              transpose: _transpose,
            ),
            if (song.source.isNotEmpty) _SongSource(song: song),
          ],
        ),
      ),
    );
  }
}

class _TransposeControl extends StatelessWidget {
  const _TransposeControl({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = value > 0 ? '+$value' : '$value';
    return Semantics(
      container: true,
      label: 'Транспанаванне акордаў',
      child: Wrap(
        key: const Key('song-transpose-control'),
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          IconButton.filledTonal(
            key: const Key('song-transpose-down'),
            tooltip: 'Панізіць на паўтон',
            onPressed: value <= kMinTranspose
                ? null
                : () => onChanged(value - 1),
            icon: const PhosphorIcon(PhosphorIconsBold.minus, size: 18),
          ),
          Semantics(
            liveRegion: true,
            label: '$label паўтонаў',
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 40),
              child: Text(
                label,
                key: const Key('song-transpose-value'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          IconButton.filledTonal(
            key: const Key('song-transpose-up'),
            tooltip: 'Павысіць на паўтон',
            onPressed: value >= kMaxTranspose
                ? null
                : () => onChanged(value + 1),
            icon: const PhosphorIcon(PhosphorIconsBold.plus, size: 18),
          ),
          TextButton(
            key: const Key('song-transpose-reset'),
            onPressed: value == 0 ? null : () => onChanged(0),
            style: TextButton.styleFrom(foregroundColor: cs.tertiary),
            child: const Text('Арыгінал'),
          ),
        ],
      ),
    );
  }
}

class _SongSource extends StatelessWidget {
  const _SongSource({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final reader = ReaderTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: reader.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text.rich(
            key: const Key('song-source'),
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Крыніца: ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: song.source),
              ],
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: reader.muted),
          ),
        ),
      ),
    );
  }
}

class _SongFavoriteControl extends ConsumerWidget {
  const _SongFavoriteControl({required this.songId, required this.favorite});

  final String songId;
  final bool favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 48,
      child: IconButton.filledTonal(
        key: const Key('song-detail-favorite'),
        tooltip: favorite ? 'Выдаліць з абраных' : 'Дадаць у абраныя',
        onPressed: () {
          HapticFeedback.selectionClick();
          ref.read(songPreferencesProvider.notifier).toggleFavorite(songId);
        },
        icon: PhosphorIcon(
          favorite ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
          size: 21,
          color: favorite ? cs.error : null,
        ),
      ),
    );
  }
}
