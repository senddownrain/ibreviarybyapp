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
import 'package:mybrev_flutter/widgets/songs/song_chord_control.dart';
import 'package:mybrev_flutter/widgets/songs/song_text.dart';
import 'package:mybrev_flutter/widgets/loading/app_load_states.dart';
import 'package:mybrev_flutter/analytics/local_analytics.dart'
    show analyticsFeature;

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

  /// Whether the preferred `right` layout is rendered as `above` right now.
  /// Runtime-only hint for the chord control; the preference is untouched.
  final ValueNotifier<bool> _rightFallback = ValueNotifier(false);

  @override
  void didUpdateWidget(covariant SongDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) _transpose = 0;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _rightFallback.dispose();
    super.dispose();
  }

  /// [SongText] reports from its layout pass, so the hint is updated after
  /// the frame.
  void _setRightFallback(bool value) {
    if (_rightFallback.value == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rightFallback.value = value;
    });
  }

  void _setTranspose(int value) {
    HapticFeedback.selectionClick();
    final next = value.clamp(kMinTranspose, kMaxTranspose);
    if (next != _transpose) analyticsFeature('chord_transpose');
    setState(() => _transpose = next);
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
                  child: AppProgressLine(key: Key('song-loading')),
                )
              : Text(message, key: const Key('song-not-found')),
        ),
      );
    }

    final prefs = ref.watch(songPreferencesProvider);
    final favorite = prefs.favoriteSongIds.contains(song.id);
    final prefsNotifier = ref.read(songPreferencesProvider.notifier);
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
        actions: [_SongFavoriteControl(songId: song.id, favorite: favorite)],
        contextHeader: ReaderContextHeader(
          eyebrow: 'СПЕЎНІК ПІЛІГРЫМКОВЫ',
          title: song.title,
          metadata: tags.isEmpty ? null : tags.join(' · '),
          accentColor: cs.tertiary,
          // Songs without chords stay clean: no chord controls at all.
          details: song.hasChords
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _rightFallback,
                    builder: (context, fallback, _) => SongChordControl(
                      showChords: prefs.showChords,
                      layout: prefs.chordLayout,
                      layoutFallback: fallback,
                      transpose: _transpose,
                      seasonColor: cs.tertiary,
                      onShowChordsChanged: (value) {
                        HapticFeedback.selectionClick();
                        prefsNotifier.setShowChords(value);
                      },
                      onLayoutChanged: (value) {
                        HapticFeedback.selectionClick();
                        prefsNotifier.setChordLayout(value);
                      },
                      onTransposeChanged: _setTranspose,
                    ),
                  ),
                )
              : null,
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SongText(
              song: song,
              textStyle: textStyle,
              showChords: prefs.showChords,
              layout: prefs.chordLayout,
              transpose: _transpose,
              onRightFallbackChanged: _setRightFallback,
            ),
            if (song.source.isNotEmpty)
              _SongSource(song: song, bodyStyle: textStyle),
          ],
        ),
      ),
    );
  }
}

class _SongSource extends StatelessWidget {
  const _SongSource({required this.song, required this.bodyStyle});

  final Song song;
  final TextStyle bodyStyle;

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
            style: reader
                .sourceStyle(bodyStyle.fontSize ?? 16)
                .copyWith(fontFamily: bodyStyle.fontFamily),
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
